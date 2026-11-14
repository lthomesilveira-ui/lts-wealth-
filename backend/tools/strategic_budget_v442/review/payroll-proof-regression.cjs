const assert = require('node:assert/strict');
const {derive}=require('./strategy.js');
const months=Array.from({length:12},(_,i)=>({month:`2026-${String(i+1).padStart(2,'0')}`,income_target:3000,income_regular:0}));
const event={event_date:'2026-12-31',description:'Empréstimo',category:'Empréstimos',signed_amount:-400,source:'synthetic',source_ref:'loan-one',competence_month:'2026-12',competence_evidence:['Synthetic documented competence']};
const budget={ok:true,as_of:'2026-11-14',year:2026,months,rows:[{category:'Empréstimos',reference_monthly:null,months:months.map(m=>({month:m.month,target:null,target_basis:'history',actual:0,card_actual:0,pending:0}))}],income_approvals:{},category_aliases:{}};
const flow={current_future:{events:[event],from:'2026-11-14',to:'2026-12-31'}};
function result(base_income,net_income){const p=structuredClone(budget);p.planning={payroll_withholding:[{source:'synthetic',source_ref:'loan-one',date:event.event_date,amount:400,base_income,net_income,evidence:['Synthetic proof']} ]};return derive(p,flow,{cards:[]});}
const cases=[[400,null],[400,undefined],[400,''],[null,-400],[-100,-500],[400,false]];
for(const [base,net]of cases){const q=result(base,net);assert.equal(q.rows[0].months[11].strategy.floor,400,`Incomplete or negative proof must not remove obligation: ${JSON.stringify([base,net])}`);assert.equal(q.strategy.payroll_withheld_not_added.length,0);}
for(const [base,net] of [[2000,1600],[400,0],['2000','1600']]){const q=result(base,net);assert.equal(q.rows[0].months[11].strategy.floor,0);assert.equal(q.strategy.payroll_withheld_not_added.length,1);}
console.log('PASS 6 malformed proofs rejected; 3 exact valid proofs retained; synthetic only');
