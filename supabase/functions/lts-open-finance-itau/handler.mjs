import { VERSION, SafeError, Pluggy, collect, reconcile, enforceOneToOne, dateOnly } from './core.mjs';

const RPCS = new Set(['lts_open_finance_pilot_owner_v1', 'lts_open_finance_begin_itau_v1', 'lts_open_finance_sources_v1',
  'lts_open_finance_stage_batch_v1', 'lts_open_finance_finish_itau_v1', 'lts_open_finance_report_itau_v1', 'lts_open_finance_consume_job_v1']);
const ORIGINS = new Set(['https://lthomesilveira-ui.github.io', 'https://supabase.com']);
function safeCode(e) { return e instanceof SafeError && /^[A-Z0-9_]{1,80}$/.test(e.code) ? e.code : 'INTERNAL_ERROR'; }
export function makeHandler(env, fetcher = fetch) {
  const supabaseUrl = env('SUPABASE_URL'), service = env('SUPABASE_SERVICE_ROLE_KEY');
  const headers = { apikey: service, Authorization: 'Bearer ' + service, 'Content-Type': 'application/json' };
  const status = () => ({ client_id_configured: Boolean(env('PLUGGY_CLIENT_ID')), client_secret_configured: Boolean(env('PLUGGY_CLIENT_SECRET')),
    item_id_configured: Boolean(env('PLUGGY_ITAU_ITEM_ID')), promotion_enabled: false, version: VERSION });
  const rpc = async (name, data = {}) => {
    if (!RPCS.has(name)) throw new SafeError('UNSUPPORTED_DATABASE_OPERATION');
    let r;
    try { r = await fetcher(supabaseUrl + '/rest/v1/rpc/' + name, { method: 'POST', headers, body: JSON.stringify(data), redirect: 'error', signal: AbortSignal.timeout(30000) }); }
    catch { throw new SafeError('DATABASE_NETWORK_ERROR'); }
    if (!r.ok) {
      // Map only a closed list of known database errors; never echo SQL details/payloads.
      const body = await r.json().catch(() => ({}));
      const known = ['SYNC_ALREADY_RUNNING', 'PILOT_OWNER_AMBIGUOUS', 'PILOT_ALREADY_BOUND_TO_DIFFERENT_ITEM', 'RUN_OWNER_MISMATCH'];
      throw new SafeError(known.includes(body.message) ? body.message : 'DATABASE_OPERATION_FAILED', 409);
    }
    return r.json();
  };
  return async req => {
    const origin = req.headers.get('origin');
    const out = (body, code = 200) => new Response(JSON.stringify(body), { status: code, headers: {
      'Content-Type': 'application/json', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff',
      'Access-Control-Allow-Origin': ORIGINS.has(origin) ? origin : 'https://lthomesilveira-ui.github.io',
      'Access-Control-Allow-Methods': 'POST, OPTIONS', 'Access-Control-Allow-Headers': 'authorization,apikey,content-type', 'Vary': 'Origin'
    } });
    if (origin && !ORIGINS.has(origin)) return out({ error: 'ORIGIN_NOT_ALLOWED' }, 403);
    if (req.method === 'OPTIONS') return out({}, 200);
    if (req.method !== 'POST') return out({ error: 'METHOD_NOT_ALLOWED' }, 405);
    let run = null, userId = null;
    try {
      if (!supabaseUrl || !service) throw new SafeError('SERVER_CONFIGURATION_MISSING');
      const auth = req.headers.get('authorization') ?? '';
      if (!/^Bearer .+$/i.test(auth)) throw new SafeError('UNAUTHORIZED', 401);
      const token = auth.slice(7), jobToken = req.headers.get('x-lts-of-job');
      // Platform verify_jwt is on. Also check the live owner identity in the handler.
      let user = null, job = null;
      if (jobToken) {
        if (!/^[0-9a-f]{64}$/.test(jobToken)) throw new SafeError('UNAUTHORIZED', 401);
        job = await rpc('lts_open_finance_consume_job_v1', { p_token: jobToken });
        if (!job?.user_id) throw new SafeError('UNAUTHORIZED', 401);
      } else if (token !== service) {
        const r = await fetcher(supabaseUrl + '/auth/v1/user', { headers: { apikey: service, Authorization: auth }, redirect: 'error', signal: AbortSignal.timeout(15000) });
        if (!r.ok) throw new SafeError('UNAUTHORIZED', 401);
        user = await r.json();
        if (!user?.id) throw new SafeError('UNAUTHORIZED', 401);
      }
      userId = await rpc('lts_open_finance_pilot_owner_v1');
      if ((user && user.id !== userId) || (job && job.user_id !== userId)) throw new SafeError('FORBIDDEN', 403);
      const input = await req.text();
      if (input.length > 4096) throw new SafeError('REQUEST_TOO_LARGE', 413);
      let body; try { body = JSON.parse(input); } catch { throw new SafeError('INVALID_JSON', 400); }
      if (!body || typeof body !== 'object' || Array.isArray(body)) throw new SafeError('INVALID_JSON', 400);
      if (Object.keys(body).some(k => !['action', 'run_id', 'offset'].includes(k))) throw new SafeError('UNSUPPORTED_INPUT_FIELD', 400);
      if (job && body.action !== job.action) throw new SafeError('JOB_ACTION_MISMATCH', 403);
      if (body.action === 'status') return out({ ...status(), report: await rpc('lts_open_finance_report_itau_v1', { p_user_id: userId }) });
      if (body.action === 'report') {
        if (body.run_id && !/^[0-9a-f-]{36}$/i.test(body.run_id)) throw new SafeError('INVALID_RUN_ID', 400);
        if (body.offset !== undefined && (!Number.isInteger(body.offset) || body.offset < 0)) throw new SafeError('INVALID_OFFSET', 400);
        return out(await rpc('lts_open_finance_report_itau_v1', { p_user_id: userId, p_run_id: body.run_id ?? null, p_offset: body.offset ?? 0 }));
      }
      if (!['discover', 'sync'].includes(body.action)) throw new SafeError('UNSUPPORTED_ACTION', 400);
      const cfg = status();
      if (!cfg.client_id_configured || !cfg.client_secret_configured) return out({ error: 'PLUGGY_SECRETS_REQUIRED', ...cfg }, 409);
      const pluggy = new Pluggy(env('PLUGGY_CLIENT_ID'), env('PLUGGY_CLIENT_SECRET'), fetcher);
      let binding = env('PLUGGY_ITAU_ITEM_ID');
      if (!binding) {
        const r = await fetcher(supabaseUrl + '/rest/v1/lts_open_finance_connection?select=provider_connection_ref&user_id=eq.' + encodeURIComponent(userId) + '&provider=eq.pluggy&institution_code=eq.341&status=not.in.(disabled,revoked)', { headers, redirect: 'error', signal: AbortSignal.timeout(15000) });
        if (!r.ok) throw new SafeError('BINDING_READ_FAILED');
        const rows = await r.json();
        if (!Array.isArray(rows) || rows.length > 1) throw new SafeError('EXISTING_ITEM_ID_REQUIRED', 409);
        binding = rows[0]?.provider_connection_ref;
      }
      const item = await pluggy.existingItem(binding);
      const itemSummary = { id: item.id, status: item.status, executionStatus: item.executionStatus,
        lastUpdatedAt: item.lastUpdatedAt ?? null, consentExpiresAt: item.consentExpiresAt ?? null,
        products: item.products ?? [], resourcesCollectedAt: item.resourcesCollectedAt ?? null, connector_name: item.connector.name };
      if (body.action === 'discover') return out({ item: itemSummary, itau_binding_verified: false, promotion_enabled: false });
      const startedAt = Date.now();
      const data = await collect(pluggy, item, Boolean(binding), async institutionBasis => {
        run = await rpc('lts_open_finance_begin_itau_v1', { p_user_id: userId, p_item_id: item.id,
          p_item: { ...itemSummary, institution_basis: institutionBasis }, p_request_id: crypto.randomUUID() });
      });
      const days = data.records.map(r => r.normalized_payload.date ?? dateOnly(r.normalized_payload.as_of)).filter(Boolean).sort();
      // Fetch complete bounded source windows. No silent REST row cap, and no old-history rewrite.
      const from = days[0] ?? new Date().toISOString().slice(0,10), to = days.at(-1) ?? from;
      const sources = new Map(), windows = [];
      for (let start = from; start <= to;) {
        if (Date.now() - startedAt > 110000) throw new SafeError('SYNC_TIME_BUDGET');
        const nextDate = new Date(start + 'T12:00:00Z'); nextDate.setUTCDate(nextDate.getUTCDate() + 31);
        const end = nextDate.toISOString().slice(0,10) < to ? nextDate.toISOString().slice(0,10) : to;
        const snapshot = await rpc('lts_open_finance_sources_v1', { p_user_id: userId, p_from: start, p_to: end });
        if (!snapshot.complete_for_consulted_sources || !Array.isArray(snapshot.rows)) throw new SafeError('INCOMPLETE_LTS_SOURCE_READ');
        for (const row of snapshot.rows) sources.set(row.kind + ':' + row.table + ':' + row.ref, row);
        windows.push({ from: start, to: end, source_as_of: snapshot.source_as_of });
        const next = new Date(end + 'T12:00:00Z'); next.setUTCDate(next.getUTCDate() + 1); start = next.toISOString().slice(0,10);
      }
      const sourceRows = [...sources.values()];
      for (const r of data.records) r.reconciliation = reconcile(r, sourceRows);
      enforceOneToOne(data.records);
      for (let i = 0; i < data.records.length; i += 100) await rpc('lts_open_finance_stage_batch_v1', {
        p_user_id: userId, p_connection_id: run.connection_id, p_run_id: run.run_id, p_records: data.records.slice(i, i + 100)
      });
      const result = await rpc('lts_open_finance_finish_itau_v1', { p_user_id: userId, p_run_id: run.run_id, p_status: data.status,
        p_metadata: { expected_count: data.records.length, coverage: data.coverage, source_windows: windows,
          item: itemSummary, source_count: sourceRows.length, institution_basis: data.institutionBasis,
          limitations: ['No financial promotion', 'No deletion inferred from a missing provider record', 'Investment liquidity unreported unless separately evidenced', 'Existing LTS sources are not universally certified'] },
        p_error_code: data.status === 'partial' ? 'PRODUCT_COVERAGE_INCOMPLETE' : null });
      run = null;
      return out(result);
    } catch (e) {
      const code = safeCode(e);
      if (run && userId) {
        try { await rpc('lts_open_finance_finish_itau_v1', { p_user_id: userId, p_run_id: run.run_id, p_status: 'failed', p_metadata: { expected_count: 0 }, p_error_code: code }); }
        catch { return out({ error: code, run_id: run.run_id, run_finalization_pending: true, promotion_enabled: false }, 503); }
      }
      return out({ error: code, run_id: run?.run_id ?? null, promotion_enabled: false }, e instanceof SafeError ? e.status : 503);
    }
  };
}
