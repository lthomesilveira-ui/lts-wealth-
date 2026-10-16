'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const ROOT=path.resolve('releases/v280'),BASE=path.resolve('releases/v279');
const line=(s,n)=>{const v=s.split('\n').find(x=>x.includes(n));assert(v,n);return v.trim()};
const block=(s,a,b)=>{const i=s.indexOf(a),j=s.indexOf(b,i+a.length);assert(i>=0&&j>i,a);return s.slice(i,j).trim()};
const defer=()=>{let resolve,reject;return{promise:new Promise((a,b)=>{resolve=a;reject=b}),resolve:v=>resolve(v),reject:e=>reject(e)}};
const settle=async()=>{for(let i=0;i<8;i++)await new Promise(r=>setImmediate(r))};
function environment(root=ROOT){
 const a=fs.readFileSync(path.join(root,'lts-v183-v168-feedback-safe.js'),'utf8'),b=fs.readFileSync(path.join(root,'lts-v183-expense-history-candidate.js'),'utf8'),candidate=a.includes('function syncExpenseReaders()');
 const st={expense:{key:'6m',tab:'overview',token:0,data:null,context:null,error:null,loading:false,customFrom:'',customTo:''},transactions:{token:0,rows:null,loading:false,error:null},invoices:{token:0,rows:null,display:[],loading:false,error:null}};
 const state={expense:{key:'',token:0,data:null,loading:false,error:null},monthly:{key:'',token:0,data:null,loading:false,error:null,progress:''},cards:{token:0,data:null,loading:false,error:null,bank:'Todos'}};
 const calls=[],auth=[],timers=new Map();let serial=0,renders=0,day='2026-09-20';
 const request=(owner,name,args)=>{const gate=defer(),call={owner,name,args,gate,generation:ctx.BOOT?.generation};calls.push(call);return gate.promise};
 const ctx={console,Date,Promise,queueMicrotask,st,v168:st,state,D:{user:'a'},BOOT:{generation:1},V:'Despesas',CF:{kept:999},
  today:()=>day,addMonths:(iso,n)=>{const d=new Date(iso+'T12:00:00Z');d.setUTCMonth(d.getUTCMonth()+n);return d.toISOString().slice(0,10)},date:x=>x,
  arr:v=>Array.isArray(v)?v:[],num:v=>Number(v),yearOf:v=>String(v).slice(0,4),sum:xs=>xs.reduce((a,b)=>a+b,0),effectiveRows:v=>v,
  pause:async()=>{},S:{auth:{onAuthStateChange:fn=>auth.push(fn)}},
  setTimeout:(fn,ms)=>{const id=++serial;timers.set(id,{fn,ms});return id},clearTimeout:id=>timers.delete(id),
  rpc:(n,a)=>request('v168',n,a),directRpc:(n,a)=>request('v175',n,a),
  refresh:route=>{if(ctx.V===route)ctx.render()},document:{getElementById:()=>null,querySelectorAll:()=>[]},
  halfYearChunks:(from,to)=>[{from,to}],verifyPart:x=>x,mergeMonthly:xs=>xs[0],
  modal:()=>({querySelector:()=>({set innerHTML(x){calls.push({owner:'modal',html:x})}})}),loading:()=>'',esc:x=>x,money:x=>x,kpi:()=>'',errorBox:x=>x,
  showInvoiceDetail:()=>calls.push({owner:'detail-ui'}),toast2:()=>calls.push({owner:'toast'}),cardAccount:()=>''};ctx.window=ctx;vm.createContext(ctx);
 const helpers=candidate?block(a,'    // Keep editor-only values','    async function expenseContextWithinBudget'):'';
 vm.runInContext(`(()=>{
 ${line(a,'function expenseRange(key)')}
 ${line(a,'function expenseRangeError(r)')}
 ${helpers}
 ${line(a,'async function rpcRead(')}
 ${line(a,'async function expenseContextWithinBudget(')}
 ${line(a,'async function ensureExpense(force)')}
 ${line(a,'async function ensureTransactions(force)')}
 ${line(a,'async function ensureInvoices(force)')}
 ${line(a,'async function openInvoiceDetail(')}
 ${line(a,'async function openExpenseDrilldown(')}
 globalThis.reader168={expense:ensureExpense,transactions:ensureTransactions,invoices:ensureInvoices,detail:openInvoiceDetail,drill:openExpenseDrilldown};
 ${candidate?'globalThis.sync168=syncExpenseReaders;':''}
 })();`,ctx,{filename:'V168-real-readers'});
 vm.runInContext(`(()=>{
 ${block(b,'function expenseRange(){','async function directRpc(')}
 ${block(b,'function currentRead(','async function ensureMonthly(')}
 ${block(b,'async function ensureMonthly(','\n    S.rpc=')}
 globalThis.reader175={expense:ensureExpense,monthly:ensureMonthly,cards:ensureCards};
 ${candidate?'globalThis.sync175=syncExpenseReaders;':''}
 })();`,ctx,{filename:'V175-real-readers'});
 ctx.render=()=>{if(candidate){ctx.sync175();ctx.sync168()}renders++};
 const begin=name=>{const [owner,key]=name.split('.');return ctx[owner][key](false)};
 const slot=name=>{const [owner,key]=name.split('.');return (owner==='reader168'?st:state)[key]};
 const payload=(call,tag)=>call.owner==='v168'?{tag,rows:[{tag}]}:{data:{tag,months:['2026-09-01'],revenue_groups:[],extraordinary_groups:[],expense_groups:[]}};
 const release=(set,tag,error=false)=>{for(const call of set){if(error)call.gate.reject(Error(tag));else call.gate.resolve(payload(call,tag))}};
 const session=(signedOut=false)=>{ctx.BOOT.generation++;ctx.D=signedOut?null:{user:'b'};ctx.render()};
 return{ctx,st,state,calls,begin,slot,release,session,renders:()=>renders,auth:e=>auth.forEach(f=>f(e)),setDay:d=>day=d};
}
const names=['reader168.expense','reader168.transactions','reader168.invoices','reader175.expense','reader175.monthly','reader175.cards'];
const results=[];async function test(name,fn){await fn();results.push({test:name,result:'PASS'});console.log('PASS '+name)}
async function main(){
 for(const name of ['reader168.expense','reader175.expense'])await test('V279 counterproof applies old session response: '+name,async()=>{const e=environment(BASE),flight=e.begin(name);const calls=[...e.calls];e.session();e.release(calls,'old');await flight;assert.equal(e.slot(name).data.tag,'old')});
 for(const name of names){
  await test('old success after logout has no store/finally/render effect: '+name,async()=>{const e=environment(),flight=e.begin(name),calls=[...e.calls];e.session(true);const s=e.slot(name),before=JSON.stringify(s),renders=e.renders();e.release(calls,'old-success');await flight;await settle();assert.equal(JSON.stringify(s),before);assert.equal(e.renders(),renders);assert.equal(e.calls.length,calls.length);assert.equal(s.loading,false);await e.begin(name);assert.equal(e.calls.length,calls.length)});
  await test('old error cannot clear new loading; new session succeeds once: '+name,async()=>{const e=environment(),old=e.begin(name),calls=[...e.calls];e.session();const fresh=e.begin(name),newCalls=e.calls.slice(calls.length);assert(newCalls.length>0);const s=e.slot(name),before=JSON.stringify(s),renders=e.renders();assert.equal(s.loading,true);e.release(calls,'old-error',true);await old;await settle();assert.equal(JSON.stringify(s),before);assert.equal(e.renders(),renders);assert.equal(e.calls.length,calls.length+newCalls.length);e.release(newCalls,'new-success');await fresh;assert.equal(s.loading,false);assert.equal((s.data||s.rows?.[0]).tag,'new-success');await e.begin(name);assert.equal(e.calls.length,calls.length+newCalls.length)});
  await test('old error after logout does not write error or render: '+name,async()=>{const e=environment(),flight=e.begin(name),calls=[...e.calls];e.session(true);const before=JSON.stringify(e.slot(name)),renders=e.renders();e.release(calls,'old-error',true);await flight;await settle();assert.equal(JSON.stringify(e.slot(name)),before);assert.equal(e.renders(),renders);assert.equal(e.calls.length,calls.length)});
  await test('old success after new data cannot overwrite current session: '+name,async()=>{const e=environment(),old=e.begin(name),oldCalls=[...e.calls];e.session();const fresh=e.begin(name),newCalls=e.calls.slice(oldCalls.length);e.release(newCalls,'current-session');await fresh;const before=JSON.stringify(e.slot(name)),renders=e.renders();e.release(oldCalls,'old-success');await old;assert.equal(JSON.stringify(e.slot(name)),before);assert.equal(e.renders(),renders);assert.equal(e.calls.length,oldCalls.length+newCalls.length)});
  await test('current session error remains visible with bounded legacy retry: '+name,async()=>{const e=environment();let done=false;const flight=e.begin(name).finally(()=>done=true),released=new Set();for(let i=0;i<5&&!done;i++){const batch=e.calls.filter(c=>!released.has(c));batch.forEach(c=>released.add(c));e.release(batch,'current-error',true);await settle()}await flight;const s=e.slot(name);assert.equal(s.loading,false);assert.equal(s.error,'current-error');assert.equal(e.calls.length,name==='reader168.expense'?2:['reader168.transactions','reader168.invoices'].includes(name)?3:1);const count=e.calls.length;const [owner,key]=name.split('.');const retry=e.ctx[owner][key](true);await settle();const next=e.calls.slice(count);assert(next.length>0);e.release(next,'current-retry');await retry;assert.equal(s.loading,false);assert.equal((s.data||s.rows?.[0]).tag,'current-retry')});
  await test('slot replacement retires old callbacks: '+name,async()=>{const e=environment(),flight=e.begin(name),calls=[...e.calls],old=e.slot(name),[owner,key]=name.split('.');(owner==='reader168'?e.st:e.state)[key]={...old,loading:true,data:{tag:'replacement'},rows:[{tag:'replacement'}]};const replacement=e.slot(name),before=JSON.stringify([old,replacement]),renders=e.renders();e.release(calls,'old');await flight;assert.equal(JSON.stringify([old,replacement]),before);assert.equal(e.renders(),renders)});
 }
 await test('same generation day rollover does not retire slots or draft session ownership',async()=>{const e=environment();e.st.expense.key='custom';e.st.expense.customFrom='2026-08-01';e.st.expense.customTo='2026-08-31';const flight=e.begin('reader175.expense'),s=e.state.expense,token=s.token;e.setDay('2026-09-21');e.ctx.render();assert.equal(s.token,token);assert.equal(s.loading,true);e.release(e.calls,'day-control');await flight;assert.equal(s.data.tag,'day-control')});
 await test('fallback D identity and auth epoch retire only expense family',async()=>{for(const mode of ['fallback','auth']){const e=environment();e.st.wealth={data:{kept:true},loading:true};if(mode==='fallback'){delete e.ctx.BOOT;e.ctx.render()}const flight=e.begin('reader175.expense'),old=[...e.calls];if(mode==='fallback')e.ctx.D={user:'new'};else e.auth('SIGNED_OUT');e.ctx.render();const before=JSON.stringify(e.state),renders=e.renders();e.release(old,'old');await flight;assert.equal(JSON.stringify(e.state),before);assert.equal(e.renders(),renders);assert.deepEqual(e.st.wealth,{data:{kept:true},loading:true});assert.deepEqual(e.ctx.CF,{kept:999})}});
 await test('pending invoice detail and expense drilldown do not paint/toast after session change',async()=>{for(const type of ['detail','drill'])for(const error of [false,true]){const e=environment(),button={disabled:false,textContent:'Open'};const flight=type==='detail'?e.ctx.reader168.detail({date:'2026-09-01',amount:1,description:'x'},button):e.ctx.reader168.drill({label:'x',dimension:'category',key:'x'});const old=[...e.calls];e.session();const before=JSON.stringify(button),count=e.calls.length;e.release(old,'old',error);await flight;assert.equal(e.calls.length,count);assert.equal(JSON.stringify(button),before)}});
 // Real directRpc body: both auth and response decoding are held independently.
 for(const stage of ['auth','body'])await test('V175 directRpc guards session after '+stage+' await',async()=>{const b=fs.readFileSync(path.join(ROOT,'lts-v183-expense-history-candidate.js'),'utf8'),auth=defer(),body=defer(),calls=[];const ctx={D:{user:'a'},BOOT:{generation:1},S:{auth:{onAuthStateChange(){},getSession:()=>auth.promise}},state:{},AbortController,Promise,Date,setTimeout:()=>1,clearTimeout(){},K:'synthetic',U:'https://example.invalid',fetch:async()=>{calls.push('fetch');return{ok:true,json:()=>body.promise}}};ctx.window=ctx;vm.createContext(ctx);vm.runInContext(`(()=>{${block(b,'    let expenseReadEpoch=0;','    function yearChunks(')}globalThis.read=directRpc;})();`,ctx);const flight=ctx.read('test',{});if(stage==='auth'){ctx.BOOT.generation++;auth.resolve({data:{session:{access_token:'synthetic'}}})}else{auth.resolve({data:{session:{access_token:'synthetic'}}});await settle();ctx.BOOT.generation++;body.resolve({tag:'old'})}const out=await flight;assert.equal(out.data,null);assert.match(out.error.message,/outra sessão/);assert.equal(calls.length,stage==='auth'?0:1)});
 const out={passed:results.length,results,scope:'Real expense reader/guard functions; controlled promises and parser fixtures, no network/browser',hashes:Object.fromEntries(['lts-v183-v168-feedback-safe.js','lts-v183-expense-history-candidate.js'].map(f=>[f,crypto.createHash('sha256').update(fs.readFileSync(path.join(ROOT,f))).digest('hex')]))};fs.writeFileSync('qa/v280-reader-session-results.json',JSON.stringify(out,null,2)+'\n');
}
module.exports={environment,settle,defer,names};if(require.main===module)main().catch(e=>{console.error(e);process.exitCode=1});
