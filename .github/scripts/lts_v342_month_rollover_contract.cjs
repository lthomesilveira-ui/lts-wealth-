'use strict';
// Execute the actual month component and model with synthetic data and clocks.
// Browser layout and the financial interface are checked separately in CI.
const vm=require('node:vm'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const release=process.env.LTS_RELEASE||'v342',expectStale=process.env.LTS_EXPECT_STALE_MONTH==='true';
assert(['v341','v342','v344','v346','v352','v353','v356','v359','v365','v368'].includes(release));
const model=require('../../releases/'+release+'/lts-v337-month-model.js');
const source=fs.readFileSync(path.join('releases',release,'lts-v337-month-overview.js'),'utf8');
const turn=()=>new Promise(resolve=>setImmediate(resolve));
async function settle(h,month){for(let i=0;i<100;i++){await turn();const s=h.state();if(s?.status==='ready'&&(!month||s.data?.month===month))return;}throw Error('Monthly fixture did not settle: '+JSON.stringify(h.state()));}
function harness(start='2026-10-31T23:59:00-03:00'){
 let clock=Date.parse(start),generation=1,holdNext=false,pending=[],section=null;
 const calls=[],painted=[],listeners=new Map(),auth=[];
 const NativeDate=Date,ClockDate=class extends NativeDate{constructor(...args){super(...(args.length?args:[clock]));}static now(){return clock;}};
 const control={value:'',onchange:null};
 const doc={head:{appendChild(node){if(node.tagName==='SCRIPT')vm.runInContext(node.textContent,frame);return node;}},
  getElementById(id){return id==='v337Overview'?section:null;},
  createElement(tag){if(tag==='section')return {id:'',className:'',setAttribute(){},remove(){section=null;},querySelector(q){return q==='[aria-label="Mês do resumo"]'?control:null;},set innerHTML(s){painted.push(s);this.html=s;control.value=s.match(/max="[^"]*" value="([^"]*)"/)?.[1]||'';},get innerHTML(){return this.html||'';}};return {tagName:tag.toUpperCase(),textContent:'',id:''};},
  querySelector(q){return q==='.v168-dashboard'?root:null;}};
 const root={querySelector(q){if(q==='#v337Overview')return section;if(q==='.v168-grid.two'||q==='.v168-kpis')return {before(node){section=node;},after(node){section=node;}};return null;}};
 function result(args,override){
  const month=args.p_from.slice(0,7),revenue=override??(month==='2026-11'?211:111),expenses=10;
  const row={month:month+'-01',revenue,extraordinary:0,expenses,cash_after_extraordinary:revenue-expenses};
  return {data:{window_integrity:{from:args.p_from,to:args.p_to},monthly_totals:[row],totals:{...row}}};
 }
 const parent={LTSV337Month:model};
 const win={parent,addEventListener(name,fn){if(!listeners.has(name))listeners.set(name,[]);listeners.get(name).push(fn);},__LTS_V312_CARD_REVIEW:{},__LTS_V227_TRANSPORT:{invalidate(){}},__LTS_V178_STATE:{}};
 const sandbox={window:win,document:doc,Date:ClockDate,Intl,console,queueMicrotask,setTimeout,clearTimeout,BOOT:{get generation(){return generation;}},D:{},N:{classList:{contains(){return false;}}},V:'Dashboard',render(){},S:{rpc(name,args){assert.equal(name,'lts_browser_monthly_v229');calls.push({...args});if(holdNext){holdNext=false;return new Promise(resolve=>pending.push({resolve,args}));}return Promise.resolve(result(args));},auth:{onAuthStateChange(fn){auth.push(fn);}}}};
 const frame=vm.createContext(sandbox);win.__LTS_V337_MONTH=undefined;
 const shell={contentWindow:win,contentDocument:doc,addEventListener(){}};
 const outerDoc={getElementById(id){return id==='shell'?shell:null;}};
 const outer=vm.createContext({window:parent,document:outerDoc,setTimeout,console});
 vm.runInContext(source,outer);
 return {calls,painted,state:()=>win.__LTS_V337_MONTH?.state,control,
  clock(value){clock=Date.parse(value);},
  invalidate(){for(const fn of listeners.get('lts:data-invalidated')||[])fn();},
  choose(month){control.value=month;assert.equal(typeof control.onchange,'function');control.onchange();},
  hold(){holdNext=true;},release(override){for(const x of pending.splice(0))x.resolve(result(x.args,override));},
  async pending(){for(let i=0;i<100;i++){await turn();if(pending.length)return;}throw Error('No pending monthly read');},
  auth(event){for(const fn of auth)fn(event);},nextGeneration(){generation++;},render(){sandbox.render();}};
}
(async()=>{
 const h=harness();await settle(h,'2026-10');
 assert.equal(h.control.value,'2026-10');
 h.clock('2026-11-01T00:01:00-03:00');h.invalidate();await settle(h);
 if(expectStale){
  assert.equal(h.state().day,'2026-11-01');assert.equal(h.state().month,'2026-10');
  assert.equal(h.calls.at(-1).p_from,'2026-10-01');assert.equal(h.calls.at(-1).p_to,'2026-10-31');
  console.log(JSON.stringify({pass:true,release,old_month_reproduced:true,business_day:h.state().day,observed_month:h.control.value,expected_default_month:'2026-11',old_month_request:h.calls.at(-1)}));return;
 }
 assert.equal(h.state().month,'2026-11');assert.equal(h.control.value,'2026-11');
 assert.equal(h.state().data.to,'2026-11-01');assert.equal(h.state().data.entries,211);
 h.choose('2026-09');await settle(h,'2026-09');h.clock('2026-12-01T00:01:00-03:00');h.invalidate();await settle(h,'2026-09');
 assert.equal(h.control.value,'2026-09');assert.equal(h.state().data.to,'2026-09-30');
 h.choose('2026-12');await settle(h,'2026-12');h.clock('2027-01-01T00:01:00-03:00');h.invalidate();await settle(h,'2027-01');
 assert.equal(h.control.value,'2027-01');assert.equal(h.state().data.from,'2027-01-01');assert.equal(h.state().data.to,'2027-01-01');
 const local=harness('2026-10-31T23:59:00Z');await settle(local,'2026-10');local.clock('2026-11-01T00:01:00Z');local.invalidate();await settle(local,'2026-10');
 assert.equal(local.state().day,'2026-10-31');assert.equal(local.state().data.to,'2026-10-31');
 const day=harness('2026-10-30T23:59:00-03:00');await settle(day,'2026-10');day.clock('2026-10-31T00:01:00-03:00');day.invalidate();await settle(day,'2026-10');assert.equal(day.state().data.to,'2026-10-31');
 const late=harness();await settle(late,'2026-10');late.hold();late.invalidate();await late.pending();late.clock('2026-11-01T00:01:00-03:00');late.invalidate();await settle(late,'2026-11');late.release(777);await turn();await turn();
 assert.equal(late.state().data.month,'2026-11');assert.equal(late.state().data.entries,211);assert(!late.painted.some(x=>x.includes('777,00')),'Old response never appears');
 const session=harness();await settle(session,'2026-10');session.choose('2026-09');await settle(session,'2026-09');session.hold();session.invalidate();await session.pending();session.auth('SIGNED_OUT');session.clock('2026-11-01T00:01:00-03:00');session.nextGeneration();session.auth('SIGNED_IN');session.render();await settle(session,'2026-11');session.release(777);await turn();await turn();
 assert.equal(session.control.value,'2026-11');assert.equal(session.state().data.entries,211);assert(!session.painted.some(x=>x.includes('777,00')));
 console.log(JSON.stringify({pass:true,release,default_follows_sao_paulo_month:true,historical_choice_preserved:true,current_month_selection_resumes_following:true,year_boundary:true,utc_midnight_is_not_local_midnight:true,same_month_day_boundary:true,late_previous_month_rejected:true,new_session_resets_default:true,production_calls:false}));
})().catch(e=>{console.error(e);process.exitCode=1;});
