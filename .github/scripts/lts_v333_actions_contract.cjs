'use strict';
const assert=require('node:assert/strict'),model=require('../../releases/v333/lts-v333-actions-model.js');
const input={asOf:'2026-10-25',cockpit:{work:{top_actions:[{title:'Old invoice',maintenance_kind:'card_cycle',amount:10},{title:'Conferir extrato'}]}},
 recurring:{horizon_checks:[{key:'school',title:'Escola',review_kind:'planning_review',missing_years:[2027],observed_median_amount_brl:50}],items:[{description:'Escola',review_kind:'planning_review'},{description:'Transferência',review_kind:'reconciliation_review'}]},
 cards:{cards:[{family:'itau_mastercard',cycles:[{month:'2026-10-01',due_date:'2026-10-25',amount:999,basis:'open_finance_invoice_v263'},{month:'2026-11-01',due_date:'2026-11-16',amount:123.45,basis:'open_finance_composition'},{month:'2026-12-01',due_date:'2026-12-16',amount:100,basis:'derived_current_installments'}]},
 {family:'c6',cycles:[{month:'2026-11-01',due_date:null,amount:null,complete:false,basis:'incomplete_cycle_identity'}]},
 {family:'aeternum',cycles:[{month:'2026-11-01',due_date:'2026-11-25',amount:400,settlement_confirmed:true}]}]}};
const before=JSON.stringify(input),result=model.build(input);
assert(result.ready);assert.equal(result.items.length,5);assert.equal(JSON.stringify(input),before);
assert(!result.items.some(x=>x.title==='Old invoice'));
const card=result.items.find(x=>x.family==='itau_mastercard');assert.equal(card.impact_amount,123.45);assert.match(card.detail,/16\/11\/2026/);assert.match(card.detail,/ainda não foi recebido/);assert.equal(card.month,'2026-11-01');
const c6=result.items.find(x=>x.family==='c6');assert.equal(c6.impact_amount,null);assert.match(c6.detail,/Vencimento a confirmar/);
assert(!result.items.some(x=>x.family==='aeternum'));
assert.equal(model.build({...input,recurring:null}).ready,false);assert.equal(model.build({...input,cards:null}).ready,false);
const failed=model.build({...input,error:true});assert.equal(failed.ready,false);assert.equal(failed.items.length,5);assert.equal(failed.error,true);
assert.deepEqual(model.build({asOf:input.asOf,recurring:{items:[],horizon_checks:[]},cards:{cards:[]}}),{items:[],ready:true,error:false});
console.log(JSON.stringify({pass:true,current_invoice_references:true,missing_dates_preserved:true,source_unchanged:true,unknown_not_zero:true}));
