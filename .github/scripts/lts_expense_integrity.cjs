'use strict';
/**
 * Offline, read-only contract verifier for the existing expense readers.
 * No network, credentials, SQL, source edits, category inference or deduplication.
 * canonical_key and treatment MUST come from a verified source-lineage adapter.
 * The adapter and integration with the current app are NOT implemented here.
 */
const assert = require('node:assert/strict');
const RESERVED = new Set(['', 'a classificar', '—', 'classificação pendente']);
const dateOK = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value)
  && !Number.isNaN(Date.parse(value + 'T12:00:00Z'))
  && new Date(value + 'T12:00:00Z').toISOString().slice(0, 10) === value;
const blankCategory = value => RESERVED.has(String(value || '').trim().toLocaleLowerCase('pt-BR'));

function auditExpenses(input) {
  const issues = [];
  const add = (code, scope, key) => issues.push({code, scope, ...(key ? {key} : {})});
  if (!input || !dateOK(input.from) || !dateOK(input.to) || input.from > input.to) {
    throw new TypeError('Expected a valid inclusive YYYY-MM-DD period.');
  }
  for (const side of ['reference', 'report']) {
    if (!input[side] || !Array.isArray(input[side].rows) || !Array.isArray(input[side].coverage)) {
      throw new TypeError('Both readings require rows and explicit documentary coverage.');
    }
  }
  if (!Array.isArray(input.unresolved_controls)) throw new TypeError('Controls must be explicit.');
  if (!input.reference.date_basis || input.reference.date_basis !== input.report.date_basis) {
    add('date_basis_mismatch', 'report');
  }
  if (input.reference.lineage_verified !== true) add('reference_lineage_unverified', 'reference');
  if (input.reference.coverage_complete !== true) add('coverage_incomplete', 'reference');
  if (input.reference.rows.length === 0 && input.reference.zero_activity_verified !== true) {
    add('empty_is_not_verified_zero', 'reference');
  }
  function index(side) {
    const map = new Map();
    for (const row of input[side].rows) {
      if (!row || typeof row.canonical_key !== 'string' || !row.canonical_key
          || !Number.isSafeInteger(row.amount_cents) || !dateOK(row.period_date)
          || !['included', 'control', 'unknown'].includes(row.treatment)
          || !['observed', 'open_invoice', 'projection'].includes(row.evidence_state)
          || typeof row.category !== 'string') {
        throw new TypeError('Rows require exact source identity, cents, period date, treatment and evidence.');
      }
      if (map.has(row.canonical_key)) add('duplicate_source', side, row.canonical_key);
      else map.set(row.canonical_key, row);
      if (row.period_date < input.from || row.period_date > input.to) add('outside_period', side, row.canonical_key);
      if (row.treatment === 'unknown') add('economic_treatment_unresolved', side, row.canonical_key);
      if (row.treatment === 'included' && blankCategory(row.category)) add('category_pending', side, row.canonical_key);
      if (row.treatment === 'included' && row.evidence_state === 'projection') add('projection_is_not_realized', side, row.canonical_key);
    }
    return map;
  }
  const reference = index('reference'), report = index('report');
  for (const [key, expected] of reference) {
    const actual = report.get(key);
    if (!actual) { add('missing_source', 'report', key); continue; }
    for (const field of ['amount_cents', 'period_date', 'category', 'treatment', 'evidence_state']) {
      if (actual[field] !== expected[field]) add(field + '_mismatch', 'report', key);
    }
    if ((actual.center_cost || null) !== (expected.center_cost || null)) add('center_cost_mismatch', 'report', key);
  }
  for (const key of report.keys()) if (!reference.has(key)) add('extra_source', 'report', key);
  for (const side of ['reference', 'report']) {
    const ids = new Set();
    for (const coverage of input[side].coverage) {
      if (!coverage || !coverage.id || !['transactions', 'categories_only', 'total_only', 'missing'].includes(coverage.detail_level)) {
        throw new TypeError('Coverage needs a source id and its documented detail level.');
      }
      if (ids.has(coverage.id)) add('duplicate_coverage', side, coverage.id);
      ids.add(coverage.id);
      if (coverage.detail_level === 'missing') add('missing_document', side, coverage.id);
    }
  }
  const reportCoverage = new Map(input.report.coverage.map(item => [item.id, item]));
  for (const source of input.reference.coverage) {
    const actual = reportCoverage.get(source.id);
    if (!actual) add('missing_coverage', 'report', source.id);
    else if (source.detail_level !== actual.detail_level) add('detail_level_mismatch', 'report', source.id);
  }
  const referenceIds = new Set(input.reference.coverage.map(item => item.id));
  for (const source of input.report.coverage) if (!referenceIds.has(source.id)) add('extra_coverage', 'report', source.id);
  if (input.report.claims_transaction_drilldown === true && input.reference.coverage.some(item => item.detail_level !== 'transactions')) {
    add('unsupported_drilldown_claim', 'report');
  }
  const sum = side => {
    let cents = 0;
    for (const row of input[side].rows) if (row.treatment === 'included') {
      cents += row.amount_cents;
      if (!Number.isSafeInteger(cents)) throw new RangeError('Unsafe total: do not round silently.');
    }
    return cents;
  };
  const referenceTotal = sum('reference'), reportTotal = sum('report');
  if (referenceTotal !== reportTotal) add('source_total_mismatch', 'report');
  if (!Number.isSafeInteger(input.report.declared_total_cents)
      || input.report.declared_total_cents !== reportTotal) add('displayed_total_mismatch', 'report');
  for (const control of input.unresolved_controls) add('open_control', 'report', String(control));
  const openInvoices = input.reference.rows.some(row => row.treatment === 'included' && row.evidence_state === 'open_invoice');
  if (openInvoices && input.report.labels_open_invoice !== true) add('open_invoice_not_labelled', 'report');
  return Object.freeze({
    version: 'expense-source-integrity-v1',
    source_mutations: 0,
    automatic_classifications: 0,
    source_parity: issues.length === 0,
    provisional_period: openInvoices,
    definitive_report_ready: issues.length === 0 && !openInvoices,
    user_questions_answered: input.user_questions_answered === true,
    issues,
    totals: {reference_cents: referenceTotal, report_cents: reportTotal}
  });
}

function selfTest() {
  const base = () => {
    const rows = [
      {canonical_key:'fixture:purchase:1', amount_cents:12300, period_date:'2026-08-01', original_purchase_date:'2026-06-28', category:'Exemplo', treatment:'included', evidence_state:'observed', center_cost:null},
      {canonical_key:'fixture:payment:1', amount_cents:12300, period_date:'2026-08-10', category:'Liquidação', treatment:'control', evidence_state:'observed', center_cost:null}
    ];
    const ref = {date_basis:'documented_competence', rows, lineage_verified:true, coverage_complete:true, coverage:[{id:'fixture:invoice:1',detail_level:'transactions'}]};
    return {from:'2026-08-01',to:'2026-08-31',reference:ref,report:{...JSON.parse(JSON.stringify(ref)),declared_total_cents:12300,claims_transaction_drilldown:true},unresolved_controls:[],user_questions_answered:true};
  };
  const cases = [];
  const test = (name, fn) => { fn(); cases.push(name); };
  const detects = (change, code) => { const value=base();change(value);assert(auditExpenses(value).issues.some(issue=>issue.code===code)); };
  test('matching_sources_and_older_purchase_installment',()=>assert(auditExpenses(base()).definitive_report_ready));
  test('no_input_mutation',()=>{const x=base(),before=JSON.stringify(x);auditExpenses(x);assert.equal(JSON.stringify(x),before);});
  test('answered_is_not_applied',()=>detects(x=>{x.reference.rows[0].category='A classificar';x.report.rows[0].category='A classificar';},'category_pending'));
  test('stale_category_detected',()=>detects(x=>x.report.rows[0].category='Categoria anterior','category_mismatch'));
  test('missing_row_detected',()=>detects(x=>x.report.rows.shift(),'missing_source'));
  test('extra_row_detected',()=>detects(x=>x.report.rows.push({...x.report.rows[0],canonical_key:'fixture:extra'}),'extra_source'));
  test('duplicate_source_detected',()=>detects(x=>x.report.rows.push({...x.report.rows[0]}),'duplicate_source'));
  test('one_cent_not_ignored',()=>detects(x=>x.report.rows[0].amount_cents++,'amount_cents_mismatch'));
  test('payment_not_second_consumption',()=>detects(x=>x.report.rows[1].treatment='included','treatment_mismatch'));
  test('different_date_basis_detected',()=>detects(x=>x.report.date_basis='original_purchase_date','date_basis_mismatch'));
  test('pending_reconciliation_prevents_ready',()=>detects(x=>x.unresolved_controls.push('fixture:advance_link'),'open_control'));
  test('partial_history_not_fake_drilldown',()=>detects(x=>{x.reference.coverage[0].detail_level='categories_only';x.report.coverage[0].detail_level='categories_only';},'unsupported_drilldown_claim'));
  test('missing_document_detected',()=>detects(x=>x.reference.coverage[0].detail_level='missing','missing_document'));
  test('empty_not_assumed_zero',()=>detects(x=>{x.reference.rows=[];x.report.rows=[];x.report.declared_total_cents=0;},'empty_is_not_verified_zero'));
  test('open_invoice_is_explicitly_provisional',()=>{const x=base();for(const side of ['reference','report'])x[side].rows[0].evidence_state='open_invoice';x.report.labels_open_invoice=true;const y=auditExpenses(x);assert(y.source_parity);assert(y.provisional_period);assert(!y.definitive_report_ready);});
  test('projection_not_realized',()=>detects(x=>x.reference.rows[0].evidence_state='projection','projection_is_not_realized'));
  test('invalid_money_rejected',()=>assert.throws(()=>{const x=base();x.report.rows[0].amount_cents=1.5;auditExpenses(x);},TypeError));
  test('same_descriptions_do_not_link_sources',()=>detects(x=>x.report.rows[0].canonical_key='fixture:similar-description','missing_source'));
  test('zero_requires_positive_evidence',()=>{const x=base();for(const side of ['reference','report'])x[side].rows=[];x.reference.zero_activity_verified=true;x.report.declared_total_cents=0;assert(auditExpenses(x).definitive_report_ready);});
  test('refund_sign_is_preserved',()=>{const x=base();for(const side of ['reference','report'])x[side].rows.push({...x[side].rows[0],canonical_key:'fixture:credit',amount_cents:-300});x.report.declared_total_cents=12000;assert(auditExpenses(x).source_parity);});
  return {status:'PASS',passed:cases.length,cases,scope:'synthetic fixtures only; no database or browser calls',live_adapter_implemented:false,live_report_verified:false,source_mutations:0};
}
module.exports = {auditExpenses, selfTest};
if (require.main === module) {
  if (process.argv[2] !== '--self-test') {
    console.error('Use --self-test. Live adapter is deliberately not provided.');process.exitCode=2;
  } else console.log(JSON.stringify(selfTest(),null,2));
}
