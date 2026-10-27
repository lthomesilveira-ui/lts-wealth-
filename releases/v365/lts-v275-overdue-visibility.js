/* Read-only visibility of overdue forecasts already present in the Flow payload. */
(function () {
  'use strict';
  function makeContract() {
    const owns = (object, key) => !!object && Object.prototype.hasOwnProperty.call(object, key);
    function day(value) {
      if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return null;
      const date = new Date(value + 'T12:00:00Z');
      return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value ? value : null;
    }
    function businessDay(now) {
      const parts = new Intl.DateTimeFormat('en-CA', {timeZone:'America/Sao_Paulo', year:'numeric', month:'2-digit', day:'2-digit'}).formatToParts(now || new Date());
      const get = name => parts.find(part => part.type === name).value;
      return get('year') + '-' + get('month') + '-' + get('day');
    }
    function amount(value) {
      if (typeof value !== 'number' && !(typeof value === 'string' && /^-?\d+(?:\.\d+)?$/.test(value.trim()))) return null;
      const number = Number(value);
      return Number.isFinite(number) ? number : null;
    }
    const escape = value => String(value == null ? '' : value).replace(/[&<>"']/g, char => ({'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;'}[char]));
    const money = value => new Intl.NumberFormat('pt-BR', {style:'currency', currency:'BRL'}).format(value);
    function model(flow, context) {
      const current = day(context.today), account = context.account || 'Consolidado';
      const result = (status, rows, extra) => Object.assign({status, rows:rows || [], account, today:current, invalidCount:0}, extra || {});
      if (!current) return result('unavailable');
      if (context.loading) return result('loading');
      if (!flow || typeof flow !== 'object' || flow.error) return result('unavailable');
      if (context.range && (flow.from !== context.range.from || flow.to !== context.range.to)) return result('range_mismatch');
      const source = flow.observed_bank_movements;
      if (!source || !owns(source, 'pending_projections')) return result('source_missing');
      if (!Array.isArray(source.pending_projections)) return result('invalid_source');
      // These are calculation-day contracts, never bank snapshot timestamps.
      const anchors = [flow.current_future && flow.current_future.current_anchor_date,
        flow.projected_operational_anchor && flow.projected_operational_anchor.as_of].filter(value => value != null);
      if (!anchors.length) return result('undated');
      if (anchors.some(value => day(value) !== current)) return result('stale');
      const seen = new Map(), conflicts = new Set();
      let invalidCount = 0;
      for (const event of source.pending_projections) {
        if (!event || typeof event !== 'object' || Array.isArray(event)) { invalidCount++; continue; }
        const due = day(event.event_date), value = amount(event.signed_amount);
        const bank = typeof event.account === 'string' ? event.account.trim() : '';
        const ref = event.financial_event_id || event.id || (event.source && event.source_ref ? event.source + ':' + event.source_ref : null);
        if (!due || value === null || !bank || typeof ref !== 'string' || !ref) { invalidCount++; continue; }
        const row = {key:ref + '|' + due, dueDate:due, account:bank, amount:value,
          confirmed:event.bank_confirmed === true, suppressed:event.is_suppressed === true,
          description:typeof event.description === 'string' && event.description.trim() ? event.description : 'Previsão sem descrição',
          confirmation:value < 0 ? 'pagamento a confirmar' : value > 0 ? 'recebimento a confirmar' : 'movimento a confirmar'};
        const previous = seen.get(row.key);
        if (previous && (previous.amount !== row.amount || previous.account !== row.account || previous.description !== row.description || previous.confirmed !== row.confirmed || previous.suppressed !== row.suppressed)) {
          conflicts.add(row.key);
        } else if (!previous) seen.set(row.key, row);
      }
      for (const key of conflicts) seen.delete(key);
      invalidCount += conflicts.size;
      const rows = Array.from(seen.values()).filter(row => !row.confirmed && !row.suppressed && row.dueDate < current && (account === 'Consolidado' || row.account === account)).map(({confirmed, suppressed, ...row}) => row).sort((a, b) => a.dueDate.localeCompare(b.dueDate) || a.account.localeCompare(b.account) || a.key.localeCompare(b.key));
      return result(invalidCount ? 'partial' : 'ready', rows, {invalidCount});
    }
    function markup(view, expanded) {
      const unavailable = {
        range_mismatch:'Atualize o fluxo para conferir os pagamentos vencidos.',
        source_missing:'Não foi possível conferir os pagamentos vencidos. Atualize o fluxo.',
        invalid_source:'Não foi possível conferir os pagamentos vencidos. Atualize o fluxo.',
        undated:'Atualize o fluxo para conferir os pagamentos vencidos.',
        stale:'Atualize o fluxo para conferir os pagamentos vencidos.',
        unavailable:'Não foi possível conferir os pagamentos vencidos. Atualize o fluxo.'
      };
      if (view.status === 'loading') return '';
      if (unavailable[view.status]) return '<p role="status">' + escape(unavailable[view.status]) + '</p>';
      const caution = view.status === 'partial' ? '<p role="status">Alguns pagamentos não puderam ser conferidos. Atualize o fluxo.</p>' : '';
      if (!view.rows.length) return caution;
      const count = view.rows.length;
      return caution + '<details' + (expanded ? ' open' : '') + '><summary>' + count + (count === 1 ? ' pagamento vencido a conferir' : ' pagamentos vencidos a conferir') + '</summary><ul>' +
        view.rows.map(row => '<li><span><b>' + escape(row.description) + '</b><small>' + escape(row.account) + ' · Vencimento ' + escape(row.dueDate.split('-').reverse().join('/')) + ' · ' + escape(row.confirmation) + '</small></span><strong>' + escape(money(row.amount)) + '</strong></li>').join('') + '</ul></details>';
    }
    return {day, businessDay, model, markup};
  }
  if (typeof module === 'object' && module.exports) { module.exports = makeContract(); return; }
  function runtime(build) {
    if (window.__LTS_FLOW_OVERDUE_PROJECTIONS) return;
    const contract = build(), previousRender = render, previousLoad = typeof loadFlowRange === 'function' ? loadFlowRange : null, expandedByAccount = new Map();
    let scheduled = false;
    const id = 'ltsFlowOverdueProjections';
    const state = window.__LTS_FLOW_OVERDUE_PROJECTIONS = {installed:true, financial_data_changed:false, network_requests_added:false, last_status:null};
    function rememberExpanded() {
      const panel = document.getElementById(id), details = panel && panel.querySelector('details');
      // Native details.open changes before the browser dispatches its queued toggle.
      // Keep the rendered account, even if ACC has already changed for navigation.
      if (details && typeof panel.__ltsAccount === 'string') expandedByAccount.set(panel.__ltsAccount, details.open === true);
    }
    function after() {
      rememberExpanded();
      let panel = document.getElementById(id);
      if (V !== 'Atualizações') { if (panel) panel.remove(); return; }
      const host = document.querySelector('.v168-updates .v168-head');
      if (!host) return;
      const from = typeof FLOWFROM === 'undefined' ? null : FLOWFROM;
      const to = typeof FLOWTO === 'undefined' ? null : FLOWTO;
      const account = 'Consolidado';
      const view = contract.model(typeof FLOWQ === 'undefined' ? null : FLOWQ, {
        today:contract.businessDay(), account,
        loading:typeof FLOWLOADING !== 'undefined' && FLOWLOADING,
        range:contract.day(from) && contract.day(to) ? {from, to} : null
      });
      state.last_status = view.status;
      const html = contract.markup(view, expandedByAccount.get(account) === true);
      if (!html) { if (panel) panel.remove(); return; }
      if (!panel) {
        panel = document.createElement('section'); panel.id = id; panel.className = 'v168-note lts-overdue-forecasts';
        panel.setAttribute('aria-label', 'Previsões vencidas ainda sem conciliação'); host.insertAdjacentElement('afterend', panel);
      }
      if (panel.__ltsMarkup !== html || panel.__ltsAccount !== account) {
        panel.hidden = !html;
        panel.innerHTML = html; panel.__ltsMarkup = html; panel.__ltsAccount = account;
        const details = panel.querySelector('details');
        if (details) details.addEventListener('toggle', () => {
          // Removed/replaced elements may dispatch an already queued toggle later.
          if (document.getElementById(id) === panel && panel.querySelector('details') === details && panel.__ltsAccount === account) expandedByAccount.set(account, details.open === true);
        });
      }
    }
    if (!document.getElementById('ltsOverdueForecastStyle')) {
      const style = document.createElement('style'); style.id = 'ltsOverdueForecastStyle';
      style.textContent = '.lts-overdue-forecasts{margin:8px 0;overflow-wrap:anywhere}.lts-overdue-forecasts p{margin:4px 0}.lts-overdue-forecasts summary{cursor:pointer;font-weight:600}.lts-overdue-forecasts ul{list-style:none;padding:0;margin:8px 0 0}.lts-overdue-forecasts li{display:flex;gap:12px;justify-content:space-between;align-items:flex-start;padding:7px 0;border-top:1px solid #cbd5e144}.lts-overdue-forecasts li span{min-width:0}.lts-overdue-forecasts small{display:block;font-size:12px}.lts-overdue-forecasts strong{white-space:nowrap;font-variant-numeric:tabular-nums}@media(max-width:430px){.lts-overdue-forecasts li{flex-direction:column;gap:2px}}';
      document.head.appendChild(style);
    }
    function settle() {
      if (scheduled) return; scheduled = true;
      queueMicrotask(() => { scheduled = false; after(); });
    }
    render = function () { rememberExpanded(); const result = previousRender.apply(this, arguments); after(); settle(); return result; };
    if (previousLoad) loadFlowRange = function () {
      rememberExpanded();
      const result = previousLoad.apply(this, arguments);
      if (result && typeof result.then === 'function') return result.then(value => { after(); settle(); return value; }, error => { after(); settle(); throw error; });
      after(); settle(); return result;
    };
    after(); settle();
  }
  const shell = document.getElementById('shell');
  const installState = window.__LTS_V275_OVERDUE_INSTALL || (window.__LTS_V275_OVERDUE_INSTALL = {status:'waiting', attempts:0, budget_ms:60000});
  function install(){
    try{
      const frame=shell?.contentWindow,doc=shell?.contentDocument;
      if(!frame||!doc||!frame.__LTS_V228_FLOW||!frame.__LTS_V235_HISTORY||!frame.__LTS_V257_UI_STATE?.installed)return false;
      if(!frame.__LTS_FLOW_OVERDUE_PROJECTIONS){const script=doc.createElement('script');script.textContent='('+runtime.toString()+')('+makeContract.toString()+');';doc.head.appendChild(script);}
      if(frame.__LTS_FLOW_OVERDUE_PROJECTIONS){installState.status='installed';return true;}
    }catch{}
    return false;
  }
  let generation=0;
  function start(){const current=++generation;let tries=0;installState.status='waiting';installState.attempts=0;
    function attempt(){if(current!==generation)return;installState.attempts=tries+1;if(install())return;if(++tries<240)setTimeout(attempt,250);else installState.status='timed_out';}attempt();
  }
  shell?.addEventListener('load',start);start();
 window.LTSV339Boot?.watch('lts-v275-overdue-visibility.js',install);
})();
