/* Local-only reproduction. Executes exact published runtime bodies against invented
   fixtures. No network, browser, SQL, production writes, or historical sources. */
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const SOURCE = path.resolve(process.env.LTS_PROJECTION_BASE_ROOT || path.join(__dirname,'../../releases/v283'));
const BASE_ASSET=path.join(SOURCE,'lts-v179-cash-recovery.js');
const CANDIDATE_ASSET=path.join(path.resolve(process.env.LTS_PROJECTION_CANDIDATE_ROOT||SOURCE),'lts-v179-cash-recovery.js');
const OUTPUT=path.resolve(process.env.LTS_PROJECTION_OUTPUT||'projection-coverage-runtime-results.json');
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
let sources = Object.fromEntries(FILES.map(name=>[name, fs.readFileSync(path.join(SOURCE,name),'utf8')]));
function runtime(name) {
  const source=sources[name], start=source.indexOf('function runtime()');
  const end=source.indexOf(name.includes('v225')?'\n  let attempts=':'\n function install()', start);
  assert(start>=0 && end>start, 'exact runtime delimiters '+name);
  let body=source.slice(start,end).trim();
  assert(body.endsWith('}'));
  // Expose private functions solely inside this VM. Function bodies stay unchanged.
  const exports=name.includes('v179')?'window.__test179={startDashboard,loadState,priorityCash,day,loadForecast,mergeForecast,forecastCoverage:typeof forecastCoverage==="function"?forecastCoverage:null};':
    name.includes('v225')?'window.__test225={refreshScreens,poll,freshnessRows,freshnessMarkup,paintFreshness};':'';
  return '('+body.slice(0,-1)+'\n'+exports+'\n})();';
}
async function settle(rounds=20) { for(let i=0;i<rounds;i++)await new Promise(resolve=>setImmediate(resolve)); }
function environment(candidate=true) {
  sources['lts-v179-cash-recovery.js']=fs.readFileSync(candidate?CANDIDATE_ASSET:BASE_ASSET,'utf8');
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
  ctx.D=false;ctx.__LTS_V225.started=true;
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
const TO='2027-12-31';
const row=(date,n=100)=>({date,fix86_columns:{saldo_apos_d0_1:n,saldo_apos_rsu:n+20,saldo_apos_fgts:n+30}});
function dates(from=TODAY,to=TO){const out=[];for(let t=Date.parse(from+'T12:00Z'),z=Date.parse(to+'T12:00Z');t<=z;t+=86400000)out.push(new Date(t).toISOString().slice(0,10));return out}
function payload(rows=dates().map(d=>row(d)),flags={}){return{ok:true,...flags,flow:{from:TODAY,to:TO,current_future:{days:rows,events:[{source:'invented',source_ref:'fixture',event_date:'2027-04-03',signed_amount:7.25}]}}}}
const serialize=x=>JSON.parse(JSON.stringify(x));
const results=[];let assertions=0;
function check(condition,label){assert(condition,label);assertions++;}
async function loaded(p,candidate=true){const e=environment(candidate);e.routes.lts_browser_flow_v242=()=>json(p);await e.ctx.__test179.loadForecast();await settle();return e}
function state(e){return e.ctx.__LTS_V178_STATE}
(async()=>{
 // Exact unchanged runtime reproduces a false full-horizon claim.
 const truncated=payload([row(TODAY),row('2026-10-17')]);
 const old=await loaded(truncated,false);
 check(state(old).planningUI.status==='ready','baseline incorrectly ready with two dates');
 check(state(old).planningUI.data.fgts_covers_horizon===true,'baseline incorrectly covers 442 days using two dates');
 check(state(old).planningUI.data.period_to===TO,'baseline claims requested end rather than received end');
 results.push({name:'baseline counterexample',days_received:2,horizon_days:442,planning_status:state(old).planningUI.status,fgts_covers_horizon:state(old).planningUI.data.fgts_covers_horizon,claimed_period_to:TO});
 const valid=payload(),baseline=await loaded(valid,false),e=await loaded(valid),s=state(e);
 check(s.forecast.status==='ready','complete range ready');
 check(s.forecast.data.coverage.complete===true,'complete validated');
 check(s.forecast.data.coverage.expected_days===442,'442 day count');
 assert.deepEqual(serialize(s.forecast.data.flow),serialize(state(baseline).forecast.data.flow));assertions++;
 assert.deepEqual(serialize(s.planningUI),serialize(state(baseline).planningUI));assertions++;
 check(s.forecast.parts[0].flow.current_future.days.length===442,'raw source preserved');
 // Every missing day is rejected, including today, dates of vesting, leap-adjacent boundaries, and horizon end.
 for(let i=0;i<442;i++){
  const fixture=payload(valid.flow.current_future.days.filter((_,j)=>j!==i));
  const c=e.ctx.__test179.forecastCoverage([fixture],TODAY,TO);
  check(c.complete===false&&c.reason==='missing_dates','missing date '+i);
 }
 const failures=[
  ['truncated',truncated,'missing_dates'],
  ['missing tomorrow',payload(valid.flow.current_future.days.filter(d=>d.date!=='2026-10-17')),'missing_dates'],
  ['duplicate identical',payload([...valid.flow.current_future.days,row(TODAY)]),'duplicate_date'],
  ['duplicate conflicting',payload([...valid.flow.current_future.days,row(TODAY,-999)]),'duplicate_date'],
  ['duplicate masks gap',payload(valid.flow.current_future.days.slice(1).concat(row('2026-10-17'))),'duplicate_date'],
  ['impossible calendar day',payload(valid.flow.current_future.days.concat(row('2027-02-30'))),'invalid_date'],
  ['empty date',payload(valid.flow.current_future.days.concat(row(''))),'invalid_date'],
 ];
 for(const [label,p,reason]of failures){
  const x=await loaded(p),t=state(x);
  check(t.forecast.status==='incomplete',label+' forecast blocked');
  check(t.planningUI.status==='incomplete'&&t.planningUI.data===null,label+' no coverage claim');
  check(t.forecast.data.complete===false&&t.forecast.data.coverage.reason===reason,label+' correct reason');
  check(await x.ctx.__LTS_V178_REVIEW.cachedFlow(TODAY,TO)===null,label+' not reusable as full-range flow');
 }
 for(const key of ['saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'])for(const value of [null,'',true,false,{},[], ' ', 'NaN','Infinity']){
  const p=structuredClone(valid);p.flow.current_future.days[50].fix86_columns[key]=value;
  check(e.ctx.__test179.forecastCoverage([p],TODAY,TO).complete===false,key+' invalid '+String(value));
 }
 const numbers=structuredClone(valid);for(const d of numbers.flow.current_future.days)for(const k of Object.keys(d.fix86_columns))d.fix86_columns[k]=String(d.fix86_columns[k]);
 check(e.ctx.__test179.forecastCoverage([numbers],TODAY,TO).complete===true,'numeric strings accepted');
 const reversed=payload([...valid.flow.current_future.days].reverse());const reverse=await loaded(reversed);
 assert.deepEqual(serialize(state(reverse).planningUI),serialize(s.planningUI));assertions++;
 const negative=structuredClone(valid);negative.flow.current_future.days.find(d=>d.date==='2027-04-03').fix86_columns.saldo_apos_fgts=-1;
 const neg=await loaded(negative);check(state(neg).planningUI.data.fgts_covers_horizon===false,'known negative retained');check(state(neg).planningUI.data.fgts_first_negative==='2027-04-03','negative date retained');
 const flagged=await loaded(payload(undefined,{complete:false,incomplete_families:['C6']}));
 check(state(flagged).forecast.data.coverage.complete===true,'complete shape distinct from family completeness');check(state(flagged).planningUI.data===null,'server incomplete still blocks');
 const leap=payload(dates('2028-02-28','2028-03-01').map(d=>row(d)));
 check(e.ctx.__test179.forecastCoverage([leap],'2028-02-28','2028-03-01').expected_days===3,'leap day included');
 check(!e.ctx.__test179.forecastCoverage([payload([row('2028-02-28'),row('2028-03-01')])],'2028-02-28','2028-03-01').complete,'missing leap day blocks');
 const refresh=await loaded(valid),wait=deferred();refresh.routes.lts_browser_flow_v242=()=>wait.promise;
 refresh.ctx.__LTS_V227_TRANSPORT.invalidate(false);const job=refresh.ctx.__test179.loadForecast(true);await settle();
 check(state(refresh).planningUI.status==='loading'&&state(refresh).planningUI.data===null,'old coverage removed while refreshing');
 wait.resolve(json({message:'invented nonretryable failure',code:'fixture'},400));await job;
 check(state(refresh).planningUI.status==='error'&&state(refresh).planningUI.data===null,'old coverage not retained after refresh failure');
 refresh.routes.lts_browser_flow_v242=()=>json(valid);refresh.ctx.__LTS_V227_TRANSPORT.invalidate(false);await refresh.ctx.__test179.loadForecast(true);
 check(state(refresh).planningUI.status==='ready','explicit retry recovers');
 const logout=environment(),pending=deferred();logout.routes.lts_browser_flow_v242=()=>pending.promise;const pendingJob=logout.ctx.__test179.loadForecast();await settle();logout.authEvent('SIGNED_OUT');pending.resolve(json(valid));await pendingJob;
 check(state(logout).forecast.status==='idle'&&state(logout).planningUI.status==='idle','late signed-out response ignored');
 // A partial result can recover through the public refresh orchestration used by the UI.
 const recovered=await loaded(truncated);recovered.routes.lts_browser_flow_v242=()=>json(valid);
 recovered.seed();recovered.ctx.D={};recovered.ctx.V='Dashboard';
 await recovered.ctx.__LTS_V178_REVIEW.refresh();await settle();
 check(state(recovered).forecast.status==='ready'&&state(recovered).planningUI.status==='ready','incomplete to full through public refresh');
 check(state(recovered).planningUI.data.fgts_covers_horizon===true,'coverage only restored after full refresh');
 const labelSource=fs.readFileSync(CANDIDATE_ASSET,'utf8').split('\n').find(x=>x.includes('if(!forecastReady)'));
 const labelExpression=labelSource.slice(labelSource.indexOf("(state.forecast.status==='loading'?" )+1,labelSource.indexOf("+'</div><button" )-1);
 const incompleteLabel=vm.runInContext('(()=>{const state=__LTS_V178_STATE,f=state.forecast.data;return '+labelExpression+'})()', (await loaded(truncated)).ctx);
 check(incompleteLabel==='Projeção incompleta. Atualize para conferir todo o período.','exact UI expression describes missing dates without claiming C6');
 // A response crossing midnight/year remains dated to its original request and
 // cannot be presented as current or reused for the new year.
 const midnight=environment(),yearWait=deferred();midnight.advance(Date.parse('2027-01-01T02:59:00Z')-START);
 let firstArgs;midnight.routes.lts_browser_flow_v242=({init})=>{firstArgs=JSON.parse(init.body);return yearWait.promise};
 const yearJob=midnight.ctx.__test179.loadForecast();await settle();
 check(firstArgs.p_to==='2027-12-31','Dec31 request ends next year');
 midnight.advance(120000);yearWait.resolve(json(payload(dates('2026-12-31','2027-12-31').map(d=>row(d)))));await yearJob;
 check(state(midnight).planningUI.date==='2026-12-31','late response retains old date');
 const planningLine=fs.readFileSync(CANDIDATE_ASSET,'utf8').split('\n').find(x=>x.includes('ds.data.planningUI=state.planningUI'));
 const planningExpression=planningLine.trim().slice('ds.data.planningUI='.length,-1);
 check(vm.runInContext('(()=>{const state=__LTS_V178_STATE,day=__test179.day;return '+planningExpression+'})()',midnight.ctx)===null,'actual dashboard current-date predicate rejects last-year response');
 check(await midnight.ctx.__LTS_V178_REVIEW.cachedFlow('2027-01-01','2027-12-31')===null,'late last-year forecast cannot enter current cache');
 let nextArgs;midnight.routes.lts_browser_flow_v242=({init})=>{nextArgs=JSON.parse(init.body);return json(payload(dates('2027-01-01','2028-12-31').map(d=>row(d))))};
 midnight.ctx.__LTS_V227_TRANSPORT.invalidate(false);await midnight.ctx.__test179.loadForecast(true);
 check(nextArgs.p_to==='2028-12-31','Jan1 next request extends correct year');
 check(state(midnight).forecast.data.coverage.expected_days===731,'new horizon includes leap day');
 check(state(midnight).planningUI.date==='2027-01-01'&&state(midnight).planningUI.data.period_to==='2028-12-31','new-year coverage dated correctly');
 const out={pass:true,assertions,scope:'exact four runtime bodies in local VM; invented fixtures; no production mutations; not browser visual QA',baseline_sha256:crypto.createHash('sha256').update(fs.readFileSync(BASE_ASSET)).digest('hex'),candidate_sha256:crypto.createHash('sha256').update(fs.readFileSync(CANDIDATE_ASSET)).digest('hex'),results};
 fs.writeFileSync(OUTPUT,JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
