'use strict';process.env.LTS_FLOW_RELEASE='v451';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');
const out='qa/v451';fs.mkdirSync(out,{recursive:true});
const state=(phase,v='2')=>({state:phase,required:phase!=='ready',cached_available:true,request_version:v,completed_version:phase==='ready'?v:'2',cached_refreshed_at:'2026-11-16T17:00:00Z'});
async function run(browser,engine,width,release){
 const h=await setup(browser,width,980,'2026-11-16T17:00:00Z'),label=release+'-'+engine+'-'+width;
 let products=0,statuses=0,armed=false,frame;const failures=new Set(),calls={};
 const send=(r,j,status=200)=>r.fulfill({status,contentType:'application/json',body:JSON.stringify(j)});
 const fail=(r,name,code)=>{calls[name]=(calls[name]||0)+1;if(armed&&!failures.has(name)){failures.add(name);return send(r,{code,message:'synthetic transient'},500)}return null};
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',r=>send(r,{ok:true,mvp:fixture.product(),refresh:state('ready',++products===1?'2':'3')}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',r=>send(r,{ok:true,refresh:state(++statuses===1?'pending':'ready','3')}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',r=>send(r,require('./lts_v441_fixture.cjs')()));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_expense_review_queue_v229',r=>{
  const error=fail(r,'expense','57014');if(error)return error;const a=JSON.parse(r.request().postData());
  return send(r,{from:a.p_from,to:a.p_to,offset:a.p_offset,row_count:0,matched_count:0,next_offset:null,rows:[]});
 });
 await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_policy_v412',r=>fail(r,'projection','55000')||send(r,fixture.response('lts_browser_projection_policy_v412',{})));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_open_finance_pending_v225',r=>fail(r,'pending','57014')||send(r,{version:'pending-expense-v225',net_expense:13.27,transaction_count:1,unclassified_count:0,rows:[]}));
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});
  await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/'+release+'/index.html'));assert(frame);
  await frame.getByRole('heading',{name:'Dashboard',exact:true}).waitFor();await h.page.waitForLoadState('networkidle');
  const financial=await frame.evaluate(()=>JSON.stringify(D));
  armed=true;await frame.evaluate(()=>{
   __LTS_V227_TRANSPORT.invalidate(false);
   __LTS_V296_CLASSIFICATIONS.state.query='fixture search';
   __LTS_V312_CARD_REVIEW.state.drafts.set('fixture-source',{category:'Mercado'});
   __LTS_V225.pending.key='';render();
   void __LTS_V296_CLASSIFICATIONS.refresh();void __LTS_V412_PROJECTION.load(true,false);
  });
  if(release==='v450'){
   await frame.waitForFunction(()=>__LTS_V296_CLASSIFICATIONS.state.error&&__LTS_V412_PROJECTION.status==='error'&&__LTS_V225.pending.error);
   assert.equal(products,1);assert.equal(statuses,0,'The predecessor misses non-audit transient errors');
   await h.page.screenshot({path:out+'/'+label+'-reproduced.png'});
   return{release,engine,width,pass:true,predecessor_failure_reproduced:true,synthetic:true};
  }
  await frame.waitForFunction(()=>__LTS_V415_REFRESH.snapshot().pending===false&&__LTS_V415_REFRESH.snapshot().refresh.request_version==='3');
  await frame.waitForFunction(()=>!__LTS_V296_CLASSIFICATIONS.state.loading&&!__LTS_V296_CLASSIFICATIONS.state.error&&__LTS_V412_PROJECTION.status==='disabled'&&!__LTS_V225.pending.loading&&!__LTS_V225.pending.error&&__LTS_V225.pending.data?.net_expense===13.27);
  await h.page.waitForLoadState('networkidle');
  assert.equal(products,2);assert.equal(statuses,2);assert.equal(failures.size,3);
  assert.equal(await frame.evaluate(()=>JSON.stringify(D)),financial);
  assert.equal(await frame.evaluate(()=>__LTS_V296_CLASSIFICATIONS.state.query),'fixture search');
  assert.deepEqual(await frame.evaluate(()=>__LTS_V312_CARD_REVIEW.state.drafts.get('fixture-source')),{category:'Mercado'});
  assert.equal(await frame.locator('#ltsRefreshStatusV415').isVisible(),false);
  await h.page.screenshot({path:out+'/'+label+'-recovered.png'});
  await frame.locator('#v337Overview details').first().locator('summary').click();
  await h.page.screenshot({path:out+'/'+label+'-origin.png'});
  await frame.locator('#v337Overview details').first().locator('summary').click();
  const actions=frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible');await actions.click();
  await frame.waitForFunction(()=>__LTS_V181_STATE.review.status==='ready');
  assert.equal(await frame.locator('#v181ReviewQueue [role="alert"]').count(),0);
  await h.page.screenshot({path:out+'/'+label+'-actions.png',fullPage:true});
  const text=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state|Despesas provisórias não disponíveis|Não foi possível atualizar todas as classificações/.test(text));
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);assert(Object.values(calls).every(n=>n<=5),'Bounded dependent reads');
  return{release,engine,width,pass:true,all_three_failures_recovered:true,existing_job_only:true,financial_content_unchanged:true,filters_and_drafts_preserved:true,synthetic:true,private_session:false,physical_device:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,products,statuses,calls,failures:[...failures],reads:h.reads,errors:h.errors,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[393,1366])for(const release of['v450','v451']){const r=await run(browser,engine,width,release);results.push(r);console.log(JSON.stringify(r));}}finally{await browser.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===8&&results.every(x=>x.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
