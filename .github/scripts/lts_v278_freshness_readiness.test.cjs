'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const file=path.resolve(process.argv[2]||path.join(__dirname,'lts_freshness_fullstack.candidate.js'));
const source=fs.readFileSync(file,'utf8'),start=source.indexOf('  async function waitFreshnessDashboardReady(){'),end=source.indexOf('\n  await waitFreshnessDashboardReady();',start);
assert(start>=0&&end>start,'exact fullstack readiness helper exists');
const helper=source.slice(start,end),checks=[];
const check=(name,value)=>{assert(value,name);checks.push(name);};
const deferred=()=>{let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};};
const turn=()=>new Promise(r=>setImmediate(r));
function setup(body=helper){
 const first=deferred(),second=deferred(),waits=[],frames=[];let readyCalls=0,finished=false;
 const window={__LTS_V178_STATE:Object.fromEntries(['cash','forecast','wealth','awards','dashboardReport'].map(k=>[k,{status:['cash','forecast'].includes(k)?'ready':'loading'}])),__LTS_V225:{started:true,syncing:false,loading:false,statusRead:null},__LTS_V226:{loading:false},__LTS_V178_REVIEW:{ready:()=>++readyCalls===1?first.promise:second.promise}};
 const context={window,V:'Dashboard',Promise,requestAnimationFrame:fn=>frames.push(fn)};
 context.frame={evaluate:fn=>fn(),waitForFunction:fn=>{const d=deferred();waits.push({fn,resolve:d.resolve});return d.promise;}};
 vm.createContext(context);vm.runInContext(body+'\nthis.wait=waitFreshnessDashboardReady;',context);
 const running=context.wait().then(()=>{finished=true;});
 return {context,window,first,second,waits,frames,running,get readyCalls(){return readyCalls;},get finished(){return finished;}};
}
(async()=>{
 const gate=setup();await turn();
 check('Gate first awaits the real orchestration promise before inspecting ready flags',gate.readyCalls===1&&gate.waits.length===0&&!gate.finished);
 gate.first.resolve();await turn();const predicate=gate.waits[0].fn;
 check('Cash and forecast alone cannot pass while later required readers are loading',predicate()===false);
 for(const state of Object.values(gate.window.__LTS_V178_STATE))state.status='ready';
 check('All five required readers allow a settled dashboard',predicate()===true);
 for(const key of ['cash','forecast','wealth','awards','dashboardReport'])for(const status of ['idle','loading','error']){gate.window.__LTS_V178_STATE[key].status=status;assert.equal(predicate(),false,key+' '+status);gate.window.__LTS_V178_STATE[key].status='ready';}
 check('Every required reader blocks capture in idle, loading or failed state',true);
 for(const [key,value] of [['started',false],['syncing',true],['loading',true],['statusRead',Promise.resolve()]]){const previous=gate.window.__LTS_V225[key];gate.window.__LTS_V225[key]=value;assert.equal(Boolean(predicate()),false,key);gate.window.__LTS_V225[key]=previous;}
 gate.window.__LTS_V226.loading=true;assert.equal(predicate(),false);gate.window.__LTS_V226.loading=false;gate.context.V='Fluxo Diário';assert.equal(predicate(),false);gate.context.V='Dashboard';
 check('Collection bootstrap, in-flight status, card work and wrong route all block capture',true);
 gate.waits.shift().resolve();await turn();
 check('A queued forced refresh is awaited through the second current orchestration promise',gate.readyCalls===2&&gate.frames.length===0&&!gate.finished);
 gate.second.resolve();await turn();assert.equal(gate.frames.length,1);gate.frames.shift()();await turn();
 check('One render frame does not release capture before the queued render boundary',gate.frames.length===1&&gate.waits.length===0&&!gate.finished);
 gate.frames.shift()();await turn();
 check('Readiness is checked again after both rendering frames',gate.waits.length===1&&!gate.finished);
 gate.window.__LTS_V225.loading=true;assert.equal(gate.waits[0].fn(),false);gate.window.__LTS_V225.loading=false;assert.equal(gate.waits[0].fn(),true);gate.waits.shift().resolve();await gate.running;
 check('Capture can proceed only after final state check succeeds',gate.finished);
 // Negative control reproduces the inherited gate's missing reader dependency.
 const old=setup(helper.replaceAll("['cash','forecast','wealth','awards','dashboardReport']","['cash','forecast']"));old.first.resolve();await turn();
 check('Negative control: cash/forecast-only gate accepts the still-repainting dashboard',old.waits[0].fn()===true);
 check('New gate adds no arbitrary timeout or detached-element retry',!helper.includes('waitForTimeout')&&!helper.includes('catch(')&&!helper.includes('setTimeout'));
 const capture=source.indexOf("await captureTarget(settledFreshnessPanel,'freshness-near-balance')");
 check('Capture resolves its locator after explicit readiness, with geometry assertions retained',capture>source.indexOf("const settledFreshnessPanel=frame.locator('.v225-balance-freshness')")&&source.slice(end,capture).includes('await waitFreshnessDashboardReady();')&&source.includes('heightsWithoutPanel'));
 console.log(JSON.stringify({passed:checks.length,checks,scope:'Exact fullstack readiness helper evaluated with controlled application promises and rendering frames; negative old-gate control; no browser executed'},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
