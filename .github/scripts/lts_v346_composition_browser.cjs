'use strict';
// Synthetic session and HTTP; optional owner-data replay is explicitly labelled.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const fixtures=require('./lts_v309_fixtures.cjs'),base=process.env.LTS_TEST_BASE||'http://127.0.0.1:8788',out=path.resolve(process.env.LTS_QA_DIR||'qa/v346');fs.mkdirSync(out,{recursive:true});
const actual=process.env.LTS_ACTUAL_COMPOSITION_SNAPSHOT?JSON.parse(fs.readFileSync(process.env.LTS_ACTUAL_COMPOSITION_SNAPSHOT)):null;
const period={from:'2022-04-01',to:'2022-04-30'},key='synthetic-parent',group=actual?'Bebidas':'Categoria fictícia';
const mk=(key,amount,description,extra={})=>({key,amount,description,period:'2022-04-01',date:'2022-04-01',source_date:'2022-04-01',date_kind:'source',category:group,original_category:group,original_amount:amount,account_source:'Cartão fictício',last4:'1234',source:{file:'Planilha fictícia.xlsx',sheet:'Cartão fictício',row:1,description,date:'2022-04-01',amount,date_cell:'C1',amount_cell:'D1'},...extra});
const children=[mk('s1',70,'Descrição original <script>unsafe()</script>'),mk('s2',35,'Outra descrição',{source:{file:'Planilha fictícia.xlsx',sheet:'Cartão fictício',row:2,amount_formula:'20+15'}}),mk('s3',-5,'Estorno original'),mk('s4',0,'Registro zero')];
const parent={key,amount:100,description:'Despesas consolidadas cartão',period:'2022-04-01',date_kind:'month',account_source:'Cartão fictício',category:group,current_category:group,composition:{status:'complete',count:4,nonzero_count:3}};
const synthetic={detail:{revision:'synthetic-composition-1',row_count:1,total:100,rows:[parent],offset:0,next_offset:null,components:[]},composition:{status:'complete',total:100,identified_total:100,residual_total:0,count:4,nonzero_count:3,rows:children}};
const data=actual||synthetic;
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function run(browser,viewport,label){
 const ctx=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-26T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-26T22:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await ctx.newPage();page.setDefaultTimeout(25000);const errors=[],writes=[],requests=[];let mode='complete',holdResolve,heldStarted,releaseHold;
 let heldGate;
 page.on('pageerror',e=>errors.push(String(e)));
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();
  if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=x=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(x)});
  if(url.pathname==='/auth/v1/token')return send(session);if(url.pathname==='/auth/v1/logout')return send({});
  if(name==='lts_browser_expense_detail_v346'){requests.push({name,args});return send(data.detail);}
  if(name==='lts_browser_expense_composition_v346'){
   requests.push({name,args});if(mode==='hold'){heldStarted();await heldGate;}
   if(mode==='error')return route.fulfill({status:500,contentType:'application/json',body:'{"message":"private SQL raw failure must stay hidden"}'});
   let p=structuredClone(data.composition);
   if(mode==='missing')p=actual?data.missing:{...p,status:'missing',count:0,nonzero_count:0,rows:[],identified_total:0,residual_total:100};
   if(mode==='partial')p={...p,status:'partial',count:1,nonzero_count:1,rows:[p.rows[0]],identified_total:p.rows[0].amount,residual_total:p.total-p.rows[0].amount};
   if(mode==='stale')p={...p,status:'stale',count:0,nonzero_count:0,rows:[],identified_total:0,residual_total:p.total};
   return send(p);
  }
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixtures.product()});
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return send({ok:true,rows:[],row_count:0,offset:0,next_offset:null,category_options:[]});
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(/_decision_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixtures.response(name,args));
 });
 let frame;
 try{
  await page.goto(base+'/releases/v346/app.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/v346/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V178_REVIEW?.installed);
  const open=async()=>{await frame.evaluate(({group,period,total})=>{V='Despesas';render();window.__LTS_V178_REVIEW.openDetail(group,null,period,total);},{group,period,total:data.detail.total});await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);};
  const drawer=frame.locator('#v178Drawer'),ready=()=>frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading),invalidate=()=>frame.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate(false));
  await open();assert.equal(await drawer.locator('[data-composition-key]').count(),1);const filter=drawer.locator('.v178-filter input');await filter.fill(data.detail.rows[0].description);const query=await filter.inputValue();
  await drawer.locator('[data-composition-key]').click();await ready();assert.equal(await drawer.locator('tbody tr').count(),data.composition.count);
  assert.match(await drawer.innerText(),/Total do consolidado/);assert.match(await drawer.innerText(),/Data da planilha/);
  assert.equal(await drawer.locator('.v346-origin[open]').count(),0);await drawer.locator('.v346-origin summary').first().click();
  assert.match(await drawer.innerText(),/linha/);assert.match(await drawer.innerText(),new RegExp(actual?'Cartão Itaú':'Cartão fictício'));assert.equal(await frame.evaluate(()=>typeof window.unsafe),'undefined');
  const box=await drawer.locator('.v178-drawer').evaluate(el=>({w:el.clientWidth,s:el.scrollWidth}));assert(box.s<=box.w+2);
  await page.screenshot({path:path.join(out,label+'-composition-origin.png')});
  await drawer.locator('.v344-back').click();await ready();assert.equal(await filter.inputValue(),query);assert.match(await drawer.locator('header small').innerText(),/01\/04\/2022 a 30\/04\/2022/);
  // Responses from each mode are intentionally uncached.
  for(const status of ['partial','missing','stale','error']){
   if(actual)break;
   mode=status;await invalidate();await drawer.locator('[data-composition-key]').click();await ready();
   const text=await drawer.innerText();assert(!text.includes('private SQL'));assert(status==='error'?text.includes('Não foi possível abrir'):status==='partial'?text.includes('Composição parcial'):status==='missing'?text.includes('Ainda falta localizar'):text.includes('mudou desde'));
   if(status==='missing')await page.screenshot({path:path.join(out,label+'-missing-composition.png')});
   await drawer.locator('.v344-back').click();await ready();
  }
  mode='hold';await invalidate();heldGate=new Promise(resolve=>releaseHold=resolve);const started=new Promise(resolve=>heldStarted=resolve);
  await drawer.locator('[data-composition-key]').click();await started;await drawer.locator('.v344-back').click();releaseHold();await ready();await page.waitForTimeout(80);assert.equal(await drawer.locator('[data-composition-key]').count(),1);
  mode='complete';await invalidate();await drawer.locator('[data-composition-key]').click();await ready();await frame.evaluate(()=>window.dispatchEvent(new Event('lts:data-invalidated')));assert.equal(await drawer.count(),0);
  assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);assert(requests.every(r=>r.args.p_from===period.from&&r.args.p_to===period.to));
  return{pass:true,label,viewport,actual_owner_data_replay:!!actual,synthetic_session:true,private_http:false,physical_device:false,source_rows:data.composition.count,total:data.composition.total,origin_closed_by_default:true,parent_filter_and_period_preserved:true,late_response_ignored:true,no_financial_writes:true};
 }catch(e){await page.screenshot({path:path.join(out,label+'-failure.png')});console.error({errors,writes,requests});throw e;}finally{releaseHold?.();await ctx.close();}
}
(async()=>{const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{})});try{const results=[];for(const [vp,label]of[[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,vp,label));fs.writeFileSync(path.join(out,'composition-browser-results.json'),JSON.stringify(results,null,2));console.log(JSON.stringify(results));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
