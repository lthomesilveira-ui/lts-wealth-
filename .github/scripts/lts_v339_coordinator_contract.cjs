'use strict';
const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
const source=fs.readFileSync('releases/v339/lts-v339-component-boot.js','utf8');
async function fixture(){
 const listeners={},observers=[],microtasks=[];let doc={head:{name:'first'}};
 const shell={contentWindow:{location:{pathname:'/releases/v339/index.html'}},get contentDocument(){return doc;},addEventListener(name,fn){listeners[name]=fn;}};
 class Observer{constructor(callback){this.callback=callback;this.active=false;observers.push(this);}observe(target,options){assert.equal(options.childList,true);assert.equal(options.subtree,undefined);this.target=target;this.active=true;}disconnect(){this.active=false;}}
 const window={};vm.runInNewContext(source,{window,document:{getElementById:()=>shell},MutationObserver:Observer,queueMicrotask:fn=>microtasks.push(fn),Map,Object,String});
 const drain=()=>{let n=0;while(microtasks.length){assert(++n<1000,'No self-sustaining scheduling loop');microtasks.shift()();}};
 const mutation=()=>{for(const o of observers.filter(x=>x.active))o.callback([]);drain();};
 return{api:window.LTSV339Boot,drain,mutation,reload(){doc={head:{name:'second'}};listeners.load();drain();},active:()=>observers.filter(x=>x.active).length};
}
(async()=>{
 const f=await fixture();let dependency=false,firstCalls=0,secondCalls=0,thirdCalls=0;
 f.api.watch('late-parent',()=>{firstCalls++;return dependency;});
 f.api.watch('child',()=>{secondCalls++;return dependency;});f.drain();
 assert.equal(firstCalls,1);assert.equal(secondCalls,1);assert.equal(f.active(),1,'One head observer covers all pending modules');
 f.drain();assert.equal(firstCalls,1,'No permanent timer/polling loop');
 dependency=true;f.mutation();assert.equal(firstCalls,2);assert.equal(secondCalls,2);assert.equal(f.active(),0,'Disconnect after ready');
 f.mutation();assert.equal(firstCalls,2,'Ready component is never reinstalled on later mutations');
 f.api.watch('third',()=>{thirdCalls++;return true;});f.drain();assert.equal(thirdCalls,1);assert.equal(f.active(),0);
 f.api.watch('third',()=>{throw Error('duplicate registration');});f.drain();assert.equal(thirdCalls,1);
 f.reload();assert.equal(firstCalls,3);assert.equal(secondCalls,3);assert.equal(thirdCalls,2);assert.equal(f.api.snapshot().epoch,2,'Document replacement rearms each module once');
 const failed=await fixture();let calls=0;failed.api.watch('broken',()=>{calls++;throw Error('synthetic install failure');});failed.drain();
 for(let i=0;i<200;i++)failed.mutation();assert.equal(calls,128,'A failed component has a finite attempt budget');assert.equal(failed.active(),0);assert.equal(failed.api.snapshot().components[0].exhausted,true);
 const unsigned=await fixture();unsigned.api.watch('not-ready',()=>undefined);unsigned.drain();assert.equal(unsigned.api.snapshot().components[0].ready,false,'Undefined cannot certify successful initialization');
 assert(!/\bfetch\s*\(|setInterval\s*\(|setTimeout\s*\(|localStorage|sessionStorage|\.rpc\s*\(/.test(source),'Coordinator has no data reads, auth storage or timer polling');
 console.log(JSON.stringify({pass:true,late_dependency:true,one_head_observer:true,no_polling:true,disconnect_after_ready:true,document_replacement:true,finite_attempts:true,no_financial_or_auth_operations:true}));
})().catch(e=>{console.error(e);process.exitCode=1;});
