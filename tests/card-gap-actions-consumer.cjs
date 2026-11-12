// Read-only consumer contract checks. No source data or financial mutation.
'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs');
if(!process.env.ACTIONS_MODEL_FILE)throw new Error('Set ACTIONS_MODEL_FILE to the repository actions-model file.');
const api=require(require('node:path').resolve(process.env.ACTIONS_MODEL_FILE));
const build=recurring=>api.build({recurring,cards:{cards:[]},cockpit:{},asOf:'2028-07-10'});
const ended={key:'card_c6',description_key:'card_c6',title:'Synthetic card',direction:'expense',review_kind:'covered',missing_months:[],missing_years:[],gap_count:0,period_coverage:[]};
const fallback={description_key:'card_c6',description:'Synthetic card',direction:'expense',review_kind:'planning_review'};
assert.equal(build({horizon_checks:[ended],items:[fallback]}).items.length,0,'An explicit no-gap horizon identity prevents legacy action fallback');
const documentary={...ended,review_kind:'planning_review',missing_months:['2028-08'],gap_count:1};
assert.equal(build({horizon_checks:[documentary],items:[fallback]}).items.length,1,'A documentary gap remains an action');
const pending={...ended,review_kind:'reconciliation_review',awaiting_payment_evidence_count:1};
assert.equal(build({horizon_checks:[pending],items:[fallback]}).items.length,1,'An unpaid existing obligation remains an action');
const unknown={...ended,key:'other_series',description_key:'other_series',review_kind:'planning_review',missing_months:['2028-09']};
assert.equal(build({horizon_checks:[ended,unknown],items:[fallback]}).items.length,1,'Unrelated series remain unchanged');
if(process.argv[2]){
 const payload=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
 const recurring=payload.result||payload;
 const result=build(recurring);
 const falseGaps=result.items.filter(x=>x.origin==='recurring'&&['card_c6','card_itau'].includes(x.key)&&x.review_kind==='planning_review');
 assert.equal(falseGaps.length,0,'The supplied corrected fixture must not revive the false C6/Itaú actions');
}
console.log(JSON.stringify({pass:true,consumerChecks:process.argv[2]?5:4}));
