'use strict';
function documentaryPaymentNote(cycle, esc, formatDate, mode = 'note') {
  const e = cycle?.documentary_payment_evidence;
  const sourceLabel = cycle?.payment_status === 'payment_not_reported' ? ' · pagamento não informado' : cycle?.payment_status === 'payment_reported' ? ' · pagamento informado' : cycle?.payment_status === 'paid' ? ' · pagamento confirmado' : '';
  const isLabel = mode === 'label';
  if (!e) return isLabel ? sourceLabel : '';
  if (e.status === 'source_changed') return isLabel ? sourceLabel : '<p class="v226-note">A fonte do pagamento mudou. A associação documental precisa ser conferida novamente.</p>';
  const isoDate = value => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value || '')) return false;
    const date = new Date(value + 'T12:00:00Z');
    return Number.isFinite(date.valueOf()) && date.toISOString().slice(0, 10) === value;
  };
  const baseValid = e.status === 'identified_in_statement' && e.cash_effect === 'none' && e.currency === 'BRL' && isoDate(e.payment_date) && typeof e.amount === 'number' && Number.isFinite(e.amount) && e.amount > 0;
  if (!baseValid) return isLabel ? sourceLabel : '';
  if (e.basis === 'reviewed_original_link_and_exact_issuer_refresh') {
    const refreshValid = e.issuer_payment_type === 'FULL_PAYMENT' && e.bank_posting_status === 'POSTED' && isoDate(e.issuer_payment_date) && isoDate(e.bank_posting_date) && e.payment_date === e.bank_posting_date && typeof cycle.amount === 'number' && Number.isFinite(cycle.amount) && cycle.amount > 0 && cycle.amount === e.amount;
    if (!refreshValid) return isLabel ? sourceLabel : '';
    if (isLabel) return ' · pagamento integral informado pelo emissor';
    return '<p class="v226-note">Emissor: pagamento integral informado em ' + esc(formatDate(e.issuer_payment_date)) + '. Banco: débito lançado no extrato em ' + esc(formatDate(e.bank_posting_date)) + '. Associação documental conferida; cada data corresponde à sua fonte.</p>';
  }
  if (isLabel) return sourceLabel;
  return '<p class="v226-note">Pagamento identificado no extrato em ' + esc(formatDate(e.payment_date)) + '. Associação documental conferida; o estado informado pelo emissor é apresentado separadamente.</p>';
}
module.exports = { documentaryPaymentNote };
