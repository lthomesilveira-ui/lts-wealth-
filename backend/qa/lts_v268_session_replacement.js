'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const tick=()=>new Promise(r=>setImmediate(r));
function extract(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i);return s.slice(i,j);}
async function run(source,gatedName,authFirst){
 const callbacks=new Map(),auth=[],calls=[],renders=[],mirrorWrites=[];let session='A',release,atGate=false,active=0,maxActive=0;const gate=new Promise(r=>release=r);
 const state={date:'2026-10-13',...Object.fromEntries(['cash','wealth','forecast','awards','dashboardReport','planningUI'].map(k=>[k,{status:'idle'}]))};
 let wealthMirror=null;
 const wealth={get data(){return wealthMirror;},set data(v){wealthMirror=v;mirrorWrites.push({whileSession:session,payloadSession:v?.fromSession});}};
 const c={state,queueMicrotask,cache:new Map(),inflight:new Map(),dashboardFlight:null,dashboardSerial:0,D:{user:'A'},N:{classList:{contains:()=>false}},V:'Dashboard',day:()=> '2026-10-13',yearRange:()=>({from:'2026-01-01',to:'2026-10-13'}),arr:x=>Array.isArray(x)?x:[],finite:x=>x!==null&&x!==undefined&&x!==''&&Number.isFinite(Number(x))?Number(x):null,v168:{wealth},S:{auth:{getSession:async()=>{const captured=session;if(gatedName==='getSession'&&captured==='A'){atGate=true;await gate;}return {data:{session:captured?{access_token:captured}:null}};},onAuthStateChange:cb=>auth.push(cb)}},publishCashDiagnostic:()=>{},logError:()=>{},closeDetail:()=>{},window:{addEventListener:(name,cb)=>callbacks.set(name,cb)},render:()=>{if(c.D&&c.V==='Dashboard'){renders.push({session,cash:state.cash.data?.fromSession,wealth:state.wealth.data?.fromSession,wealthMirror:wealthMirror?.fromSession});queueMicrotask(()=>c.startDashboard(false));}},request:async(name,args,timeout,force)=>{const capturedSession=session;calls.push({name,session:capturedSession,force});active++;maxActive=Math.max(maxActive,active);if(name===gatedName&&capturedSession==='A'){atGate=true;await gate;}else await tick();active--;if(name==='lts_browser_flow_v242')return {fromSession:capturedSession,flow:{current_future:{days:[{date:'2026-10-13',fix86_columns:{saldo_apos_d0_1:1,saldo_apos_rsu:1,saldo_apos_fgts:1}}],events:[]}}};return {fromSession:capturedSession};}};
 c.window.__LTS_V227_TRANSPORT={invalidate:(notify=true)=>{if(notify)callbacks.get('lts:data-invalidated')();}};
 vm.createContext(c);vm.runInContext(extract(source,'  async function loadState(','  function cashComplete(')+'\n'+extract(source,"  S.auth.onAuthStateChange?.((event)=>",'  async function cachedFlow'),c);
 c.startDashboard(false);for(let i=0;i<20&&!atGate;i++)await tick();assert(atGate);
 session=null;c.D=null;
 if(authFirst){auth[0]('SIGNED_OUT');callbacks.get('lts:data-invalidated')();}
 else{callbacks.get('lts:data-invalidated')();auth[0]('SIGNED_OUT');}
 session='B';c.D={user:'B'};callbacks.get('lts:data-invalidated')();c.render();release();for(let i=0;i<25;i++)await tick();
 const result={gatedName,authFirst,calls,maxActive,states:Object.fromEntries(['cash','wealth','forecast','dashboardReport','planningUI'].map(k=>[k,state[k].status])),currentCash:state.cash.data?.fromSession,currentWealth:state.wealth.data?.fromSession,mirrorWrites,staleRenders:renders.filter(r=>r.session==='B'&&[r.cash,r.wealth,r.wealthMirror].includes('A'))};
 c.D=null;return result;
}
(async()=>{
 const source=fs.readFileSync(path.resolve(__dirname,'../../releases/v268/lts-v179-cash-recovery.js'),'utf8'),results=[];
 for(const n of ['lts_browser_cash_today_v242','lts_browser_wealth_detail_v242','lts_browser_flow_v242','getSession'])for(const authFirst of [false,true]){
  const r=await run(source,n,authFirst);assert.equal(r.maxActive,1);assert.equal(r.staleRenders.length,0);
  assert(!r.mirrorWrites.some(w=>w.whileSession==='B'&&w.payloadSession==='A'));
  assert(Object.values(r.states).every(s=>s==='ready'));assert.equal(r.currentCash,'B');assert.equal(r.currentWealth,'B');
  results.push({gatedName:n,authFirst,pass:true,calls:r.calls.length});
 }
 console.log(JSON.stringify({pass:true,cases:results,network_calls:0,financial_writes:0}));
})().catch(error=>{console.error(error);process.exitCode=1;});
