'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const priority=require('../../releases/v441/lts-v384-read-priority.js');
async function run(){
 const starts=[],held=[],events=[];let active=0,max=0,invalidations=0;
 const inner={parent:{LTSV384ReadPriority:priority},dispatchEvent:e=>{if(e.type==='lts:data-invalidated')invalidations++;},fetch:async(url,init)=>{active++;max=Math.max(max,active);starts.push(url.split('/').pop());await new Promise(r=>held.push(r));active--;return new Response('{}');}};inner.window=inner;inner.V='Fluxo Diário';inner.location={pathname:'/releases/v441/index.html'};
 let context;const doc={head:{appendChild:n=>vm.runInContext(n.textContent,context)},documentElement:{setAttribute:(k,v)=>events.push(JSON.parse(v))},getElementById:()=>null,createElement:()=>({})};inner.document=doc;
 context=vm.createContext({...inner,Headers,Response,AbortController,Event,performance,setTimeout,clearTimeout});
 const shell={contentWindow:inner,contentDocument:doc,addEventListener(){}};vm.runInNewContext(fs.readFileSync('releases/v441/lts-v227-read-transport.js','utf8'),{window:{},document:{getElementById:()=>shell},setTimeout,clearTimeout});
 const request=(name,cb)=>context.window.fetch('https://fixture.invalid/rest/v1/rpc/'+name,{method:'POST',headers:{Authorization:'synthetic-only'},body:'{}',ltsOnReadStart:cb});
 const tick=()=>new Promise(r=>setTimeout(r,60));
 let admitted=0;const flow=request('lts_browser_flow_v185');await tick();const review=request('lts_browser_card_review_queue_v312'),product=request('lts_browser_product_v1',()=>admitted++);assert.equal(admitted,0);held.shift()();await tick();assert.equal(starts[1],'lts_browser_product_v1');assert.equal(admitted,1);held.shift()();await tick();assert.equal(starts[2],'lts_browser_card_review_queue_v312');held.shift()();await Promise.all([flow,review,product]);assert.equal(max,1);
 for(const route of ['Dashboard','Fluxo Diário','Atualizações','Despesas'])assert.equal(priority.forRoute('lts_browser_product_v1',route),-3);
 const first=request('lts_browser_budget_read_v441');await tick();held.shift()();await first;const revision=context.window.__LTS_V227_TRANSPORT.revision;
 const save=request('lts_browser_budget_save_v441');await tick();held.shift()();await save;assert.equal(invalidations,0);assert.equal(context.window.__LTS_V227_TRANSPORT.revision,revision);
 const second=request('lts_browser_budget_read_v441');await tick();assert.equal(starts.filter(x=>x==='lts_browser_budget_read_v441').length,2,'Budget reads cannot reuse pre-save response');held.shift()();await second;
 console.log(JSON.stringify({pass:true,actual_transport:true,one_heavy_read:true,product_priority:true,deadline_callback_on_admission:true,budget_save_preserves_financial_caches:true,budget_read_fresh_after_save:true}));
}
run().catch(e=>{console.error(e);process.exitCode=1;});
