(function () {
  'use strict';
  const openDates = new Set();
  const aeternumRef = /^projection:v469:(?:owner_[a-z_]+|sub_[a-z0-9_]+|pharmacy|hair|membership|prime_2990):([0-9]{4}-[0-9]{2}-[0-9]{2})$/;

  const itauRef = /^projection:v468:(?:apple_monthly_[0-9]+_[0-9]{2}|google_ai_plus):([0-9]{4}-[0-9]{2}-[0-9]{2})$/;
  const labels = {itau: 'Provisão cartão Itaú', aeternum: 'Provisão Visa Aeternum'};

  function cardOf(event) {
    if (typeof event.event_date !== 'string' || event.source !== 'planning_projection_v412' || !Number.isFinite(Number(event.signed_amount)) || Number(event.signed_amount) >= 0) return null;
    const card = event.account === 'Itaú' ? 'itau' : event.account === 'Bradesco' ? 'aeternum' : null;
    if (!card) return null;
    const ref = card === 'itau' ? itauRef : aeternumRef;
    return ref.exec(event.source_ref || '')?.[1] === event.event_date ? card : null;
  }

  function groupFor(events) {
    // A render may replace an open disclosure before its queued toggle event fires.
    for (const node of document.querySelectorAll('details[data-v478-invoice]')) {
      if (node.open) openDates.add(node.dataset.v478Invoice);
      else openDates.delete(node.dataset.v478Invoice);
    }
    const groups = new Map();
    const byEvent = new Map();
    for (const event of events) {
      const card = cardOf(event);
      if (!card) continue;
      const key = card + ':' + event.event_date;
      if (!groups.has(key)) groups.set(key, []);
      const parts = groups.get(key);
      parts.push(event);
      byEvent.set(event, parts);
    }
    return byEvent;
  }

  function title(event, original) {
    if (event.source === 'planning_projection_v412' && event.account === 'Itaú'
        && event.source_ref === 'projection:v412:netflix:' + event.event_date) return 'Provisão Netflix';
    return original;
  }

  function componentName(event) {
    const name = String(event.description || '').replace(/^provisão de\s+/iu, '')
      .replace(/(?:\s*·\s*(?:visa aeternum|provisão|previsão|assinatura prevista|continuidade prevista))+$/iu, '').trim();
    return name ? name[0].toLocaleUpperCase('pt-BR') + name.slice(1) : 'Despesa prevista';
  }

  function invoice(parts, escape, money) {
    if (!parts.length) return '';
    const card = cardOf(parts[0]);
    if (!card) return '';
    const key = card + ':' + parts[0].event_date;
    const cents = event => Math.round(-Number(event.signed_amount) * 100);
    const total = parts.reduce((sum, event) => sum + cents(event), 0);
    const items = [...parts].sort((a, b) => cents(b) - cents(a) || componentName(a).localeCompare(componentName(b), 'pt-BR'));
    const rows = items.map(event => '<li><span>' + escape(componentName(event)) + '</span><b>' + money(cents(event)/100) + '</b></li>').join('');
    return '<details class="v478-invoice" data-v478-invoice="' + escape(key) + '"' + (openDates.has(key) ? ' open' : '') + '>'
      + '<summary><span><b>' + labels[card] + '</b><small>Ver composição</small></span><strong>' + money(total/100) + '</strong></summary>'
      + '<ul aria-label="Valores projetados">' + rows + '</ul></details>';
  }

  document.addEventListener('toggle', event => {
    const node = event.target;
    if (!(node instanceof HTMLDetailsElement) || !node.isConnected || !node.hasAttribute('data-v478-invoice')) return;
    if (node.open) openDates.add(node.dataset.v478Invoice);
    else openDates.delete(node.dataset.v478Invoice);
  }, true);
  window.LTSInvoiceProvision = {isComponent: event => Boolean(cardOf(event)), groupFor, title, invoice};
})();
