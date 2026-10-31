'use strict';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),base='http://127.0.0.1:8788',out='qa/v382';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function setup(browser,width,height){
 const ctx=await browser.newContext({viewport:{width,height},isMobile:width<1000,hasTouch:width<1000,locale:'pt-BR',timezoneId:'America/Sao_Paulo',serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-30T15:00:00Z']));}static now(){return NativeDate.parse('2026-10-30T15:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));Object.defineProperty(navigator,'standalone',{get:()=>true});},session);
 const page=await ctx.newPage(),errors=[],writes=[],reads=[];page.setDefaultTimeout(25000);page.on('pageerror',e=>errors.push(String(e)));
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===base)return route.continue();if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});reads.push({name,args});
  if(url.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:[]});
  if(/^lts_browser_card_cycles_/.test(name))return send(fixture.cards());
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  if(/^lts_browser_monthly_/.test(name))return send(fixture.monthly(args.p_from,args.p_to));
  if(name==='lts_browser_recurring_plans_v366')return send({ok:true,rules:[]});
  if(/_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixture.response(name,args));
 });return {ctx,page,errors,writes,reads};
}
async function ready(page,release){
 const frame=page.frames().find(f=>new URL(f.url()).pathname.endsWith('/releases/'+release+'/index.html'));assert(frame,'inner app frame');
 await frame.waitForFunction(()=>window.__LTS_V365?.installed&&window.__LTS_V183_FLOW_PERIOD_STATE?.installed&&window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.initial_applied_at&&D&&!N.classList.contains('hidden'));
 assert.equal(await frame.evaluate(()=>V),'Dashboard','authenticated opening completes on the Dashboard before navigation');
 if(release==='v382')await frame.waitForFunction(()=>window.__LTS_V382_FLOW_LAYOUT?.installed);
 if(release==='v382')await frame.evaluate(()=>{const base=loadFlowRange;loadFlowRange=function(...args){(window.__flowTestEvents||(window.__flowTestEvents=[])).push({type:'loadFlowRange',args,at:performance.now()});return base.apply(this,args)};});
 return frame;
}
async function open(h,release,launcher=false){
 await h.page.goto(base+(launcher?'/mobile/?source=home-screen':'/releases/'+release+'/app.html'),{waitUntil:'domcontentloaded'});
 await h.page.waitForFunction(launcher?()=>document.getElementById('wealth')?.contentDocument?.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready':()=>document.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
 const frame=await ready(h.page,release);await h.page.waitForLoadState('networkidle');return frame;
}
async function flow(frame){
 const route=frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');
 assert.equal(await route.count(),1,'one visible Flow route');await route.click();
 await frame.waitForFunction(()=>V==='Fluxo Diário');
 await frame.evaluate(()=>loadFlowRange('2026-10-25','2030-12-31'));
 await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2026-10-25'&&FLOWQ?.to==='2030-12-31');
}
async function geometry(frame){return frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,controls:document.querySelector('.flow-sticky-controls').getBoundingClientRect().toJSON(),filters:document.querySelector('.v382-banks')?.parentElement.getBoundingClientRect().toJSON(),material_height:[...document.querySelectorAll('.flow-sticky-controls .lts-freshness-alert')].reduce((sum,e)=>sum+e.getBoundingClientRect().height+parseFloat(getComputedStyle(e).marginTop)+parseFloat(getComputedStyle(e).marginBottom),0),period:document.querySelector('.v382-period')?.getBoundingClientRect().toJSON(),visiblePresets:[...document.querySelectorAll('.v382-presets button')].filter(e=>e.getClientRects().length>0).length}));}
async function snapshot(frame){return frame.evaluate(()=>({from:FLOWFROM,to:FLOWTO,flow:FLOWQ,presets:[...document.querySelectorAll('[data-p],#flowDefaultRange')].map(e=>e.textContent.trim()).sort(),banks:[...document.querySelectorAll('[data-a]')].map(e=>e.textContent.trim()),actions:[...document.querySelectorAll('.flow-sticky-controls>.flowbar:first-child .chips button')].map(e=>e.textContent.trim()),warnings:[...document.querySelectorAll('.flow-sticky-controls .lts-freshness-alert')].map(e=>({text:e.textContent.trim(),visible:e.getClientRects().length>0}))}));}
async function run(browser,engine,width,height){
 const before=await setup(browser,width,height),after=await setup(browser,width,height),label=engine+'-'+width;let frame;
 try{
  const prior=await open(before,'v379');await flow(prior);await before.page.waitForLoadState('networkidle');const original=await snapshot(prior),old=await geometry(prior);
  await before.page.screenshot({path:out+'/'+label+'-before.png'});
  frame=await open(after,'v382',true);await flow(frame);await after.page.waitForLoadState('networkidle');
  const current=await snapshot(frame);assert.equal(hash(current.flow),hash(original.flow),'identical financial response under the same dates');assert.deepEqual(current.presets,original.presets);assert.deepEqual(current.banks,original.banks);assert.deepEqual(current.actions,original.actions);assert.deepEqual(current.warnings,original.warnings,'material financial warnings stay visible');
  assert.equal(await frame.locator('.v382-period[open]').count(),0);assert.match(await frame.locator('.v382-period-range').innerText(),/25\/10\/2026.*31\/12\/2030/);
  const closed=await geometry(frame);assert(closed.scroll<=closed.width+2,'closed layout fits');assert(closed.filters.height<=118,'collapsed bank and period height: '+closed.filters.height);assert(closed.controls.height-closed.material_height<=210,'controls excluding visible material warnings: '+JSON.stringify(closed));assert.equal(closed.visiblePresets,0);
  if(width<=430)assert(closed.controls.height<old.controls.height-160,'mobile filter height materially reduced');
  const banks=await frame.locator('.v382-banks button').evaluateAll(es=>es.map(e=>({text:e.textContent.trim(),x:e.getBoundingClientRect().x,right:e.getBoundingClientRect().right,height:e.getBoundingClientRect().height})));
  assert(banks.every(b=>b.x>=0&&b.right<=width+2&&b.height>=43),'all banks visible and touchable');
  await after.page.screenshot({path:out+'/'+label+'-after.png'});
  const summary=()=>frame.locator('.v382-period>summary');await summary().click();assert.equal(await frame.locator('.v382-period[open]').count(),1);
  const inputs=await frame.locator('.v382-field input,.v382-field select').evaluateAll(es=>es.map(e=>({x:e.getBoundingClientRect().x,right:e.getBoundingClientRect().right,height:e.getBoundingClientRect().height,font:Number.parseFloat(getComputedStyle(e).fontSize)})));
  assert(inputs.every(e=>e.x>=0&&e.right<=width+2&&e.height>=43&&e.font>=16),'native date fields fit without sub-16px font');
  const from=()=>frame.getByLabel('Data inicial do Fluxo',{exact:true}),to=()=>frame.getByLabel('Data final do Fluxo',{exact:true});
  await from().fill('2025-12-15');await to().fill('2026-01-10');await frame.evaluate(()=>{document.activeElement?.blur();render()});
  assert.equal(await from().inputValue(),'2025-12-15');assert.equal(await to().inputValue(),'2026-01-10');assert.equal(await frame.locator('.v382-period[open]').count(),1);
  await frame.locator('#flowApply').click();await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2025-12-15'&&FLOWQ?.to==='2026-01-10');
  assert.match(await frame.locator('.v382-period-range').innerText(),/15\/12\/2025.*10\/01\/2026/);
  await frame.getByLabel('Ano do período do Fluxo',{exact:true}).selectOption('2026');await frame.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2026-01-01'&&FLOWTO==='2026-12-31');
  assert.equal(await frame.locator('[data-p="Próximos 30 dias"]').evaluate(e=>typeof e.onclick),'function','preserved quick-period handler remains attached');
  await frame.locator('[data-p="Próximos 30 dias"]').click();await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2026-10-30'&&FLOWQ?.to==='2026-11-28');
  // Repeat the native picker -> first quick preset click to expose sequencing errors.
  for(let i=0;i<4;i++){
   await frame.getByLabel('Ano do período do Fluxo',{exact:true}).selectOption(String(2025+i%2));
   await frame.waitForFunction(year=>!FLOWLOADING&&FLOWQ?.from===year+'-01-01'&&FLOWQ?.to===year+'-12-31',String(2025+i%2));
   await frame.locator('[data-p="Próximos 30 dias"]').click();
   await frame.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2026-10-30'&&FLOWQ?.to==='2026-11-28');
  }
  const shown=await frame.evaluate(()=>SHOWZERO);await frame.locator('#flowZero').click();assert.equal(await frame.evaluate(()=>SHOWZERO),!shown);
  await summary().click();assert.equal(await frame.locator('.v382-period[open]').count(),0);await frame.locator('[data-a="Bradesco"]').click();await frame.waitForFunction(()=>ACC==='Bradesco');assert.equal(await frame.locator('.v382-period[open]').count(),0);
  await frame.locator('[data-a="Consolidado"]').click();await frame.evaluate(()=>{document.activeElement?.blur();render()});assert.equal(await frame.locator('.v382-period[open]').count(),0);
  await summary().focus();await after.page.keyboard.press('Enter');assert.equal(await frame.locator('.v382-period[open]').count(),1);await after.page.keyboard.press('Enter');assert.equal(await frame.locator('.v382-period[open]').count(),0);
  await frame.locator('.v382-tools>summary').click();await frame.getByRole('button',{name:'Fechar detalhes',exact:true}).click();assert.equal(await frame.evaluate(()=>EXP.size),0);await frame.locator('.v382-tools>summary').click();
  // Zoom-like text enlargement must preserve access to the same bank and period controls.
  if(width<=430){await frame.addStyleTag({content:'html{-webkit-text-size-adjust:150%!important;text-size-adjust:150%!important}'});const scaled=await geometry(frame);assert(scaled.scroll<=width+2,'enlarged text fits');}
  await frame.evaluate(()=>{V='Dashboard';renderNav();render()});await after.page.waitForLoadState('networkidle');
  const dashboard=await frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,sourceOpen:document.querySelectorAll('.v337-source[open]').length}));
  assert(dashboard.scroll<=width+2);assert.equal(dashboard.sourceOpen,0);assert(!(await frame.locator('body').innerText()).includes('Obrigação mais antiga'));await after.page.screenshot({path:out+'/'+label+'-dashboard.png'});
  assert.deepEqual(before.errors,[]);assert.deepEqual(after.errors,[]);assert.deepEqual(before.writes,[]);assert.deepEqual(after.writes,[]);
  return {pass:true,engine,width,height,before_height:old.controls.height,after_height:closed.controls.height,financial_response_sha256:hash(current.flow),same_financial_response:true,all_presets_and_banks_preserved:true,native_fields_fit:true,draft_preserved:true,cross_year_apply:true,year_and_quick_presets:true,year_to_quick_preset_cycles:5,initial_dashboard_before_flow:true,zero_day_toggle:true,open_state_survives_render:true,keyboard_disclosure:true,dashboard_fit:true,synthetic_http:true,private_session:false,physical_iphone:false};
 }catch(error){
  const frames=[];for(const f of [...before.page.frames(),...after.page.frames()]){if(!f.url().endsWith('/index.html'))continue;try{frames.push({url:f.url(),state:await f.evaluate(()=>({view:V,boot:document.body.dataset.ltsBootState,product:!!D,navHidden:N.classList.contains('hidden'),v365:window.__LTS_V365,v183:window.__LTS_V183_FLOW_PERIOD_STATE,v290:window.__LTS_V290_USABILITY,v382:window.__LTS_V382_FLOW_LAYOUT,dashboard:window.__LTS_DASHBOARD_EXECUTIVE_STATUS,bootComponents:window.LTSV339Boot?.status,from:FLOWFROM,to:FLOWTO,loading:FLOWLOADING})),body:(await f.locator('body').innerText()).slice(0,1000)});}catch(e){frames.push({url:f.url(),error:String(e)});}}
  fs.writeFileSync(out+'/'+label+'-failure-bootstrap.json',JSON.stringify({frames,stack:error.stack},null,2));
  if(frame){fs.writeFileSync(out+'/'+label+'-failure-dom.html',await frame.locator('body').innerHTML());fs.writeFileSync(out+'/'+label+'-failure-state.json',JSON.stringify({state:await frame.evaluate(()=>({from:FLOWFROM,to:FLOWTO,preset:FLOWPRESET,loading:FLOWLOADING,focused:document.activeElement?.outerHTML.slice(0,240),events:window.__flowTestEvents})),reads:after.reads.slice(-20),stack:error.stack},null,2));}
  await after.page.screenshot({path:out+'/'+label+'-failure.png'}).catch(()=>{});console.error(label,{errors:after.errors,writes:after.writes,last_reads:after.reads.slice(-8)});throw error;
 }finally{await before.ctx.close();await after.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of [['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{for(const[w,h]of [[360,800],[393,852],[430,932],[852,393],[1366,900]]){let result;try{result=await run(browser,engine,w,h);}catch(error){result={pass:false,engine,width:w,height:h,error:error.stack};process.exitCode=1;}results.push(result);fs.writeFileSync(out+'/result.json',JSON.stringify({pass:results.length===10&&results.every(r=>r.pass),results},null,2));console.log(JSON.stringify(result));}}finally{await browser.close()}}})().catch(error=>{console.error(error);process.exitCode=1});
