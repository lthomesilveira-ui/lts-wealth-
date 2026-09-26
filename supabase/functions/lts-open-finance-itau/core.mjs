// Server-only, dependency-free Pluggy reader. Never creates, updates or deletes an Item.
export const VERSION = 'pluggy-itau-shadow-v1';
export class SafeError extends Error {
  constructor(code, status = 503) { super(code); this.code = code; this.status = status; }
}
export const textKey = v => String(v ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
export const numeric = v => typeof v === 'number' && Number.isFinite(v) ? v : null;
export const cents = v => numeric(v) === null ? null : Math.round((v + Math.sign(v) * Number.EPSILON) * 100);
export function dateOnly(v) {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}(?:T|$)/.test(v)) return null;
  const day = v.slice(0, 10);
  return !Number.isNaN(Date.parse(day)) && new Date(day).toISOString().slice(0, 10) === day ? day : null;
}
export function brazilDay(v) {
  if (!dateOnly(v)) return null;
  if (v.length === 10) return v;
  // Preserve the provider's raw date separately; timestamps are UTC per Pluggy docs.
  if (!/(Z|[+-]\d{2}:\d{2})$/.test(v)) return null;
  const d = new Date(v);
  if (Number.isNaN(d.getTime())) return null;
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric', month: '2-digit', day: '2-digit' }).format(d);
}
export function stable(value) {
  if (Array.isArray(value)) return '[' + value.map(stable).join(',') + ']';
  if (value && typeof value === 'object') return '{' + Object.keys(value).sort().map(k => JSON.stringify(k) + ':' + stable(value[k])).join(',') + '}';
  return JSON.stringify(value);
}
export async function hash(value) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(stable(value)))), b => b.toString(16).padStart(2, '0')).join('');
}
export function assertNoSecrets(value) {
  if (!value || typeof value !== 'object') return;
  for (const [key, val] of Object.entries(value)) {
    if (/^(client.?secret|client.?id|api.?key|access.?token|refresh.?token|authorization|password|credentials)$/i.test(key)) throw new SafeError('UNEXPECTED_SECRET_FIELD');
    assertNoSecrets(val);
  }
}
function id(v) { if (typeof v !== 'string' || !v || v.length > 200) throw new SafeError('INVALID_PROVIDER_ID'); return v; }
export class Pluggy {
  constructor(clientId, clientSecret, fetcher = fetch, deadline = Date.now() + 110000) {
    if (!clientId || !clientSecret) throw new SafeError('PLUGGY_SECRETS_REQUIRED', 409);
    this.clientId = clientId; this.clientSecret = clientSecret; this.fetcher = fetcher; this.deadline = deadline;
    this.apiKey = null; this.expires = 0;
  }
  async request(path, auth = false, retry = 0) {
    const allowed = /^\/(auth|accounts|investments|loans|bills|v2\/items|v2\/transactions|items\/[a-zA-Z0-9-]+(?:\/resources)?)(?:\?|$)/;
    if (!allowed.test(path) || path.includes('#') || path.includes('\\')) throw new SafeError('UNSAFE_PROVIDER_PATH');
    if (Date.now() > this.deadline) throw new SafeError('SYNC_TIME_BUDGET');
    if (!auth && (!this.apiKey || Date.now() > this.expires)) {
      const token = await this.request('/auth', true);
      if (typeof token.apiKey !== 'string' || !token.apiKey) throw new SafeError('INVALID_AUTH_RESPONSE');
      this.apiKey = token.apiKey; this.expires = Date.now() + 110 * 60000;
    }
    let res;
    try {
      res = await this.fetcher('https://api.pluggy.ai' + path, {
        method: auth ? 'POST' : 'GET', redirect: 'error', signal: AbortSignal.timeout(Math.min(15000, Math.max(1, this.deadline - Date.now()))),
        headers: auth ? { 'Content-Type': 'application/json' } : { 'X-API-KEY': this.apiKey },
        ...(auth ? { body: JSON.stringify({ clientId: this.clientId, clientSecret: this.clientSecret }) } : {})
      });
    } catch { throw new SafeError('PROVIDER_NETWORK_ERROR'); }
    if (res.status === 401 && !auth && retry === 0) { this.apiKey = null; return this.request(path, false, 1); }
    if ((res.status === 429 || res.status >= 500) && retry < 2) {
      const delay = Math.min(1500, Math.max(250, Number(res.headers.get('retry-after')) * 1000 || 500));
      await new Promise(r => setTimeout(r, delay)); return this.request(path, auth, retry + 1);
    }
    if (!res.ok) {
      // Do not propagate provider response bodies or headers: they can echo sensitive inputs.
      if (path.startsWith('/v2/items') && res.status === 403) throw new SafeError('ITEM_LIST_NOT_AVAILABLE', 409);
      throw new SafeError('PROVIDER_HTTP_' + res.status, 502);
    }
    try { return await res.json(); } catch { throw new SafeError('PROVIDER_INVALID_JSON'); }
  }
  async list(path, query, mode = 'page') {
    const base = new URLSearchParams(query).toString();
    let next = '?' + base, rows = [], seen = new Set();
    for (let page = 1; page <= 100; page++) {
      const suffix = mode === 'page' ? '?' + base + '&page=' + page + '&pageSize=500' : next;
      if (seen.has(suffix)) throw new SafeError('PROVIDER_CURSOR_LOOP');
      seen.add(suffix);
      const data = await this.request(path + suffix);
      if (!Array.isArray(data.results)) throw new SafeError('PROVIDER_INVALID_PAGE');
      rows.push(...data.results);
      if (rows.length > 40000) throw new SafeError('PROVIDER_RECORD_LIMIT');
      if (mode === 'cursor') {
        if (data.next === null) return rows;
        if (typeof data.next !== 'string' || !data.next.startsWith('?') || data.next.includes('#')) throw new SafeError('PROVIDER_INVALID_CURSOR');
        // Reject a provider cursor that silently changes its account/item scope.
        const q = new URLSearchParams(data.next);
        for (const [key, val] of Object.entries(query)) if (q.get(key) !== val) throw new SafeError('PROVIDER_CURSOR_SCOPE');
        next = data.next;
      } else {
        if (!Number.isInteger(data.totalPages) || data.totalPages < 0 || (data.page !== page && data.totalPages !== 0)) throw new SafeError('PROVIDER_INVALID_PAGE');
        if (mode === 'single' && data.totalPages > 1) throw new SafeError('UNEXPECTED_ACCOUNT_PAGINATION');
        if (page >= data.totalPages) {
          if (Number.isInteger(data.total) && rows.length !== data.total) throw new SafeError('PROVIDER_INCOMPLETE_PAGE_SET');
          return rows;
        }
      }
    }
    throw new SafeError('PROVIDER_PAGE_LIMIT');
  }
  async existingItem(explicitId) {
    let itemId = explicitId;
    if (!itemId) {
      const items = await this.list('/v2/items', {}, 'cursor');
      const proxy = items.filter(i => textKey(i.connector?.name) === 'meupluggy' || textKey(i.connector?.name) === 'meu pluggy');
      if (proxy.length !== 1) throw new SafeError('EXISTING_ITEM_ID_REQUIRED', 409);
      itemId = proxy[0].id;
    }
    if (!/^[0-9a-f-]{36}$/i.test(itemId)) throw new SafeError('INVALID_ITEM_ID', 400);
    const item = await this.request('/items/' + itemId);
    if (item.id !== itemId || !['meupluggy', 'meu pluggy'].includes(textKey(item.connector?.name))) throw new SafeError('NOT_MEUPLUGGY_PROXY', 409);
    if (item.connector?.isSandbox) throw new SafeError('SANDBOX_NOT_REAL_DATA', 409);
    if (item.status !== 'UPDATED' || item.executionStatus !== 'SUCCESS') throw new SafeError('ITEM_NOT_READY', 409);
    if (item.consentExpiresAt && Date.parse(item.consentExpiresAt) <= Date.now()) throw new SafeError('CONSENT_EXPIRED', 409);
    return item;
  }
}
export async function normalize(kind, raw, ctx) {
  assertNoSecrets(raw);
  const rid = id(raw.id);
  if (raw.itemId && raw.itemId !== ctx.item.id) throw new SafeError('PROVIDER_ITEM_SCOPE');
  if (raw.accountId && ctx.account && raw.accountId !== ctx.account.id) throw new SafeError('PROVIDER_ACCOUNT_SCOPE');
  const account = ctx.account ?? raw;
  const n = { version: VERSION, provider_id: rid, institution: 'Itaú', institution_basis: ctx.institutionBasis,
    item_id: ctx.item.id, provider_account_id: ctx.account?.id ?? (['account', 'balance', 'credit_card'].includes(kind) ? rid : null),
    name: raw.name ?? raw.productName ?? null, currency: raw.currencyCode ?? raw.totalAmountCurrencyCode ?? null,
    as_of: raw.date ?? null, provider_updated_at: raw.updatedAt ?? null, source_sync_at: ctx.item.lastUpdatedAt ?? null,
    amount: null, layer: kind, warnings: [], official_effect: false };
  if (['account', 'balance', 'credit_card'].includes(kind)) {
    Object.assign(n, { amount: numeric(raw.balance), account_number: raw.number ?? null, account_type: raw.subtype ?? null,
      as_of: raw.updatedAt ?? null, available_balance: kind === 'credit_card' ? null : numeric(raw.balance),
      balance_semantics: kind === 'credit_card' ? 'provider_card_balance_not_bill_total' : 'available_bank_balance',
      closing_balance: numeric(raw.bankData?.closingBalance), automatically_invested_balance: numeric(raw.bankData?.automaticallyInvestedBalance),
      last4: kind === 'credit_card' ? String(raw.number ?? '').replace(/\D/g, '').slice(-4) || null : null,
      brand: raw.creditData?.brand ?? null, due_date: dateOnly(raw.creditData?.balanceDueDate),
      available_credit_limit: numeric(raw.creditData?.availableCreditLimit) });
    if (!n.as_of) n.warnings.push('position_date_unreported_item_sync_is_separate');
  } else if (['transaction', 'card_transaction'].includes(kind)) {
    const card = kind === 'card_transaction', value = numeric(raw.amountInAccountCurrency) ?? numeric(raw.amount);
    const effectiveCurrency = numeric(raw.amountInAccountCurrency) !== null ? account.currencyCode : raw.currencyCode;
    const signed = value === null ? null : card ? -value : raw.type === 'DEBIT' ? -Math.abs(value) : raw.type === 'CREDIT' ? Math.abs(value) : null;
    Object.assign(n, { amount: signed, provider_amount: numeric(raw.amount), currency: effectiveCurrency ?? null,
      date: brazilDay(raw.date), provider_date: raw.date ?? null, provider_civil_date: dateOnly(raw.date), date_basis: 'America/Sao_Paulo',
      description: raw.descriptionRaw ?? raw.description ?? '', status: raw.status ?? null,
      provider_transaction_id: raw.providerId ?? null, provider_code: raw.providerCode ?? null,
      account_type: account.subtype ?? null, account_number: account.number ?? null,
      last4: card ? String(account.number ?? '').replace(/\D/g, '').slice(-4) || null : null,
      card_name: card ? account.name : null, bill_id: raw.creditCardMetadata?.billId ?? null,
      installment_number: raw.creditCardMetadata?.installmentNumber ?? null,
      total_installments: raw.creditCardMetadata?.totalInstallments ?? null,
      operation_type: raw.operationType ?? null,
      layer: card ? (/PAGAMENTO/.test(raw.operationType ?? '') ? 'card_payment_evidence' : 'card_consumption') : 'bank_cash' });
    if (!n.date) n.warnings.push('unresolved_posting_date');
    if (n.date && n.date !== n.provider_civil_date) n.warnings.push('utc_date_differs_from_brazil_day');
    if (n.amount === null) n.warnings.push('unresolved_amount_or_sign');
    if (!card && value !== null && ((raw.type === 'DEBIT' && value > 0) || (raw.type === 'CREDIT' && value < 0))) n.warnings.push('provider_sign_type_disagreement');
  } else if (kind === 'invoice') {
    Object.assign(n, { amount: numeric(raw.totalAmount), date: dateOnly(raw.dueDate), due_date: dateOnly(raw.dueDate),
      closing_date: dateOnly(raw.billClosingDate), last4: String(account.number ?? '').replace(/\D/g, '').slice(-4) || null,
      card_name: account.name ?? null, payments: raw.payments ?? null, finance_charges: raw.financeCharges ?? null,
      settlement_status: 'not_inferred', layer: 'card_invoice_obligation' });
  } else if (kind === 'investment') {
    Object.assign(n, { amount: numeric(raw.balance), net_valuation: numeric(raw.balance), gross_valuation: numeric(raw.amount),
      withdrawal_available: numeric(raw.amountWithdrawal), taxes: numeric(raw.taxes), taxes2: numeric(raw.taxes2),
      original_amount: numeric(raw.amountOriginal), code: raw.code ?? null, subtype: raw.subtype ?? null,
      due_date: dateOnly(raw.dueDate), grace_period_date: dateOnly(raw.gracePeriodDate),
      liquidity: raw.liquidity ?? null, liquidity_status: raw.liquidity == null ? 'not_reported_by_documented_schema' : 'provider_field_uninterpreted', status: raw.status ?? null,
      amount_semantics: 'net_valuation' });
    if (n.withdrawal_available === null) n.warnings.push('withdrawal_unreported');
    if (!n.as_of) n.warnings.push('position_date_unreported');
  } else if (kind === 'loan') {
    Object.assign(n, { amount: numeric(raw.payments?.contractOutstandingBalance), contract_ref: raw.contractNumber ?? null,
      ipoc_code: raw.ipocCode ?? null, contract_amount: numeric(raw.contractAmount), loan_kind: raw.kind ?? null,
      due_date: dateOnly(raw.dueDate), amount_semantics: 'outstanding_balance_not_contract_amount' });
  }
  if (!n.currency) n.warnings.push('currency_unreported');
  return { resource_type: kind, provider_record_id: ctx.item.id + ':' + rid, provider_account_ref: n.provider_account_id,
    signed_amount: n.amount, currency: n.currency ?? 'XXX', occurred_at: ['transaction', 'card_transaction'].includes(kind) && n.date ? raw.date : null,
    posting_date: n.date ?? null, reference_month: null, description_raw: n.description ?? n.name,
    provider_updated_at: raw.updatedAt ?? null, raw_hash: await hash(raw), raw_payload: raw, normalized_payload: n };
}
export async function collect(pluggy, item, bindingIsExplicit = false, onValidated = async () => {}) {
  const accountRows = await pluggy.list('/accounts', { itemId: item.id }, 'single');
  const bankCodes = accountRows.filter(a => a.type === 'BANK').map(a => String(a.bankData?.transferNumber ?? '').match(/^(\d{3})\//)?.[1]).filter(Boolean);
  if (bankCodes.some(c => c !== '341')) throw new SafeError('INSTITUTION_CONFLICT', 409);
  const positiveEvidence = bankCodes.includes('341') || accountRows.some(a => /\bitau\b/.test(textKey(a.name + ' ' + (a.marketingName ?? ''))));
  if (!bindingIsExplicit && !positiveEvidence) throw new SafeError('ITAU_ITEM_BINDING_REQUIRED', 409);
  const institutionBasis = positiveEvidence ? 'provider_institution_evidence' : 'operator_selected_existing_itau_proxy';
  await onValidated(institutionBasis);
  const records = [], coverage = [];
  const seen = new Map();
  const add = async (kind, rows, account) => {
    for (const row of rows) {
      const n = await normalize(kind, row, { item, account, institutionBasis });
      const key = kind + ':' + n.provider_record_id;
      if (seen.has(key)) { if (seen.get(key) !== n.raw_hash) throw new SafeError('PROVIDER_DUPLICATE_CONFLICT'); continue; }
      seen.set(key, n.raw_hash); records.push(n);
    }
  };
  coverage.push({ product: 'accounts', status: 'available', count: accountRows.filter(a => a.type === 'BANK').length });
  coverage.push({ product: 'cards', status: 'available', count: accountRows.filter(a => a.type === 'CREDIT').length });
  const safeRead = async (product, path, query, mode, kind, account) => {
    try {
      const rows = await pluggy.list(path, query, mode);
      await add(kind, rows, account);
      coverage.push({ product, account_id: account?.id ?? null, status: rows.length ? 'available' : 'empty', count: rows.length });
    } catch (e) {
      if (!(e instanceof SafeError)) throw new SafeError('COLLECTION_FAILURE');
      coverage.push({ product, account_id: account?.id ?? null, status: 'unavailable', error_code: e.code, count: null });
    }
  };
  for (const a of accountRows) {
    if (!['BANK', 'CREDIT'].includes(a.type)) throw new SafeError('UNKNOWN_ACCOUNT_TYPE');
    await add(a.type === 'CREDIT' ? 'credit_card' : 'account', [a]);
    if (a.type === 'BANK') await add('balance', [a]);
    await safeRead(a.type === 'CREDIT' ? 'card_transactions' : 'transactions', '/v2/transactions', { accountId: a.id }, 'cursor', a.type === 'CREDIT' ? 'card_transaction' : 'transaction', a);
    if (a.type === 'CREDIT') await safeRead('invoices', '/bills', { accountId: a.id }, 'page', 'invoice', a);
  }
  await safeRead('investments', '/investments', { itemId: item.id }, 'page', 'investment');
  await safeRead('loans', '/loans', { itemId: item.id }, 'single', 'loan');
  const end = await pluggy.request('/items/' + item.id);
  if (end.status !== 'UPDATED' || end.executionStatus !== 'SUCCESS' || end.lastUpdatedAt !== item.lastUpdatedAt) throw new SafeError('PROVIDER_CHANGED_DURING_SYNC');
  return { records, coverage, institutionBasis, status: coverage.some(c => c.status === 'unavailable') ? 'partial' : 'success' };
}
export function reconcile(record, sources) {
  const n = record.normalized_payload, kind = record.resource_type;
  const pool = sources.filter(s => s.kind === kind);
  const out = (classification, candidates, reason) => ({ classification, reason, candidates: candidates.map(s => ({
    table: s.table, ref: s.ref, date: s.date ?? null, amount: s.amount ?? null, identity: s.identity ?? null,
    delta: cents(n.amount) !== null && cents(s.amount) !== null ? (cents(n.amount) - cents(s.amount)) / 100 : null,
    scope: s.scope ?? null })) });
  if (!n.currency || n.amount === null || n.warnings.includes('provider_sign_type_disagreement') || (['transaction', 'card_transaction'].includes(kind) && (!n.date || n.status !== 'POSTED'))) return out('conflict', [], 'incomplete_or_pending_provider_record');
  const explicit = pool.filter(s => s.provider_id && [n.provider_id, n.provider_transaction_id].filter(Boolean).includes(s.provider_id));
  const sameAmount = s => cents(s.amount) === cents(n.amount);
  const sameDate = s => Boolean(s.date && (n.date ?? dateOnly(n.as_of)) === s.date);
  if (explicit.length) return out(explicit.length === 1 && sameAmount(explicit[0]) && sameDate(explicit[0]) && explicit[0].currency === n.currency ? 'exact' : 'conflict', explicit, 'provider_identity_comparison');
  const matches = pool.filter(s => {
    if (s.currency !== n.currency || textKey(s.institution) !== textKey(n.institution)) return false;
    if (kind === 'account' || kind === 'balance') return n.account_type === 'CHECKING_ACCOUNT' && s.account_type === 'checking';
    if (kind === 'credit_card') return Boolean((n.last4 && n.last4 === s.last4) || textKey(n.name) === textKey(s.name));
    if (kind === 'transaction') return sameDate(s) && (sameAmount(s) || (textKey(n.description) && textKey(n.description) === textKey(s.description)));
    if (kind === 'card_transaction') return sameDate(s) && Boolean(n.last4 && n.last4 === s.last4) && (sameAmount(s) || textKey(n.description) === textKey(s.description));
    if (kind === 'invoice') return sameDate(s) && Boolean((n.last4 && n.last4 === s.last4) || textKey(n.card_name) === textKey(s.name));
    if (kind === 'investment') return Boolean((n.code && n.code === s.code) || textKey(n.name) === textKey(s.name));
    if (kind === 'loan') return Boolean(n.contract_ref && n.contract_ref === s.contract_ref);
    return false;
  });
  if (!matches.length) return out('new', [], 'not_found_in_consulted_lts_sources');
  if (matches.length > 1) return out('conflict', matches, 'ambiguous_lts_candidates');
  const s = matches[0];
  if (sameDate(s) && !sameAmount(s)) return out('conflict', matches, 'same_date_different_amount');
  // A bank label or an equal amount is not an immutable account/transaction identity.
  const identityExact = kind === 'loan' ? n.contract_ref === s.contract_ref : kind === 'investment' ? Boolean(n.code && n.code === s.code && s.amount_semantics === 'net_valuation') : false;
  if (identityExact && sameDate(s) && sameAmount(s)) return out('exact', matches, 'documented_identity_date_currency_amount');
  return out('candidate', matches, sameDate(s) ? 'identity_requires_review' : 'position_dates_differ_or_unknown');
}
export function enforceOneToOne(records) {
  const refs = new Map();
  for (const r of records) for (const c of r.reconciliation.candidates) {
    // Account metadata and its balance observation deliberately describe different layers.
    const key = r.resource_type + ':' + c.table + ':' + c.ref;
    const list = refs.get(key) ?? []; list.push(r); refs.set(key, list);
  }
  for (const list of refs.values()) if (list.length > 1) for (const r of list) {
    r.reconciliation.classification = 'conflict'; r.reconciliation.reason = 'multiple_provider_records_share_lts_candidate';
  }
  return records;
}
