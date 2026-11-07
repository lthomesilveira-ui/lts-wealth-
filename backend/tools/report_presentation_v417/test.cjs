'use strict';
const assert=require('node:assert/strict'),path=require('node:path');
const root=path.resolve(__dirname,'../../..'),api=require(path.join(root,'releases/v417/lts-v412-projection-policy.js'));
const old=require(path.join(root,'releases/v415/lts-v412-projection-policy.js'));
function row(key='card_example',n=3){return {series_key:key,description:'Categoria fictícia',method:'history_total_budget',direction:'expense',expected_months:n,coverage_months:n,observed_months:n,months_with_spend:n,outlier_months:[],warnings:[],annual_totals:[{year:2027,partial_year:false,budget_total_brl:12000,additional_brl:4000}],reference_stale:false,reference_amount_brl:1000,reference_window:{from:n===3?'2026-08-01':'2025-11-01',to:'2026-10-31'},annual_rate:0,uses_history:true};}
function payload(){return {ok:true,version:'projection-policy-v412',enabled:true,schema_version:1,as_of:'2026-11-06',horizon_end:'2031-12-31',next_review_on:'2027-01-01',history_window:{from:'2025-11-01',to:'2026-10-31'},card_method:'total_budget_floor',outliers_excluded:false,missing_months_assumed_zero:false,financial_sources_modified:false,series:[row(),row('non_card_example',12)],warnings:[]};}
let tests=[];function check(name,f){f();tests.push(name)}
check('predecessor reproduces rejection of valid three-month response',()=>assert.throws(()=>old.build(payload())));
check('three-month cards and twelve-month other series accepted',()=>assert.deepEqual(api.build(payload()).series.map(x=>x.expected),[3,12]));
check('amount and annual totals unchanged',()=>{let m=api.build(payload());assert.equal(m.series[0].amount,100000);assert.equal(m.series[0].annual[0].total,1200000)});
check('prior compatible window retained',()=>{let p=payload(),r=p.series[0];r.reference_stale=true;r.coverage_months=2;r.observed_months=2;r.months_with_spend=2;r.reference_window={from:'2026-07-01',to:'2026-09-30'};assert.equal(api.build(p).series[0].referenceStale,true)});
check('partial data not treated as complete',()=>{let p=payload();p.series[0].coverage_months=2;assert.throws(()=>api.build(p))});
check('missing reference stays missing',()=>{let p=payload();p.series[0].coverage_months=2;p.series[0].reference_amount_brl=null;assert.equal(api.build(p).series[0].amount,null)});
check('other series cannot silently change to three months',()=>{let p=payload();p.series[0].series_key='non_card';assert.throws(()=>api.build(p))});
for(const w of [{from:'2026-08-02',to:'2026-10-31'},{from:'2026-08-01',to:'2026-09-30'},{from:'2026-09-01',to:'2026-11-30'}])check('reject invalid rolling window '+w.from+'/'+w.to,()=>{let p=payload();p.series[0].reference_window=w;assert.throws(()=>api.build(p))});
check('duplicate series rejected',()=>{let p=payload();p.series.push({...p.series[0]});assert.throws(()=>api.build(p))});
check('negative values rejected',()=>{let p=payload();p.series[0].reference_amount_brl=-10;assert.throws(()=>api.build(p))});
check('oversized coverage rejected',()=>{let p=payload();p.series[0].coverage_months=4;assert.throws(()=>api.build(p))});
check('disabled policy stays disabled',()=>assert.equal(api.build({version:'projection-policy-v412',enabled:false}),null));
check('five-year horizon preserved',()=>assert.equal(api.build(payload()).horizon,'2031-12-31'));
if(require.main===module)console.log(JSON.stringify({passed:true,count:tests.length,tests},null,2));
module.exports={payload};
