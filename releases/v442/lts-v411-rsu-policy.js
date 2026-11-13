/* Gross and estimated net awards. Financial values are supplied by the server. */
(function () {
  'use strict';
  function createAPI() {
    const fail = () => { throw Error('Invalid RSU policy response'); };
    function cents(value, nullable = false) {
      if (nullable && value === null) return null;
      if (typeof value !== 'number' && typeof value !== 'string') return fail();
      const text = String(value);
      if (!/^\d+(?:\.\d{1,2})?$/.test(text)) return fail();
      const [whole, fraction = ''] = text.split('.');
      const result = BigInt(whole) * 100n + BigInt((fraction + '00').slice(0, 2));
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail();
      return Number(result);
    }
    function quantity(value) {
      if ((typeof value !== 'number' && typeof value !== 'string') || !/^\d+(?:\.\d+)?$/.test(String(value))) return fail();
      const n = Number(value); if (!Number.isFinite(n) || n < 0) return fail(); return n;
    }
    function day(value, nullable = false) {
      if (nullable && value === null) return null;
      if (!/^\d{4}-\d\d-\d\d$/.test(String(value))) return fail();
      const parsed = new Date(value + 'T12:00:00Z');
      if (!Number.isFinite(parsed.getTime()) || parsed.toISOString().slice(0, 10) !== value) return fail();
      return value;
    }
    function sum(values) {
      const result = values.reduce((a, b) => a + BigInt(b), 0n);
      if (result > BigInt(Number.MAX_SAFE_INTEGER)) return fail(); return Number(result);
    }
    function amounts(source, keys = ['gross_value_brl', 'net_value_brl', 'reserve_value_brl']) {
      const [gross, net, reserve] = keys.map(k => cents(source[k]));
      if (sum([net, reserve]) !== gross) return fail(); return { gross, net, reserve };
    }
    function grant(source) {
      const grantDate = day(source.grant_date, true), eligible = source.acceleration_eligible;
      if (![true, false, null].includes(eligible)) return fail();
      if (eligible === true && (!grantDate || grantDate >= '2026-01-01' || !source.grant_id)) return fail();
      if (grantDate && grantDate >= '2026-01-01' && eligible !== false) return fail();
      if (source.grant_year != null && (!grantDate || Number(source.grant_year) !== Number(grantDate.slice(0, 4)))) return fail();
      return { grantId: source.grant_id || null, grantDate, eligible };
    }
    function build(payload) {
      if (!payload || payload.version !== 'rsu-policy-v411' || payload.schema_version !== 1) return fail();
      const p = payload.policy;
      if (p?.enabled === false) return null;
      if (p?.enabled !== true || Number(p.reserve_rate) !== 0.30 || Number(p.net_factor) !== 0.70
        || p.cash_already_available_untouched !== true || p.retention_award_excluded !== true
        || !Array.isArray(p.scope) || p.scope.length !== 2 || !p.scope.includes('RSU') || !p.scope.includes('Cash RSU')) return fail();
      const keys = new Set(), awardIds = new Set();
      if (!Array.isArray(payload.future_schedule)) return fail();
      const schedule = payload.future_schedule.map(row => {
        if (!row.group_key || keys.has(row.group_key) || !['RSU', 'Cash RSU'].includes(row.asset_type)
          || !Array.isArray(row.components) || !row.components.length || ![true, false, null].includes(row.acceleration_eligible)) return fail();
        keys.add(row.group_key);
        const a = amounts(row), eligibilityDate = day(row.eligibility_date), availableDate = day(row.available_date);
        if (availableDate < eligibilityDate) return fail();
        const components = row.components.map(item => {
          if (!item.award_id || awardIds.has(item.award_id)) return fail(); awardIds.add(item.award_id);
          const c = amounts(item), vesting = day(item.eligibility_date), available = day(item.available_date), g = grant(item);
          if (vesting !== eligibilityDate || available < vesting || available > availableDate) return fail();
          return { ...c, ...g, id: item.award_id, quantity: quantity(item.quantity), vesting, available,
            valuationBasis: item.valuation_basis || null, grantLinkStatus: item.grant_link_status || null };
        });
        if (sum(components.map(x => x.gross)) !== a.gross || sum(components.map(x => x.net)) !== a.net
          || sum(components.map(x => x.reserve)) !== a.reserve
          || row.acceleration_eligible === true && components.some(x => x.eligible !== true)) return fail();
        return { ...a, key: row.group_key, type: row.asset_type, eligibilityDate, availableDate,
          quantity: quantity(row.quantity), eligible: row.acceleration_eligible, components };
      });
      const s = payload.summary || {}, total = amounts(s, ['schedule_gross_brl', 'schedule_net_brl', 'schedule_reserve_brl']);
      const regular = { gross: cents(s.regular_gross_brl), net: cents(s.regular_net_brl) }, cash = { gross: cents(s.cash_gross_brl), net: cents(s.cash_net_brl) };
      if (sum([regular.gross, cash.gross]) !== total.gross || sum([regular.net, cash.net]) !== total.net
        || sum(schedule.map(x => x.gross)) !== total.gross || sum(schedule.map(x => x.net)) !== total.net
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.gross)) !== regular.gross
        || sum(schedule.filter(x => x.type === 'RSU').map(x => x.net)) !== regular.net) return fail();
      let reference = null;
      if (payload.morgan_reference !== null) {
        const r = payload.morgan_reference;
        if (!r || r.currency !== 'BRL' || r.replaces_dated_position !== false) return fail();
        const asOf = day(r.as_of_date, true);
        if (r.reference_date_known !== (asOf !== null)) return fail();
        const received = r.received_at ? new Date(r.received_at) : null;
        if (received && !Number.isFinite(received.getTime())) return fail();
        reference = { asOf, receivedAt: r.received_at || null, receivedOn: day(r.received_on ?? null, true), gross: cents(r.total_gross_brl), available: cents(r.available_total_brl),
          unavailableGross: cents(r.unavailable_gross_brl), regular: { gross: cents(r.regular_rsu_gross_brl), net: cents(r.regular_rsu_net_brl) },
          cash: { gross: cents(r.cash_rsu_gross_brl), net: cents(r.cash_rsu_net_brl) }, brokerageCash: cents(r.brokerage_cash_brl),
          unallocatedGross: cents(r.unallocated_gross_brl), unallocatedNet: cents(r.unallocated_net_brl, true),
          knownGross: cents(r.known_awards_gross_brl), knownNet: cents(r.known_awards_net_brl), knownAfterReserve: cents(r.known_after_reserve_brl) };
        if (sum([reference.available, reference.unavailableGross]) !== reference.gross
          || sum([reference.regular.gross, reference.cash.gross, reference.unallocatedGross]) !== reference.unavailableGross
          || sum([reference.regular.gross, reference.cash.gross]) !== reference.knownGross
          || sum([reference.regular.net, reference.cash.net]) !== reference.knownNet
          || sum([reference.knownNet, reference.brokerageCash]) !== reference.knownAfterReserve
          || reference.unallocatedGross > 0 && reference.unallocatedNet !== null) return fail();
      }
      let acceleration = null;
      if (payload.acceleration !== null) {
        const a = payload.acceleration;
        if (!a || a.status !== 'conditional' || a.confirmed_date !== null || a.calendar_unchanged !== true
          || a.grant_cutoff !== '2026-01-01' || typeof a.event !== 'string' || !a.event.trim() || !Array.isArray(a.grants)) return fail();
        const ids = new Set();
        const grants = a.grants.map(g => {
          const v = grant(g); if (!v.grantId || ids.has(v.grantId) || !v.grantDate || !['RSU', 'Cash RSU'].includes(g.asset_type)) return fail();
          ids.add(v.grantId); return { ...v, type: g.asset_type, quantity: quantity(g.quantity) };
        });
        const mapped = a.schedule_mapped_count, unmapped = a.schedule_unmapped_count;
        if (![mapped, unmapped].every(n => Number.isInteger(n) && n >= 0)) return fail();
        acceleration = { event: a.event, grants, priceUsd: cents(a.contract_price_usd), eligibleQuantity: quantity(a.eligible_quantity),
          excludedQuantity: quantity(a.excluded_quantity), grossUsd: cents(a.eligible_gross_usd), netUsd: cents(a.eligible_net_usd),
          gross: cents(a.eligible_gross_brl, true), net: cents(a.eligible_net_brl, true),
          fxRate: a.fx_rate == null ? null : quantity(a.fx_rate), fxBasis: a.fx_basis || null, mapped, unmapped };
        if ((acceleration.gross === null) !== (acceleration.net === null)) return fail();
      }
      let payroll = null;
      if (payload.payroll_policy !== null) {
        const p = payload.payroll_policy;
        if (!p || p.coopharma_treatment !== 'subtract_documented_schedule_once' || p.actual_net_preserved !== true || p.forecasts_only !== true) return fail();
        payroll = { base: cents(p.monthly_base_brl) };
      }
      return { total, regular, cash, schedule, reference, acceleration, payroll };
    }
    function matchGroup(row, group) {
      if (!row || !group || row.group_key !== group.key || row.asset_type !== group.type) return false;
      try { return day(row.eligibility_date) === group.eligibilityDate && day(row.available_date) === group.availableDate
        && cents(row.gross_value_brl) === group.gross && cents(row.net_value_brl) === group.net
        && quantity(row.quantity) === group.quantity; } catch { return false; }
    }
    return { build, cents, day, matchGroup };
  }
  const api = createAPI();
  if (typeof module !== 'undefined' && module.exports) { module.exports = api; return; }
  if (typeof document === 'undefined') return;
  const shell = document.getElementById('shell');
  function runtime(factory) {
    if (window.__LTS_V411_RSU?.installed) return;
    const api = factory(), prior = render, ui = window.__LTS_V168_STATE;
    const state = { installed: true, version: 'v411', status: 'idle', token: 0, model: null, error: null };
    const identity = () => typeof BOOT === 'object' ? BOOT.generation : D;
    let owner = identity(), marketRevision = null;
    const money = (n, currency = 'BRL') => n === null || n === undefined ? '—' : new Intl.NumberFormat('pt-BR', { style: 'currency', currency }).format(n / 100);
    const number = n => new Intl.NumberFormat('pt-BR', { maximumFractionDigits: 6 }).format(n);
    const date = d => d ? d.split('-').reverse().join('/') : 'não informada';
    const el = (tag, text, cls) => { const e = document.createElement(tag); if (text != null) e.textContent = text; if (cls) e.className = cls; return e; };
    const pair = (label, value) => { const p = el('div', null, 'v411-pair'); p.append(el('span', label), el('b', money(value))); return p; };
    function disclosure(title) { const d = el('details', null, 'v411-origin'); d.append(el('summary', title)); return d; }
    function table(regular, cash, total) {
      const t = el('table', null, 'v411-values'); t.setAttribute('aria-label', 'RSUs: valores brutos e líquidos estimados');
      const head = el('thead'), hr = el('tr'); for (const s of ['Tipo', 'Bruto', 'Líquido estimado']) hr.append(el('th', s)); head.append(hr); t.append(head);
      const body = el('tbody');
      for (const [name, value] of [['RSUs', regular], ['Cash RSUs', cash], ['Total', total]]) {
        const tr = el('tr'); tr.append(el('th', name), el('td', money(value?.gross)), el('td', money(value?.net))); body.append(tr);
      }
      t.append(body); return t;
    }
    function warning(message) { const p = el('p', message, 'v411-warning'); p.setAttribute('role', 'status'); return p; }
    function retry() { const b = el('button', 'Atualizar valores', 'v168-btn'); b.type = 'button'; b.dataset.v411Refresh = ''; b.onclick = () => refresh(); return b; }
    function statusNote() {
      if (state.status === 'error') { const p = warning('Não foi possível conferir os valores líquidos das RSUs. Atualize antes de usar a projeção.'); p.append(document.createTextNode(' '), retry()); return p; }
      return el('p', 'Conferindo valores brutos e líquidos…', 'v411-loading');
    }
    function projection(model) {
      const card = el('article', null, 'v168-card v411-projection'); card.dataset.v411Projection = '';
      card.append(el('h2', 'RSUs e Cash RSUs · agenda normal'), table(model?.regular, model?.cash, model?.total));
      if (!model) card.append(statusNote());
      else card.append(el('p', 'Líquido estimado após reserva de 30% para planejamento. Os vestings futuros permanecem fora do dinheiro disponível hoje.', 'v411-note'));
      return card;
    }
    function referencePanel(r) {
      const card = el('article', null, 'v168-card v411-reference'); card.dataset.v411Reference = '';
      card.append(el('h2', 'Posição informada pela corretora'), pair('Total bruto informado', r.gross));
      const total = { gross: r.knownGross, net: r.knownNet };
      card.append(table(r.regular, r.cash, total), pair('Dinheiro já disponível', r.brokerageCash), pair('Componentes identificados após reserva + dinheiro', r.knownAfterReserve));
      if (!r.asOf) card.append(warning('A data desta posição não foi informada. Ela permanece separada da posição datada.'));
      if (r.unallocatedGross > 0) card.append(warning('Falta identificar ' + money(r.unallocatedGross) + ' do total bruto. O líquido completo ainda está em apuração.'));
      const origin = disclosure('Origem e data');
      origin.append(el('p', 'Data da posição: ' + date(r.asOf) + '.'));
      if (r.receivedAt) origin.append(el('p', 'Recebido em ' + new Intl.DateTimeFormat('pt-BR', { dateStyle: 'short', timeStyle: 'short', timeZone: 'America/Sao_Paulo' }).format(new Date(r.receivedAt)) + ' (Brasília).'));
      else if (r.receivedOn) origin.append(el('p', 'Recebido em ' + date(r.receivedOn) + '.'));
      origin.append(el('p', 'A referência documental e a agenda de vestings usam bases distintas e não são somadas. Dinheiro já disponível não recebe nova reserva. Retention Award permanece separado.')); card.append(origin); return card;
    }
    function accelerationPanel(a) {
      const card = el('article', null, 'v168-card v411-acceleration'); card.dataset.v411Acceleration = '';
      card.append(el('h2', 'Antecipação condicional'), el('p', a.event, 'v411-note'), warning('Data ainda não confirmada. A agenda normal permanece em vigor.'));
      card.append(el('p', 'A quantidade é o saldo ainda não adquirido da referência. Vestings ocorridos antes do fechamento devem ser excluídos; o valor final depende do saldo no fechamento.', 'v411-note'));
      card.append(pair('Bruto elegível no cenário', a.gross), pair('Líquido estimado no cenário', a.net));
      const detail = disclosure('Concessões e premissas do cenário');
      detail.append(el('p', 'Somente concessões anteriores a 2026 participam desta condição. As concessões de 2026 mantêm seus vestings originais.'));
      detail.append(el('p', 'Preço contratual: ' + money(a.priceUsd, 'USD') + '. Valor bruto elegível: ' + money(a.grossUsd, 'USD') + '; líquido estimado: ' + money(a.netUsd, 'USD') + '.'));
      detail.append(el('p', a.fxRate === null ? 'Conversão para reais ainda indisponível.' : 'Câmbio considerado: ' + number(a.fxRate) + ' reais por dólar.'));
      for (const g of a.grants) detail.append(el('p', date(g.grantDate) + ' · ' + g.type + ' · ' + number(g.quantity) + ' unidades · ' + (g.eligible === true ? 'incluída na condição' : g.eligible === false ? 'fora desta antecipação' : 'elegibilidade em conferência')));
      if (a.unmapped > 0) card.append(warning('O cenário usa as concessões documentadas. Ainda falta vincular ' + a.unmapped + ' componente(s) à agenda; nenhuma data foi antecipada.'));
      card.append(detail); return card;
    }
    function componentOrigin(group) {
      const d = disclosure('Origem e composição desta parcela'); d.classList.add('v411-component-origin');
      for (const c of group.components) {
        const line = el('div', null, 'v411-component');
        line.append(el('p', number(c.quantity) + ' unidades · concessão ' + (c.grantDate ? date(c.grantDate) : 'a identificar') + '.'));
        line.append(pair('Bruto', c.gross), pair('Líquido estimado', c.net));
        line.append(el('p', 'Vesting ' + date(c.vesting) + ' · disponibilidade prevista ' + date(c.available) + '.'));
        line.append(el('p', c.eligible === true ? 'Concessão anterior a 2026; participa somente do cenário condicional.' : c.eligible === false ? 'Fora da antecipação; calendário original preservado.' : 'Concessão ainda sem vínculo documental nesta parcela.'));
        d.append(line);
      }
      d.append(el('p', 'Reserva de 30% como premissa de planejamento. Vesting e disponibilidade prevista não comprovam recebimento bancário.')); return d;
    }
    function patchQuoteModal() {
      if (!state.model) return;
      const modal = document.getElementById('v168Modal');
      if (!modal?.querySelector('#v168AwSave')) return;
      const note = [...modal.querySelectorAll('.v168-note')].find(n => /RSU normal|Cash RSU usa/.test(n.textContent));
      if (note) note.textContent = 'RSUs e Cash RSUs usam líquido estimado após reserva de 30% para planejamento. O valor bruto permanece no acompanhamento.';
    }
    function patchAgenda(root, model) {
      const agenda = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Vestings e disponibilidade');
      if (!agenda) return;
      const total = agenda.querySelector('.v168-cardhead strong'); if (total) total.textContent = money(model?.total.net);
      agenda.querySelectorAll('.v183-award-model-note').forEach(n => n.remove());
      const rows = ui.wealth?.data?.rsu?.future_schedule || [];
      [...agenda.querySelectorAll('.v168-award')].forEach((card, index) => {
        const row = rows[index], group = model?.schedule.find(x => x.key === row?.group_key), matches = api.matchGroup(row, group);
        const value = card.children[3];
        if (value) { value.replaceChildren(el('span', 'Bruto'), el('b', money(matches ? group.gross : null)), el('span', 'Líquido estimado'), el('b', money(matches ? group.net : null)), el('small', date(row?.available_date) + ' · disponibilidade prevista')); value.classList.add('v411-award-values'); }
        card.querySelectorAll('[data-v168-award-date]').forEach(input => input.closest('label')?.remove());
        card.querySelectorAll('[data-v168-award-save]').forEach(button => button.remove());
        card.querySelectorAll('.v183-award-source,.v411-component-origin,.v411-group-warning').forEach(n => n.remove());
        if (matches) card.append(componentOrigin(group));
        else { const p = warning(model ? 'Esta parcela precisa ser atualizada para conferir bruto e líquido.' : 'Líquido em conferência.'); p.classList.add('v411-group-warning'); card.append(p); }
      });
    }
    function patchKpi(root, label, value, note, displayedLabel) {
      const k = [...root.querySelectorAll('.v168-kpi')].find(x => x.querySelector('span')?.textContent.trim() === label);
      if (!k) return; const v = k.querySelector('strong'); if (v) v.textContent = money(value); const s = k.querySelector('small'); if (s) s.textContent = note;
      if (displayedLabel) k.querySelector('span').textContent = displayedLabel;
    }
    function patchDashboard(model) {
      const root = document.querySelector('.v168-dashboard'); if (!root) return;
      patchKpi(root, 'RSUs futuras', model?.regular.net, model ? 'Líquido estimado · bruto ' + money(model.regular.gross) : 'Líquido em conferência');
      patchKpi(root, 'Cash RSUs futuras', model?.cash.net, model ? 'Líquido estimado · bruto ' + money(model.cash.gross) : 'Líquido em conferência');
      for (const label of ['Total de posições futuras', 'Compensação futura', 'RSUs e Cash RSUs futuras']) patchKpi(root, label, model?.total.net, model ? 'Após reserva de 30% · bruto ' + money(model.total.gross) + ' · Retention Award separado' : 'Líquido em conferência', 'RSUs e Cash RSUs futuras');
      root.querySelector('[data-v411-dashboard]')?.remove();
      if (!model && state.status === 'error') { const p = statusNote(); p.dataset.v411Dashboard = ''; root.prepend(p); }
    }
    function patchWealth(model) {
      const root = document.querySelector('.v168-wealth'); if (!root) return;
      root.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration]').forEach(n => n.remove());
      if (ui.wealth?.tab === 'overview') {
        const card = [...root.querySelectorAll('article')].find(n => n.querySelector('h2')?.textContent === 'Valores a receber no futuro');
        if (card) card.replaceWith(projection(model)); return;
      }
      if (ui.wealth?.tab !== 'rsu') return;
      const anchor = root.querySelector('.v168-tabs') || root.querySelector('[role="tablist"]');
      const p = projection(model); if (anchor) anchor.after(p); else root.prepend(p);
      let last = p;
      if (model?.reference) { const card = referencePanel(model.reference); last.after(card); last = card; }
      if (model?.acceleration) { const card = accelerationPanel(model.acceleration); last.after(card); }
      patchAgenda(root, model);
      // Old comparison cards remain documentary history, not the current net policy.
      root.querySelectorAll('.v172-morgan > .v168-note').forEach(n => { n.textContent = 'Posição datada e agenda são bases distintas. A agenda atual considera reserva de 30% para RSUs e Cash RSUs.'; });
      const oldReference = root.querySelector('.v352-brokerage-reference');
      if (oldReference && model?.reference && !oldReference.parentElement?.classList.contains('v411-prior-reference')) {
        const d = disclosure('Referência anteriormente cadastrada'); d.classList.add('v411-prior-reference'); oldReference.before(d); d.append(oldReference);
      }
    }
    function patchFlow(model) {
      document.querySelector('[data-v411-flow-policy]')?.remove();
      const controls = document.querySelector('.flow-sticky-controls'); if (!controls) return;
      if (!model) { if (state.status === 'error') { const p = statusNote(); p.dataset.v411FlowPolicy = ''; controls.after(p); } return; }
      const d = disclosure('Premissas de RSU e salário'); d.dataset.v411FlowPolicy = '';
      d.append(el('p', 'RSUs e Cash RSUs: líquido estimado após reserva de 30%, disponível nas datas da agenda normal. A condição de antecipação permanece separada.'));
      if (model.payroll) d.append(el('p', 'Previsão de salário mensal: base ' + money(model.payroll.base) + ' menos a parcela Coopharma da competência. Valores já líquidos do holerite permanecem preservados.'));
      controls.after(d);
    }
    function after() {
      if (owner !== identity()) { owner = identity(); marketRevision = null; invalidate(); }
      if (!D || N.classList.contains('hidden')) return;
      if (!['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) return;
      if (state.status === 'idle') queueMicrotask(() => load());
      if (state.status === 'disabled') return;
      if (V === 'Dashboard') patchDashboard(state.model);
      if (V === 'Patrimônio') patchWealth(state.model);
      if (V === 'Fluxo Diário') patchFlow(state.model);
      patchQuoteModal();
    }
    async function load(force = false) {
      if (!D || N.classList.contains('hidden')) return;
      if (state.status === 'loading' || !force && state.status !== 'idle') return;
      const token = ++state.token, requestedOwner = identity(); state.status = 'loading'; state.error = null;
      try {
        const response = await S.rpc('lts_browser_rsu_policy_v411', {});
        if (token !== state.token || requestedOwner !== identity()) return;
        if (response?.error) throw Error('Policy unavailable');
        state.model = api.build(response?.data); state.status = state.model ? 'ready' : 'disabled';
      } catch {
        if (token !== state.token || requestedOwner !== identity()) return;
        state.model = null; state.status = 'error'; state.error = 'unavailable';
      }
      if (['Dashboard', 'Patrimônio', 'Fluxo Diário'].includes(V)) render();
    }
    function invalidate() { state.token++; state.status = 'idle'; state.model = null; state.error = null; }
    function refresh() {
      invalidate();
      if (ui.wealth) { ui.wealth.data = null; ui.wealth.error = null; }
      window.__LTS_V178_REVIEW?.refresh?.(); render(); load();
    }
    const rpc = S.rpc.bind(S), writers = new Set(['lts_browser_save_all_award_assumptions_v1', 'lts_browser_save_award_assumption_v1', 'lts_browser_market_mode_v290']);
    S.rpc = function (name, args, ...rest) {
      const result = rpc(name, args, ...rest);
      if (name === 'lts_browser_market_quotes_v290') return Promise.resolve(result).then(response => {
        if (!response?.error && response?.data?.revision != null) {
          const changed = marketRevision !== null && marketRevision !== response.data.revision;
          marketRevision = response.data.revision;
          if (changed) { invalidate(); queueMicrotask(() => load()); }
        }
        return response;
      });
      if (!writers.has(name)) return result;
      return Promise.resolve(result).then(response => { if (!response?.error && response?.data?.ok) { invalidate(); queueMicrotask(() => load()); } return response; });
    };
    S.auth.onAuthStateChange?.(event => { if (event === 'SIGNED_OUT' || event === 'SIGNED_IN') { invalidate(); document.querySelectorAll('[data-v411-projection],[data-v411-reference],[data-v411-acceleration],[data-v411-flow-policy]').forEach(n => n.remove()); } });
    document.addEventListener('click', event => {
      if (event.target.closest?.('[data-v168-award-edit]')) patchQuoteModal();
    });
    document.addEventListener('click', event => { if (event.target.closest?.('#logout')) invalidate(); }, true);
    const style = el('style'); style.id = 'v411-rsu-style';
    style.textContent = '.v411-projection,.v411-reference,.v411-acceleration{margin:14px 0!important;min-width:0}.v411-values{border-collapse:collapse;width:100%;margin:12px 0;font-size:13px;table-layout:fixed}.v411-values th,.v411-values td{padding:10px 7px;border-bottom:1px solid #e1e7ed;text-align:right;overflow-wrap:anywhere;vertical-align:top}.v411-values th:first-child{text-align:left;width:24%}.v411-values td{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-values tbody tr:last-child{font-weight:700}.v411-pair{display:flex;justify-content:space-between;gap:12px;align-items:baseline;padding:8px 0;font-size:13px}.v411-pair span{min-width:0}.v411-pair b{font-variant-numeric:tabular-nums;white-space:nowrap}.v411-note,.v411-warning,.v411-loading{font-size:13px;line-height:1.5;margin:10px 0;white-space:normal}.v411-warning{color:#875b18}.v411-loading,.v411-note{color:#536174}.v411-origin{margin:10px 0;font-size:12px;line-height:1.5;white-space:normal;overflow-wrap:anywhere}.v411-origin>summary{cursor:pointer;padding:9px 0;font-weight:600}.v411-origin p{margin:8px 0}.v411-component{padding:7px 0;border-top:1px solid #e1e7ed}.v411-component-origin,.v411-group-warning{grid-column:1/-1}.v411-award-values{display:flex;flex-direction:column;gap:3px}.v411-award-values>b{white-space:nowrap}.v411-award-values>span:nth-of-type(2){margin-top:7px}.v411-prior-reference{padding:0 8px}.v411-values th{font-weight:600}@media(max-width:600px){.v411-values{font-size:12px;display:block}.v411-values thead,.v411-values tbody{display:block}.v411-values tr{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);column-gap:8px}.v411-values th,.v411-values td{padding:8px 0;text-align:left}.v411-values th:first-child{width:auto;grid-column:1/-1;padding-bottom:1px;border-bottom:0}.v411-values thead th:first-child{display:none}.v411-values td{font-size:12px}.v411-pair{font-size:12px;gap:7px}.v411-projection h2,.v411-reference h2,.v411-acceleration h2{font-size:16px}.v411-origin>summary{min-height:24px}}';
    document.head.append(style);
    render = function () { const result = prior.apply(this, arguments); after(); return result; };
    Object.assign(state, { after, refresh, load, invalidate }); window.__LTS_V411_RSU = state; after();
  }
  function install() {
    try {
      const w = shell?.contentWindow, d = shell?.contentDocument;
      if (!w?.__LTS_V365?.installed || !w?.__LTS_V183_AWARD_PROVENANCE?.installed) return false;
      if (!w.__LTS_V411_RSU?.installed) { const script = d.createElement('script'); script.textContent = '(' + runtime.toString() + ')(' + createAPI.toString() + ');'; d.head.append(script); }
      return !!w.__LTS_V411_RSU?.installed;
    } catch { return false; }
  }
  let generation = 0;
  function start() { const current = ++generation; let tries = 0; function attempt() { if (current !== generation) return; if (!install() && ++tries < 400) setTimeout(attempt, 100); } attempt(); }
  shell?.addEventListener('load', start); start(); window.LTSV339Boot?.watch('lts-v411-rsu-policy.js', install);
})();
