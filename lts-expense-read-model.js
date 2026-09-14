/* Existing Despesas readers: pure normalization and request lifecycle.
 * No RPC names, network, database writes, browser storage or category mapping.
 * Accept only payloads already obtained through an authorized application path.
 */
(function (root, factory) {
  'use strict';
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.LTSExpenseReadModel = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';
  const MONTH_VERSION = 'expense-month-detail-v2-certified-category-allocation';
  const EXEC_VERSION = 'expense-executive-v12-cached-effective-contract';
  const PENDING = new Set(['', 'a classificar', '—', 'classificação pendente']);
  const LEVELS = new Set(['transaction', 'category_only', 'total_only']);
  const own = (o, k) => Object.prototype.hasOwnProperty.call(o, k);
  function freeze(value) {
    if (value && typeof value === 'object' && !Object.isFrozen(value)) {
      Object.values(value).forEach(freeze); Object.freeze(value);
    }
    return value;
  }
  const copy = value => JSON.parse(JSON.stringify(value));
  function record(value) {
    if (!value || typeof value !== 'object' || Array.isArray(value)) throw new TypeError('Expected object.');
    return value;
  }
  function date(value) {
    if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) throw new TypeError('Expected ISO date.');
    const time = Date.parse(value + 'T12:00:00Z');
    if (!Number.isFinite(time) || new Date(time).toISOString().slice(0, 10) !== value) throw new TypeError('Invalid date.');
    return value;
  }
  function monthEnd(month) {
    const d = new Date(date(month) + 'T12:00:00Z');
    d.setUTCMonth(d.getUTCMonth() + 1, 0); return d.toISOString().slice(0, 10);
  }
  function integer(value) {
    if (!Number.isSafeInteger(value) || value < 0) throw new TypeError('Expected nonnegative count.');
    return value;
  }
  function text(value, empty) {
    if (typeof value !== 'string' || (!empty && !value.trim())) throw new TypeError('Expected text.');
    return value; // Preserve the original spelling; never normalize the taxonomy.
  }
  function cents(value) {
    if (typeof value !== 'string' && typeof value !== 'number') throw new TypeError('Missing monetary value.');
    const s = String(value);
    if (!/^-?\d+(?:\.\d{1,2})?$/.test(s)) throw new TypeError('Expected exact decimal money, at most two decimals.');
    const [whole, fraction = ''] = s.replace(/^-/, '').split('.');
    const n = (BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0'))) * (s[0] === '-' ? -1n : 1n);
    if (n > BigInt(Number.MAX_SAFE_INTEGER) || n < BigInt(Number.MIN_SAFE_INTEGER)) throw new RangeError('Money exceeds exact range.');
    return Number(n);
  }
  function sum(values) {
    let n = 0;
    for (const v of values) { n += v; if (!Number.isSafeInteger(n)) throw new RangeError('Total exceeds exact range.'); }
    return n;
  }
  function selection(input) {
    record(input);
    const month = date(input.month), through = date(input.through);
    if (!month.endsWith('-01') || through < month || through > monthEnd(month)) throw new TypeError('Invalid month interval.');
    const category = input.category == null ? null : text(input.category, false);
    return freeze({month, through, category});
  }
  function keyFor(row, month) {
    // Exact report identity, NOT a guessed cross-source reconciliation link.
    return JSON.stringify([text(row.source_table, false), text(row.source_ref, false), date(month)]);
  }
  function normalizeMonth(payload, requested) {
    record(payload);
    if (payload.version !== MONTH_VERSION) throw new TypeError('Unsupported monthly reader contract.');
    const scope = selection({month: payload.month, through: payload.through, category: payload.category_filter});
    if (requested) {
      const wanted = selection(requested);
      if (JSON.stringify(scope) !== JSON.stringify(wanted)) throw new TypeError('Response differs from selected period/category.');
    }
    if (!Array.isArray(payload.items) || !Array.isArray(payload.categories)) throw new TypeError('Missing detail arrays.');
    const issues = [], add = (code, key) => issues.push({code, ...(key ? {key} : {})});
    const total = cents(payload.total), declaredRows = integer(payload.rows), identities = new Set();
    const rows = payload.items.map(raw => {
      record(raw);
      const eventDate = date(raw.event_date);
      // A historical category-only row need not identify a real purchase date.
      const transactionDate = raw.transaction_date == null ? null : date(raw.transaction_date);
      if (!LEVELS.has(raw.detail_level)) throw new TypeError('Unknown documentary detail level.');
      const key = keyFor(raw, scope.month), category = text(raw.category, true);
      if (identities.has(key)) add('duplicate_source', key);
      identities.add(key);
      if (eventDate < scope.month || eventDate > scope.through) add('outside_selected_period', key);
      if (scope.category !== null && category !== scope.category) add('wrong_category_filter', key);
      if (PENDING.has(category.trim().toLocaleLowerCase('pt-BR'))) add('category_pending', key);
      return {key, sourceTable: raw.source_table, sourceRef: raw.source_ref, eventDate, transactionDate,
        amountCents: cents(raw.amount), category, centerCost: raw.center_cost == null ? null : text(raw.center_cost, true),
        counterparty: raw.counterparty == null ? null : text(raw.counterparty, true), originType: text(raw.origin_type, false),
        originName: text(raw.origin_name, false), detailLevel: raw.detail_level, coverageMode: text(raw.coverage_mode, false),
        canOpenTransaction: raw.detail_level === 'transaction'};
    });
    if (declaredRows !== rows.length) add('row_count_mismatch');
    const actualTotal = sum(rows.map(r => r.amountCents));
    if (total !== actualTotal) add('detail_total_mismatch');
    const partial = scope.through !== monthEnd(scope.month);
    if (payload.is_partial !== partial) add('partial_period_flag_mismatch');
    const amounts = new Map();
    for (const row of rows) {
      if (row.detailLevel === 'total_only') continue;
      const prev = amounts.get(row.category) || {name: row.category, totalCents: 0, rows: 0};
      prev.totalCents = sum([prev.totalCents, row.amountCents]); prev.rows++; amounts.set(row.category, prev);
    }
    const categories = Array.from(amounts.values()).sort((a, b) => b.totalCents - a.totalCents || a.name.localeCompare(b.name, 'pt-BR'));
    const declaredCategories = new Map();
    for (const c of payload.categories) {
      record(c); const name = text(c.name, true);
      if (declaredCategories.has(name)) add('duplicate_category_summary', name);
      declaredCategories.set(name, {totalCents: cents(c.total), rows: integer(c.rows)});
    }
    for (const c of categories) {
      const d = declaredCategories.get(c.name);
      if (!d || d.totalCents !== c.totalCents || d.rows !== c.rows) add('category_summary_mismatch', c.name);
    }
    for (const name of declaredCategories.keys()) if (!amounts.has(name)) add('extra_category_summary', name);
    const unallocated = sum(rows.filter(r => r.detailLevel === 'total_only').map(r => r.amountCents));
    const allocated = sum(rows.filter(r => r.detailLevel === 'category_only').map(r => r.amountCents));
    if (cents(payload.category_unallocated_total) !== unallocated) add('unallocated_total_mismatch');
    if (cents(payload.category_allocated_history_total) !== allocated) add('allocated_total_mismatch');
    if (cents(payload.category_known_total) !== total - unallocated) add('known_category_total_mismatch');
    const integrity = issues.filter(x => x.code !== 'category_pending');
    return freeze({version: 'expense-month-read-model-v1', scope, rows, categories, declaredTotalCents: total,
      actualTotalCents: actualTotal, partial, issues, internallyConsistent: integrity.length === 0,
      missingCategoryRows: issues.filter(x => x.code === 'category_pending').length,
      totalOnlyRows: rows.filter(r => r.detailLevel === 'total_only').length,
      categoryOnlyRows: rows.filter(r => r.detailLevel === 'category_only').length,
      sourceParityVerified: false, definitiveReportReady: false});
  }
  function compareExecutiveMonth(executive, detail) {
    record(executive);
    if (executive.version !== EXEC_VERSION || detail.version !== 'expense-month-read-model-v1') throw new TypeError('Unsupported reader contracts.');
    record(executive.period); record(executive.summary);
    const from = date(executive.period.from), to = date(executive.period.to), issues = [];
    if (detail.scope.category !== null || from !== detail.scope.month || to !== detail.scope.through) {
      return freeze({comparable: false, agreement: false, sourceParityVerified: false, issues: [{code: 'different_selection'}]});
    }
    if (!Array.isArray(executive.monthly_detail)) throw new TypeError('Missing executive month array.');
    const entries = executive.monthly_detail.filter(m => m.month === detail.scope.month);
    if (entries.length !== 1) issues.push({code: 'executive_month_missing_or_duplicated'});
    else {
      if (cents(entries[0].total) !== detail.declaredTotalCents) issues.push({code: 'executive_month_total_mismatch'});
      if (integer(entries[0].rows) !== detail.rows.length) issues.push({code: 'executive_month_rows_mismatch'});
    }
    if (cents(executive.summary.selected_total) !== detail.declaredTotalCents) issues.push({code: 'executive_selected_total_mismatch'});
    // Rankings are intentionally limited by the existing backend. Check displayed
    // rows, but never treat an omitted rank as a zero-valued category.
    const ranks = executive.rankings && executive.rankings.categories;
    if (!Array.isArray(ranks)) throw new TypeError('Missing category ranking.');
    const seen = new Set(), known = new Map(detail.categories.map(c => [c.name, c]));
    for (const r of ranks) {
      const name = text(r.name, true), c = known.get(name);
      if (seen.has(name)) issues.push({code: 'duplicate_executive_rank', key: name});
      seen.add(name);
      if (!c || cents(r.total) !== c.totalCents || integer(r.rows) !== c.rows) issues.push({code: 'executive_category_mismatch', key: name});
    }
    if (!detail.internallyConsistent) issues.push({code: 'monthly_detail_inconsistent'});
    const rawTimestamp = executive.data_quality && executive.data_quality.cache_refreshed_at;
    const cacheAsOf = typeof rawTimestamp === 'string' && Number.isFinite(Date.parse(rawTimestamp)) ? rawTimestamp : null;
    return freeze({comparable: true, agreement: issues.length === 0, issues, cacheAsOf,
      sourceParityVerified: false, definitiveReportReady: false});
  }
  function rangeSelection(input) {
    record(input); const from=date(input.from), to=date(input.to);
    if (from>to) throw new TypeError('Invalid inclusive interval.');
    return freeze({from,to});
  }
  function normalizeDual(payload, requested) {
    record(payload);
    if (payload.version !== 'expense-dual-lens-v2-recent-cash') throw new TypeError('Unsupported cash/consumption contract.');
    const scope=rangeSelection(payload);
    if (requested && JSON.stringify(scope)!==JSON.stringify(rangeSelection(requested))) throw new TypeError('Response differs from selected interval.');
    const cash=record(payload.cash), cons=record(payload.consumption);
    for(const array of [cash.buckets,cash.monthly,cash.recent,cons.categories,cons.monthly]) if(!Array.isArray(array))throw new TypeError('Missing lens arrays.');
    const issues=[], add=code=>issues.push({code});
    const gross=cents(cash.gross_outflows), transfers=cents(cash.own_transfers), spend=cents(cash.spend_outflows);
    const pendingCash=cents(cash.pending_reconciliation), consumed=cents(cons.total), pendingCons=cents(cons.unclassified);
    const buckets=cash.buckets.map(b=>{
      if(typeof b.excluded_from_spend!=='boolean')throw new TypeError('Missing documented cash treatment.');
      return {name:text(b.bucket,false),rows:integer(b.rows),totalCents:cents(b.total),excluded:b.excluded_from_spend};
    });
    const categories=cons.categories.map(c=>({name:text(c.category,true),rows:integer(c.rows),totalCents:cents(c.total)}))
      .sort((a,b)=>b.totalCents-a.totalCents||a.name.localeCompare(b.name,'pt-BR'));
    if(new Set(buckets.map(b=>b.name)).size!==buckets.length)add('duplicate_cash_bucket');
    if(new Set(categories.map(c=>c.name)).size!==categories.length)add('duplicate_consumption_category');
    if(sum([spend,transfers])!==gross || sum(buckets.map(b=>b.totalCents))!==gross)add('cash_total_mismatch');
    if(sum(buckets.filter(b=>b.excluded).map(b=>b.totalCents))!==transfers)add('cash_treatment_mismatch');
    if(sum(categories.map(c=>c.totalCents))!==consumed)add('consumption_total_mismatch');
    if(sum(categories.map(c=>c.rows))!==integer(cons.rows))add('consumption_row_count_mismatch');
    if(sum(categories.filter(c=>c.name.trim().toLocaleLowerCase('pt-BR')==='a classificar').map(c=>c.totalCents))!==pendingCons)add('pending_consumption_mismatch');
    const monthly=(array)=>{
      const map=new Map();
      for(const item of array){const month=date(item.month);if(!month.endsWith('-01'))throw new TypeError('Invalid monthly key.');
        if(month<scope.from.slice(0,7)+'-01'||month>scope.to.slice(0,7)+'-01')add('monthly_point_outside_interval');
        if(map.has(month))add('duplicate_monthly_point');
        map.set(month,cents(item.total));}
      return map;
    };
    const cashMonth=monthly(cash.monthly), consMonth=monthly(cons.monthly);
    if(sum(cashMonth.values())!==spend)add('cash_monthly_total_mismatch');
    if(sum(consMonth.values())!==consumed)add('consumption_monthly_total_mismatch');
    const seen=new Set();
    const recent=cash.recent.map(r=>{
      const day=date(r.date),key=JSON.stringify([text(r.source,false),text(r.source_ref,false),day]);
      if(seen.has(key))add('duplicate_recent_cash_source'); seen.add(key);
      if(day<scope.from||day>scope.to)add('recent_cash_outside_interval');
      if(typeof r.excluded_from_spend!=='boolean')throw new TypeError('Missing cash treatment.');
      return {key,date:day,description:text(r.description,true),account:r.account==null?null:text(r.account,true),
        amountCents:cents(r.amount),category:r.category==null?null:text(r.category,true),bucket:text(r.bucket,false),
        excluded:r.excluded_from_spend,evidenceStatus:text(r.evidence_status,false)};
    });
    const allCashRows=sum(buckets.map(b=>b.rows));
    if(recent.length>allCashRows || recent.length>120)add('recent_cash_count_mismatch');
    return freeze({version:'expense-dual-read-model-v1',scope,issues,internallyConsistent:issues.length===0,
      grossOutflowsCents:gross,ownTransfersCents:transfers,spendOutflowsCents:spend,consumptionCents:consumed,
      pendingCashCents:pendingCash,missingCategoryRows:sum(categories.filter(c=>PENDING.has(c.name.trim().toLocaleLowerCase('pt-BR'))).map(c=>c.rows)),
      buckets,categories,recentCash:recent,recentCashIsComplete:recent.length===allCashRows,
      monthly:Array.from(new Set([...cashMonth.keys(),...consMonth.keys()])).sort().map(month=>({month,
        cashCents:cashMonth.has(month)?cashMonth.get(month):null,consumptionCents:consMonth.has(month)?consMonth.get(month):null})),
      partialCalendarRange:scope.from.slice(8)!=='01'||scope.to!==monthEnd(scope.to.slice(0,7)+'-01'),
      sourceParityVerified:false,definitiveReportReady:false});
  }
  function createReadSession(options) {
    if (!options || typeof options.load !== 'function') throw new TypeError('Provide an authorized response loader.');
    const adapt = options.adapt || normalizeMonth, selectScope = options.selection || selection, listeners = new Set();
    let generation = 0, destroyed = false, active = null;
    let state = freeze({phase: 'idle', request: null, model: null, message: null});
    function emit(next) {
      state = freeze(next);
      // A view subscriber must not turn a successful read into a financial error.
      for (const fn of listeners) { try { fn(state); } catch (_) { /* isolate view callbacks */ } }
    }
    async function select(request) {
      if (destroyed) throw new Error('Session disposed.');
      const wanted = selectScope(request), seq = ++generation;
      if (active) active.abort();
      active = new AbortController(); const signal = active.signal;
      emit({phase: 'loading', request: wanted, model: null, message: 'Carregando despesas do período selecionado…'});
      try {
        const answer = await options.load(copy(wanted), {signal});
        if (destroyed || seq !== generation) return state;
        let payload = answer;
        if (answer && own(answer, 'error') && own(answer, 'data')) {
          if (answer.error) throw answer.error; payload = answer.data;
        }
        const model = adapt(payload, wanted);
        emit({phase: 'ready', request: wanted, model, message: null});
      } catch (error) {
        if (destroyed || seq !== generation) return state;
        const auth = error && (error.status === 401 || error.status === 403 || error.code === '42501');
        emit({phase: auth ? 'authentication_required' : 'error', request: wanted, model: null,
          message: auth ? 'Sua sessão precisa ser renovada para consultar as despesas.' : 'Não foi possível carregar este período. Nenhum valor foi substituído por zero.'});
      }
      return state;
    }
    function clear() {
      ++generation; if (active) active.abort(); active = null;
      emit({phase: 'idle', request: null, model: null, message: null});
    }
    return Object.freeze({select, getState: () => state,
      subscribe(fn) { if (destroyed || typeof fn !== 'function') throw new TypeError('Invalid subscriber.'); listeners.add(fn); return () => listeners.delete(fn); },
      invalidate: clear,
      dispose() { if (destroyed) return; clear(); destroyed = true; listeners.clear(); }});
  }
  function presentation(model) {
    if (!model || model.version !== 'expense-month-read-model-v1') throw new TypeError('Expected normalized month.');
    return freeze({title: 'Conferência de despesas',
      status: model.internallyConsistent ? 'Totais internos conferidos; conciliação da origem ainda pendente.' : 'Resumo e detalhamento divergem. Total indisponível até conferência.',
      totalCents: model.internallyConsistent ? model.declaredTotalCents : null,
      periodLabel: model.partial ? 'Mês parcial' : 'Mês completo no intervalo consultado',
      coverageLabel: model.totalOnlyRows ? 'Há valores históricos sem composição por categoria.' : model.categoryOnlyRows ? 'Parte do histórico tem categoria, mas não compras individuais.' : 'Linhas de transação disponíveis; cobertura documental ainda não certificada.',
      missingCategoryRows: model.missingCategoryRows, definitiveReportReady: false});
  }
  return Object.freeze({cents, date, selection, normalizeMonth, compareExecutiveMonth, normalizeDual, rangeSelection, createReadSession, presentation, keyFor});
});
