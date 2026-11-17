'use strict';
const assert=require('node:assert/strict'),contract=require('../../releases/v466/lts-v275-overdue-visibility.js');
const row=(id,amount)=>({source:'invented',source_ref:id,event_date:'2026-11-15',account:'Banco fictício',signed_amount:amount,description:'Movimento de teste'});
const flow=rows=>({from:'2026-11-01',to:'2026-11-30',current_future:{current_anchor_date:'2026-11-17'},observed_bank_movements:{pending_projections:rows}});
const cases=[[[row('a',120)],'1 recebimento vencido a conferir'],[[row('a',-120)],'1 pagamento vencido a conferir'],[[row('a',120),row('b',20)],'2 recebimentos vencidos a conferir'],[[row('a',-120),row('b',-20)],'2 pagamentos vencidos a conferir'],[[row('a',120),row('b',-20)],'2 lançamentos vencidos a conferir']];
for(const [rows,label] of cases){const input=flow(rows),before=JSON.stringify(input),view=contract.model(input,{today:'2026-11-17',account:'Consolidado'});assert.equal(view.status,'ready');const html=contract.markup(view,false);assert(html.includes('<summary>'+label+'</summary>'));assert.equal(JSON.stringify(input),before);assert.equal(view.rows.reduce((a,r)=>a+r.amount,0),rows.reduce((a,r)=>a+r.signed_amount,0));assert(!html.includes('<details open'));}
assert(!/pagamentos vencidos/.test(contract.markup({status:'unavailable',rows:[]},false)));assert.equal(contract.markup({status:'ready',rows:[]},false),'');
console.log(JSON.stringify({pass:true,direction_labels:5,empty_and_failure_labels:true,financial_writes:0}));
