'use strict';
const assert=require('node:assert/strict'),model=require('../../releases/v337/lts-v337-month-model.js');
const clone=x=>JSON.parse(JSON.stringify(x)),today='2026-10-16',range=model.bounds('2026-10',today);
assert.deepEqual(range,{month:'2026-10',from:'2026-10-01',to:today,partial:true});
assert.equal(model.bounds('2013-10',today).from,'2013-10-10');
assert.equal(model.bounds('2024-02',today).to,'2024-02-29');
assert.equal(model.bounds('2025-02',today).to,'2025-02-28');
for(const month of ['2013-09','2026-11','2026-13','2026-00','2026-1','bad',''])assert.equal(model.bounds(month,today),null,month);
const row={month:'2026-10-01',revenue:150,extraordinary:20,expenses:100,cash_after_extraordinary:70};
const payload={window_integrity:{from:range.from,to:range.to},monthly_totals:[row],totals:{...row}};
assert.deepEqual(model.summarize(payload,range),{...range,revenue:150,extraordinary:20,entries:170,expenses:100,result:70});
const zero=clone(payload);for(const key of ['revenue','extraordinary','expenses','cash_after_extraordinary'])zero.monthly_totals[0][key]=zero.totals[key]=0;
assert.equal(model.summarize(zero,range).result,0,'Explicit zero is a real value');
for(const value of [null,undefined,'',true,[],{},'  ','NaN',Infinity]){const p=clone(payload);p.monthly_totals[0].expenses=value;assert.equal(model.summarize(p,range),null,'Missing/malformed amount must not become zero');}
const mutate=[p=>p.monthly_totals=[],p=>p.monthly_totals.push(clone(row)),p=>p.monthly_totals[0].month='2026-09-01',p=>p.monthly_totals[0].month='2026-10-02',p=>p.window_integrity.from='2026-09-01',p=>p.window_integrity.to='2026-10-31',p=>p.monthly_totals[0].cash_after_extraordinary=80,p=>delete p.totals.expenses,p=>p.totals.revenue=151];
for(const f of mutate){const p=clone(payload);f(p);assert.equal(model.summarize(p,range),null);}
const banks={status:'complete',as_of:today,cash:1000,bank_positions:[{institution_code:'341',balance:600},{institution_code:'237',balance:400},{institution_code:'336',balance:0}]};
assert.equal(model.bankPositions(banks,today).rows[2].balance,0);assert.equal(model.bankPositions(banks,today).total,1000);
for(const f of [p=>p.bank_positions.pop(),p=>p.bank_positions.push({institution_code:'999',balance:0}),p=>p.bank_positions[1].institution_code='341',p=>p.bank_positions[2].balance=null,p=>p.bank_positions[2].balance=true,p=>p.cash=999,p=>p.as_of='2026-10-15',p=>p.status='partial']){const p=clone(banks);f(p);assert.equal(model.bankPositions(p,today),null);}
console.log(JSON.stringify({pass:true,release:'v337',calendar_boundaries:true,range_identity:true,zero_vs_unknown:true,monthly_reconciliation:true,three_bank_reconciliation:true}));
