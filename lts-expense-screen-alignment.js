/* V162 expense integration: existing same-origin frame, existing RPC and source data.
 * No financial writers, new frames, polling or persistent storage.
 */
(function () {
  'use strict';
  function runtime() {
    'use strict';
    if (window.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed) return;
    const M = window.parent.LTSExpenseReadModel;
    if (!M || typeof despesas !== 'function' || typeof expenseDualBounds !== 'function') return;
    const status = window.__LTS_EXPENSE_SCREEN_ALIGNMENT = {
      installed: true, version: 'current-sources-expense-screen-v1', financial_writes: 0,
      source_certification: false, lastDetailParity: null
    };
    let key = null, previousRoute = V, previousProduct = D;
    const datePattern = /^\d{4}-\d{2}-\d{2}$/;
    function selectedRows(from, to) {
      return (D?.expense_drilldown?.rows || []).filter(row => {
        const d = String(row.event_date || '').slice(0, 10);
        if (row.is_card === true) {
          const competence = String(row.competence_month || '').slice(0, 7);
          return /^\d{4}-\d{2}$/.test(competence) && competence >= from.slice(0, 7) && competence <= to.slice(0, 7);
        }
        return datePattern.test(d) && d >= from && d <= to;
      });
    }
    function parity(model) {
      const rows = selectedRows(model.scope.from, model.scope.to), amounts = new Map();
      let total = 0, count = 0;
      try {
        for (const row of rows) {
          const category = String(row.category || row.category_candidate || row.category_raw || 'A classificar');
          const cents = M.cents(row.amount), record = amounts.get(category) || {total: 0, count: 0};
          record.total += cents; record.count++; total += cents; count++; amounts.set(category, record);
          if (!Number.isSafeInteger(total) || !Number.isSafeInteger(record.total)) return false;
        }
        if (total !== model.consumptionCents || count !== model.categories.reduce((n, c) => n + c.rows, 0)) return false;
        if (amounts.size !== model.categories.length) return false;
        return model.categories.every(c => amounts.has(c.name) && amounts.get(c.name).total === c.totalCents && amounts.get(c.name).count === c.rows);
      } catch (_) { return false; }
    }
    const session = M.createReadSession({
      selection: M.rangeSelection,
      load: request => S.rpc('lts_browser_expense_dual_lens_v1', {p_from: request.from, p_to: request.to}),
      adapt(payload, requested) {
        const normalized = M.normalizeDual(payload, requested);
        if (!normalized.internallyConsistent) throw new Error('expense_source_consistency');
        if (!parity(normalized)) throw new Error('expense_summary_detail_disagreement');
        status.lastDetailParity = true;
        return Object.freeze({...normalized, legacy: payload});
      }
    });
    session.subscribe(state => {
      window.EXPDUAL = {key, loading: state.phase === 'loading', error: state.phase === 'error' || state.phase === 'authentication_required' ? state.message : null,
        data: state.model?.legacy || null, model: state.model || null, phase: state.phase};
      if (V === 'Despesas') render();
    });
    loadExpenseDual = function (a, b) {
      key = a + '|' + b; status.lastDetailParity = null;
      return session.select({from: a, to: b});
    };
    expenseDualState = function () {
      const [a, b] = expenseDualBounds(), wanted = a + '|' + b;
      if (key !== wanted) loadExpenseDual(a, b);
      return window.EXPDUAL?.key === wanted ? window.EXPDUAL : null;
    };
    exp110Rows = function () { const [a, b] = expenseDualBounds(); return selectedRows(a, b); };
    expenseRows = function () { const [a, b] = expenseDualBounds(); return selectedRows(a, b); };

    const originalCoverage = exp117CoverageCard;
    exp117CoverageCard = function (analysis) {
      const payload = window.EXPDUAL?.data, c = payload?.consumption || {};
      if (!(Number(c.open_invoice_count) > 0)) return originalCoverage(analysis);
      return `<div class="exp117-coverage protected"><div><span>Origem e cobertura</span><h3>Período com fatura aberta</h3><p>${esc(String(c.open_invoice_count))} fatura(s) em aberto: ${brl(c.open_invoice_total)} em itens documentados. Esta posição pode mudar até o fechamento. Não representa pagamento confirmado.</p></div><div class="exp117-coverageside"><b>Leitura do cartão</b><strong>Por competência da fatura</strong><small>Sem inventar a data original da compra</small></div></div>`;
    };
    const originalTx = expenseTx;
    expenseTx = function (row) {
      let html = originalTx(row);
      if (row.is_card === true && !row.is_credit && !row.transaction_date) {
        html = html.replace('Compra ' + fmt(row.event_date), 'Data original não informada');
      }
      if (row.statement_state === 'open' || row.source_table === 'card_invoice_current_items') {
        html = html.replace('<div class="expense-meta">', '<div class="expense-meta"><i class="tag">Fatura aberta · provisório</i>');
      }
      return html;
    };
    exp110Monthly = function () {
      const model = window.EXPDUAL?.model;
      if (!model) return '<div class="empty">Dados do período indisponíveis.</div>';
      const months = model.monthly.slice(-12), maximum = Math.max(1, ...months.flatMap(m => [m.cashCents, m.consumptionCents].filter(v => v !== null).map(Math.abs)));
      const bar = (value, name, tag) => value === null ? `<${tag} class="lts-exp-missing" title="${name}: sem informação"></${tag}>` : `<${tag} style="height:${Math.max(2, Math.abs(value) / maximum * 100)}%" title="${name}: ${brl(value / 100)}"></${tag}>`;
      return `<div class="exp110-months">${months.map(m => `<div class="exp110-month"><div class="exp110-bars">${bar(m.cashCents,'Caixa','i')}${bar(m.consumptionCents,'Consumo','em')}</div><b>${expenseMonthPt(m.month)}</b></div>`).join('')}</div><div class="exp110-legend"><span><i class="exp110-dot"></i>Saídas de caixa</span><span><i class="exp110-dot gold"></i>Consumo</span><span>Sem barra: informação ausente, não zero</span></div>`;
    };
    const originalView = despesas;
    despesas = function () {
      const html = originalView(), state = window.EXPDUAL;
      if (!state?.data || state.loading || state.error) return html;
      const asOf = state.data.data_quality?.bank_evidence_as_of;
      const [from] = expenseDualBounds();
      return `<div class="notice lts-exp-source-notice" role="status">${asOf ? 'Base bancária documentada até ' + esc(fmt(asOf)) + '. ' : 'Data-base bancária não informada. '}Compras de cartão por competência da fatura; movimentos bancários pela data de caixa.${from.slice(8) !== '01' ? ' O início no meio do mês mantém as parcelas da competência selecionada.' : ''} Não é uma consulta bancária em tempo real.</div>` + html;
    };
    const originalRender = render;
    render = function () {
      if (D !== previousProduct || (previousRoute === 'Despesas' && V !== 'Despesas')) {
        previousProduct = D; key = null; status.lastDetailParity = null; session.invalidate();
      }
      previousRoute = V;
      const result = originalRender();
      const badge = window.parent.document.getElementById('scope');
      if (badge) badge.textContent = V === 'Despesas' ? 'Despesas · homologação' : 'Fluxo Diário · homologação';
      return result;
    };
    const style = document.createElement('style'); style.id = 'lts-expense-source-alignment-style';
    style.textContent = '.lts-exp-source-notice{font-size:12px;line-height:1.55;margin-bottom:14px}.exp110-bars .lts-exp-missing{height:0!important;border:0!important}.exp117-coverage p{overflow-wrap:anywhere}';
    document.head.appendChild(style);
    if (V === 'Despesas') render();
  }
  const frame = document.getElementById('shell');
  function install() {
    try {
      const doc = frame?.contentDocument;
      if (!doc || !frame.contentWindow?.location.pathname.endsWith('/index.html') || doc.getElementById('lts-expense-source-alignment')) return;
      const script = doc.createElement('script'); script.id = 'lts-expense-source-alignment';
      script.textContent = '(' + runtime.toString() + ')();';
      (doc.head || doc.documentElement).appendChild(script);
    } catch (_) { /* The same-origin frame may still be navigating. The load event retries once. */ }
  }
  frame?.addEventListener('load', install);
  if (frame?.contentDocument?.readyState === 'complete') install();
})();
