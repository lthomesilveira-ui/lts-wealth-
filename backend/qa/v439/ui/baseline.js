/* Projection amounts come from the owner-scoped server calculation. */
(function () {
  'use strict';
  function createAPI() {
    const invalid = () => { throw Error('Invalid projection response'); };
    const methods = new Set(['history_total_budget', 'fixed', 'salary_net', 'inflated_calendar', 'repeat_calendar']);
    function day(value) {
      if (typeof value !== 'string' || !/^\d{4}-\d\d-\d\d$/.test(value)) return invalid();
      const date = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(date.getTime()) || date.toISOString().slice(0, 10) !== value) return invalid();
      return value;
    }
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!['number', 'string'].includes(typeof value) || !/^\d+(?:\.\d{1,2})?$/.test(String(value))) return invalid();
      const [whole, fraction = ''] = String(value).split('.');
      const n = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (n > BigInt(Number.MAX_SAFE_INTEGER)) return invalid();
      return Number(n);
    }
    function windowDates(value) {
      if (!value) return invalid();
      const from = day(value.from), to = day(value.to);
      if (from > to) return invalid();
      return { from, to };
    }
    function build(payload) {
      if (!payload || payload.version !== 'projection-policy-v412') return invalid();
      if (payload.enabled === false) return null;
      if (payload.enabled !== true || payload.schema_version !== 1 || !Array.isArray(payload.series)
        || !Array.isArray(payload.warnings) || payload.card_method !== 'total_budget_floor'
        || payload.outliers_excluded !== false || payload.missing_months_assumed_zero !== false
        || payload.financial_sources_modified !== false) return invalid();
      const asOf = day(payload.as_of), horizon = day(payload.horizon_end), nextReview = day(payload.next_review_on);
      if (horizon !== (Number(asOf.slice(0, 4)) + 5) + '-12-31' || nextReview <= asOf) return invalid();
      const historyWindow = windowDates(payload.history_window), keys = new Set();
      const series = payload.series.map(row => {
        const expected = row?.expected_months;
        const cardBudget = row?.method === 'history_total_budget' && /^card_/.test(row?.series_key || '');
        if (!row || typeof row.series_key !== 'string' || !row.series_key.trim() || keys.has(row.series_key)
          || typeof row.description !== 'string' || !row.description.trim() || !methods.has(row.method)
          || !['income', 'expense'].includes(row.direction) || !(expected === 12 || expected === 3 && cardBudget)
          || !Number.isInteger(row.coverage_months) || row.coverage_months < 0 || row.coverage_months > expected
          || !Number.isInteger(row.observed_months) || row.observed_months < row.coverage_months || row.observed_months > expected
          || !Number.isInteger(row.months_with_spend) || row.months_with_spend < 0 || row.months_with_spend > row.observed_months
          || !Array.isArray(row.outlier_months) || !Array.isArray(row.warnings) || !Array.isArray(row.annual_totals)
          || typeof row.reference_stale !== 'boolean') return invalid();
        keys.add(row.series_key);
        const rate = Number(row.annual_rate);
        if (!Number.isFinite(rate) || rate < 0 || rate > .25 || row.method !== 'inflated_calendar' && rate !== 0) return invalid();
        const referenceWindow = windowDates(row.reference_window), amount = cents(row.reference_amount_brl, true);
        if (expected === 3) {
          const start = new Date(referenceWindow.from + 'T12:00:00Z');
          const end = new Date(start); end.setUTCMonth(end.getUTCMonth() + expected); end.setUTCDate(end.getUTCDate() - 1);
          if (!referenceWindow.from.endsWith('-01') || end.toISOString().slice(0, 10) !== referenceWindow.to
            || referenceWindow.to >= asOf.slice(0, 7) + '-01') return invalid();
        }
        if ((row.method === 'history_total_budget' || row.uses_history === true) && amount !== null && row.coverage_months < expected && !row.reference_stale) return invalid();
        return { key: row.series_key, description: row.description, method: row.method, direction: row.direction,
          account: String(row.account || ''), amount, rate, historyWindow: referenceWindow, referenceStale: row.reference_stale,
          templateYear: Number.isInteger(row.template_year) ? row.template_year : null,
          expected, covered: row.coverage_months, observed: row.observed_months, spendingMonths: row.months_with_spend, outliers: row.outlier_months.map(day),
          warnings: row.warnings.map(String), dueDayBasis: row.due_day_basis || null,
          usesHistory: row.uses_history === true || row.method === 'history_total_budget',
          annual: row.annual_totals.map(year => {
            if (!Number.isInteger(year.year) || year.year < Number(asOf.slice(0, 4)) || year.year > Number(horizon.slice(0, 4))
              || typeof year.partial_year !== 'boolean') return invalid();
            return { year: year.year, total: cents(year.budget_total_brl, true), additional: cents(year.additional_brl, true), partial: year.partial_year };
          }) };
      });
      return { asOf, horizon, nextReview, historyWindow, series, partialYear: payload.current_year_partial === true };
    }
    return { build, cents, day };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V412_PROJECTION?.installed) return;
    const api = factory(), previous = render, ui = window.__LTS_V168_STATE;
    const previousRange = loadFlowRange, previousRPC = S.rpc.bind(S);
    const state = { installed: true, status: 'idle', model: null, sequence: 0, readAt: 0, horizonKey: null, explicitRange: false, consumerSequence: 0 };
    let openingFullRange = false;
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity();
    const date = value => value.split('-').reverse().join('/');
    const money = value => value === null ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(value / 100);
    const el = (tag, text, className) => { const node = document.createElement(tag); if (text != null) node.textContent = text; if (className) node.className = className; return node; };
    function reset() {
      if (owner === identity() && D && !N.classList.contains('hidden')) return false;
      owner = identity(); state.sequence++; state.consumerSequence++; state.status = 'idle'; state.model = null; state.readAt = 0; state.horizonKey = null; state.explicitRange = false;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      return true;
    }
    function fullRange(model = state.model) {
      if (!model) return null;
      const from = new Date(model.asOf + 'T12:00:00Z'); from.setUTCDate(from.getUTCDate() - 5);
      return { from: from.toISOString().slice(0, 10), to: model.horizon,
        previousEnd: (Number(model.asOf.slice(0, 4)) + 4) + '-12-31' };
    }
    // Only the old automatic defaults are extended. Explicit user periods keep
    // the exact dates requested by the existing navigation and editor handlers.
    loadFlowRange = function (from, to) {
      const range = fullRange();
      if (window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action && !openingFullRange) state.explicitRange = true;
      if (range && from === range.from && to === range.previousEnd
        && !state.explicitRange && !window.__LTS_V382_FLOW_LAYOUT?.explicit_period_action) to = range.to;
      return previousRange.call(this, from, to);
    };
    S.rpc = function (name, args, ...rest) {
      const range = fullRange();
      if (range && args) {
        if (/^lts_browser_flow_v\d+$/.test(name) && V === 'Dashboard'
          && args.p_from === state.model.asOf && args.p_to === range.previousEnd) args = { ...args, p_to: range.to };
        if (/^lts_browser_recurring_future_gap_audit_v\d+$/.test(name)
          && args.p_as_of === state.model.asOf && args.p_horizon_end === range.previousEnd) args = { ...args, p_horizon_end: range.to };
      }
      return previousRPC(name, args, ...rest);
    };
    function openFullRange() {
      const range = fullRange(); if (!range) return;
      const layout = window.__LTS_V382_FLOW_LAYOUT, prior = layout?.explicit_period_action;
      state.explicitRange = false; openingFullRange = true;
      if (layout) layout.explicit_period_action = true;
      try { return loadFlowRange(range.from, range.to); }
      finally { openingFullRange = false; if (layout) layout.explicit_period_action = prior; }
    }
    async function refreshConsumers() {
      const model = state.model, generation = owner, token = ++state.consumerSequence;
      if (!model) return;
      const stillCurrent = () => generation === identity() && token === state.consumerSequence && state.model?.horizon === model.horizon;
      if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.loading = false; }
      const forecast = Promise.resolve(window.__LTS_V178_REVIEW?.refreshForecast?.()).catch(() => {});
      try {
        const response = await S.rpc('lts_browser_recurring_future_gap_audit_v5', { p_as_of: model.asOf, p_horizon_end: model.horizon });
        if (!stillCurrent()) return;
        if (response.error || !Array.isArray(response.data?.horizon_checks)) throw Error();
        if (ui?.updates) { ui.updates.recurring = response.data; ui.updates.error = null; }
        if (ui?.dashboard) { ui.dashboard.data ||= {}; ui.dashboard.data.recurring = response.data; }
      } catch { if (stillCurrent() && ui?.updates) ui.updates.error = 'Não foi possível atualizar as revisões. Tente novamente.'; }
      finally { await forecast; if (stillCurrent()) render(); }
    }
    function applyHorizon() {
      const range = fullRange(); if (!range) return;
      if (state.horizonKey !== range.to) {
        state.horizonKey = range.to;
        if (ui?.dashboard) { ui.dashboard.token = (ui.dashboard.token || 0) + 1; ui.dashboard.started = false; ui.dashboard.loading = false; }
        queueMicrotask(() => { if (state.model?.horizon === range.to) refreshConsumers(); });
      }
      if (V !== 'Fluxo Diário') return;
      for (const id of ['flowDefaultRange', 'goToday']) {
        const button = document.getElementById(id); if (!button) continue;
        if (id === 'flowDefaultRange') { button.textContent = '5 anteriores + fim de ' + range.to.slice(0, 4);
          button.title = 'Cinco dias anteriores e cinco anos futuros completos'; }
        button.onclick = openFullRange;
      }
      const year = document.getElementById('flowYear'), end = document.getElementById('flowTo');
      if (year && ![...year.options].some(option => option.value === range.to.slice(0, 4)))
        year.append(new Option(range.to.slice(0, 4), range.to.slice(0, 4)));
      if (end) end.max = range.to;
      if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING)
        queueMicrotask(() => { if (!state.explicitRange && FLOWFROM === range.from && FLOWTO === range.previousEnd && !FLOWLOADING) openFullRange(); });
    }
    function message(text) { const node = el('p', text, 'v412-warning'); node.setAttribute('role', 'status'); return node; }
    function warningTexts(model) {
      const texts = [];
      for (const row of model.series) {
        if (row.referenceStale) texts.push(row.description + ': usando a última média completa.');
        else if (row.warnings.includes('history_unavailable') || row.warnings.includes('partial_history')) texts.push(row.description + ': histórico incompleto.');
        if (row.warnings.includes('unreconciled_periods') || row.warnings.includes('calendar_unavailable')) texts.push(row.description + ': há previsões a conferir.');
      }
      return texts;
    }
    function methodText(row) {
      if (row.method === 'history_total_budget') return 'Média de ' + row.expected + ' meses completos' + (row.expected === 3 ? ', atualizada com as novas faturas.' : '.');
      if (row.method === 'inflated_calendar') return 'Reajuste estimado de ' + new Intl.NumberFormat('pt-BR', { style: 'percent', maximumFractionDigits: 2 }).format(row.rate) + ' ao ano. Cobranças confirmadas têm prioridade.';
      if (row.method === 'salary_net') return 'Salário previsto após o desconto do empréstimo em folha.';
      if (row.method === 'repeat_calendar') return 'Calendário e valores mantidos, sem aumento automático.';
      return 'Valor mantido, sem aumento automático.';
    }
    function origin(model) {
      const details = el('details', null, 'v412-origin'); details.append(el('summary', 'Premissas das projeções'));
      details.append(el('p', 'Planejamento até ' + date(model.horizon) + ', com extensão anual.'));
      warningTexts(model).forEach(text => details.append(message(text)));
      if (model.partialYear) details.append(el('p', 'O ano corrente considera somente as datas futuras; sua soma é parcial.'));
      for (const row of model.series) {
        const section = el('section', null, 'v412-rule'); section.append(el('h3', row.description));
        if (row.amount !== null) section.append(el('strong', money(row.amount) + (row.method === 'history_total_budget' ? ' · referência mensal' : ' · base nominal')));
        section.append(el('p', methodText(row)));
        if (row.templateYear !== null) section.append(el('p', 'Calendário de referência: ' + row.templateYear + '.'));
        if (row.usesHistory) {
          section.append(el('p', 'Janela da média: ' + date(row.historyWindow.from) + ' a ' + date(row.historyWindow.to) + '.'));
          if (row.referenceStale) section.append(el('p', 'Revisão atual com ' + row.covered + ' de ' + row.expected + ' meses cobertos. A última base completa continua em uso.'));
          else section.append(el('p', row.covered + ' de ' + row.expected + ' meses cobertos; ' + row.spendingMonths + ' meses com gasto.'));
          if (row.outliers.length) section.append(el('p', 'Valores atípicos foram mantidos na média. Meses: ' + row.outliers.map(x => x.slice(5, 7) + '/' + x.slice(0, 4)).join(', ') + '.'));
        }
        if (String(row.dueDayBasis || '').startsWith('history_modal_day')) section.append(el('p', 'Dia de planejamento estimado pela data mais frequente do histórico; uma data documentada tem prioridade.'));
        details.append(section);
      }
      details.append(el('p', 'Faturas fechadas prevalecem. Parcelas antigas de gastos não recorrentes continuam até terminar; as reservas de novas compras não são somadas duas vezes.'));
      return details;
    }
    function panel(compact) {
      const card = el('article', null, 'v412-policy' + (compact ? ' v412-compact' : ' v168-card'));
      card.dataset.v412Policy = compact ? 'flow' : 'updates';
      const header = el('div', null, 'v412-heading');
      header.append(el(compact ? 'strong' : 'h2', state.model ? 'Projeções até ' + date(state.model.horizon) : 'Projeções futuras'));
      const button = el('button', state.status === 'queued' ? 'Atualização em andamento…' : state.status === 'refreshing' ? 'Solicitando…' : 'Atualizar projeções', 'v168-btn');
      button.type = 'button'; button.dataset.v412Refresh = ''; button.disabled = ['loading', 'refreshing', 'queued'].includes(state.status); button.onclick = () => refresh(); header.append(button); card.append(header);
      if (state.status === 'error') card.append(message('Não foi possível conferir as projeções. Atualize antes de usar as estimativas.'));
      else if (!state.model) card.append(el('p', 'Conferindo as projeções…', 'v412-loading'));
      else { const warnings = warningTexts(state.model); if (warnings.length) card.append(message('Há estimativas a conferir nas premissas.')); card.append(origin(state.model)); }
      return card;
    }
    function patchDialog() {
      const dialog = document.getElementById('v366RecurringDialog'); if (!dialog) return;
      const horizon = state.model?.horizon || (Number(new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Sao_Paulo', year: 'numeric' }).format(new Date())) + 5) + '-12-31';
      for (const node of dialog.querySelectorAll('.v366-policy')) {
        if (node.textContent.startsWith('A continuidade cobre')) {
          const next = node.textContent.replace(/até o fim de \d{4}/, 'até ' + date(horizon));
          if (next !== node.textContent) node.textContent = next;
        }
      }
    }
    function paint() {
      reset(); if (!D || N.classList.contains('hidden')) return;
      document.querySelectorAll('[data-v412-policy]').forEach(node => node.remove());
      if (state.status !== 'disabled') {
        if (V === 'Fluxo Diário') { const parent = document.querySelector('.flow-sticky-controls'); if (parent) parent.after(panel(true)); }
        if (V === 'Atualizações') { const parent = document.querySelector('.v168-updates'); if (parent) parent.prepend(panel(false)); }
        if (V === 'Dashboard' && state.status === 'error') {
          const parent = document.querySelector('.v168-dashboard');
          if (parent) { const warning = panel(false); warning.dataset.v412Policy = 'dashboard-warning'; parent.prepend(warning); }
        }
      }
      applyHorizon();
      patchDialog();
      if (['Dashboard', 'Fluxo Diário', 'Atualizações'].includes(V)) queueMicrotask(() => load());
    }
    async function load(force = false, recalculate = false) {
      reset(); if (!D || N.classList.contains('hidden') || ['loading', 'refreshing', 'queued'].includes(state.status)
        || !force && Date.now() - state.readAt < 300000) return;
      const generation = owner, token = ++state.sequence;
      state.status = recalculate ? 'refreshing' : 'loading';
      if (recalculate) render();
      try {
        const response = await S.rpc(recalculate ? 'lts_browser_projection_refresh_v412' : 'lts_browser_projection_policy_v412', {});
        if (response.error) throw Error();
        if (generation !== identity() || token !== state.sequence) return;
        if (recalculate && response.data?.refresh && window.__LTS_V415_REFRESH) {
          window.__LTS_V415_REFRESH.observeRefresh(response.data.refresh);
          if (!window.LTSV415ProductRefresh.ready(response.data.refresh)) {
            state.status = 'queued'; state.readAt = Date.now();
            if (response.data.version === 'projection-policy-v412') state.model = api.build(response.data);
            if (typeof toast === 'function') toast('Atualização solicitada.');
            return;
          }
        }
        const model = api.build(response.data);
        if (generation !== identity() || token !== state.sequence) return;
        const wasEnabled = !!state.model;
        state.model = model; state.status = model ? (recalculate ? 'refreshing' : 'ready') : 'disabled'; state.readAt = Date.now();
        if (model) applyHorizon();
        if (!model && wasEnabled) {
          state.consumerSequence++; state.horizonKey = null;
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          if (ui?.updates) { ui.updates.token = (ui.updates.token || 0) + 1; ui.updates.recurring = null; ui.updates.loading = false; }
          if (ui?.dashboard?.data) delete ui.dashboard.data.recurring;
          await window.__LTS_V178_REVIEW?.refreshForecast?.();
          if (V === 'Fluxo Diário' && FLOWQ?.from && FLOWQ?.to) await loadFlowRange(FLOWQ.from, FLOWQ.to);
        }
        if (recalculate && model) {
          window.__LTS_V227_TRANSPORT?.invalidate?.();
          await refreshConsumers();
          if (V === 'Fluxo Diário' && typeof loadFlowRange === 'function') {
            const from = FLOWQ?.from, to = FLOWQ?.to;
            if (from && to) await loadFlowRange(from, to);
          }
        }
      } catch {
        if (generation === identity() && token === state.sequence) { state.model = null; state.status = 'error'; state.readAt = Date.now(); }
      } finally { if (generation === identity() && token === state.sequence) {
        if (state.status === 'refreshing') state.status = state.model ? 'ready' : 'disabled';
        render();
      } }
    }
    async function refresh() { return load(true, true); }
    const style = document.createElement('style'); style.textContent = '.v412-policy{box-sizing:border-box;margin:10px 0;padding:12px 14px;border:1px solid #dbe3eb;border-radius:12px;background:#fff;color:#20364b;max-width:100%}.v412-heading{display:flex;align-items:center;justify-content:space-between;gap:10px;flex-wrap:wrap}.v412-heading h2{font-size:18px;margin:0}.v412-heading>strong{font-size:14px}.v412-heading button{min-height:40px}.v412-origin{font-size:12px;line-height:1.45;margin-top:7px}.v412-origin>summary{cursor:pointer;color:#52677a}.v412-origin p{margin:7px 0}.v412-rule{padding:10px 0;border-bottom:1px solid #e4eaf0}.v412-rule h3{font-size:13px;margin:0 0 5px}.v412-rule strong{white-space:nowrap}.v412-warning{color:#79500a;background:#fff7e5;padding:8px;border-radius:8px;font-size:12px;line-height:1.45;margin:8px 0}.v412-loading{font-size:12px;margin:7px 0}@media(max-width:400px){.v412-policy{padding:10px}.v412-heading{gap:7px}.v412-heading button{font-size:12px}}'; document.head.append(style);
    render = function () { const result = previous.apply(this, arguments); paint(); return result; };
    Object.assign(state, { load, refresh }); window.__LTS_V412_PROJECTION = state;
    window.addEventListener('lts:product-refresh-ready', () => {
      reset(); if (!D || N.classList.contains('hidden')) return;
      state.status = 'idle'; state.readAt = 0;
      load(true, false).then(() => { if (state.model && state.status === 'ready') refreshConsumers(); });
    });
    const observer = new MutationObserver(patchDialog); observer.observe(document.body, { childList: true, subtree: true });
    paint();
  }
  function install() {
    try { const w = shell?.contentWindow, d = shell?.contentDocument; if (!w?.__LTS_V411_RSU) return false;
      if (!w.__LTS_V412_PROJECTION) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V412_PROJECTION;
    } catch { return false; }
  }
  let attempts = 0; function start() { if (!install() && ++attempts < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { attempts = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v412-projection-policy.js', install);
})();

