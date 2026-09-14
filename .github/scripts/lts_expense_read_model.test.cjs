'use strict';
const assert = require('node:assert/strict');
const M = require('../../lts-expense-read-model.js');
const A = require('./lts_expense_reader_adapter.cjs');
const clone = x => JSON.parse(JSON.stringify(x));
function fixture() {
  const row = (ref, amount, category, level='transaction') => ({event_date:'2026-08-03', transaction_date:'2026-06-15', amount,
    category, center_cost:null, counterparty:'Exemplo fictício', origin_type:'cartão', origin_name:'Cartão de teste',
    source_table:'fixture_purchase', source_ref:ref, coverage_mode:level==='transaction'?'card_detail_structured':'card_invoice_aggregate_fallback', detail_level:level});
  return {version:'expense-month-detail-v2-certified-category-allocation', month:'2026-08-01',through:'2026-08-31',is_partial:false,
    category_filter:null,total:145,rows:4,category_known_total:125,category_unallocated_total:20,category_allocated_history_total:0,
    categories:[{name:'B',total:25,rows:2},{name:'A',total:100,rows:1}],
    items:[row('1',100,'A'),row('2',30,'B'),row('3',-5,'B'),row('4',20,'Total histórico','total_only')]};
}
function executive() {
  return {version:'expense-executive-v12-cached-effective-contract',period:{from:'2026-08-01',to:'2026-08-31'},
    summary:{selected_total:145},monthly_detail:[{month:'2026-08-01',total:145,rows:4}],
    rankings:{categories:[{name:'A',total:100,rows:1}]},data_quality:{cache_refreshed_at:'2026-09-01T08:00:00Z'}};
}
function auditOptions() {
  const detail = fixture(), month=M.normalizeMonth(detail);
  const bindings=month.rows.map(r=>({report_identity:JSON.parse(r.key),canonical_key:'fixture:'+r.sourceRef,coverage_id:'document:'+r.sourceRef,evidence_state:'observed'}));
  const rows=month.rows.map(r=>({canonical_key:'fixture:'+r.sourceRef,amount_cents:r.amountCents,period_date:r.eventDate,
    category:r.category,center_cost:r.centerCost,treatment:'included',evidence_state:'observed'}));
  const coverage=month.rows.map(r=>({id:'document:'+r.sourceRef,detail_level:r.canOpenTransaction?'transactions':'total_only'}));
  return {detail,bindings,bindings_verified:true,report_date_basis:'documented_event_date',reference:{from:'2026-08-01',to:'2026-08-31',
    date_basis:'documented_event_date',rows,coverage,lineage_verified:true,coverage_complete:true,unresolved_controls:[],user_questions_answered:true}};
}
const tests=[];
function test(name,fn){tests.push({name,fn});}
const issue=(change,code)=>{const p=fixture();change(p);assert(M.normalizeMonth(p).issues.some(i=>i.code===code));};
test('exact_decimal_cents_and_refund',()=>{assert.equal(M.cents('12.30'),1230);assert.equal(M.cents(-0.05),-5);});
test('null_blank_localized_or_subcent_money_rejected',()=>{for(const v of [null,undefined,'','1.234,50',true,1.234,Infinity,'1e3'])assert.throws(()=>M.cents(v));});
test('unsafe_money_rejected',()=>assert.throws(()=>M.cents('90071992547409.92'),RangeError));
test('invalid_calendar_date_rejected',()=>assert.throws(()=>M.date('2026-02-30')));
test('valid_existing_month_contract',()=>assert(M.normalizeMonth(fixture()).internallyConsistent));
test('old_purchase_retained_by_documented_event_period',()=>assert.equal(M.normalizeMonth(fixture()).rows[0].transactionDate,'2026-06-15'));
test('total_is_not_changed_by_filtering_older_purchase',()=>assert.equal(M.normalizeMonth(fixture()).actualTotalCents,14500));
test('sorted_categories_preserve_names',()=>assert.deepEqual(M.normalizeMonth(fixture()).categories.map(c=>c.name),['A','B']));
test('input_not_mutated_and_output_deeply_frozen',()=>{const p=fixture(),s=JSON.stringify(p),n=M.normalizeMonth(p);assert.equal(JSON.stringify(p),s);assert(Object.isFrozen(n.rows[0]));assert.throws(()=>n.rows[0].category='Changed',TypeError);});
test('missing_total_is_not_zero',()=>{const p=fixture();p.total=null;assert.throws(()=>M.normalizeMonth(p));});
test('unknown_contract_rejected',()=>{const p=fixture();p.version='new-unknown';assert.throws(()=>M.normalizeMonth(p));});
test('exact_one_cent_difference_blocks_total',()=>{const p=fixture();p.total=145.01;const n=M.normalizeMonth(p);assert.equal(M.presentation(n).totalCents,null);});
test('duplicate_source_detected',()=>issue(p=>{p.items[1].source_ref='1';},'duplicate_source'));
test('truncated_response_detected',()=>issue(p=>p.rows=5,'row_count_mismatch'));
test('category_changed_without_summary_detected',()=>issue(p=>p.items[0].category='Outra','category_summary_mismatch'));
test('category_only_does_not_claim_purchase_detail',()=>{const p=fixture();p.items[0].detail_level='category_only';p.category_allocated_history_total=100;const n=M.normalizeMonth(p);assert.equal(n.rows[0].canOpenTransaction,false);assert.equal(n.categoryOnlyRows,1);});
test('total_only_no_fake_item_drilldown',()=>{const n=M.normalizeMonth(fixture());assert.equal(n.rows[3].canOpenTransaction,false);assert(!n.categories.some(c=>c.name==='Total histórico'));});
test('pending_category_not_full_classification',()=>{const p=fixture();p.items[0].category='A classificar';p.categories[1].name='A classificar';const n=M.normalizeMonth(p);assert.equal(n.missingCategoryRows,1);assert.equal(n.definitiveReportReady,false);});
test('partial_month_explicit',()=>{const p=fixture();p.through='2026-08-14';p.is_partial=true;assert.equal(M.presentation(M.normalizeMonth(p)).periodLabel,'Mês parcial');});
test('false_complete_period_detected',()=>issue(p=>{p.through='2026-08-14';},'partial_period_flag_mismatch'));
test('mismatched_requested_scope_rejected',()=>assert.throws(()=>M.normalizeMonth(fixture(),{month:'2026-08-01',through:'2026-08-14'})));
test('out_of_period_not_silently_dropped',()=>issue(p=>p.items[1].event_date='2026-07-31','outside_selected_period'));
test('different_category_response_rejected',()=>assert.throws(()=>M.normalizeMonth(fixture(),{month:'2026-08-01',through:'2026-08-31',category:'A'})));
test('safe_empty_does_not_certify_zero_activity',()=>{const p=fixture();Object.assign(p,{items:[],categories:[],rows:0,total:0,category_known_total:0,category_unallocated_total:0});assert.equal(M.normalizeMonth(p).definitiveReportReady,false);});
test('executive_month_agreement_is_not_source_certification',()=>{const n=M.compareExecutiveMonth(executive(),M.normalizeMonth(fixture()));assert(n.agreement);assert.equal(n.sourceParityVerified,false);});
test('limited_top_rank_not_treated_as_full_breakdown',()=>assert(M.compareExecutiveMonth(executive(),M.normalizeMonth(fixture())).agreement));
test('same_total_wrong_rank_detected',()=>{const e=executive();e.rankings.categories[0].total=101;assert(!M.compareExecutiveMonth(e,M.normalizeMonth(fixture())).agreement);});
test('whole_period_vs_month_not_comparable',()=>{const e=executive();e.period.from='2026-07-07';assert.equal(M.compareExecutiveMonth(e,M.normalizeMonth(fixture())).comparable,false);});
test('filtered_category_vs_total_not_comparable',()=>{const p=fixture();p.category_filter='A';assert.equal(M.compareExecutiveMonth(executive(),M.normalizeMonth(p)).comparable,false);});
test('stale_total_detected',()=>{const e=executive();e.summary.selected_total=146;assert(!M.compareExecutiveMonth(e,M.normalizeMonth(fixture())).agreement);});
test('missing_cache_timestamp_remains_unknown',()=>{const e=executive();e.data_quality={};assert.equal(M.compareExecutiveMonth(e,M.normalizeMonth(fixture())).cacheAsOf,null);});
test('adapter_exact_identity_and_no_mutations',()=>{const o=auditOptions(),before=JSON.stringify(o),x=A.buildAuditInput(o);assert.equal(JSON.stringify(o),before);assert.equal(x.input.report.rows[0].canonical_key,'fixture:1');});
test('adapter_never_matches_by_description_or_amount',()=>{const o=auditOptions();o.bindings.shift();assert.throws(()=>A.buildAuditInput(o),/documented binding/);});
test('adapter_unverified_lineage_stays_unverified',()=>{const o=auditOptions();o.bindings_verified=false;assert.equal(A.buildAuditInput(o).input.reference.lineage_verified,false);});
test('adapter_preserves_cash_control_from_independent_reference',()=>{const o=auditOptions();o.reference.rows[0].treatment='control';const x=A.buildAuditInput(o);assert.equal(x.input.reference.rows[0].treatment,'control');assert.equal(x.input.report.rows[0].treatment,'included');});
test('adapter_refuses_partial_reference_scope',()=>{const o=auditOptions();o.reference.from='2026-07-07';assert.throws(()=>A.buildAuditInput(o));});
test('adapter_preserves_missing_categories_and_credits',()=>{const o=auditOptions(),x=A.buildAuditInput(o);assert.equal(x.input.report.rows[2].amount_cents,-500);});
test('integrated_existing_integrity_checker_passes_exact_reference',()=>assert(A.auditMonthly(auditOptions()).source_parity));
test('integrated_checker_rejects_control_as_consumption',()=>{const o=auditOptions();o.reference.rows[0].treatment='control';const r=A.auditMonthly(o);assert(!r.definitive_report_ready);assert(r.issues.some(i=>i.code==='treatment_mismatch'));});
test('integrated_checker_rejects_stale_classification',()=>{const o=auditOptions();o.reference.rows[0].category='Updated known category';assert(A.auditMonthly(o).issues.some(i=>i.code==='category_mismatch'));});
test('integrated_checker_requires_verified_bindings',()=>{const o=auditOptions();o.bindings_verified=false;assert(!A.auditMonthly(o).source_parity);});
test('integrated_checker_does_not_close_open_invoice',()=>{const o=auditOptions();o.bindings[0].evidence_state='open_invoice';o.reference.rows[0].evidence_state='open_invoice';o.labels_open_invoice=true;const r=A.auditMonthly(o);assert(r.source_parity);assert(!r.definitive_report_ready);});
test('integrated_checker_refuses_hidden_open_invoice',()=>{const o=auditOptions();o.bindings[0].evidence_state='open_invoice';o.reference.rows[0].evidence_state='open_invoice';assert(A.auditMonthly(o).issues.some(i=>i.code==='open_invoice_not_labelled'));});
test('integrated_checker_flags_document_binding_disagreement',()=>{const o=auditOptions();o.bindings[0].coverage_id='unproven-document';assert(A.auditMonthly(o).issues.some(i=>i.code==='missing_coverage'));});
const request={month:'2026-08-01',through:'2026-08-31',category:null};
test('session_loading_has_no_old_total',async()=>{let resolve;const s=M.createReadSession({load:()=>new Promise(r=>resolve=r)});const task=s.select(request);assert.equal(s.getState().model,null);assert.equal(s.getState().phase,'loading');resolve(fixture());await task;assert.equal(s.getState().phase,'ready');});
test('session_late_old_response_cannot_replace_new_period',async()=>{const jobs=[];const s=M.createReadSession({load:(r,o)=>new Promise(resolve=>jobs.push({r,o,resolve}))});const one=s.select(request),two=s.select({...request,through:'2026-08-14'});assert(jobs[0].o.signal.aborted);const newer=fixture();newer.through='2026-08-14';newer.is_partial=true;jobs[1].resolve(newer);await two;jobs[0].resolve(fixture());await one;assert.equal(s.getState().model.scope.through,'2026-08-14');});
test('session_safe_error_not_raw_sql_or_zero',async()=>{const s=M.createReadSession({load:async()=>{throw new Error('private SQL or token');}});await s.select(request);assert.equal(s.getState().model,null);assert(!s.getState().message.includes('private'));assert.equal(s.getState().phase,'error');});
test('session_no_automatic_retry',async()=>{let calls=0;const s=M.createReadSession({load:async()=>{calls++;throw new Error();}});await s.select(request);assert.equal(calls,1);});
test('session_auth_failure_is_separate',async()=>{const s=M.createReadSession({load:async()=>({data:null,error:{code:'42501'}})});await s.select(request);assert.equal(s.getState().phase,'authentication_required');});
test('session_logout_invalidates_inflight_response',async()=>{let done;const s=M.createReadSession({load:()=>new Promise(r=>done=r)});const job=s.select(request);s.invalidate();done(fixture());await job;assert.equal(s.getState().phase,'idle');assert.equal(s.getState().model,null);});
test('session_subscriber_failure_does_not_corrupt_read',async()=>{const s=M.createReadSession({load:async()=>fixture()});s.subscribe(()=>{throw new Error('view');});await s.select(request);assert.equal(s.getState().phase,'ready');});
test('session_disposal_prevents_future_reads',async()=>{const s=M.createReadSession({load:async()=>fixture()});s.dispose();await assert.rejects(s.select(request));});
(async()=>{for(const t of tests){await t.fn();}console.log(JSON.stringify({status:'PASS',tests:tests.length,scope:'synthetic existing-contract payloads only',database_calls:0,network_calls:0,source_mutations:0,cases:tests.map(t=>t.name)},null,2));})().catch(e=>{console.error(e);process.exitCode=1;});
module.exports={fixture,executive,auditOptions};
