'use strict';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const release=process.env.LTS_RELEASE||'v379';
const fixture=require('./lts_v379_fixtures.cjs'),base='http://127.0.0.1:8788',out='qa/v379';fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
async function setup(browser,width,height){
 const ctx=await browser.newContext({viewport:{width,height},isMobile:width<1000,hasTouch:width<1000,locale:'pt-BR',timezoneId:'America/Sao_Paulo',serviceWorkers:'block'});
 await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-16T15:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T15:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));Object.defineProperty(navigator,'standalone',{get:()=>true});},session);
 const page=await ctx.newPage(),reads=[],errors=[],writes=[];page.setDefaultTimeout(25000);page.on('pageerror',e=>errors.push(String(e)));
 let holdFrom=null,heldResolve,heldStarted,corruptFrom=null;
 await ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin===base)return route.continue();if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();
  const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});reads.push({name,args});
  if(url.pathname==='/auth/v1/token')return send(session);
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
  if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:[]});
  if(/^lts_browser_card_cycles_/.test(name))return send(fixture.cards());
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  if(/^lts_browser_monthly_/.test(name)){
   const report=fixture.monthly(args.p_from,args.p_to);
   if(corruptFrom===args.p_from){corruptFrom=null;report.monthly_totals.shift();}
   if(holdFrom===args.p_from){holdFrom=null;heldStarted?.();await new Promise(resolve=>heldResolve=resolve);}
   return send(report);
  }
  if(/^lts_browser_expense_detail_/.test(name)){
   const rows=fixture.ledger.filter(x=>x.date>=args.p_from&&x.date<=args.p_to&&x.expenses).map((x,i)=>({key:'synthetic-detail-'+i,date:x.date,date_kind:'day',description:'Despesa de teste',account_source:'Conta fictícia',amount:x.expenses,category:'Compromissos financeiros — Empréstimos'}));
   return send({version:'synthetic-detail',from:args.p_from,to:args.p_to,group:args.p_group,subgroup:null,total:rows.reduce((s,x)=>s+x.amount,0),row_count:rows.length,matched_count:rows.length,offset:0,next_offset:null,revision:'synthetic-period-1',rows,components:[]});
  }
  if(name==='lts_browser_recurring_plans_v366')return send({ok:true,rules:[]});
  if(/_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
  return send(fixture.response(name,args));
 });
 return{ctx,page,reads,errors,writes,
  hold(from){holdFrom=from;return new Promise(resolve=>heldStarted=resolve);},release(){heldResolve?.();heldResolve=null;},corrupt(from){corruptFrom=from;}};
}
async function ready(page){
 await page.waitForFunction(()=>(document.getElementById('wealth')?.contentDocument?.getElementById('shell')||document.getElementById('shell'))?.contentDocument?.body?.dataset.ltsBootState==='ready');
 const frame=page.frames().find(f=>f.url().includes('/releases/'+release+'/index.html'));assert(frame);
 await frame.waitForFunction(()=>window.__LTS_V365?.installed&&window.__LTS_V182_FEEDBACK?.installed&&window.__LTS_V337_MONTH?.installed&&D&&!N.classList.contains('hidden'));
 return frame;
}
async function fit(frame,tag){const size=await frame.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert(size.scroll<=size.width+2,tag+': global horizontal overflow '+JSON.stringify(size));return size;}
async function run(browser,engine,width,height){
 const h=await setup(browser,width,height),{page}=h,label=engine+'-'+width;let frame;
 try{
  // This contract targets the explicitly selected immutable period implementation.
  // V393's replacement monthly contract and launcher are covered in their own tests.
  await page.goto(base+'/releases/'+release+'/app.html',{waitUntil:'domcontentloaded'});frame=await ready(page);
  await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');
  const overview=frame.locator('#v337Overview'),waitRange=(from,to)=>frame.waitForFunction(([from,to])=>{const s=window.__LTS_V337_MONTH.state;return s.status==='ready'&&s.data?.from===from&&s.data?.to===to},[from,to]);
  await overview.getByRole('button',{name:'Período',exact:true}).click();await waitRange('2026-10-01','2026-10-16');
  const from=()=>overview.getByLabel('Data inicial do balanço'),to=()=>overview.getByLabel('Data final do balanço'),apply=()=>overview.getByRole('button',{name:'Aplicar intervalo',exact:true});
  const choose=async(a,b)=>{await from().fill(a);await to().fill(b);await apply().click();await waitRange(a,b);};
  await choose('2025-12-15','2026-01-10');
  assert.match(await overview.locator('.v337-metrics').innerText(),/3\.200,00/);assert.match(await overview.locator('.v337-metrics').innerText(),/1\.200,00/);assert.match(await overview.locator('.v337-metrics').innerText(),/2\.000,00/);
  assert.equal(await overview.locator('.v379-months[open]').count(),0);await overview.locator('.v379-months summary').click();assert.equal(await overview.locator('.v379-months tbody tr').count(),2);
  assert.match(await overview.locator('.v379-months').innerText(),/dez.*2025/);assert.match(await overview.locator('.v379-months').innerText(),/jan.*2026/);
  await from().fill('2026-06-10');await frame.evaluate(()=>render());assert.equal(await from().inputValue(),'2026-06-10','draft dates survive background renders');
  await to().fill('2026-06-01');await apply().click();await overview.getByRole('alert').waitFor();assert.match(await overview.locator('.v337-period').innerText(),/15\/12\/2025 a 10\/01\/2026/);
  assert(!h.reads.some(x=>/^lts_browser_monthly_/.test(x.name)&&x.args.p_from==='2026-06-10'&&x.args.p_to==='2026-06-01'));
  await choose('2026-06-10','2026-06-15');assert.match(await overview.locator('.v337-metrics').innerText(),/3\.800,00/);
  const held=h.hold('2026-01-01');await from().fill('2026-01-01');await to().fill('2026-01-31');await apply().click();await held;
  await choose('2026-06-10','2026-06-15');h.release();await page.waitForLoadState('networkidle');assert.match(await overview.locator('.v337-period').innerText(),/10\/06\/2026 a 15\/06\/2026/);assert.match(await overview.locator('.v337-metrics').innerText(),/3\.800,00/);
  h.corrupt('2025-11-01');await from().fill('2025-11-01');await to().fill('2025-12-31');await apply().click();await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='error');assert.equal(await overview.locator('.v337-metrics').count(),0);
  await overview.getByRole('button',{name:'Tentar novamente',exact:true}).click();await waitRange('2025-11-01','2025-12-31');assert.match(await overview.locator('.v337-metrics').innerText(),/900,00/);
  assert.equal(await overview.locator('.v337-source[open]').count(),0);await fit(frame,label+' dashboard-period');await overview.scrollIntoViewIfNeeded();await page.screenshot({path:out+'/'+label+'-period.png'});
  await overview.getByRole('button',{name:'Mês',exact:true}).click();await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V337_MONTH.state.data?.month==='2026-10');
  await frame.waitForFunction(()=>window.__LTS_V226?.cycles?.complete===true);assert.equal(await frame.locator('.v356-oldest').count(),0);assert(!(await frame.locator('body').innerText()).includes('Obrigação mais antiga'));
  const bankCards=frame.locator('.v226-upcoming');assert.match(await bankCards.innerText(),/2\.299,31/);assert.match(await bankCards.innerText(),/532,73/);assert.match(await bankCards.innerText(),/03\/12\/2026/);
  await frame.evaluate(()=>{V='Despesas';window.__LTS_V168_STATE.expense.tab='overview';renderNav();render();});
  await frame.waitForFunction(()=>!!window.__LTS_V175_STATE?.expense?.data&&!window.__LTS_V175_STATE.expense.loading);await fit(frame,label+' expenses-overview');
  if(width<=900){
   const geometry=await frame.locator('.v168-expenses .v168-tabs button,.v168-expenses .v168-periods button').evaluateAll(es=>es.map(e=>({text:e.textContent.trim(),left:e.getBoundingClientRect().left,right:e.getBoundingClientRect().right,width:e.ownerDocument.defaultView.innerWidth})));
   assert(geometry.every(x=>x.left>=0&&x.right<=x.width+2),'every expense tab and preset must be in the visible width: '+JSON.stringify(geometry));
  }
  await page.screenshot({path:out+'/'+label+'-expenses-overview.png'});
  await frame.locator('[data-v168-exp-tab="monthly"]').click();await frame.waitForFunction(()=>!!window.__LTS_V175_STATE?.monthly?.data&&!window.__LTS_V175_STATE.monthly.loading);
  const expenseFrom=()=>frame.locator('#v168ExpenseFrom'),expenseTo=()=>frame.locator('#v168ExpenseTo');assert(await expenseFrom().isVisible());assert(await expenseTo().isVisible());
  await expenseFrom().fill('2025-12-15');await expenseTo().fill('2026-01-10');await frame.locator('#v168ExpenseApply').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE.monthly.key==='2025-12-15|2026-01-10'&&!window.__LTS_V175_STATE.monthly.loading&&!!window.__LTS_V175_STATE.monthly.data);
  assert.match(await frame.locator('.v379-period-head').innerText(),/15\/12\/2025 a 10\/01\/2026/);assert.match(await frame.locator('.v175-monthly .v168-kpis').innerText(),/2\.000,00/);assert.equal(await frame.locator('.v182-months tbody tr').count(),3);
  await fit(frame,label+' expenses-monthly');await frame.locator('.v379-period-head').scrollIntoViewIfNeeded();await page.screenshot({path:out+'/'+label+'-expenses-monthly.png'});
  const group=frame.locator('.v182-matrix').filter({has:frame.getByRole('heading',{name:'Despesas por categoria',exact:true})});
  const total=group.locator('tbody tr[data-lts-category-key] td:last-child .v183-month-detail').first();await total.click();
  const drawer=frame.locator('.v178-drawer');await drawer.waitFor();await frame.waitForFunction(()=>!window.__LTS_V178_STATE.detail.loading);assert.match(await drawer.innerText(),/15\/12\/2025 a 10\/01\/2026/);assert.match(await drawer.innerText(),/1\.200,00/);
  await drawer.getByRole('button',{name:/Voltar para/}).click();assert.equal(await expenseFrom().inputValue(),'2025-12-15');assert.equal(await expenseTo().inputValue(),'2026-01-10');
  await frame.locator('[data-v168-exp-tab="cards"]').click();await frame.waitForFunction(()=>!!window.__LTS_V226?.cycles&&!!window.__LTS_V175_STATE?.cards?.data&&!window.__LTS_V175_STATE.cards.loading);await page.waitForLoadState('networkidle');await fit(frame,label+' expenses-cards');assert.equal(await frame.locator('.v356-oldest').count(),0);
  const cards=frame.locator('.v168-expenses .v226-banks');assert.match(await cards.innerText(),/2\.299,31/);await cards.scrollIntoViewIfNeeded();await page.screenshot({path:out+'/'+label+'-expenses-cards.png'});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,height,period_and_month_modes:true,cross_year_and_partial_days:true,draft_survives_render:true,invalid_range_does_not_apply:true,late_read_ignored:true,missing_month_not_zero:true,retry:true,expense_period_editor_visible:true,monthly_breakdown_and_total:true,drilldown_and_return_preserve_range:true,oldest_duplicate_removed:true,card_values_preserved:true,expense_controls_fit:true,synthetic_http:true,private_session:false,physical_iphone:false};
 }catch(e){await page.screenshot({path:out+'/'+label+'-failure.png'});console.error({label,errors:h.errors,writes:h.writes,lastReads:h.reads.slice(-12)});throw e;}finally{h.release();await h.ctx.close();}
}
(async()=>{
 const results=[];
 for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){
  const browser=await type.launch({headless:true});try{for(const[width,height]of[[360,800],[390,844],[844,390],[1366,900]])results.push(await run(browser,engine,width,height));}finally{await browser.close();}
 }
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));
})().catch(e=>{console.error(e);process.exitCode=1});
