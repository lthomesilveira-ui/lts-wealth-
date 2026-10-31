'use strict';
process.env.LTS_FLOW_RELEASE='v384';
const {setup,geometry,snapshot}=require('./lts_v382_browser.cjs'),{webkit,chromium}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs'),crypto=require('node:crypto');
const base='http://127.0.0.1:8788',out='qa/v384-performance';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
// Fixed, identical latency on static resources; browser timings remain real.
// RPC delays are 1/10 of the observed upstream means, rounded by reader family.
const rpcDelay=name=>/review_queue/.test(name)?500:/wealth_detail/.test(name)?380:/recurring_future/.test(name)?324:/monthly/.test(name)?251:/product_/.test(name)?208:/flow_v/.test(name)?218:/expenses_/.test(name)?159:/dashboard_cockpit/.test(name)?141:/card_cycles/.test(name)?103:10;
async function run(browser,engine,release,latency,width,trial){
 const h=await setup(browser,width,width===393?852:900,'2026-10-31T15:00:00Z');let frame;const requests=[],responses=[],responseJobs=[];
 h.page.on('request',r=>{if(new URL(r.url()).origin===base)requests.push({path:new URL(r.url()).pathname,type:r.resourceType()});});
 h.page.on('response',r=>{const req=r.request(),url=new URL(req.url());if(!url.pathname.startsWith('/rest/v1/rpc/'))return;responseJobs.push(r.body().then(body=>responses.push({name:url.pathname.split('/').pop(),args:req.postData(),sha256:crypto.createHash('sha256').update(body).digest('hex')})));});
 await h.ctx.route('**/*',async route=>{const req=route.request(),url=new URL(req.url());let delay=0;if(url.origin===base&&['script','stylesheet'].includes(req.resourceType()))delay=latency;else if(url.pathname.startsWith('/rest/v1/rpc/'))delay=rpcDelay(url.pathname.split('/').pop());if(delay)await new Promise(resolve=>setTimeout(resolve,delay));return route.fallback();});
 const started=performance.now();
 try{
  await h.page.goto(base+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().startsWith(base+'/releases/'+release+'/index.html'));assert(frame);
  // A useful opening has every visible financial section, cards and monthly
  // balance loaded. Measure background completion separately, without masking it
  // behind networkidle in the user-visible readiness measurement.
  await frame.waitForFunction(()=>window.__LTS_V365?.installed&&window.__LTS_V183_FLOW_PERIOD_STATE?.installed&&window.__LTS_V382_FLOW_LAYOUT?.installed&&document.body.dataset.ltsBootState==='ready'&&V==='Dashboard'&&D&&!N.classList.contains('hidden')&&window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.loaded&&!window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.loading&&['cash','forecast','wealth','awards','dashboardReport'].every(k=>window.__LTS_V178_STATE?.[k]?.status==='ready')&&window.__LTS_V337_MONTH?.state?.status==='ready'&&window.__LTS_V226?.cycles&&!window.__LTS_V226?.loading);
  const readyMs=performance.now()-started;
  await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS?.state?.data&&!window.__LTS_V296_CLASSIFICATIONS.state.loading&&window.__LTS_V312_CARD_REVIEW?.state?.data&&!window.__LTS_V312_CARD_REVIEW.state.loading);
  await h.page.waitForLoadState('networkidle');await Promise.all(responseJobs);const detailsMs=performance.now()-started;
  const initialRpc=responses.slice().sort((a,b)=>JSON.stringify(a).localeCompare(JSON.stringify(b)));
  // Connection status is deliberately uncached and its two startup consumers
  // may share an in-flight read. Collapse identical status replies only; retain
  // every financial read's multiplicity, all arguments and all response bytes.
  const seenStatus=new Set(),comparableRpc=initialRpc.filter(r=>{if(r.name!=='lts_browser_open_finance_status_v1')return true;const key=JSON.stringify(r);if(seenStatus.has(key))return false;seenStatus.add(key);return true;});
  const rpcHash=hash(comparableRpc);
  const dashboard=await frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,sourceOpen:document.querySelectorAll('.v337-source[open]').length}));assert(dashboard.scroll<=width+2);assert.equal(dashboard.sourceOpen,0);assert(!(await frame.locator('body').innerText()).includes('Obrigação mais antiga'));
  if(trial===0)await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+release+'-dashboard.png'});
  const route=frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');assert.equal(await route.count(),1);const flowStart=performance.now();await route.click();await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2026-10-26'&&FLOWQ?.to==='2030-12-31');
  const flowMs=performance.now()-flowStart,g=await geometry(frame),state=await snapshot(frame);assert(g.scroll<=width+2);assert.equal(g.visiblePresets,0);assert(g.filters.height<=118);assert.equal(await frame.locator('.v382-period[open]').count(),0);
  assert.equal(await frame.evaluate(()=>EXP.size),0,'day expansion behavior remains unchanged after owner clarification');
  const financialHash=hash(state.flow),components=await h.page.evaluate(()=>document.getElementById('shell').contentWindow.parent.LTSV339Boot.snapshot().components.map(x=>({id:x.id,ready:x.ready,exhausted:x.exhausted})).sort((a,b)=>a.id.localeCompare(b.id)));
  assert(!components.some(x=>x.exhausted),'no exhausted boot component');
  if(trial===0)await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+release+'-flow.png'});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  const startupScripts=requests.filter(x=>x.type==='script'&&x.path.startsWith('/releases/'+release+'/')&&!['index.html'].some(n=>x.path.endsWith(n)));
  return {pass:true,engine,release,latency_ms:latency,width,trial,ready_ms:Math.round(readyMs),details_ms:Math.round(detailsMs),flow_ms:Math.round(flowMs),script_requests:startupScripts.length,requests:requests.length,financial_sha256:financialHash,all_initial_rpc_sha256:rpcHash,initial_rpc_count:initialRpc.length,initial_rpc_fingerprints:initialRpc,components,synthetic_http:true,physical_iphone:false,private_session:false};
 }catch(error){if(frame)fs.writeFileSync(out+'/'+engine+'-'+release+'-failure.json',JSON.stringify({error:error.stack,state:await frame.evaluate(()=>({V,FLOWFROM,FLOWTO,FLOWLOADING,boot:document.body.dataset.ltsBootState,components:parent.LTSV339Boot?.snapshot?.()})),reads:h.reads},null,2));throw error;}finally{await h.ctx.close();}
}
const median=xs=>[...xs].sort((a,b)=>a-b)[Math.floor(xs.length/2)];
(async()=>{const results=[],summaries=[];for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{for(const latency of[0,120]){const width=latency?393:1366;for(let trial=0;trial<3;trial++){const order=trial%2?['v384','v383']:['v383','v384'];for(const release of order){const x=await run(browser,engine,release,latency,width,trial);results.push(x);console.log(JSON.stringify({...x,components:undefined}));fs.writeFileSync(out+'/result.json',JSON.stringify({pass:false,results,summaries},null,2));}}
 const old=results.filter(x=>x.engine===engine&&x.latency_ms===latency&&x.release==='v383'),now=results.filter(x=>x.engine===engine&&x.latency_ms===latency&&x.release==='v384');assert.equal(old.length,3);assert.equal(now.length,3);assert.equal(new Set([...old,...now].map(x=>x.financial_sha256)).size,1,'financial response identical');if(new Set([...old,...now].map(x=>x.all_initial_rpc_sha256)).size!==1)console.error(JSON.stringify({rpc_mismatch:true,engine,latency,runs:[...old,...now].map(x=>({release:x.release,trial:x.trial,rpc:x.initial_rpc_fingerprints}))}));assert.equal(new Set([...old,...now].map(x=>x.all_initial_rpc_sha256)).size,1,'all RPC names,parameters,responses and financial read multiplicity identical; identical uncached connection-status replies may coalesce');assert(now.every(x=>x.script_requests<Math.min(...old.map(x=>x.script_requests))-50),'at least50fewer startup script requests');const before=median(old.map(x=>x.ready_ms)),after=median(now.map(x=>x.ready_ms));
 const summary={engine,latency_ms:latency,width,before_ready_median_ms:before,after_ready_median_ms:after,reduction_pct:Math.round((1-after/before)*1000)/10,before_details_median_ms:median(old.map(x=>x.details_ms)),after_details_median_ms:median(now.map(x=>x.details_ms)),before_script_requests:median(old.map(x=>x.script_requests)),after_script_requests:median(now.map(x=>x.script_requests)),identical_financial_response:true,identical_complete_rpc_set:true};summaries.push(summary);console.log(JSON.stringify({summary}));assert(summary.after_details_median_ms<=summary.before_details_median_ms*1.1+250,'background completion does not materially regress');if(latency)assert(after<=before*.9,'useful cold opening improves by at least10% under120ms resource latency: '+JSON.stringify(summary));else assert(after<=before*1.3+200,'no substantial low-latency regression');
 }}finally{await browser.close();}}
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results,summaries,conditions:'Cold isolated contexts; fixed static latency0/120ms; mocked RPC latency1/10 observed means; useful readiness requires every visible financial section; complete background/RPC parity and completion time checked separately; real browser wall time; no production/iPhone timing claim'},null,2));})().catch(error=>{console.error(error);process.exitCode=1});
