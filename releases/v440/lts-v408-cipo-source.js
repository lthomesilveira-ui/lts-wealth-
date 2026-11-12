/* Documentary acquisition groups. This module never changes financial values. */
(function () {
  'use strict';
  function createAPI() {
    const schema = 'cipo-acquisition-documentary-v408';
    function integer(value) {
      const n = Number(value);
      if (!Number.isSafeInteger(n) || n < 1) throw Error('Invalid source row');
      return n;
    }
    function cents(value) {
      if (!/^\d+(?:\.\d{1,2})?$/.test(String(value))) throw Error('Invalid amount');
      const n = Math.round(Number(value) * 100);
      if (!Number.isSafeInteger(n)) throw Error('Amount outside supported range');
      return n;
    }
    function day(value) {
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) throw Error('Invalid date');
      const d = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(d.getTime()) || d.toISOString().slice(0, 10) !== value) throw Error('Invalid date');
      return value;
    }
    function build(payload) {
      if (payload == null) return null;
      if (payload.schema !== schema || payload.property_code !== 'cipo396'
        || payload.evidence_kind !== 'workbook_acquisition_composition') throw Error('Unexpected evidence');
      const verifiedOn = day(payload.verified_on);
      if (!Array.isArray(payload.groups) || payload.groups.length !== 32
        || !Array.isArray(payload.residuals) || payload.residuals.length !== 5
        || !Array.isArray(payload.source_files) || payload.source_files.length !== 2) throw Error('Incomplete evidence');
      const files = new Map();
      for (const file of payload.source_files) {
        if (!file.file || files.has(file.file) || !/^[a-f0-9]{64}$/.test(file.sha256 || '')) throw Error('Invalid source file');
        files.set(file.file, file);
      }
      if (payload.source_files.filter(x => x.primary === true).length !== 1) throw Error('Missing primary source');
      const keys = new Set(), sourceRefs = new Set(), sourceRows = new Set(), ids = new Set();
      let count = 0, total = 0, constructor = 0, broker = 0, dateDifferences = 0;
      const groups = payload.groups.map(group => {
        const row = integer(group.source_row), scheduledDate = day(group.scheduled_date);
        if (!group.id || ids.has(group.id) || sourceRows.has(row) || group.source_sheet !== 'Sonho'
          || group.individual_allocation !== null || !Array.isArray(group.cash_rows) || !group.cash_rows.length) throw Error('Invalid acquisition group');
        ids.add(group.id); sourceRows.add(row);
        for (const [key, column] of [['schedule_date', 'W'], ['constructor', 'Y'], ['broker', 'Z'], ['total', 'AA']]) {
          if (group.source_cells?.[key] !== column + row) throw Error('Invalid group source');
        }
        const a = cents(group.constructor_brl), b = cents(group.broker_brl), t = cents(group.total_brl);
        if (a + b !== t || t <= 0) throw Error('Components do not reconcile');
        let cashTotal = 0;
        const cash = group.cash_rows.map(item => {
          const ref = item.source_table + ':' + item.source_ref;
          if (item.source_table !== 'evento_base' || !/^\d+$/.test(String(item.source_ref))
            || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref)) throw Error('Duplicate or invalid cash identity');
          keys.add(item.row_key); sourceRefs.add(ref);
          const amount = cents(item.amount), date = day(item.event_date);
          if (amount <= 0 || !Array.isArray(item.workbook_rows) || item.workbook_rows.length !== 2) throw Error('Incomplete cash source');
          const seenFiles = new Set();
          for (const evidence of item.workbook_rows) {
            const n = integer(evidence.row);
            if (!files.has(evidence.file) || seenFiles.has(evidence.file)
              || evidence.sheet !== 'Pagamentos e Recebimentos' || evidence.property_label !== 'Cipó 396'
              || evidence.description_cell !== 'A' + n || evidence.amount_cell !== 'B' + n
              || evidence.date_cell !== 'C' + n || evidence.property_cell !== 'G' + n) throw Error('Incomplete workbook identity');
            seenFiles.add(evidence.file);
          }
          count++; cashTotal += amount;
          return { date, cents: amount, sourceRows: item.workbook_rows.map(x => ({ file: x.file, sheet: x.sheet, row: x.row })) };
        });
        const differs = cash.some(item => item.date !== scheduledDate);
        if (cashTotal !== t || group.date_difference !== differs) throw Error('Cash group does not reconcile');
        if (differs) dateDifferences++;
        total += t; constructor += a; broker += b;
        return { id: group.id, sourceRow: row, scheduledDate, constructorCents: a, brokerCents: b, totalCents: t, cash, dateDifference: differs };
      });
      const residuals = payload.residuals.map(item => {
        const ref = item.source_table + ':' + item.source_ref;
        if (!['evento_base', 'financial_events'].includes(item.source_table) || !item.source_ref
          || !item.row_key || keys.has(item.row_key) || sourceRefs.has(ref) || !item.reason) throw Error('Invalid residual identity');
        keys.add(item.row_key); sourceRefs.add(ref);
        const amount = cents(item.amount);
        if (!amount) throw Error('Invalid residual amount');
        return { date: day(item.event_date), cents: amount, description: item.description, reason: item.reason };
      });
      const residualTotal = residuals.reduce((sum, item) => sum + item.cents, 0);
      if (count !== 43 || dateDifferences !== 3 || total !== cents(payload.documented_total_brl)
        || constructor !== cents(payload.constructor_total_brl) || broker !== cents(payload.broker_total_brl)
        || residualTotal !== cents(payload.residual_total_brl)
        || payload.counts?.groups !== 32 || payload.counts?.documented_rows !== 43
        || payload.counts?.residual_rows !== 5 || payload.counts?.date_difference_groups !== 3) throw Error('Evidence totals do not reconcile');
      return { groups, residuals, verifiedOn, totalCents: total, constructorCents: constructor, brokerCents: broker,
        residualTotalCents: residualTotal, rowCount: count, dateDifferences, files: payload.source_files.map(x => ({ ...x })) };
    }
    function renderPanel(document, model) {
      const el = (tag, text, className) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (className) e.className = className; return e; };
      const money = n => new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' }).format(n / 100);
      const date = value => value.split('-').reverse().join('/');
      const pair = (label, amount) => { const e = el('div', null, 'v408-pair'); e.append(el('span', label), el('b', money(amount))); return e; };
      const section = el('section', null, 'v408-cipo-source'); section.dataset.v408Cipo = '';
      section.append(el('p', 'Conferência de ' + date(model.verifiedOn) + ': ' + model.rowCount + ' lançamentos documentados. Falta detalhar 5 lançamentos (' + money(model.residualTotalCents) + ').', 'v408-material'));
      const details = el('details'); details.append(el('summary', 'Composição histórica da aquisição'));
      details.append(el('p', 'A planilha separa os pagamentos entre construtora e corretora. Os valores abaixo compõem a aquisição do imóvel.'));
      const totals = el('div', null, 'v408-totals'); totals.append(pair('Construtora', model.constructorCents), pair('Corretora', model.brokerCents), pair('Total documentado', model.totalCents)); details.append(totals);
      details.append(el('p', '32 grupos reúnem os 43 lançamentos. A composição é apresentada por grupo, sem dividir seus componentes entre os pagamentos de caixa.'));
      const list = el('div', null, 'v408-groups');
      for (const group of model.groups) {
        const item = el('details', null, 'v408-group');
        const dates = [...new Set(group.cash.map(x => x.date))].sort();
        const label = dates.length === 1 ? date(dates[0]) : date(dates[0]) + ' a ' + date(dates[dates.length - 1]);
        const title = el('summary'); title.append(el('span', label + ' · ' + group.cash.length + (group.cash.length === 1 ? ' lançamento' : ' lançamentos')), el('b', money(group.totalCents))); item.append(title);
        if (group.constructorCents) item.append(pair('Construtora', group.constructorCents));
        if (group.brokerCents) item.append(pair('Corretora', group.brokerCents));
        if (group.dateDifference) item.append(el('p', 'A grade registra ' + date(group.scheduledDate) + '. As datas originais de caixa são as apresentadas abaixo.', 'v408-date-difference'));
        for (const cash of group.cash) item.append(pair('Caixa · ' + date(cash.date), cash.cents));
        const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem'));
        origin.append(el('p', 'Sonho · linha ' + group.sourceRow + ' · colunas W, Y, Z e AA.'));
        for (const file of model.files) {
          const rows = group.cash.flatMap(x => x.sourceRows.filter(y => y.file === file.file).map(y => y.row));
          origin.append(el('p', file.file + ' · Pagamentos e Recebimentos · ' + (rows.length === 1 ? 'linha ' : 'linhas ') + rows.join(', ') + '.'));
        }
        item.append(origin); list.append(item);
      }
      details.append(list);
      const residual = el('details', null, 'v408-residuals'); residual.append(el('summary', 'Cinco lançamentos ainda em conferência'));
      for (const item of model.residuals) { const row = el('div', null, 'v408-residual'); row.append(pair(date(item.date), item.cents), el('p', item.reason)); residual.append(row); }
      details.append(residual);
      const origin = el('details', null, 'v408-origin'); origin.append(el('summary', 'Origem e limites'));
      origin.append(el('p', 'Planilha original de julho de 2026 e sua cópia compactada. A cópia confere as mesmas células; não é uma segunda confirmação bancária.'));
      origin.append(el('p', 'Há três grupos com datas diferentes entre a grade e o caixa. Ambas são preservadas. Esta composição não informa principal amortizado ou juros do financiamento bancário.'));
      origin.append(el('p', 'Os 44 pagamentos bancários já documentados e os nove outros itens de aquisição permanecem separados desta composição.'));
      for (const file of model.files) origin.append(el('p', file.file + ' · SHA-256 ' + file.sha256));
      details.append(origin); section.append(details); return section;
    }
    return { build, renderPanel };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V408_CIPO?.installed) return;
    const api = factory(), prior = render, state = window.__LTS_V168_STATE, seen = new WeakMap();
    function after() {
      if (V !== 'Patrimônio' || state.wealth?.tab !== 'assets') return;
      const card = document.querySelector('[data-v309-contract="cipo_396"]');
      if (!card) return;
      const docs = state.wealth?.data?.financing?.documentary?.items || [];
      const entries = docs.filter(x => x.commitment_id === 'cipo_396' && x.metadata?.acquisition_documentary_bridge_v408).map(x => x.metadata.acquisition_documentary_bridge_v408);
      const payload = entries[0];
      if (seen.get(card) === payload && card.querySelector('[data-v408-cipo]')) return;
      card.querySelector('[data-v408-cipo]')?.remove();
      if (!payload) return;
      seen.set(card, payload);
      try {
        if (entries.some(x => JSON.stringify(x) !== JSON.stringify(payload))) throw Error('Conflicting evidence copies');
        card.append(api.renderPanel(document, api.build(payload)));
      } catch {
        const warning = document.createElement('p'); warning.dataset.v408Cipo = ''; warning.className = 'v408-material';
        warning.textContent = 'A composição histórica precisa ser conferida antes de ser exibida. Atualize os dados de patrimônio.'; card.append(warning);
      }
    }
    const style = document.createElement('style'); style.id = 'v408-cipo-style';
    style.textContent = '.v408-cipo-source{margin-top:14px;padding-top:10px;border-top:1px solid #dce3e9}.v408-cipo-source p{font-size:13px;line-height:1.5;color:#536174}.v408-material{font-size:13px;line-height:1.5;color:#825b22!important}.v408-cipo-source details{margin-top:10px}.v408-cipo-source summary{cursor:pointer;font-size:13px;font-weight:600;padding:8px 0}.v408-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:7px 0;font-size:13px}.v408-pair b,.v408-group>summary>b{white-space:nowrap;font-variant-numeric:tabular-nums}.v408-groups{margin:12px 0}.v408-group{border-top:1px solid #e5eaf0;padding:3px 0}.v408-group>summary{display:flex;justify-content:space-between;gap:10px;flex-wrap:wrap}.v408-group[open]{padding-bottom:8px}.v408-origin{font-size:12px;overflow-wrap:anywhere}.v408-origin p{font-size:12px}.v408-date-difference{color:#825b22!important}.v408-residual{padding:5px 0;border-bottom:1px solid #e5eaf0}.v408-residual p{margin:2px 0 9px}.v408-totals{margin:10px 0}@media(max-width:700px){.v408-pair{gap:8px}.v408-group>summary span{min-width:0;flex:1}.v408-cipo-source summary{font-size:12px}.v408-pair span{min-width:0}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    window.__LTS_V408_CIPO = { installed: true, after }; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed) return false;
      if (w.__LTS_V408_CIPO?.installed) return true;
      const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script);
      return !!w.__LTS_V408_CIPO?.installed;
    } catch { return false; }
  }
  let tries = 0;
  function start() { if (!install() && ++tries < 400) setTimeout(start, 100); }
  shell?.addEventListener('load', () => { tries = 0; start(); }); start();
  window.LTSV339Boot?.watch('lts-v408-cipo-source.js', install);
})();
