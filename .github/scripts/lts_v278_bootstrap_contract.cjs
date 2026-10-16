'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const assetPath=path.resolve(process.argv[2]||'releases/v278/lts-v225-open-finance.js');
const source=fs.readFileSync(assetPath,'utf8');
function extract(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i,'exact source boundary: '+a+' → '+b);return s.slice(i,j)}
// Use the real V278 state, model and session guards. Only the environment side effects are synthetic.
const initial=extract(source,'    const state =','    window.__LTS_V225 = state;');
const dependencies=extract(source,'    // BEGIN PURE FRESHNESS MODEL:','    const previousRender = render;');
const read=extract(source,'    async function readStatus()','    async function refreshScreens()');
const refresh=extract(source,'    async function refresh(force)','    const brl=');
const clear=extract(source,'    function clearSession()','    function after()');
const after=extract(source,'    function after()','    render=function()');
const fix='queueMicrotask(async()=>{if(!signedIn())return;await readStatus();await refresh(false);});';assert(after.includes(fix),'initial status read precedes refresh request');
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function setup(body,options={}){
 const calls=[],paints=[],tasks=[],timers=[];
 const c={calls,paints,V:'Dashboard',loggedIn:true,statusTimer:null,BOOT:{generation:1},D:{synthetic:'product'},Date,Intl,Map,Set,Number,
  sessionStorage:{getItem:()=>null,setItem:()=>{}},clearTimeout:()=>{},signedIn:()=>c.loggedIn,
  paint:()=>paints.push({view:c.V,status:c.testState.status}),paintPending:()=>{},watch:()=>{c.statusTimer=1;timers.push(60000)},queueMicrotask:f=>tasks.push(f),
  window:{__LTS_V178_REVIEW:{ready:async()=>{}}},refreshScreens:()=>{},poll:()=>{throw Error('unexpected poll after failed refresh')},
  rpc:async name=>{calls.push(name);if(name.endsWith('status_v1'))return options.statusPromise?await options.statusPromise:(options.status||{connections:[{id:'synthetic-connection',provider:'synthetic-provider',institution_code:'341',last_success_at:'2026-09-20T12:15:00Z',provider_item_updated_at:'2026-09-19T18:00:00Z'}]});if(options.refreshPromise)return await options.refreshPromise;throw Error('503 synthetic collection failure')}};
 vm.createContext(c);vm.runInContext(initial+dependencies+read+refresh+clear+body+'\nthis.testState=state;this.start=after;this.manual=refresh;',c,{filename:assetPath+'#bootstrap-contract'});
 return {c,state:c.testState,calls,paints,tasks,timers};
}
(async()=>{
 let cases=0;
 // Keep the original negative control: the old bootstrap fails to show received status on refresh failure.
 const old=setup(after.replace(fix,'queueMicrotask(()=>refresh(false));'));old.c.start();await old.tasks.shift()();assert.equal(old.state.status,null);assert.deepEqual(old.calls,['lts_browser_open_finance_refresh_v1']);cases++;
 const good=setup(after);good.c.start();await good.tasks.shift()();assert.equal(good.state.status.connections.length,1);assert.match(good.state.error,/solicitar a coleta/);assert.deepEqual(good.calls,['lts_browser_open_finance_status_v1','lts_browser_open_finance_refresh_v1']);assert.deepEqual(good.timers,[60000]);cases++;
 good.c.start();good.c.start();assert.equal(good.tasks.length,0,'rerender does not repeat initial request');cases++;
 const empty=setup(after,{status:{connections:[]}});empty.c.start();await empty.tasks.shift()();assert.equal(empty.state.status.connections.length,0);assert.match(empty.state.error,/coleta/);cases++;
 const absent=setup(after,{statusPromise:Promise.reject(Error('503 status unavailable'))});absent.c.start();await absent.tasks.shift()();assert.equal(absent.state.status,null);assert.equal(absent.state.loading,false);cases++;
 let reject;const promise=new Promise((_,r)=>reject=r);const repeat=setup(after,{refreshPromise:promise});const first=repeat.c.manual(true);await tick();await repeat.c.manual(true);assert.deepEqual(repeat.calls,['lts_browser_open_finance_refresh_v1']);reject(Error('503'));await first;cases++;
 let resolve;const delayed=setup(after,{statusPromise:new Promise(r=>resolve=r)});delayed.c.start();const loading=delayed.tasks.shift()();delayed.c.V='Atualizações';const before=delayed.paints.length;resolve({connections:[]});await loading;assert(delayed.paints.slice(before).every(x=>x.view==='Atualizações'),'late response paints only current route');cases++;
 const gone=setup(after);gone.c.start();gone.c.loggedIn=false;await gone.tasks.shift()();assert.equal(gone.calls.length,0,'logout before microtask prevents request');cases++;
 assert.equal(cases,8,'all eight inherited behavioral cases are preserved');
 console.log(JSON.stringify({passed:cases,negativeOldBootstrapReproduced:true,asset_sha256:crypto.createHash('sha256').update(source).digest('hex'),scope:'Exact V278 state, freshness/session dependencies, readStatus/refresh/clearSession/after; synthetic RPC, paint and timers; all eight inherited behaviors preserved'}));
})().catch(e=>{console.error(e);process.exitCode=1});
