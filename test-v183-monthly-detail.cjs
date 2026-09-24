'use strict';
const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('lts-v183-v182-feedback-safe.js','utf8');
function harness(){
 const r={from:'2026-01-17',to:'2026-02-12'},buttons=[],calls=[];
 const group={label:'Fixture & group',total:18,monthly:[{month:'2026-01-01',amount:20},{month:'2026-02-01',amount:-2}]};
 const state={monthly:{key:r.from+'|'+r.to,data:{expense_groups:[group]},loading:false}};
 const scope={range:()=>r,v175:state,document:{querySelectorAll:()=>buttons},detail:{openDetail(...args){calls.push(args)}},
 safe:x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
 n:x=>Number(x)||0,money:x=>String(x),monthText:x=>x};
 const start=source.indexOf('    function detailButton('),end=source.indexOf('    function finalBalance(');
 assert.ok(start>0&&end>start);
 const api=vm.runInNewContext(source.slice(start,end)+'\n({detailButton,detailRange,bindMonthlyDetails,matrix})',scope);
 return{api,r,state,buttons,calls,group};
}
test('monthly detail clips partial first/last months and handles leap years',()=>{
 const {api,r}=harness();
 assert.equal(JSON.stringify(api.detailRange('2026-01',r)),JSON.stringify({from:'2026-01-17',to:'2026-01-31'}));
 assert.equal(JSON.stringify(api.detailRange('2026-02',r)),JSON.stringify({from:'2026-02-01',to:'2026-02-12'}));
 assert.equal(api.detailRange('2024-02',{from:'2024-01-01',to:'2024-12-31'}).to,'2024-02-29');
 assert.equal(api.detailRange('2025-12',r),null);
 for(const month of ['2026-00','2026-13','x','2026-02-01'])assert.equal(api.detailRange(month,r),null);
 assert.equal(JSON.stringify(api.detailRange('',r)),JSON.stringify(r));
});
test('expense name, monthly amount and total use the existing exact detail',()=>{
 const h=harness(),b={dataset:{group:h.group.label,month:'2026-02',amount:'-2'}};
 h.buttons.push(b);h.api.bindMonthlyDetails();b.onclick();
 assert.equal(h.calls.length,1);assert.equal(h.calls[0][0],h.group.label);assert.equal(h.calls[0][3],-2);
 assert.equal(h.calls[0][2].from,'2026-02-01');assert.equal(h.calls[0][2].to,'2026-02-12');
 b.dataset.month='';b.dataset.amount='18';b.onclick();assert.equal(h.calls[1][2].from,h.r.from);assert.equal(h.calls[1][3],18);
});
test('stale period, loading, changed total and unknown group cannot open misleading detail',()=>{
 const h=harness(),b={dataset:{group:h.group.label,month:'',amount:'18'}};h.buttons.push(b);h.api.bindMonthlyDetails();
 h.state.monthly.loading=true;b.onclick();h.state.monthly.loading=false;
 h.state.monthly.key='old';b.onclick();h.state.monthly.key=h.r.from+'|'+h.r.to;
 b.dataset.amount='19';b.onclick();b.dataset.amount='18';b.dataset.group='unknown';b.onclick();
 assert.equal(h.calls.length,0);
});
test('aggregate-only invoice coverage opens its source group, never invented purchases',()=>{
 const h=harness();h.state.monthly.data.expense_unclassified_card_coverage={label:'Faturas conciliadas pelo total',total:4,monthly:[{month:'2026-02-01',amount:4}]};
 const b={dataset:{group:'Faturas conciliadas pelo total',month:'2026-02',amount:'4'}};h.buttons.push(b);h.api.bindMonthlyDetails();b.onclick();
 assert.equal(h.calls[0][0],'Faturas conciliadas pelo total');assert.equal(h.calls[0][3],4);
});
test('expense matrix escapes labels and preserves every amount including credits',()=>{
 const h=harness(),html=h.api.matrix('Expenses',[h.group],['2026-01','2026-02'],null,true);
 assert.equal((html.match(/class="v183-month-detail"/g)||[]).length,4);
 assert.match(html,/data-group="Fixture &amp; group"/);assert.match(html,/data-amount="-2"/);
 const escaped=h.api.detailButton('<img src=x onerror="x">',1,'','<script>');
 assert.doesNotMatch(escaped,/<img|<script>/);assert.match(escaped,/&lt;script&gt;/);
});
test('income matrices retain existing semantics and are not sent to expense detail',()=>{
 const h=harness();assert.doesNotMatch(h.api.matrix('Income',[h.group],['2026-01','2026-02']),/v183-month-detail/);
 assert.doesNotMatch(source,/\.insert\(|\.update\(|\.delete\(/);
 assert.doesNotThrow(()=>new Function(source));
});
