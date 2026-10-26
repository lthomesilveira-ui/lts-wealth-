'use strict';
const vm=require('node:vm'),fs=require('node:fs'),assert=require('node:assert/strict');
async function main(){
 const RELEASE=process.env.LTS_RELEASE||'v335';assert(['v335','v337','v339','v341','v342'].includes(RELEASE));
 const calls=[],telemetry=[],heavy=/product_|dashboard_cockpit_|wealth_detail_|awards_|income_review_queue_|card_review_queue_|expense_review_queue_|flow_v|card_cycles_/;
 let active=0,maxActive=0,holdName=null,holdResolve,holdStarted,mode='normal',lightDuringHeavy=false;
 const native=async(input,init)=>{
  const name=input.split('/').pop(),isHeavy=heavy.test(name);calls.push({name,body:init.body,token:new Headers(init.headers).get('Authorization')});
  if(isHeavy){active++;maxActive=Math.max(maxActive,active);}else if(active)lightDuringHeavy=true;
  try{
   if(mode==='hang')await new Promise((_,reject)=>init.signal.addEventListener('abort',()=>reject(new DOMException('Aborted','AbortError')),{once:true}));
   else if(name===holdName){holdStarted?.();await new Promise(resolve=>holdResolve=resolve);}
   else await new Promise(resolve=>setTimeout(resolve,6));
   return new Response('{"ok":true}',{status:200});
  }finally{if(isHeavy)active--;}
 };
 const win={fetch:native,location:{pathname:'/releases/'+RELEASE+'/index.html'},dispatchEvent(){}};
 let inner;const doc={head:{appendChild(s){vm.runInContext(s.textContent,inner);}},createElement:()=>({}),documentElement:{setAttribute(k,v){telemetry.push(v);}}};
 const timer=(fn,ms)=>setTimeout(fn,ms===25000?150:ms===48000?180:ms===60000?3000:ms===30?1:ms);
 inner=vm.createContext({window:win,document:doc,Headers,Response,AbortController,DOMException,Event,performance,setTimeout:timer,clearTimeout,Map});
 const shell={contentWindow:win,contentDocument:doc,addEventListener(){}};
 vm.runInContext(fs.readFileSync('releases/'+RELEASE+'/lts-v227-read-transport.js','utf8'),vm.createContext({document:{getElementById:()=>shell},setTimeout,clearTimeout}));
 const url=name=>'https://example.invalid/rest/v1/rpc/'+name;
 const req=(body='{}',token='synthetic-a',signal)=>({method:'POST',headers:{Authorization:'Bearer '+token},body,signal});
 const names=['lts_browser_product_v1','lts_browser_dashboard_cockpit_v1','lts_browser_income_review_queue_v296','lts_browser_card_review_queue_v312','lts_browser_wealth_detail_v242','lts_browser_awards_v178','lts_browser_expense_review_queue_v229','lts_browser_flow_v242','lts_browser_card_cycles_v229'];
 await Promise.all(names.map((name,i)=>win.fetch(url(name),req(JSON.stringify({test:i})))));
 assert.equal(calls.length,names.length);assert.equal(maxActive,1,'Every guarded expensive reader must share admission');
 win.__LTS_V227_TRANSPORT.invalidate();const count=calls.length;
 const [a,b]=await Promise.all([win.fetch(url(names[2]),req()),win.fetch(url(names[2]),req())]);assert.equal(calls.length,count+1);assert.deepEqual(await a.json(),await b.json());
 await win.fetch(url(names[2]),req());assert.equal(calls.length,count+1,'Fresh identical classification read is reused');
 await win.fetch(url(names[2]),req('{}','synthetic-b'));assert.equal(calls.length,count+2,'Owners never share a cached response');
 // Keep one heavy request open while exercising independent status/cash,
 // cancellation before admission, and mutation passthrough.
 win.__LTS_V227_TRANSPORT.invalidate();holdName='lts_browser_flow_v242';
 const started=new Promise(resolve=>holdStarted=resolve),blocked=win.fetch(url(holdName),req('{"hold":true}'));
 await started;
 await Promise.all([win.fetch(url('lts_browser_cash_today_v242'),req()),win.fetch(url('lts_browser_open_finance_status_v1'),req())]);
 assert(lightDuringHeavy,'Cash and connection status must not wait for unrelated reports');
 const controller=new AbortController(),beforeAbort=calls.length;
 const queued=win.fetch(url(names[2]),req('{"cancel":true}','synthetic-a',controller.signal));controller.abort();
 await assert.rejects(queued,{name:'AbortError'});assert.equal(calls.length,beforeAbort,'Canceled queued work never reaches the API');
 const writer='lts_browser_card_review_save_v312',beforeWrites=calls.length;
 await Promise.all([win.fetch(url(writer),req()),win.fetch(url(writer),req())]);
 assert.equal(calls.length,beforeWrites+2,'Writes are neither admitted, cached nor deduplicated');
 holdResolve();await blocked;holdName=null;
 const afterInvalidation=calls.length;await win.fetch(url('lts_browser_flow_v242'),req('{"hold":true}'));
 assert.equal(calls.length,afterInvalidation+1,'A response superseded by mutation cannot populate fresh cache');
 win.__LTS_V227_TRANSPORT.invalidate();mode='hang';
 await assert.rejects(win.fetch(url(names[3]),req()),{name:'AbortError'});
 mode='normal';assert.equal((await win.fetch(url(names[3]),req())).status,200,'Timeout releases admission and permits explicit retry');
 assert.equal(maxActive,1);assert(telemetry.some(x=>x.includes('timeout')));assert(telemetry.every(x=>!x.includes('Bearer')&&!x.includes('synthetic-a')));
 console.log(JSON.stringify({pass:true,guarded_reader_kinds:names.length,max_concurrent_expensive_reads:maxActive,cash_status_independent:true,session_isolation:true,classification_dedup:true,queued_abort:true,mutations_passthrough:true,timeout_recovery:true,no_auth_in_telemetry:true}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
