/* Local-only reproduction. Executes exact published runtime bodies against invented
   fixtures. No network, browser, SQL, production writes, or historical sources. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const SOURCE = path.resolve('releases/v281');
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

const baseline=sources['lts-v179-cash-recovery.js'];
sources['lts-v179-cash-recovery.js']=fs.readFileSync(path.resolve('releases/v282/lts-v179-cash-recovery.js'),'utf8');
const src=sources['lts-v179-cash-recovery.js'];
assert.equal(src.replace("':(state.forecast.status==='idle'?'Aguardando carregamento da proje\u00e7\u00e3o\u2026':(f?.complete===false?'Proje\u00e7\u00e3o consolidada incompleta: C6 em confer\u00eancia. Os demais bancos continuam dispon\u00edveis no fluxo.':'Proje\u00e7\u00e3o indispon\u00edvel.')))","':(f?.complete===false?'Proje\u00e7\u00e3o consolidada incompleta: C6 em confer\u00eancia. Os demais bancos continuam dispon\u00edveis no fluxo.':'Proje\u00e7\u00e3o indispon\u00edvel.'))"),baseline,'exact reversal: only idle label branch differs');
const line=src.split('\n').find(s=>s.includes("if(!forecastReady)"));
const expression=line.slice(line.indexOf("(state.forecast.status==='loading'?" )+1,line.indexOf("+'</div><button" )-1);
const readyLine=src.split('\n').find(s=>s.includes('const forecastReady='));
const readyExpression=readyLine.slice(readyLine.indexOf('=')+1).trim().replace(/;$/,'');
function isReady(e){return vm.runInContext('(()=>{const state=__LTS_V178_STATE,f=state.forecast.data,arr=x=>Array.isArray(x)?x:[],day=()=>"2026-10-16";return '+readyExpression+'})()',e.ctx)}
function message(e){return vm.runInContext('(()=>{const state=__LTS_V178_STATE,f=state.forecast.data;return '+expression+'})()',e.ctx)}
(async()=>{
 const results=[];
 const e=environment(),waitingCash=deferred(),waitingFlow=deferred();e.ctx.V='Dashboard';
 e.routes.lts_browser_cash_today_v242=()=>waitingCash.promise;
 e.routes.lts_browser_flow_v242=()=>waitingFlow.promise;
 const job=e.ctx.__test179.startDashboard(false);await settle();
 assert.equal(e.ctx.__LTS_V178_STATE.cash.status,'loading');
 assert.equal(e.ctx.__LTS_V178_STATE.forecast.status,'idle');assert.equal(isReady(e),false);
 assert.equal(e.count('lts_browser_flow_v242'),0);
 assert.equal(message(e),'Aguardando carregamento da projeção…');
 results.push({phase:'cash pending, forecast not started',forecast:'idle',flow_requests:0,message:message(e)});
 waitingCash.resolve(json(cash()));await settle();
 assert.equal(e.ctx.__LTS_V178_STATE.forecast.status,'loading');assert.equal(isReady(e),false);
 assert.match(message(e),/Carregando projeção/);
 const payload=flow();payload.flow.current_future.days.push({...payload.flow.current_future.days[0],date:'2026-10-17'});
 waitingFlow.resolve(json(payload));await job;await settle();
 assert.equal(e.ctx.__LTS_V178_STATE.forecast.status,'ready');assert.equal(isReady(e),true,'ready graph bypasses placeholder');
 assert.equal(e.count('lts_browser_flow_v242'),1);
 assert.equal(e.ctx.__LTS_V178_STATE.forecast.data.flow.current_future.days.length,2);
 results.push({phase:'same orchestration completes without retry',forecast:'ready',flow_requests:1,days:2});
 const f=environment();f.ctx.V='Dashboard';f.routes.lts_browser_flow_v242=()=>json({message:'invented database error',code:'57014'},500);
 await f.ctx.__test179.startDashboard(false);await settle();
 assert.equal(f.ctx.__LTS_V178_STATE.forecast.status,'error');assert.equal(f.count('lts_browser_flow_v242'),2);assert.equal(message(f),'Projeção indisponível.');
 results.push({phase:'real error remains distinguishable in state',forecast:'error',flow_requests:2,message:message(f)});
 const labelCases=[];
 for(const [state,data,expected] of [['idle',null,'Aguardando carregamento da projeção…'],['loading',null,'Carregando projeção'],['error',null,'Projeção indisponível.'],['ready',{complete:false},'Projeção consolidada incompleta'],['error',{complete:false},'Projeção consolidada incompleta'],['ready',null,'Projeção indisponível.']]){f.ctx.__LTS_V178_STATE.forecast.status=state;f.ctx.__LTS_V178_STATE.forecast.data=data;assert(message(f).includes(expected));labelCases.push({state,message:message(f)});}
 const out={pass:true,labelCases,scope:'exact four runtime bodies and exact projection label expression; synthetic VM, not a visual browser test',source_sha256:crypto.createHash('sha256').update(src).digest('hex'),results};fs.writeFileSync(path.resolve('qa/p12-result.json'),JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
