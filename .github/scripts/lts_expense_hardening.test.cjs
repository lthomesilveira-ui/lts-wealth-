'use strict';
// All fixtures are synthetic. No database, network, credentials or money writes.
const assert = require('node:assert/strict');
const path = require('node:path');
const M = require(process.env.LTS_TEST_MODEL ? path.resolve(process.env.LTS_TEST_MODEL) : '../../lts-expense-read-model.js');
const cases=[];
const test=(name,fn)=>cases.push({name,fn});
const scope={from:'2024-01-01',to:'2024-03-31'};
function fixture(){
 return {version:'expense-dual-lens-v2-recent-cash',...scope,
 cash:{gross_outflows:300,own_transfers:100,spend_outflows:200,pending_reconciliation:20,
  buckets:[{bucket:'Compras',rows:2,total:200,excluded_from_spend:false},{bucket:'Transferências próprias',rows:1,total:100,excluded_from_spend:true}],
  monthly:[{month:'2024-01-01',total:200}],recent:[
   {date:'2024-01-10',source:'fixture',source_ref:'one',description:'A',account:'Conta',amount:180,category:'Exemplo',bucket:'Compras',excluded_from_spend:false,evidence_status:'documentado'},
   {date:'2024-01-12',source:'fixture',source_ref:'two',description:'B',account:'Conta',amount:20,category:'Exemplo',bucket:'Compras',excluded_from_spend:false,evidence_status:'operacional_pendente'},
   {date:'2024-01-15',source:'fixture',source_ref:'three',description:'C',account:'Conta',amount:100,category:'Transferências',bucket:'Transferências próprias',excluded_from_spend:true,evidence_status:'documentado'}]},
 consumption:{total:120,rows:2,unclassified:0,categories:[{category:'Exemplo A',rows:1,total:90},{category:'Exemplo B',rows:1,total:30}],monthly:[{month:'2024-03-01',total:120}]}};
}
function hasIssue(change,code){const f=fixture();change(f);const m=M.normalizeDual(f);assert(m.issues.some(i=>i.code===code),JSON.stringify(m.issues));assert.equal(m.internallyConsistent,false);}
function session(load,adapt=(payload)=>payload){return M.createReadSession({load,adapt,selection:M.rangeSelection});}
const next={from:'2024-04-01',to:'2024-04-30'};
test('complete_cash_matches_without_changing_inputs',()=>{const f=fixture(),b=JSON.stringify(f),m=M.normalizeDual(f);assert(m.internallyConsistent);assert(m.recentCashIsComplete);assert.equal(JSON.stringify(f),b);assert(!m.definitiveReportReady);});
test('complete_detail_one_cent_difference_is_rejected',()=>hasIssue(f=>f.cash.recent[0].amount=180.01,'recent_cash_total_mismatch'));
test('offsetting_row_changes_still_detect_bucket_mismatch',()=>hasIssue(f=>{f.cash.recent[0].amount=179;f.cash.recent[2].amount=101;},'recent_cash_bucket_mismatch'));
test('bucket_counts_checked_even_when_totals_match',()=>hasIssue(f=>{f.cash.buckets[0].rows=1;f.cash.buckets[1].rows=2;},'recent_cash_bucket_mismatch'));
test('unexpected_bucket_is_rejected_in_partial_detail',()=>hasIssue(f=>{f.cash.recent=f.cash.recent.slice(0,1);f.cash.recent[0].bucket='Outra';},'recent_cash_bucket_unknown'));
test('excluded_flag_must_match_its_explicit_bucket',()=>hasIssue(f=>f.cash.recent[0].excluded_from_spend=true,'recent_cash_treatment_mismatch'));
test('complete_pending_amount_verified_from_status',()=>hasIssue(f=>f.cash.pending_reconciliation=21,'recent_pending_cash_mismatch'));
test('complete_monthly_totals_verified_against_detail',()=>hasIssue(f=>f.cash.recent[0].date='2024-03-10','recent_cash_monthly_mismatch'));
test('duplicate_cannot_claim_complete_cash_list',()=>{const f=fixture();f.cash.recent[1]={...f.cash.recent[0]};const m=M.normalizeDual(f);assert(m.issues.some(i=>i.code==='duplicate_recent_cash_source'));assert.equal(m.recentCashIsComplete,false);});
test('partial_recent_list_is_not_forced_to_full_total',()=>{const f=fixture();f.cash.recent=f.cash.recent.slice(0,1);const m=M.normalizeDual(f);assert(m.internallyConsistent);assert(!m.recentCashIsComplete);});
test('complete_empty_list_is_not_source_certification',()=>{const f=fixture();f.cash={gross_outflows:0,own_transfers:0,spend_outflows:0,pending_reconciliation:0,buckets:[],monthly:[],recent:[]};f.consumption={total:0,rows:0,unclassified:0,categories:[],monthly:[]};const m=M.normalizeDual(f);assert(m.internallyConsistent);assert(m.recentCashIsComplete);assert(!m.sourceParityVerified);assert(!m.definitiveReportReady);});
test('missing_interior_month_is_visible_and_null',()=>{const m=M.normalizeDual(fixture());assert.deepEqual(m.monthly.map(x=>x.month),['2024-01-01','2024-02-01','2024-03-01']);assert.equal(m.monthly[1].cashCents,null);assert.equal(m.monthly[1].consumptionCents,null);});
test('empty_months_are_never_fabricated_zeroes',()=>{const f=fixture();f.cash={gross_outflows:0,own_transfers:0,spend_outflows:0,pending_reconciliation:0,buckets:[],monthly:[],recent:[]};f.consumption={total:0,rows:0,unclassified:0,categories:[],monthly:[]};const m=M.normalizeDual(f);assert.equal(m.monthly.length,3);assert(m.monthly.every(x=>x.cashCents===null&&x.consumptionCents===null));});
test('explicit_month_zero_is_distinct_from_absence',()=>{const f=fixture();f.cash.monthly.push({month:'2024-02-01',total:0});const m=M.normalizeDual(f);assert.equal(m.monthly[1].cashCents,0);assert.equal(m.monthly[1].consumptionCents,null);});
test('calendar_crosses_year_boundary_without_local_timezone',()=>{const f=fixture();f.from='2023-12-20';f.to='2024-03-10';f.cash.recent=[];const m=M.normalizeDual(f);assert.deepEqual(m.monthly.map(x=>x.month),['2023-12-01','2024-01-01','2024-02-01','2024-03-01']);assert(m.partialCalendarRange);});
test('original_category_spelling_and_signed_credit_retained',()=>{const f=fixture();f.consumption.categories[1].total=-30;f.consumption.total=60;f.consumption.monthly[0].total=60;const m=M.normalizeDual(f);assert.equal(m.categories[1].totalCents,-3000);assert.equal(m.categories[1].name,'Exemplo B');assert(m.internallyConsistent);});
test('loading_disposal_does_not_start_a_read',async()=>{let calls=0;const s=session(async()=>{calls++;return {};});s.subscribe(x=>{if(x.phase==='loading')s.dispose();});await s.select(scope);assert.equal(calls,0);assert.equal(s.getState().model,null);});
test('loading_invalidation_does_not_start_a_read',async()=>{let calls=0;const s=session(async()=>{calls++;return {};});s.subscribe(x=>{if(x.phase==='loading')s.invalidate();});await s.select(scope);assert.equal(calls,0);assert.equal(s.getState().phase,'idle');});
test('loading_subscriber_new_period_issues_only_new_read',async()=>{const calls=[];let switched=false,nested;const s=session(async q=>{calls.push(q);return q;});s.subscribe(x=>{if(x.phase==='loading'&&!switched){switched=true;nested=s.select(next);}});await s.select(scope);await nested;assert.deepEqual(calls,[next]);assert.deepEqual(s.getState().request,next);});
test('abort_subscriber_cannot_overwrite_newer_request',async()=>{const third={from:'2024-05-01',to:'2024-05-31'},calls=[];let nested;const s=session((q,{signal})=>{calls.push(q);if(q.from===scope.from){signal.addEventListener('abort',()=>{nested=s.select(third);},{once:true});return new Promise(()=>{});}return Promise.resolve(q);});void s.select(scope);await s.select(next);await nested;assert.deepEqual(calls,[scope,third]);assert.deepEqual(s.getState().request,third);});
test('adapter_disposal_cannot_resurrect_financial_values',async()=>{let s;s=session(async()=>({total:100}),payload=>{s.dispose();return payload;});await s.select(scope);assert.equal(s.getState().model,null);assert.equal(s.getState().phase,'idle');});
test('dispose_subscriber_cannot_launch_another_request',async()=>{let calls=0,armed=false,rejected;const s=session(async()=>{calls++;return {};});s.subscribe(x=>{if(armed&&x.phase==='idle'){armed=false;rejected=s.select(next).catch(e=>e);}});await s.select(scope);armed=true;s.dispose();await rejected;assert.equal(calls,1);assert.equal(s.getState().model,null);});
test('invalid_new_selection_clears_previous_values_then_rejects',async()=>{const s=session(async()=>({total:100}));await s.select(scope);await assert.rejects(s.select({from:'not-a-date',to:scope.to}));assert.equal(s.getState().model,null);});
test('subscription_added_during_delivery_waits_for_next_event',async()=>{const seen=[];let added=false;const s=session(async()=>({}));s.subscribe(x=>{if(x.phase==='loading'&&!added){added=true;s.subscribe(y=>seen.push(y.phase));}});await s.select(scope);assert.deepEqual(seen,['ready']);});
test('late_request_rejection_cannot_erase_current_period',async()=>{let reject;const s=session(q=>q.from===scope.from?new Promise((_,r)=>{reject=r;}):Promise.resolve(q));const old=s.select(scope);await s.select(next);reject(new Error('raw private detail'));await old;assert.deepEqual(s.getState().model,next);assert.equal(s.getState().phase,'ready');});
test('normal_error_redacts_raw_server_text',async()=>{const s=session(async()=>{throw new Error('private detail');});await s.select(scope);assert.equal(s.getState().phase,'error');assert(!JSON.stringify(s.getState()).includes('private detail'));assert.equal(s.getState().model,null);});
async function run(){const results=[];for(const c of cases){try{await c.fn();results.push({name:c.name,status:'PASS'});}catch(e){results.push({name:c.name,status:'FAIL',message:e.message});}}const failures=results.filter(x=>x.status==='FAIL');const receipt={status:failures.length?'FAIL':'PASS',tests:cases.length,passed:results.length-failures.length,failed:failures.length,scope:'synthetic pure-module tests; no app integration, financial data or network',cases:results};console.log(JSON.stringify(receipt,null,2));if(failures.length)process.exitCode=1;return receipt;}
module.exports={run,fixture};
if(require.main===module)run().catch(e=>{console.error(e);process.exitCode=1;});
