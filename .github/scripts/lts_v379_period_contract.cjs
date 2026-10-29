'use strict';
const assert=require('node:assert/strict'),M=require('../../releases/v379/lts-v337-month-model.js');
const clone=x=>structuredClone(x),today='2026-10-29';
assert.equal(M.bounds('2024-02',today).to,'2024-02-29');
const r=M.periodBounds('2025-12-15','2026-01-10',today);assert.deepEqual(r.months,['2025-12','2026-01']);
const rows=[{month:'2025-12-01',revenue:1000,extraordinary:200,expenses:300,cash_after_extraordinary:900},{month:'2026-01-01',revenue:2000,extraordinary:0,expenses:900,cash_after_extraordinary:1100}];
const p={window_integrity:{from:r.from,to:r.to},monthly_totals:rows,totals:{revenue:3000,extraordinary:200,expenses:1200,cash_after_extraordinary:2000}};
const s=M.summarizePeriod(p,r);assert.equal(s.entries,3200);assert.equal(s.result,2000);assert.equal(s.months.length,2);
assert.equal(M.periodBounds('2024-02-29','2024-03-01',today).months.length,2);
for(const [from,to]of[['2025-02-29','2025-03-01'],['2026-02-30','2026-03-02'],['2026-10-30','2026-10-30'],['2013-10-09','2013-11-01'],['2026-02-01','2026-01-01'],['','2026-01-01']])assert.equal(M.periodBounds(from,to,today),null);
for(const alter of[
 j=>j.monthly_totals.pop(),j=>j.monthly_totals.push(clone(j.monthly_totals[0])),j=>j.monthly_totals[1].month='2025-12-01',
 j=>j.monthly_totals[0].expenses=null,j=>j.monthly_totals[1].revenue='abc',j=>j.monthly_totals[0].month+='bad',
 j=>j.totals.expenses+=1,j=>j.monthly_totals[1].cash_after_extraordinary=99,j=>j.window_integrity.to='2026-01-31'
]){const j=clone(p);alter(j);assert.equal(M.summarizePeriod(j,r),null);}
const negative=clone(p);negative.monthly_totals[0].expenses=1300;negative.monthly_totals[0].cash_after_extraordinary=-100;negative.totals.expenses=2200;negative.totals.cash_after_extraordinary=1000;
assert.equal(M.summarizePeriod(negative,r).months[0].result,-100);
const zero=clone(p);for(const row of zero.monthly_totals)for(const key of ['revenue','extraordinary','expenses','cash_after_extraordinary'])row[key]=0;Object.keys(zero.totals).forEach(k=>zero.totals[k]=0);assert.equal(M.summarizePeriod(zero,r).result,0);
const strings=clone(p);for(const row of strings.monthly_totals)for(const key of ['revenue','extraordinary','expenses','cash_after_extraordinary'])row[key]=String(row[key]);assert.equal(M.summarizePeriod(strings,r).result,2000);
const monthly=M.bounds('2026-01',today),one={window_integrity:{from:monthly.from,to:monthly.to},monthly_totals:[rows[1]],totals:{...rows[1]}};assert.equal(M.summarize(one,monthly).result,1100);
console.log(JSON.stringify({pass:true,year_boundary:true,partial_endpoints:true,leap_day:true,missing_or_duplicate_month_rejected:true,totals_checked:true,unknown_not_zero:true,negative_preserved:true,old_month_mode_preserved:true}));
