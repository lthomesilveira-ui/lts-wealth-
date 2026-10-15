'use strict';
// Pure presentation contract used by the browser candidate; accepts only the
// documentary field and never changes a cycle, source status or amount.
function documentaryPaymentNote(cycle, esc, formatDate) {
  const e = cycle?.documentary_payment_evidence;
  if (!e) return '';
  if (e.status === 'source_changed') return '<p class="v226-note">A fonte do pagamento mudou. A associação documental precisa ser conferida novamente.</p>';
  if (e.status !== 'identified_in_statement' || e.cash_effect !== 'none' || e.currency !== 'BRL' || !/^\d{4}-\d{2}-\d{2}$/.test(e.payment_date || '') || !(Number(e.amount) > 0)) return '';
  return '<p class="v226-note">Pagamento identificado no extrato em ' + esc(formatDate(e.payment_date)) + '. Associação documental conferida; o estado informado pelo emissor é apresentado separadamente.</p>';
}
module.exports = { documentaryPaymentNote };
