'use strict';
// Execute the shipped reader functions with deferred, read-only RPC fixtures.
// No browser session, credentials, production rows or private amounts are used.
const fs=require('node:fs');
const vm=require('node:vm');
const assert=require('node:assert/strict');
const {test}=require('node:test');
const read=name=>fs.readFileSync(name,'utf8');
function between(source,start,end){
  const a=source.indexOf(start),b=source.indexOf(end,a);
  assert.ok(a>=0&&b>a,'shipped function boundaries exist');
  return source.slice(a,b);
}
function deferred(){let resolve;const promise=new Promise(r=>{resolve=r});return{promise,resolve}}
const period=(from,to)=>({from,to});
const jan=period('2026-01-01','2026-01-31'),feb=period('2026-02-01','2026-02-28');
function monthlyData(api,r){
  const months=api.monthsExpected(r.from,r.to);
  return{...r,months,monthly_totals:months.map(month=>({month,revenue:10,expenses:3,extraordinary:2,operating_balance:7,cash_after_extraordinary:9})),
    totals:{revenue:months.length*10,expenses:months.length*3,extraordinary:months.length*2,operating_balance:months.length*7,cash_after_extraordinary:months.length*9},
    revenue_groups:[{label:'Fixture income',total:months.length*10,monthly:months.map(month=>({month,amount:10}))}],
    expense_groups:[{label:'Fixture expense',total:months.length*3,monthly:months.map(month=>({month,amount:3}))}],
    extraordinary_groups:[{label:'Fixture extra',total:months.length*2,monthly:months.map(month=>({month,amount:2}))}]};
}
function expenseHarness(){
  const entry=()=>({key:'',data:null,loading:false,error:null,token:0});
  const state={expense:entry(),monthly:{...entry(),year:null,progress:''},cards:entry()};
  const scope={state,v168:{expense:{key:'custom',customFrom:jan.from,customTo:jan.to,tab:'monthly'}},V:'Despesas',render(){},S:{},previousRpc(){},window:{parent:{}},AbortController,setTimeout,clearTimeout};
  const source=read('lts-v183-expense-history-candidate.js');
  const code=between(source,'    const arr=','    function usefulChildren(')+
    between(source,'    function monthlyPanel(){','    function canonicalInventoryName(')+
    '\n({ensureMonthly,ensureExpense,loadMonthly,monthsExpected,verifyPart,monthlyPanel,invalidateExpensePeriod,setRpc:f=>directRpc=f})';
  const api=vm.runInNewContext(code,scope);
  const setRange=r=>Object.assign(scope.v168.expense,{key:'custom',customFrom:r.from,customTo:r.to});
  return{state,scope,api,setRange};
}
function pendingRpc(api){
  const calls=[];api.setRpc((name,args)=>{const d=deferred();calls.push({name,args,...d});return d.promise});return calls;
}
function cardHarness(){
  const source=read('lts-v183-card-period-candidate.js');
  const state={status:'idle',key:'',token:0,rows:[],documentary:[],legacy:[],error:null,periods:0};
  let active=jan;const calls=[];
  const scope={state,range:()=>active,v168:{expense:{tab:'cards'}},v175:{cards:{}},V:'Despesas',render(){},S:{rpc(name,args){const d=deferred();calls.push({name,args,...d});return d.promise}},
    esc:x=>String(x??''),date:x=>x,money:x=>String(x),today:()=> '2026-09-23'};
  const code=between(source,'        function chunks(','        despesas=function(){')+'\n({load,panel})';
  const api=vm.runInNewContext(code,scope);
  return{api,state,calls,setRange:r=>{active=r}};
}
const evidence={data:{financial_effect:'none',invoices:[]},error:null};
const invoiceResult=label=>({data:{rows:[{card_name:label,due_date:jan.to,reference_month:jan.from,documented_amount:3}]},error:null});
const legacyResult={data:{financial_effect:'none',invoices:[]},error:null};
async function tick(){await Promise.resolve();await Promise.resolve()}

test('new monthly period starts immediately and late old results cannot overwrite it',async()=>{
  const h=expenseHarness(),calls=pendingRpc(h.api);
  const first=h.api.ensureMonthly();h.setRange(feb);const second=h.api.ensureMonthly();
  assert.equal(calls.length,2);assert.equal(h.state.monthly.data,null);
  calls[1].resolve({data:monthlyData(h.api,feb)});await second;
  calls[0].resolve({data:monthlyData(h.api,jan)});await first;
  assert.equal(h.state.monthly.data.from,feb.from);assert.equal(h.state.monthly.loading,false);assert.equal(h.state.monthly.error,null);
});

test('A → B → A does not revive an earlier request for the same period',async()=>{
  const h=expenseHarness(),calls=pendingRpc(h.api);
  const a=h.api.ensureMonthly();h.setRange(feb);const b=h.api.ensureMonthly();h.setRange(jan);const newest=h.api.ensureMonthly();
  calls[2].resolve({data:{...monthlyData(h.api,jan),marker:'newest'}});await newest;
  calls[0].resolve({data:{...monthlyData(h.api,jan),marker:'old'}});calls[1].resolve({data:monthlyData(h.api,feb)});await Promise.all([a,b]);
  assert.equal(h.state.monthly.data.marker,'newest');
});

test('changing away from Since 2013 stops remaining semester reads',async()=>{
  const h=expenseHarness(),calls=pendingRpc(h.api);h.setRange(period('2013-10-10','2026-09-23'));
  const old=h.api.ensureMonthly();h.setRange(feb);const current=h.api.ensureMonthly();
  calls[0].resolve({data:monthlyData(h.api,{from:calls[0].args.p_from,to:calls[0].args.p_to})});await old;
  assert.equal(calls.length,2,'the old history must not request its remaining 26 semesters');
  calls[1].resolve({data:monthlyData(h.api,feb)});await current;
  assert.equal(h.state.monthly.data.from,feb.from);
});

test('full historical fixture contains all 156 months and exact group/period totals',async()=>{
  const h=expenseHarness(),r=period('2013-10-10','2026-09-23');let requests=0;h.setRange(r);
  h.api.setRpc(async(name,args)=>{requests++;return{data:monthlyData(h.api,{from:args.p_from,to:args.p_to})}});
  await h.api.ensureMonthly();assert.equal(requests,27);assert.equal(h.state.monthly.data.months.length,156);
  assert.equal(h.state.monthly.data.totals.expenses,468);assert.equal(h.state.monthly.data.expense_groups[0].total,468);
});

test('missing historical month fails closed, never displays partial totals',async()=>{
  const h=expenseHarness();h.setRange(period('2013-10-10','2026-09-23'));
  h.api.setRpc(async(name,args)=>{const data=monthlyData(h.api,{from:args.p_from,to:args.p_to});if(args.p_from==='2014-01-01')data.months.pop();return{data}});
  await h.api.ensureMonthly();assert.equal(h.state.monthly.data,null);assert.match(h.state.monthly.error,/Histórico incompleto/);
  assert.doesNotMatch(h.api.monthlyPanel(),/v168-kpi/);
});

test('new period recovers from previous error, while same-period errors require explicit retry',async()=>{
  const h=expenseHarness();h.state.monthly.key=jan.from+'|'+jan.to;h.state.monthly.error='Fixture unavailable';let count=0;
  h.api.setRpc(async(name,args)=>{count++;return{data:monthlyData(h.api,{from:args.p_from,to:args.p_to})}});
  await h.api.ensureMonthly();assert.equal(count,0);
  h.setRange(feb);await h.api.ensureMonthly();assert.equal(count,1);assert.equal(h.state.monthly.error,null);
  h.state.monthly.error='retry';h.state.monthly.data=null;await h.api.ensureMonthly(true);assert.equal(count,2);
});

test('monthly render suppresses data from a different filter before loading begins',()=>{
  const h=expenseHarness();h.state.monthly.key=jan.from+'|'+jan.to;h.state.monthly.data=monthlyData(h.api,jan);h.setRange(feb);
  assert.match(h.api.monthlyPanel(),/Preparando o período selecionado/);assert.doesNotMatch(h.api.monthlyPanel(),/v168-kpi/);
});

test('executive expense response also belongs to the newest period',async()=>{
  const h=expenseHarness(),calls=pendingRpc(h.api);
  const old=h.api.ensureExpense();h.setRange(feb);const current=h.api.ensureExpense();
  calls[1].resolve({data:{from:feb.from}});await current;calls[0].resolve({data:{from:jan.from}});await old;
  assert.equal(h.state.expense.data.from,feb.from);
});

test('period invalidation clears old errors, busy states, payloads and generations',()=>{
  const h=expenseHarness();for(const s of [h.state.monthly,h.state.expense])Object.assign(s,{token:4,loading:true,data:{},error:'old',key:'old'});
  h.api.invalidateExpensePeriod();for(const s of [h.state.monthly,h.state.expense]){assert.equal(s.token,5);assert.equal(s.loading,false);assert.equal(s.data,null);assert.equal(s.error,null);assert.equal(s.key,'')}
});

test('cards start the new interval without waiting for the old request',async()=>{
  const h=cardHarness(),a=h.api.load();h.setRange(feb);const b=h.api.load();assert.equal(h.calls.length,2);
  h.calls[1].resolve(evidence);await tick();assert.equal(h.calls.length,4);
  h.calls[2].resolve(invoiceResult('Current fixture'));h.calls[3].resolve(legacyResult);await b;
  h.calls[0].resolve(evidence);await a;assert.equal(h.calls.length,4);assert.equal(h.state.status,'ready');assert.equal(h.state.rows[0].card_name,'Current fixture');
});

test('cards A → B → A reject an old same-key response and preserve latest status',async()=>{
  const h=cardHarness(),a=h.api.load();h.setRange(feb);const b=h.api.load();h.setRange(jan);const latest=h.api.load();
  h.calls[2].resolve(evidence);await tick();h.calls[3].resolve(invoiceResult('Newest fixture'));h.calls[4].resolve(legacyResult);await latest;
  h.calls[0].resolve({error:{message:'Old failure'}});h.calls[1].resolve(evidence);await Promise.all([a,b]);
  assert.equal(h.state.status,'ready');assert.equal(h.state.error,null);assert.equal(h.state.rows[0].card_name,'Newest fixture');
});

test('card panel cannot label old results with new dates and errors can be retried',async()=>{
  const h=cardHarness();Object.assign(h.state,{key:jan.from+'|'+jan.to,status:'ready',rows:[{card_name:'STALE_FIXTURE'}]});h.setRange(feb);
  assert.match(h.api.panel(),/Conferindo faturas/);assert.doesNotMatch(h.api.panel(),/STALE_FIXTURE/);
  Object.assign(h.state,{key:feb.from+'|'+feb.to,status:'error',error:'fixture'});
  await h.api.load();assert.equal(h.calls.length,0);const retry=h.api.load(true);assert.equal(h.calls.length,1);h.calls[0].resolve({error:{message:'fixture'}});await retry;
  assert.match(h.api.panel(),/Tentar novamente/);
});

test('monthly overlay and new assets are restricted to the isolated candidate',()=>{
  const html=read('wip35-v183-candidate.html');
  assert.match(html,/lts-v183-expense-history-candidate\.js\?v=20260924-month-detail/);
  assert.match(html,/lts-v183-v182-feedback-safe\.js\?v=20260924-month-detail/);
  assert.match(read('lts-v183-v182-feedback-safe.js'),/v175\.monthly\.key!==r\.from\+'\|'\+r\.to/);
  assert.equal(JSON.parse(read('homologacao-current.json')).version,'wip35-v181');
  const hash=require('node:crypto').createHash('sha256').update(read('index.html')).digest('hex');
  assert.equal(hash,'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
});

test('monthly verification rejects duplicate/missing month keys even when sums match',()=>{
  const h=expenseHarness(),r={from:'2026-01-01',to:'2026-02-28'},data=monthlyData(h.api,r);
  data.monthly_totals[1].month=data.monthly_totals[0].month;
  assert.throws(()=>h.api.verifyPart(data,r.from,r.to),/repetido/);
});

test('monthly verification rejects absent numbers instead of substituting zero',()=>{
  const h=expenseHarness(),data=monthlyData(h.api,jan);data.monthly_totals[0].expenses=null;
  assert.throws(()=>h.api.verifyPart(data,jan.from,jan.to),/ausente/);
});

test('monthly verification rejects category totals inconsistent with summary',()=>{
  const h=expenseHarness(),data=monthlyData(h.api,jan);data.expense_groups[0].total=4;data.expense_groups[0].monthly[0].amount=4;
  assert.throws(()=>h.api.verifyPart(data,jan.from,jan.to),/não fecha/);
});

test('monthly verification rejects out-of-range source months and accepts explicit aggregate coverage',()=>{
  const h=expenseHarness(),data=monthlyData(h.api,jan);
  data.expense_groups[0].monthly[0].month='2025-12-01';
  assert.throws(()=>h.api.verifyPart(data,jan.from,jan.to),/fora do período/);
  data.expense_groups=[];data.expense_unclassified_card_coverage={total:3,monthly:[{month:'2026-01-01',amount:3}]};
  assert.equal(h.api.verifyPart(data,jan.from,jan.to),data);
});

test('statement composition exposes exact residual without adding a cash event',()=>{
  const source=read('lts-v183-wealth-debt-integrity.js');
  const remainder=vm.runInNewContext(between(source,'  function componentRemainder(','  const shell=')+'\ncomponentRemainder');
  assert.equal(remainder(110.25,[70.10,40.05]),0.10);
  assert.equal(remainder(100,[70,40]),-10,'negative differences are divergences, not assets');
  assert.equal(remainder(100,[60,40]),0);
  for(const missing of [null,undefined,'',NaN,Infinity]){
    assert.equal(remainder(missing,[10,20]),null);
    assert.equal(remainder(100,[missing,20]),null);
  }
  assert.match(source,/não são novas entradas, imposto presumido/);
  assert.doesNotMatch(source,/S\.rpc|fetch\(|financial_events|\.insert\(|\.update\(/);
  assert.match(read('wip35-v183-candidate.html'),/lts-v183-wealth-debt-integrity\.js\?v=20260923-component-coverage/);
});
