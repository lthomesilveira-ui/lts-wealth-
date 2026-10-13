'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const sourceFile=path.resolve(__dirname,'../../releases/v268/lts-v179-cash-recovery.js');
const tick=()=>new Promise(r=>setImmediate(r));
function extract(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i);return s.slice(i,j);}
async function run(file,scenario){
 const source=fs.readFileSync(file,'utf8'),calls=[],callbacks=new Map(),auth=[];let release,first=true,requestsPending=0,maximumRequestsPending=0;
 const firstRequest=new Promise(r=>{release=r;});
 const state={date:'2026-10-13',...Object.fromEntries(['cash','wealth','forecast','awards','dashboardReport','planningUI'].map(k=>[k,{status:'idle'}]))};
 const context={queueMicrotask,state,cache:new Map(),inflight:new Map(),dashboardFlight:null,dashboardSerial:0,D:{},N:{classList:{contains:()=>false}},V:'Dashboard',day:()=> '2026-10-13',yearRange:()=>({from:'2026-01-01',to:'2026-10-13'}),arr:x=>Array.isArray(x)?x:[],finite:x=>x!==null&&x!==undefined&&x!==''&&Number.isFinite(Number(x))?Number(x):null,v168:{wealth:{}},S:{auth:{getSession:async()=>({data:{session:{access_token:'fake-test-token'}}}),onAuthStateChange:cb=>auth.push(cb)}},publishCashDiagnostic:()=>{},logError:()=>{},closeDetail:()=>{},window:{addEventListener:(name,cb)=>callbacks.set(name,cb)},render:()=>{if(context.D&&context.V==='Dashboard')queueMicrotask(()=>context.startDashboard(false));},request:async(name,args,timeout,force)=>{calls.push({name,force});requestsPending++;maximumRequestsPending=Math.max(maximumRequestsPending,requestsPending);if(first){first=false;await firstRequest;}else await tick();requestsPending--;if(name==='lts_browser_flow_v242')return {flow:{current_future:{days:[{date:'2026-10-13',fix86_columns:{saldo_apos_d0_1:1,saldo_apos_rsu:1,saldo_apos_fgts:1}}],events:[]}}};return {fromSession:'A'};}};
 context.window.__LTS_V227_TRANSPORT={invalidate:(notify=true)=>{if(notify)callbacks.get('lts:data-invalidated')();}};
 // Deliberately use the VM's native Promise; injecting the host Promise hides races.
 vm.createContext(context);vm.runInContext(extract(source,'  async function loadState(','  function cashComplete(')+'\n'+extract(source,"  S.auth.onAuthStateChange?.((event)=>",'  async function cachedFlow'),context);
 const original=context.startDashboard(false);await tick();
 let tracked=original;
 if(scenario==='force')tracked=context.startDashboard(true);
 else if(scenario==='burst'){callbacks.get('lts:data-invalidated')();callbacks.get('lts:data-invalidated')();callbacks.get('lts:data-invalidated')();}
 else if(scenario==='navigate'){callbacks.get('lts:data-invalidated')();context.V='Despesas';}
 else if(scenario==='signout'){callbacks.get('lts:data-invalidated')();auth[0]('SIGNED_OUT');context.D=null;}
 else callbacks.get('lts:data-invalidated')();
 release();let completed=false;Promise.resolve(tracked).then(()=>{completed=true;});
 for(let i=0;i<25;i++)await tick();
 const result={file:path.basename(file),scenario,calls:calls.map(c=>c.name.replace('lts_browser_','')),maximumRequestsPending,completed,forecast:state.forecast.status,report:state.dashboardReport.status};
 context.D=null;context.V='Despesas';for(let i=0;i<5;i++)await tick();
 return result;
}
(async()=>{
 const allow=new Set(['cash_today_v242','flow_v242','wealth_detail_v242','awards_v178','expenses_v229']);
 const outcomes=[];
 for(const scenario of ['invalidate','force','burst','navigate','signout']){
  const result=await run(sourceFile,scenario);
  assert.equal(result.completed,true);assert.equal(result.maximumRequestsPending,1);
  assert(result.calls.every(name=>allow.has(name)),'recovery must only read canonical sources');
  if(['navigate','signout'].includes(scenario)){assert.equal(result.calls.length,1);assert.equal(result.forecast,'idle');}
  else{assert.equal(result.calls.length,6);assert.equal(result.forecast,'ready');assert.equal(result.report,'ready');}
  outcomes.push(result);
 }
 console.log(JSON.stringify({pass:true,uses_actual_loadState_loadForecast_priorityCash_startDashboard_and_listener:true,network_calls:0,financial_writes:0,outcomes}));
})().catch(error=>{console.error(error);process.exitCode=1;});
