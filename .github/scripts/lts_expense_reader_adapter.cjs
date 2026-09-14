'use strict';
/** Offline adapter for an ALREADY obtained monthly response and independently
 * verified source references. Does not fetch sources, create links, refresh
 * caches, apply user decisions, or certify the source evidence itself. */
const model = require('../../lts-expense-read-model.js');
function buildAuditInput({detail, reference, bindings, bindings_verified, report_date_basis, labels_open_invoice = false}) {
  const month = model.normalizeMonth(detail);
  if (!reference || !Array.isArray(reference.rows) || !Array.isArray(reference.coverage)
      || reference.from !== month.scope.month || reference.to !== month.scope.through
      || month.scope.category !== null || typeof report_date_basis !== 'string' || !report_date_basis
      || !Array.isArray(reference.unresolved_controls) || !Array.isArray(bindings)) {
    throw new TypeError('An unfiltered, same-period reference and explicit identity bindings are required.');
  }
  const map = new Map(), referenceKeys = new Set(reference.rows.map(row => row.canonical_key));
  for (const b of bindings) {
    if (!b || !Array.isArray(b.report_identity) || b.report_identity.length !== 3
        || !b.report_identity.every(x => typeof x === 'string' && x.length)
        || typeof b.canonical_key !== 'string' || !referenceKeys.has(b.canonical_key)
        || typeof b.coverage_id !== 'string' || !b.coverage_id
        || !['observed','open_invoice','projection'].includes(b.evidence_state)) throw new TypeError('Invalid documented source binding.');
    const key = JSON.stringify(b.report_identity);
    if (map.has(key)) throw new TypeError('Repeated source binding.');
    map.set(key, b);
  }
  const levels = {transaction: 'transactions', category_only: 'categories_only', total_only: 'total_only'};
  const coverage = new Map();
  const rows = month.rows.map(row => {
    const b = map.get(row.key);
    if (!b) throw new TypeError('Source identity has no documented binding; do not match by amount or description.');
    const level = levels[row.detailLevel], existing = coverage.get(b.coverage_id);
    if (existing && existing.detail_level !== level) throw new TypeError('Mixed detail levels require a documented finer coverage key.');
    coverage.set(b.coverage_id, {id:b.coverage_id, detail_level:level});
    return {canonical_key:b.canonical_key, amount_cents:row.amountCents, period_date:row.eventDate,
      original_purchase_date:row.transactionDate, category:row.category, center_cost:row.centerCost,
      treatment:'included', // This existing reader includes every returned line in its expense total.
      evidence_state:b.evidence_state};
  });
  const input = {
    from:reference.from, to:reference.to,
    reference:{date_basis:reference.date_basis, rows:JSON.parse(JSON.stringify(reference.rows)),
      coverage:JSON.parse(JSON.stringify(reference.coverage)),
      lineage_verified:reference.lineage_verified === true && bindings_verified === true,
      coverage_complete:reference.coverage_complete === true, zero_activity_verified:reference.zero_activity_verified === true},
    report:{date_basis:report_date_basis, rows, coverage:Array.from(coverage.values()),
      declared_total_cents:month.declaredTotalCents, claims_transaction_drilldown:month.rows.every(r => r.canOpenTransaction),
      labels_open_invoice:labels_open_invoice === true},
    user_questions_answered:reference.user_questions_answered === true,
    unresolved_controls:[...reference.unresolved_controls, ...month.issues.filter(i => i.code !== 'category_pending').map(i => 'monthly_reader:' + i.code)]
  };
  return {input, month};
}
function auditMonthly(options) {
  const {auditExpenses} = require('./lts_expense_integrity.cjs');
  const {input, month} = buildAuditInput(options);
  return {scope:{from:input.from,to:input.to,date_basis:input.report.date_basis},
    ...auditExpenses(input), reader_contract_issues:month.issues,
    live_data_fetched:false, source_mutations:0};
}
module.exports = {buildAuditInput, auditMonthly};
