'use strict';
const assert=require('node:assert/strict'), M=require('../../lts-expense-read-model.js');
const cases=[];function test(name,fn){cases.push({name,fn});}
function fixture(){return {version:'expense-dual-lens-v2-recent-cash',from:'2026-07-07',to:'2026-08-14',cash:{gross_outflows:200,own_transfers:30,spend_outflows:170,pending_reconciliation:20,
  buckets:[{bucket:'Consumo',rows:2,total:170,excluded_from_spend:false},{bucket:'Transferências próprias',rows:1,total:30,excluded_from_spend:true}],
  monthly:[{month:'2026-07-01',total:170}],recent:[]},consumption:{total:125,rows:2,unclassified:0,
  categories:[{category:'B',rows:1,total:25},{category:'A',rows:1,total:100}],monthly:[{month:'2026-08-01',total:125}]}};}
const issue=(fn,code)=>{const x=fixture();fn(x);assert(M.normalizeDual(x).issues.some(i=>i.code===code));};
test('dual_existing_contract_accepted',()=>assert(M.normalizeDual(fixture()).internallyConsistent));
test('cash_and_consumption_are_separate_not_added',()=>{const m=M.normalizeDual(fixture());assert.equal(m.spendOutflowsCents,17000);assert.equal(m.consumptionCents,12500);assert(!('combinedTotal' in m));});
test('cash_transfers_identity_checked',()=>issue(x=>x.cash.spend_outflows=180,'cash_total_mismatch'));
test('cash_missing_is_not_zero',()=>{const x=fixture();x.cash.gross_outflows=null;assert.throws(()=>M.normalizeDual(x));});
test('consumption_missing_is_not_zero',()=>{const x=fixture();delete x.consumption.total;assert.throws(()=>M.normalizeDual(x));});
test('monthly_gaps_remain_null_not_imputed',()=>{const m=M.normalizeDual(fixture());assert.equal(m.monthly[0].consumptionCents,null);assert.equal(m.monthly[1].cashCents,null);});
test('recent_cash_is_explicitly_partial',()=>assert.equal(M.normalizeDual(fixture()).recentCashIsComplete,false));
test('pending_net_zero_not_complete_classification',()=>{const x=fixture();x.consumption.categories.push({category:'A classificar',rows:2,total:0});x.consumption.rows=4;assert.equal(M.normalizeDual(x).missingCategoryRows,2);});
test('cash_recent_does_not_certify_total_coverage',()=>{const x=fixture();x.cash.recent=[];assert.equal(M.normalizeDual(x).sourceParityVerified,false);});
test('dual_sorted_signed_categories',()=>assert.deepEqual(M.normalizeDual(fixture()).categories.map(c=>c.name),['A','B']));
test('dual_duplicate_category_detected',()=>issue(x=>x.consumption.categories.push({...x.consumption.categories[0]}),'duplicate_consumption_category'));
test('dual_request_scope_must_match',()=>assert.throws(()=>M.normalizeDual(fixture(),{from:'2026-07-01',to:'2026-08-14'})));
test('dual_partial_interval_not_calendar_comparable',()=>assert(M.normalizeDual(fixture()).partialCalendarRange));
test('dual_session_uses_existing_range_contract',async()=>{const s=M.createReadSession({load:async()=>fixture(),adapt:M.normalizeDual,selection:M.rangeSelection});await s.select({from:'2026-07-07',to:'2026-08-14'});assert.equal(s.getState().phase,'ready');assert.equal(s.getState().model.consumptionCents,12500);});
(async()=>{for(const c of cases)await c.fn();console.log(JSON.stringify({status:'PASS',tests:cases.length,scope:'synthetic dual-lens contract only',network_calls:0,database_calls:0,cases:cases.map(c=>c.name)},null,2));})().catch(e=>{console.error(e);process.exitCode=1;});
module.exports={fixture};
