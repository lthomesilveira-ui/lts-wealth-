'use strict';
const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const root='releases/v445/',scenario=require('../../releases/v445/'+fs.readdirSync(root).find(n=>n.startsWith('lts-v421-')));
const source=fs.readFileSync(root+'lts-v412-projection-policy.js','utf8'),start=source.indexOf('function applyHorizon()'),end=source.indexOf('function message(',start),actual=source.slice(start,end);
function harness(horizon='2031-12-31',previous=null){
 const state={model:{asOf:'2026-11-15',horizon},horizonKey:previous},dashboard={token:7,started:true,loading:true},queued=[];let refreshes=0;
 const context={state,ui:{dashboard},V:'Dashboard',window:{parent:{LTSV421Scenario:scenario}},fullRange:()=>({from:'2026-11-10',to:state.model.horizon}),queueMicrotask:f=>queued.push(f),refreshConsumers:()=>refreshes++};
 vm.createContext(context);vm.runInContext(actual+'\nthis.apply=applyHorizon;',context);
 return{state,dashboard,apply(){context.apply();for(const f of queued.splice(0))f()},get refreshes(){return refreshes}};
}
test('loading the already requested five-year policy preserves active screen owners',()=>{
 const h=harness();h.apply();assert.equal(h.state.horizonKey,'2031-12-31');assert.deepEqual(h.dashboard,{token:7,started:true,loading:true});assert.equal(h.refreshes,0);
 h.apply();assert.equal(h.refreshes,0);
});
test('a longer opening policy and later horizon change still recheck every consumer',()=>{
 const longer=harness('2032-12-31');longer.apply();assert.equal(longer.dashboard.token,8);assert.equal(longer.refreshes,1);
 const changed=harness('2032-12-31','2031-12-31');changed.apply();assert.equal(changed.dashboard.started,false);assert.equal(changed.refreshes,1);
});
test('both review loaders use the actual scenario horizon before the policy arrives',()=>{
 const s=fs.readFileSync(root+'lts-v384-startup-1.js','utf8');
 assert.equal((s.match(/p_horizon_end:window.parent.LTSV421Scenario.horizon\(today\(\),window.__LTS_V412_PROJECTION\?\.model\)/g)||[]).length,2);
 assert(!s.includes("p_horizon_end:(Number(today().slice(0,4))+(window.__LTS_V412_PROJECTION?.model?5:4))"));assert.equal(scenario.horizon('2026-11-15',null),'2031-12-31');assert.equal(scenario.horizon('2026-11-15',{asOf:'2026-11-15',horizon:'2032-12-31'}),'2032-12-31');
 assert(source.includes('if (recalculate && model)'));assert(source.includes('load(true, false).then(() => { if (state.model && state.status === \'ready\') refreshConsumers(); })'));
});
