/* Local-only reproduction. Executes exact published runtime bodies against invented
   fixtures. No network, browser, SQL, production writes, or historical sources. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const SOURCE = path.resolve('releases/v280');
const FILES = ['lts-v227-read-transport.js', 'lts-v179-cash-recovery.js', 'lts-v225-open-finance.js', 'lts-v228-bank-flow.js'];
const TODAY = '2026-10-16', START = Date.parse(TODAY + 'T11:20:00Z');
const BANKS = [['341', 'Itaú', 100], ['237', 'Bradesco', 200], ['336', 'C6', 300]];
const cash = () => ({version:'cash-today-v179-current-canonical', status:'complete', as_of:TODAY,
  cash:600, d0:40, brokerage_available:60, available_total:700, fgts:0,
  day:{date:TODAY, ...Object.fromEntries(BANKS.map(([,name,balance])=>[name,{balance}])), fix86_columns:{}},
  bank_positions:BANKS.map(([institution_code,institution,balance])=>({institution_code,institution,balance,source_id:'invented-'+institution_code,as_of:TODAY+'T10:00:00Z'}))});
const status = (received = TODAY+'T10:30:00Z') => ({connections:BANKS.map(([institution_code])=>({
  id:'invented-connection-'+institution_code, provider:'invented-provider', institution_code,
  last_success_at:received, provider_item_updated_at:TODAY+'T10:00:00Z', last_attempt_at:received, status:'success'}))});
const flow = () => ({ok:true,complete:true,flow:{from:TODAY,to:'2027-12-31',current_future:{days:[{date:TODAY,fix86_columns:{saldo_apos_d0_1:1,saldo_apos_rsu:1,saldo_apos_fgts:1}}],events:[]}}});
const deferred = () => {let resolve,reject; const promise=new Promise((a,b)=>{resolve=a;reject=b});return{promise,resolve,reject}};
const json = (data, code=200) => new Response(JSON.stringify(data),{status:code,headers:{'Content-Type':'application/json'}});
const sources = Object.fromEntries(FILES.map(name=>[name, fs.readFileSync(path.join(SOURCE,name),'utf8')]));
function runtime(name) {
  const source=sources[name], start=source.indexOf('function runtime()');
  const end=source.indexOf(name.includes('v225')?'\n  let attempts=':'\n function install()', start);
  assert(start>=0 && end>start, 'exact runtime delimiters '+name);
  let body=source.slice(start,end).trim();
  assert(body.endsWith('}'));
  // Expose private functions solely inside this VM. Function bodies stay unchanged.
  const exports=name.includes('v179')?'window.__test179={startDashboard,loadState,priorityCash,day};':
    name.includes('v225')?'window.__test225={refreshScreens,poll,freshnessRows,freshnessMarkup,paintFreshness};':'';
  return '('+body.slice(0,-1)+'\n'+exports+'\n})();';
}
async function settle(rounds=20) { for(let i=0;i<rounds;i++)await new Promise(resolve=>setImmediate(resolve)); }
function environment() {
  let now=START, sequence=0;const authListeners=[];
  const calls=[], timers=new Map(), nodes=new Map(), bus=new EventTarget(), docbus=new EventTarget();
  function node(tag='div') {return {tagName:tag,id:'',className:'',dataset:{},style:{},textContent:'',innerHTML:'',children:[],
    classList:{contains:()=>false,remove(){},toggle(){}},setAttribute(){},querySelector:()=>null,querySelectorAll:()=>[],
    remove(){if(this.id)nodes.delete(this.id);if(nodes.get(this.className)===this)nodes.delete(this.className)},
    insertAdjacentElement(where,el){if(el.id)nodes.set(el.id,el);if(el.className)nodes.set(el.className,el)},appendChild(){},addEventListener(){}};}
  nodes.set('ltsBankEvidence',node());
  const document={hidden:false,body:node('body'),documentElement:{setAttribute(){}},
    getElementById:id=>nodes.get(id)||null, createElement:node,
    querySelector:selector=>selector==='.flowbar'?nodes.get('ltsBankEvidence'):selector==='.v225-balance-freshness'?nodes.get('v225-balance-freshness')||null:null,
    querySelectorAll:selector=>selector==='.v225-balance-freshness'&&nodes.has('v225-balance-freshness')?[nodes.get('v225-balance-freshness')]:[],
    addEventListener:docbus.addEventListener.bind(docbus)};
  const ctx={console,Intl,Map,Set,Promise,JSON,Number,String,Math,structuredClone,Response,Headers,AbortController,DOMException,Event,
    performance,queueMicrotask,document,D:false,V:'Fluxo Diário',ACC:'Consolidado',BOOT:{generation:1},FLOWLOADING:false,FLOWFROM:TODAY,FLOWTO:TODAY,
    N:{classList:{contains:()=>false}},U:'https://invented.invalid',K:'invented-public-key',EXP:new Set(),
    Date:class extends Date {constructor(...args){super(...(args.length?args:[now]))}static now(){return now}},
    setTimeout(fn,ms){const id=++sequence;timers.set(id,{fn,ms});if(ms<=30)queueMicrotask(()=>{if(timers.delete(id))fn()});return id},
    clearTimeout(id){timers.delete(id)},
    sessionStorage:{getItem:()=>String(now),setItem(){}},
    __LTS_V176_FLOW_EXPENSE_AUDIT:{installed:true},__LTS_V168_STATE:{dashboard:{},wealth:{},expense:{key:'ytd'},updates:{}},
    __LTS_V175_STATE:{expense:{},monthly:{}},__LTS_V181_STATE:{review:{}},
    render:()=>'',renderNav:()=>'',dashboard:()=>'',despesas:()=>'',mergedFlowDays:()=>[],
    flowVals:()=>({}),flowSemanticTitle:()=>'',flowSemanticMeta:()=>'',today:()=>TODAY,dayEvents:()=>[],
    loadFlowRange(){calls.push({name:'loadFlowRange',at:now})},
    addEventListener:bus.addEventListener.bind(bus),dispatchEvent:bus.dispatchEvent.bind(bus)};
  const routes={};
  ctx.fetch=async (url,init)=>{
    const name=String(url).split('/').pop(), count=calls.filter(x=>x.name===name).length+1;
    calls.push({name,count,at:now});
    if(routes[name])return routes[name]({count,init,now});
    if(name==='lts_browser_cash_today_v242')return json(cash());
    if(name==='lts_browser_flow_v242')return json(flow());
    if(name==='lts_browser_open_finance_status_v1')return json(status());
    if(name==='lts_browser_open_finance_refresh_v1')return json({ok:true,requested_at:new Date(now).toISOString()});
    return json({ok:true,summary:{selected_total:0},rows:[],events:[]});
  };
  ctx.S={auth:{getSession:async()=>({data:{session:{access_token:'invented-token'}}}),onAuthStateChange(callback){authListeners.push(callback)}},
    rpc:async(name,args)=>{const response=await ctx.fetch(ctx.U+'/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'Bearer invented-token'},body:JSON.stringify(args||{})});return{data:await response.json(),error:null}}};
  ctx.window=ctx;vm.createContext(ctx);
  for(const name of FILES)vm.runInContext(runtime(name),ctx,{filename:name});
  ctx.D={};ctx.__LTS_V225.started=true;
  ctx.__LTS_V225.status=status();ctx.__LTS_V225.observations=new Map();
  const seed=()=>{Object.assign(ctx.__LTS_V178_STATE.cash,{status:'ready',date:TODAY,data:cash(),token:0,sessionGeneration:ctx.BOOT.generation,authEpoch:0});ctx.__LTS_V178_STATE.date=TODAY;ctx.__LTS_V178_STATE.awards.status='ready';};
  const count=name=>calls.filter(x=>x.name===name).length;
  const snapshot=()=>{ctx.render();return{cash_status:ctx.__LTS_V178_STATE.cash.status,
    cash_has_data:!!ctx.__LTS_V178_STATE.cash.data,cash_complete:ctx.__LTS_V178_REVIEW.cashComplete(ctx.__LTS_V178_STATE.cash),
    position_rows:ctx.__test225.freshnessRows().filter(x=>!!x.position).length,
    connection_origins:ctx.__test225.freshnessRows().map(x=>x.origin),
    flow_position_text:nodes.get('v274ReceivedPosition')?.textContent,
    freshness_html:nodes.get('v225-balance-freshness')?.innerHTML,
    cash_requests:count('lts_browser_cash_today_v242'),transport_revision:ctx.__LTS_V227_TRANSPORT.revision};};
  return{ctx,routes,calls,timers,nodes,seed,snapshot,count,advance:ms=>now+=ms,authEvent:event=>authListeners.forEach(fn=>fn(event))};
}
const results=[];
const CASH='lts_browser_cash_today_v242', FLOW='lts_browser_flow_v242';
const nextCash=(amount=900,date=TODAY)=>{const c=cash();c.as_of=date;c.day.date=date;c.cash=amount;c.available_total=amount+100;c.day['Itaú'].balance=amount-500;c.bank_positions[0].balance=amount-500;return c};
async function test(name,fn){await fn();results.push({test:name,result:'PASS'});console.log('PASS '+name)}
(async()=>{
 await test('request invalidation recovers cash on Flow without provider confirmation',async()=>{
  const e=environment();e.seed();const origin=e.snapshot().connection_origins;
  await e.ctx.__LTS_V225.refresh();await settle();const s=e.snapshot();
  assert.equal(e.ctx.__LTS_V225.syncing,true);assert.equal(s.cash_complete,true);assert.equal(s.position_rows,3);assert.equal(s.cash_requests,1);assert.deepEqual(s.connection_origins,origin);
 });
 await test('cash-only refresh bypasses an existing heavy dashboard flight and invalidates once',async()=>{
  const e=environment(),heavy=deferred();e.seed();e.routes[FLOW]=()=>heavy.promise;
  const opening=e.ctx.__LTS_V178_REVIEW.ready();await settle();assert.equal(e.count(FLOW),1);
  const revision=e.ctx.__LTS_V227_TRANSPORT.revision;
  await e.ctx.__test225.refreshScreens();await settle();const s=e.snapshot();
  assert.equal(s.cash_complete,true);assert.equal(s.cash_requests,1);assert.equal(e.count('loadFlowRange'),1);assert.equal(e.count(FLOW),1);assert.equal(e.ctx.__LTS_V227_TRANSPORT.revision,revision+1);
  heavy.resolve(json(flow()));await opening;
 });
 await test('old/new cash requests serialize; two invalidations coalesce one substitute',async()=>{
  const e=environment(),old=deferred(),fresh=deferred();e.seed();
  e.routes[CASH]=({count})=>count===1?old.promise:fresh.promise;
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();assert.equal(e.count(CASH),1);
  e.ctx.__LTS_V227_TRANSPORT.invalidate();e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();
  assert.equal(e.count(CASH),1);assert.equal(e.ctx.__LTS_V178_STATE.cash.data,null);
  old.resolve(json(cash()));await settle();assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'loading');assert.equal(e.ctx.__LTS_V178_STATE.cash.data,null);
  fresh.resolve(json(nextCash()));await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.data.cash,900);assert.equal(e.snapshot().cash_complete,true);
 });
 await test('Dashboard and Flow share the same active cash flight including force callers',async()=>{
  const e=environment(),gate=deferred();e.seed();e.ctx.__LTS_V178_STATE.cash.status='idle';e.routes[CASH]=()=>gate.promise;
  const a=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(),b=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);assert.equal(a,b);
  const dashboard=e.ctx.__LTS_V178_REVIEW.ready();await settle();assert.equal(e.count(CASH),1);
  gate.resolve(json(cash()));await a;await dashboard;await settle();assert.equal(e.count(CASH),1);assert.equal(e.snapshot().cash_complete,true);
 });
 await test('terminal error never retries on render, account selection or expansion',async()=>{
  const e=environment();e.seed();e.routes[CASH]=()=>json({code:'22000',message:'Invented terminal error'},400);
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'error');assert.equal(e.count(CASH),1);
  for(let i=0;i<50;i++){e.ctx.ACC=i%2?'Itaú':'Consolidado';e.ctx.EXP.add(TODAY);e.ctx.render()}await settle();assert.equal(e.count(CASH),1);assert.match(e.snapshot().flow_position_text,/indisponível/);
 });
 await test('transient retry stops at two requests per generation',async()=>{
  const e=environment();e.seed();e.routes[CASH]=()=>json({code:'57014',message:'Invented timeout'},503);
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'error');
  for(let i=0;i<30;i++)e.ctx.render();await settle();assert.equal(e.count(CASH),2);
 });
 await test('a single transient retry can restore the current cash payload',async()=>{
  const e=environment();e.seed();e.routes[CASH]=({count})=>count===1?json({message:'Invented retry'},503):json(cash());
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();assert.equal(e.count(CASH),2);assert.equal(e.snapshot().cash_complete,true);
 });
 await test('incomplete success remains unavailable and does not retry on render',async()=>{
  const e=environment();e.seed();e.routes[CASH]=()=>json({...cash(),status:'incomplete'});
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();for(let i=0;i<30;i++)e.ctx.render();await settle();
  assert.equal(e.count(CASH),1);assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'ready');assert.equal(e.snapshot().cash_complete,false);assert.equal(e.snapshot().position_rows,0);
 });
 await test('silent transport revision during getSession prevents old send and coalesces replacement',async()=>{
  const e=environment(),auth=deferred();e.seed();let reads=0;
  e.ctx.S.auth.getSession=()=>++reads===1?auth.promise:Promise.resolve({data:{session:{access_token:'invented-token'}}});
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();assert.equal(e.count(CASH),0);
  e.ctx.__LTS_V227_TRANSPORT.invalidate(false);auth.resolve({data:{session:{access_token:'invented-token'}}});await p;await settle();
  assert.equal(e.count(CASH),1);assert.equal(e.snapshot().cash_complete,true);
 });
 await test('silent pre-mutation invalidation plus HTTP failure supersedes active cash without parallel RPC',async()=>{
  const e=environment(),old=deferred(),fresh=deferred();e.seed();e.routes[CASH]=({count})=>count===1?old.promise:fresh.promise;
  e.routes.lts_browser_open_finance_refresh_v1=()=>json({message:'Invented mutation failure'},503);
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();await e.ctx.S.rpc('lts_browser_open_finance_refresh_v1');await settle();assert.equal(e.count(CASH),1);
  old.resolve(json(cash()));await settle();assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.data,null);
  fresh.resolve(json(nextCash()));await p;await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.data.cash,900);
 });
 await test('silent pre-mutation invalidation plus HTTP success coalesces one replacement',async()=>{
  const e=environment(),old=deferred(),fresh=deferred();e.seed();e.routes[CASH]=({count})=>count===1?old.promise:fresh.promise;
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();await e.ctx.S.rpc('lts_browser_open_finance_refresh_v1');await settle();assert.equal(e.count(CASH),1);
  old.resolve(json(cash()));await settle();assert.equal(e.count(CASH),2);fresh.resolve(json(nextCash()));await p;await settle();assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.data.cash,900);
 });
 await test('BOOT logout/login works without auth callbacks and never applies the prior session',async()=>{
  const e=environment(),old=deferred(),fresh=deferred();e.seed();e.routes[CASH]=({count})=>count===1?old.promise:fresh.promise;
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();e.ctx.BOOT.generation++;e.ctx.D=null;e.ctx.render();
  e.ctx.BOOT.generation++;e.ctx.D={};e.ctx.render();await settle();assert.equal(e.count(CASH),1);assert.equal(e.ctx.__LTS_V178_STATE.cash.data,null);
  old.resolve(json(cash()));await settle();assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.data,null);
  fresh.resolve(json(nextCash()));await p;await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.sessionGeneration,3);assert.equal(e.snapshot().cash_complete,true);
 });
 await test('logout during getSession sends no cash RPC and does not restart while signed out',async()=>{
  const e=environment(),auth=deferred();e.seed();e.ctx.S.auth.getSession=()=>auth.promise;
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();e.ctx.BOOT.generation++;e.ctx.D=null;e.ctx.render();
  auth.resolve({data:{session:{access_token:'invented-old-token'}}});await p;await settle();assert.equal(e.count(CASH),0);assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'idle');assert.equal(e.ctx.__LTS_V178_STATE.cash.data,undefined);
 });
 await test('auth callbacks also supersede old cash slots',async()=>{
  const e=environment(),old=deferred();e.seed();e.routes[CASH]=({count})=>count===1?old.promise:json(nextCash());
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();e.ctx.D=null;e.authEvent('SIGNED_OUT');e.ctx.D={};e.authEvent('SIGNED_IN');e.ctx.render();
  old.resolve(json(cash()));await p;await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.data.cash,900);assert.equal(e.snapshot().cash_complete,true);assert.equal(e.count(CASH),2);
 });
 await test('BRT day rollover refreshes cash without advancing global dashboard date',async()=>{
  const e=environment();e.seed();e.ctx.__LTS_V178_STATE.forecast={status:'ready',date:TODAY,data:flow(),token:0};
  e.advance(16*3600*1000);const tomorrow='2026-10-17';e.routes[CASH]=()=>json(nextCash(900,tomorrow));
  e.ctx.render();await settle();assert.equal(e.ctx.__LTS_V178_STATE.cash.date,tomorrow);assert.equal(e.ctx.__LTS_V178_STATE.date,TODAY);assert.equal(e.ctx.__LTS_V178_STATE.forecast.date,TODAY);
  const heavy=deferred();e.routes[FLOW]=()=>heavy.promise;e.ctx.V='Dashboard';e.ctx.render();await settle();
  assert.equal(e.ctx.__LTS_V178_STATE.date,tomorrow);assert.equal(e.ctx.__LTS_V178_STATE.forecast.status,'loading');assert.equal(e.ctx.__LTS_V178_STATE.forecast.data,null);
  heavy.resolve(json({...flow(),flow:{...flow().flow,current_future:{days:[{date:tomorrow,fix86_columns:{}}],events:[]}}}));await settle();
 });
 await test('day rollover during an old read discards it and serializes a current-day replacement',async()=>{
  const e=environment(),old=deferred();e.seed();e.routes[CASH]=({count})=>count===1?old.promise:json(nextCash(900,'2026-10-17'));
  const p=e.ctx.__LTS_V178_REVIEW.refreshCashOnly(true);await settle();e.advance(16*3600*1000);old.resolve(json(cash()));await p;await settle();
  assert.equal(e.count(CASH),2);assert.equal(e.ctx.__LTS_V178_STATE.cash.date,'2026-10-17');assert.equal(e.ctx.__LTS_V178_STATE.date,TODAY);
 });
 await test('loading message is distinct from terminal unavailability and keeps current Flow filters',async()=>{
  const e=environment(),gate=deferred();e.seed();e.ctx.ACC='Itaú';e.ctx.EXP.add(TODAY);e.routes[CASH]=()=>gate.promise;
  e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();assert.match(e.snapshot().flow_position_text,/Atualizando a posição recebida \(Itaú\)/);assert.equal(e.ctx.EXP.has(TODAY),true);
  gate.resolve(json(cash()));await settle();assert.equal(e.ctx.ACC,'Itaú');assert.equal(e.ctx.EXP.has(TODAY),true);assert.equal(e.snapshot().position_rows,3);
 });
 await test('an old queued Dashboard refresh cannot resume heavy work after BOOT logout/login',async()=>{
  const e=environment(),heavy=deferred();e.seed();e.routes[FLOW]=()=>heavy.promise;
  const opening=e.ctx.__LTS_V178_REVIEW.ready();await settle();assert.equal(e.count(FLOW),1);
  const oldRefresh=e.ctx.__LTS_V178_REVIEW.refresh();await settle();
  e.ctx.D=null;e.ctx.BOOT.generation++;e.ctx.render();e.ctx.D={};e.ctx.BOOT.generation++;e.ctx.render();await settle();
  assert.equal(e.snapshot().cash_complete,true);const before=e.calls.map(x=>x.name);
  heavy.resolve(json(flow()));await opening;await oldRefresh;await settle();
  const after=e.calls.slice(before.length).map(x=>x.name);assert.deepEqual(after,[]);assert.equal(e.count(FLOW),1);
 });
 await test('loading state repaints the existing DOM without a test-triggered render',async()=>{
  const e=environment(),gate=deferred();e.seed();e.snapshot();assert.match(e.nodes.get('v274ReceivedPosition').textContent,/600,00/);
  e.routes[CASH]=()=>gate.promise;e.ctx.__LTS_V227_TRANSPORT.invalidate();await settle();
  assert.match(e.nodes.get('v274ReceivedPosition').textContent,/Atualizando a posição recebida/);assert.doesNotMatch(e.nodes.get('v274ReceivedPosition').textContent,/600,00/);
  assert.match(e.nodes.get('v225-balance-freshness').innerHTML,/Horário da posição indisponível/);
  gate.resolve(json(nextCash()));await settle();assert.match(e.nodes.get('v274ReceivedPosition').textContent,/900,00/);
 });
 await test('BOOT resets captured V179 forecast and wealth slots without resuming old heavy requests',async()=>{
  const e=environment(),forecast=deferred(),wealth=deferred();e.seed();e.routes[FLOW]=()=>forecast.promise;
  e.routes.lts_browser_wealth_detail_v242=()=>wealth.promise;
  const opening=e.ctx.__LTS_V178_REVIEW.ready(),oldWealth=e.ctx.__test179.loadState('wealth','lts_browser_wealth_detail_v242',{},true);await settle();
  const previousForecast=e.ctx.__LTS_V178_STATE.forecast,previousWealth=e.ctx.__LTS_V178_STATE.wealth;
  e.ctx.D=null;e.ctx.BOOT.generation++;e.ctx.render();assert.notEqual(e.ctx.__LTS_V178_STATE.forecast,previousForecast);assert.notEqual(e.ctx.__LTS_V178_STATE.wealth,previousWealth);
  e.ctx.D={};e.ctx.BOOT.generation++;e.ctx.render();await settle();const before=e.calls.length;
  forecast.resolve(json(flow()));wealth.resolve(json({private:'invented-old-session-position'}));await opening;await oldWealth;await settle();
  assert.equal(e.ctx.__LTS_V178_STATE.forecast.data,undefined);assert.equal(e.ctx.__LTS_V178_STATE.wealth.data,undefined);assert.equal(e.calls.length,before);assert.equal(e.snapshot().cash_complete,true);
 });
 fs.writeFileSync('qa/v280-cash-unit-results.json',JSON.stringify({scope:'local VM, exact candidate runtime bodies, invented fixtures, no network',source_sha256:Object.fromEntries(FILES.map(name=>[name,crypto.createHash('sha256').update(sources[name]).digest('hex')])),results},null,2)+'\n');
 console.log('ALL '+results.length+' CANDIDATE TESTS PASSED');
})().catch(error=>{console.error(error);process.exitCode=1});
