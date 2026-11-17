'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const turn=()=>new Promise(setImmediate);
const connection=time=>({connections:[{id:'synthetic-bank',provider:'fixture',institution_code:'341',last_success_at:time}]});
function harness({active=true,pending=false,install=false,waiting=false,view='Dashboard'}={}){
 const source=fs.readFileSync('releases/v458/lts-v225-open-finance.js','utf8');
 const runtime=source.slice(source.indexOf('  function runtime() {'),source.indexOf('  let attempts=0;'));
 let answer;const calls=[],timers=new Map(),events=new Map();let id=0;
 const transport={revision:5,invalidate(){this.revision++;calls.push('invalidate')}};
 const report={data:{amount:123.45},key:'verified',token:1};
 const context={Date,Intl,Map,Set,Promise,Number,JSON,console,BOOT:{generation:1},D:{cash:123.45},FLOWLOADING:true,V:view,
  N:{classList:{contains:()=>false}},render(){calls.push('render')},sessionStorage:{getItem:()=>Date.now()},
  setTimeout:(fn,ms)=>{timers.set(++id,{fn,ms});return id},clearTimeout:i=>timers.delete(i),queueMicrotask(){},
  document:{hidden:true,querySelector:()=>null,querySelectorAll:()=>[],getElementById:()=>null,addEventListener(){}},
  S:{rpc:async()=>({data:connection('2026-11-17T11:00:00Z')}),auth:{onAuthStateChange(){}}},
  __LTS_V227_TRANSPORT:transport,__LTS_V172_STATE:{flowSequence:9},__LTS_V175_STATE:{expense:report},
  __LTS_V181_STATE:{review:{status:'ready',data:{amount:123.45},key:'verified'}},__LTS_V168_STATE:{updates:{}},
  __LTS_V226:{invalidate(){calls.push('cards.invalidate')},refresh(){calls.push('cards.refresh');transport.invalidate()}},
  __LTS_V178_REVIEW:{refreshCashOnly:async force=>calls.push('cash:'+!!force),refresh:async options=>calls.push('reports:'+options.alreadyInvalidated)},
  addEventListener:(name,fn)=>events.set(name,fn)};
 context.window=context;
 context.__LTS_V415_REFRESH={snapshot:()=>({active,pending}),poll:async()=>{calls.push('status');if(waiting)await new Promise(resolve=>answer=resolve);if(install)transport.invalidate()}};
 vm.createContext(context);vm.runInContext('('+runtime.trim()+')();',context);
 context.__LTS_V225.status=connection('2026-11-17T10:00:00Z');
 return{context,calls,report,transport,answer:()=>answer?.(),async changed(){await context.__LTS_V225.readStatus();await turn()}};
}
for(const view of ['Dashboard','Fluxo Diário'])test(view+' collection keeps verified heavy reports while the existing job is pending',async()=>{
 const h=harness({pending:true,view});await h.changed();
 assert.deepEqual(h.calls,['status','cash:true','render']);assert.deepEqual(h.report.data,{amount:123.45});
 assert.equal(h.report.key,'verified');assert.equal(h.transport.revision,5);
 assert.equal(h.context.__LTS_V172_STATE.flowSequence,9);
 assert.equal(h.context.__LTS_V181_STATE.review.status,'ready');
});
test('a product installed during the check owns invalidation exactly once',async()=>{
 const h=harness({install:true});await h.changed();
 assert.deepEqual(h.calls,['status','invalidate','cash:true','render']);
 assert.deepEqual(h.report.data,{amount:123.45});assert.equal(h.transport.revision,6);
});
test('ready unchanged product retains one legacy report refresh',async()=>{
 const h=harness();await h.changed();
 assert.deepEqual(h.calls,['status','cards.invalidate','cards.refresh','invalidate','reports:true','render']);
 assert.equal(h.transport.revision,6);assert.equal(h.report.data,null);assert.equal(h.report.token,2);
});
test('an absent or inactive controller preserves the previous compatibility path',async()=>{
 for(const absent of [false,true]){const h=harness({active:false});if(absent)delete h.context.__LTS_V415_REFRESH;await h.changed();
  assert.deepEqual(h.calls,['cards.invalidate','cards.refresh','invalidate','reports:true','render']);}
});
test('a bank status response from a prior owner cannot clear the new owner reports',async()=>{
 const h=harness({pending:true,waiting:true});await h.changed();
 h.context.BOOT.generation++;h.answer();await turn();
 assert.deepEqual(h.calls,['status']);assert.deepEqual(h.report.data,{amount:123.45});assert.equal(h.transport.revision,5);
});
