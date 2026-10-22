'use strict';
const assert=require('node:assert/strict');
const contract=require('../../releases/v295/lts-v275-overdue-visibility.js');
const context={today:'2026-10-21',account:'Itaú',range:{from:'2026-10-19',to:'2026-10-21'}};
const flow={from:'2026-10-19',to:'2026-10-21',current_future:{current_anchor_date:'2026-10-21'},observed_bank_movements:{pending_projections:[]}};
const inspect=data=>contract.model(data,context);
assert.equal(contract.markup(inspect(flow),false),'','No empty diagnostic banner');
assert.equal(contract.markup(contract.model(flow,{...context,loading:true}),false),'','No loading diagnostic banner');
for(const status of ['source_missing','invalid_source','undated','stale','unavailable','range_mismatch']){
 const html=contract.markup({status,rows:[]},false);
 assert.match(html,/Atualize o fluxo/);
 assert.doesNotMatch(html,/resposta|recebida|backend|RPC|snapshot|provedor/i);
}
const event={financial_event_id:'synthetic-forecast',event_date:'2026-10-05',account:'Itaú',signed_amount:-50,description:'Conta de energia'};
const one=inspect({...flow,observed_bank_movements:{pending_projections:[event]}});
assert.equal(one.rows.length,1);
assert.match(contract.markup(one,false),/1 pagamento vencido a conferir/);
assert.match(contract.markup(one,false),/Conta de energia/);
assert.match(contract.markup(one,false),/05\/10\/2026/);
assert.match(contract.markup(one,false),/pagamento a confirmar/);
assert(!contract.markup(one,false).includes('<details open'));
assert(contract.markup(one,true).includes('<details open'));
assert.equal(inspect({...flow,observed_bank_movements:{pending_projections:[{...event,bank_confirmed:true}]}}).rows.length,0);
assert.equal(inspect({...flow,observed_bank_movements:{pending_projections:[{...event,event_date:'2026-11-05'}]}}).rows.length,0);
const partial=inspect({...flow,observed_bank_movements:{pending_projections:[{},event]}});
assert.equal(partial.status,'partial');assert.match(contract.markup(partial,false),/Alguns pagamentos não puderam ser conferidos/);
assert.equal(partial.rows.length,1,'Malformed rows do not hide the valid overdue payment');
console.log(JSON.stringify({pass:true,healthy_empty_hidden:true,uncertainty_visible:true,actual_overdue_retained:true,source_data_unchanged:true}));
