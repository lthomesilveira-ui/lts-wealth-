'use strict';
process.env.LTS_FLOW_RELEASE='v433';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),original=fixture.response;
const {setup,open}=require('./lts_v382_browser.cjs');
const out='qa/v433';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
const bankEvent={source:'open_finance_bank_staging',source_ref:'synthetic-fgts-source',event_date:'2026-11-05',account:'Itaú',signed_amount:123.45,description:'Resgate FGTS',category:'Resgate FGTS',internal_transfer:true,asset_movement:true,cash_confirmed:true,excluded_from_spend:true};
fixture.response=function(name,args){
 const p=original(name,args);
 if(/^lts_browser_flow_/.test(name)&&p?.flow&&args.p_from<=bankEvent.event_date&&args.p_to>=bankEvent.event_date){
  p.flow.current_future.events.push(structuredClone(bankEvent));
  for(const d of p.flow.current_future.days){
   if(d.date===bankEvent.event_date){d.summary.events++;d.summary.Consolidado.entries+=123.45;d.fix86_columns.entradas+=123.45;}
   if(d.date>=bankEvent.event_date){d.Consolidado.bank_balance+=123.45;d.Itaú.balance+=123.45;for(const k of ['saldo_final','saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'])d.fix86_columns[k]+=123.45;}
  }
 }
 return p;
};
const go=async(f,view)=>{await f.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await f.waitForFunction(v=>V===v,view);};
async function build(browser,width,release){
 const h=await setup(browser,width,width<1000?852:1000,'2026-11-08T15:00:00Z');h.mode='empty';h.queueCalls=[];
 await h.ctx.route('**/rest/v1/rpc/lts_browser_expense_review_queue_v229',async route=>{
  const args=JSON.parse(route.request().postData()||'{}');h.queueCalls.push(args);
  if(h.mode==='failed')return route.fulfill({status:503,contentType:'application/json',body:'{"message":"Synthetic failure"}'});
  const count=h.mode==='one'?1:0;
  const p={version:'expense-review-queue-v229',from:args.p_from,to:args.p_to,offset:args.p_offset,row_count:count,matched_count:count,next_offset:null,
   rows:count?[{key:'synthetic-review',source_table:'fixture',source_ref:'synthetic-review',date:'2026-11-07',description:'Despesa de teste',account_source:'Conta de teste',amount:73.25,category:'A classificar',question_kind:'classification'}]:[],
   category_options:['Mercado','Assinaturas'],beneficiary_options:[],property_options:[],
   pending_projections:[{event_date:'2026-11-06',account:'Bradesco',description:'Parcela de teste sem confirmação',signed_amount:-350}]};
  if(h.mode==='invalid')p.rows=null;
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});
 });
 h.frame=await open(h,release,false);await go(h.frame,'Atualizações');
 await h.frame.waitForFunction(()=>__LTS_V181_STATE.review.status==='ready');return h;
}
async function search(h,query){await h.frame.locator('[data-v181-review-query]').fill(query);await h.frame.locator('[data-v181-review-search]').click();}
async function run(browser,engine,width){
 const before=await build(browser,width,'v425'),after=await build(browser,width,'v433'),f=after.frame;const result={engine,width};
 try{
  assert.equal(hash(await f.evaluate(()=>D)),hash(await before.frame.evaluate(()=>D)),'financial product response unchanged');
  assert.equal(await f.locator('#v181ReviewQueue .v168-cardhead strong').innerText(),'0');
  assert.match(await f.locator('.v181-pending-projections').innerText(),/Parcela de teste sem confirmação/);
  const geometry=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert(geometry.scroll<=width+2);
  const text=await f.locator('.v168-updates').innerText();
  assert(!/RPC|SQLSTATE|source_ref|source_fingerprint|backend|payload|epoch/i.test(text));
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-empty.png'});
  after.mode='one';await search(after,'one');await f.waitForFunction(()=>__LTS_V181_STATE.review.status==='ready'&&__LTS_V181_STATE.review.data.row_count===1);
  assert.match(await f.locator('#v181ReviewQueue').innerText(),/Despesa de teste/);
  const known=await f.evaluate(()=>JSON.stringify(__LTS_V181_STATE.review.data));
  after.mode='failed';await f.locator('[data-v181-review-search]').click();await f.waitForFunction(()=>__LTS_V181_STATE.review.status==='error');
  assert.equal(await f.evaluate(()=>JSON.stringify(__LTS_V181_STATE.review.data)),known);
  assert.match(await f.locator('#v181ReviewQueue').innerText(),/informações anteriores podem estar desatualizadas/);
  const warningHeight=await f.locator('#v181ReviewQueue [role=status]').evaluate(n=>n.getBoundingClientRect().height);assert(warningHeight<150);
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-failed-known.png'});
  after.mode='empty';await f.locator('[data-v181-review-retry]').click();await f.waitForFunction(()=>__LTS_V181_STATE.review.status==='ready');
  after.mode='invalid';await search(after,'invalid');await f.waitForFunction(()=>__LTS_V181_STATE.review.status==='error');
  assert.equal(await f.locator('#v181ReviewQueue .v168-cardhead strong').innerText(),'—','unavailable is not zero');
  assert.match(await f.locator('#v181ReviewQueue').innerText(),/Não foi possível carregar/);
  assert.match(await f.locator('#v296IncomeQueue').innerText(),/Nenhuma receita sem classificação/,'independent list still available');
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-unknown.png'});
  after.mode='empty';await f.locator('[data-v181-review-retry]').click();await f.waitForFunction(()=>__LTS_V181_STATE.review.status==='ready');
  await go(f,'Fluxo Diário');await go(before.frame,'Fluxo Diário');
  for(const x of [f,before.frame])await x.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.flow);
  assert.equal(hash(await f.evaluate(()=>FLOWQ)),hash(await before.frame.evaluate(()=>FLOWQ)),'full flow response unchanged');
  await f.locator('button.exp[data-d="2026-11-05"]').click();
  assert.match(await f.locator('#d-2026-11-05').innerText(),/Resgate FGTS/);
  assert.equal(await f.locator('.v425-options[open]').count(),0,'secondary controls remain closed');
  await f.locator('.v425-options>summary').click();assert.equal(await f.locator('.v425-options[open]').count(),1);await after.page.screenshot({path:out+'/'+engine+'-'+width+'-options.png'});
  await after.page.keyboard.press('Escape');await go(f,'Dashboard');await go(f,'Atualizações');
  assert.equal(await f.locator('#v181ReviewQueue').count(),1);assert.equal(await f.locator('#v181ReviewQueue .v168-cardhead strong').innerText(),'0');
  assert.deepEqual(after.errors,[]);assert.deepEqual(before.errors,[]);assert.deepEqual(after.writes,[]);assert.deepEqual(before.writes,[]);
  Object.assign(result,{pass:true,financial_responses_identical:true,known_list_preserved_on_failure:true,unknown_not_zero:true,pending_payment_preserved:true,fgts_caption:true,warning_height:warningHeight,horizontal_overflow:false,financial_writes:0,private_session:false,physical_iphone:false});
  return result;
 }catch(e){fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.txt',e.stack+'\n'+JSON.stringify({errors:after.errors,reads:after.reads.slice(-8),queueCalls:after.queueCalls})+'\n'+await f.locator('body').innerText());await after.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});throw e;}
 finally{await before.ctx.close();await after.ctx.close();}
}
(async()=>{
 const results=[],engines=process.env.LOCAL_CHROMIUM?[['chromium',chromium]]:[['chromium',chromium],['webkit',webkit]];
 for(const[engine,type]of engines){const browser=await type.launch({headless:true,...(process.env.LOCAL_CHROMIUM?{executablePath:'/usr/bin/chromium'}:{})});try{for(const width of(process.env.SMOKE_ONLY?[393]:[320,393,430,1366])){results.push(await run(browser,engine,width));console.log(JSON.stringify(results.at(-1)));}}finally{await browser.close();}}
 fs.writeFileSync(out+'/browser.json',JSON.stringify({pass:true,results},null,2));
})().catch(e=>{console.error(e);process.exitCode=1;});
