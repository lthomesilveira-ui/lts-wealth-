'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(process.argv[2]||'releases/v272/lts-v225-open-finance.js','utf8');
function extract(s,a,b){const i=s.indexOf(a),j=s.indexOf(b,i);assert(i>=0&&j>i);return s.slice(i,j)}
const read=extract(source,'    async function readStatus()','    async function refreshScreens()');
const refresh=extract(source,'    async function refresh(force)','    const brl=');
const after=extract(source,'    function after()','    render=function()');
const fix='queueMicrotask(async()=>{if(!signedIn())return;await readStatus();await refresh(false);});';assert(after.includes(fix));
const tick=()=>new Promise(resolve=>setImmediate(resolve));
function setup(body,options={}){
 const state={status:null,loading:false,syncing:false,started:false,error:'',pending:{}},calls=[],paints=[],tasks=[],timers=[];
 const c={state,calls,paints,V:'Dashboard',loggedIn:true,statusTimer:null,Date,Number,sessionStorage:{getItem:()=>null,setItem:()=>{}},clearTimeout:()=>{},signedIn:()=>c.loggedIn,paint:()=>paints.push({view:c.V,status:state.status}),paintPending:()=>{},watch:()=>{c.statusTimer=1;timers.push(60000)},queueMicrotask:f=>tasks.push(f),window:{__LTS_V178_REVIEW:{ready:async()=>{}}},refreshScreens:()=>{},poll:()=>{throw Error('unexpected poll after failed refresh')},rpc:async name=>{calls.push(name);if(name.endsWith('status_v1'))return options.statusPromise?await options.statusPromise:(options.status||{connections:[{institution_code:'341',last_success_at:'2026-09-20T12:15:00Z',provider_item_updated_at:'2026-09-19T18:00:00Z'}]});if(options.refreshPromise)return await options.refreshPromise;throw Error('503 synthetic collection failure')}};
 vm.createContext(c);vm.runInContext(read+refresh+body+'\nthis.start=after;this.manual=refresh;',c);
 return {c,state,calls,paints,tasks,timers};
}
(async()=>{
 let cases=0;
 const old=setup(after.replace(fix,'queueMicrotask(()=>refresh(false));'));old.c.start();await old.tasks.shift()();assert.equal(old.state.status,null);assert.deepEqual(old.calls,['lts_browser_open_finance_refresh_v1']);cases++;
 const good=setup(after);good.c.start();await good.tasks.shift()();assert.equal(good.state.status.connections.length,1);assert.match(good.state.error,/solicitar a coleta/);assert.deepEqual(good.calls,['lts_browser_open_finance_status_v1','lts_browser_open_finance_refresh_v1']);assert.deepEqual(good.timers,[60000]);cases++;
 good.c.start();good.c.start();assert.equal(good.tasks.length,0,'rerender does not repeat initial request');cases++;
 const empty=setup(after,{status:{connections:[]}});empty.c.start();await empty.tasks.shift()();assert.equal(empty.state.status.connections.length,0);assert.match(empty.state.error,/coleta/);cases++;
 const absent=setup(after,{statusPromise:Promise.reject(Error('503 status unavailable'))});absent.c.start();await absent.tasks.shift()();assert.equal(absent.state.status,null);assert.equal(absent.state.loading,false);cases++;
 let reject;const promise=new Promise((_,r)=>reject=r);const repeat=setup(after,{refreshPromise:promise});const first=repeat.c.manual(true);await tick();await repeat.c.manual(true);assert.deepEqual(repeat.calls,['lts_browser_open_finance_refresh_v1']);reject(Error('503'));await first;cases++;
 let resolve;const delayed=setup(after,{statusPromise:new Promise(r=>resolve=r)});delayed.c.start();const loading=delayed.tasks.shift()();delayed.c.V='Atualizações';const before=delayed.paints.length;resolve({connections:[]});await loading;assert(delayed.paints.slice(before).every(x=>x.view==='Atualizações'),'late response paints only current route');cases++;
 const gone=setup(after);gone.c.start();gone.c.loggedIn=false;await gone.tasks.shift()();assert.equal(gone.calls.length,0,'logout before microtask prevents request');cases++;
 console.log(JSON.stringify({passed:cases,negativeOldBootstrapReproduced:true,scope:'exact readStatus/refresh/after; synthetic RPC, paint and timers'}));
})().catch(e=>{console.error(e);process.exitCode=1});
