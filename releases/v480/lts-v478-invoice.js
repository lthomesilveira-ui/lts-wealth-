(function () {
  'use strict';
  const openDates = new Set();
  const componentRef = /^projection:v469:(?:owner_[a-z_]+|sub_[a-z0-9_]+|pharmacy|hair|membership|prime_2990):([0-9]{4}-[0-9]{2}-[0-9]{2})$/;

  function isComponent(event) {
    if (event.source !== 'planning_projection_v412' || event.account !== 'Bradesco') return false;
    const match = componentRef.exec(event.source_ref || '');
    const amount = Number(event.signed_amount);
    return Boolean(match && match[1] === event.event_date && Number.isFinite(amount) && amount < 0);
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
    const date = parts[0].event_date;
    const cents = event => Math.round(-Number(event.signed_amount) * 100);
    const total = parts.reduce((sum, event) => sum + cents(event), 0);
    const items = [...parts].sort((a, b) => cents(b) - cents(a) || componentName(a).localeCompare(componentName(b), 'pt-BR'));
    const rows = items.map(event => '<li><span>' + escape(componentName(event)) + '</span><b>' + money(cents(event)/100) + '</b></li>').join('');
    return '<details class="v478-invoice" data-v478-invoice="' + escape(date) + '"' + (openDates.has(date) ? ' open' : '') + '>'
      + '<summary><span><b>Provisão Visa Aeternum</b><small>Ver composição</small></span><strong>' + money(total/100) + '</strong></summary>'
      + '<ul aria-label="Valores projetados">' + rows + '</ul></details>';
  }

  document.addEventListener('toggle', event => {
    const node = event.target;
    if (!(node instanceof HTMLDetailsElement) || !node.isConnected || !node.hasAttribute('data-v478-invoice')) return;
    if (node.open) openDates.add(node.dataset.v478Invoice);
    else openDates.delete(node.dataset.v478Invoice);
  }, true);
  window.LTSInvoiceProvision = {isComponent, title, invoice};
})();
