'use strict';process.env.LTS_FLOW_RELEASE='v446';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {setup}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');const out='qa/v446';fs.mkdirSync(out,{recursive:true});
const status=state=>({state,required:state!=='ready',cached_available:true,request_version:'2',completed_version:state==='ready'?'2':'1'});
async function run(browser,engine,width){
 const h=await setup(browser,width,980,'2026-11-15T17:00:00Z'),label=engine+'-'+width,reads={income:0,expense:0,card:0};let products=0,releaseOld,frame;
 const oldReads=new Promise(r=>releaseOld=r),send=(route,value)=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(value)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',route=>{products++;if(products>1)releaseOld();return send(route,{ok:true,mvp:fixture.product(),refresh:status(products===1?'pending':'ready')})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',route=>send(route,{ok:true,refresh:status('ready')}));
 for(const[kind,name]of Object.entries({income:'lts_browser_income_review_queue_v296',expense:'lts_browser_expense_review_queue_v229',card:'lts_browser_card_review_queue_v312'}))await h.ctx.route('**/rest/v1/rpc/'+name,async route=>{
  reads[kind]++;if(products===1)await oldReads;
  const data={ok:true,row_count:kind==='income'?1:kind==='expense'?2:3,additional_count:3,matched_count:3,offset:0,next_offset:null,rows:[],category_options:[]};
  await send(route,data).catch(()=>{});
 });
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',route=>send(route,require('./lts_v441_fixture.cjs')()));
 try{
  await h.page.goto((process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788')+'/releases/v446/app.html',{waitUntil:'domcontentloaded'});await h.page.waitForFunction(()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
  frame=h.page.frames().find(f=>f.url().includes('/releases/v446/index.html'));assert(frame);
  await frame.waitForFunction(()=>__LTS_V296_CLASSIFICATIONS?.state.loading&&__LTS_V312_CARD_REVIEW?.state.loading);
  const financial=await frame.evaluate(()=>JSON.stringify(D));
  await frame.evaluate(()=>__LTS_V312_CARD_REVIEW.state.drafts.set('fixture:retained',{category:'Saúde',beneficiary:''}));
  await frame.waitForFunction(()=>!__LTS_V415_REFRESH.snapshot().pending&&__LTS_V296_CLASSIFICATIONS.state.data?.row_count===1&&__LTS_V296_CLASSIFICATIONS.state.expense===2&&__LTS_V312_CARD_REVIEW.state.data?.additional_count===3&&!__LTS_V296_CLASSIFICATIONS.state.error&&!__LTS_V312_CARD_REVIEW.state.error&&!__LTS_V296_CLASSIFICATIONS.state.loading&&!__LTS_V312_CARD_REVIEW.state.loading);
  await h.page.waitForLoadState('networkidle');assert.equal(products,2);assert(reads.income>=2,'The interrupted income owner must resume');assert(reads.card>=1&&reads.expense>=1);
  assert.equal(await frame.evaluate(()=>JSON.stringify(D)),financial);assert.deepEqual(await frame.evaluate(()=>__LTS_V312_CARD_REVIEW.state.drafts.get('fixture:retained')),{category:'Saúde',beneficiary:''});
  const nav=frame.locator('#nav [data-v="Atualizações"],#dx1MobileNav [data-mobile-route="Atualizações"]');for(const label of await nav.evaluateAll(nodes=>nodes.map(n=>n.getAttribute('aria-label'))))assert(!/pelo menos|a conferir/.test(label));
  assert.equal(await frame.locator('#ltsRefreshStatusV415').isVisible(),false);await h.page.screenshot({path:out+'/'+label+'-recovered.png'});
  await frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();await frame.getByRole('heading',{name:'Receitas a classificar',exact:true}).waitFor();await h.page.screenshot({path:out+'/'+label+'-queues.png'});
  assert(await frame.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,cancelled_queues_resume_after_ready:true,drafts_retained:true,financial_content_unchanged:true,reads,synthetic:true,private_session:false,physical_device:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,products,reads,errors:h.errors,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{releaseOld();await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const b=await type.launch({headless:true});try{for(const width of[393,1366]){const r=await run(b,engine,width);results.push(r);console.log(JSON.stringify(r))}}finally{await b.close()}}fs.writeFileSync(out+'/browser-result.json',JSON.stringify({pass:results.length===4&&results.every(x=>x.pass),results},null,2))})().catch(e=>{console.error(e);process.exitCode=1});
