'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
// Controlled data only. No customer data or sessions are committed.
const session={access_token:'expense-fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const sum=xs=>Math.round(xs.reduce((a,x)=>a+x.amount,0)*100)/100;
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x).replace(/\s+/g,' ');
const norm=s=>String(s||'').replace(/\s+/g,' ').trim();
const flowDay=date=>({date,summary:{events:0,Consolidado:{entries:0,exits:0}},Consolidado:{bank_balance:600,economic_net:0},Itaú:{balance:600,net:0},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},fix86_columns:{saldo_anterior:600,entradas:0,saidas:0,saldo_final:600,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:1000,saldo_apos_rsu:1200,saldo_apos_fgts:1250}});
async function run(browser,width,label){
 const ctx=await browser.newContext({viewport:{width,height:1000}});
 await ctx.addInitScript(()=>{const Native=Date;class Fixed extends Native{constructor(...args){super(...(args.length?args:['2026-09-30T13:00:00Z']))}static now(){return Native.parse('2026-09-30T13:00:00Z')}}window.Date=Fixed});
 await ctx.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 const rows=[{key:'family',event_date:'2014-01-15',amount:1500.25,category:'Família',card:false},{key:'larissa1',event_date:'2024-06-15',amount:9000000.27,category:'Larissa',card:false},{key:'larissa2',event_date:'2025-06-15',amount:5000.17,category:'Larissa',card:true},{key:'invoice',event_date:'2025-09-15',amount:888888.88,category:'Faturas sem composição individual',card:true},{key:'august',event_date:'2026-08-15',amount:175.3,category:'Mercado',card:false},{key:'september',event_date:'2026-09-15',amount:300.2,category:'Mercado',card:true}];
 const calls=[],errors=[];let writes=0,failSave=true;
 const selected=a=>rows.filter(r=>r.event_date>=a.p_from&&r.event_date<=a.p_to);
 const page=await ctx.newPage();page.setDefaultTimeout(20000);page.on('pageerror',e=>errors.push(String(e.stack||e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,rows:[],items:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v178')data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-09-30',cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:50,day:flowDay('2026-09-30')};
  else if(name.startsWith('lts_browser_wealth_detail'))data=wealth;
  else if(name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_v/.test(name)){
   const xs=selected(a),groups=[...new Set(xs.map(r=>r.category))],ms=[...new Set(xs.map(r=>r.event_date.slice(0,7)+'-01'))].sort();
   const from12=new Date(a.p_to.slice(0,7)+'-01T12:00:00Z');from12.setUTCMonth(from12.getUTCMonth()-11);
   const n=(Number(a.p_to.slice(0,4))-Number(a.p_from.slice(0,4)))*12+Number(a.p_to.slice(5,7))-Number(a.p_from.slice(5,7))+1;
   data={version:'expense-executive-v229-consistent-comparisons',period:{from:a.p_from,to:a.p_to,label:a.p_from==='2013-10-10'?'Desde 2013':'Período',months_in_selection:n},summary:{selected_total:sum(xs),card_total:sum(xs.filter(r=>r.card)),account_total:sum(xs.filter(r=>!r.card)),monthly_average:sum(xs)/n,rows:xs.length,pending_identification:0,last_12m:sum(selected({p_from:from12.toISOString().slice(0,10),p_to:a.p_to}))},management_groups:groups.map(name=>({name,total:sum(xs.filter(r=>r.category===name)),rows:xs.filter(r=>r.category===name).length,subgroups:[]})),monthly_detail:ms.map(month=>({month,total:sum(xs.filter(r=>r.event_date.startsWith(month.slice(0,7))))})),comparison:{previous_total:175.3,current_total:300.2,variation_pct:71.25,partial:false},coverage_disclosure:{total:sum(xs.filter(r=>r.key==='invoice')),rows:xs.filter(r=>r.key==='invoice').length}};
  }else if(name==='lts_browser_expense_detail_v229'){
   const xs=selected(a).filter(r=>!a.p_group||a.p_group==='__card_total__'&&r.card||a.p_group==='__account_total__'&&!r.card||r.category===a.p_group).filter(r=>!a.p_subgroup||r.category===a.p_subgroup);
   data={version:'expense-detail-v178',from:a.p_from,to:a.p_to,total:sum(xs),row_count:xs.length,matched_count:xs.length,offset:a.p_offset,next_offset:null,revision:'r'+writes,components:[],rows:xs.map(r=>({...r,date:r.event_date,date_kind:'day',period:r.event_date.slice(0,7)+'-01',description:'Registro de teste '+r.key,account_source:r.card?'Cartão de teste':'Conta de teste',current_category:r.category,source_table:'evento_base',source_ref:r.key,can_classify:r.key!=='invoice',document_status:r.key==='invoice'?'composition_missing':null,invoice_month:r.key==='invoice'?'2025-09-01':null,invoice_family:r.key==='invoice'?'itau_mastercard':null,source_identity:r.key==='family'?{category:'Família',sheet:'Pagamentos e Recebimentos',rows:[25],note:'Categoria conferida com a planilha original.'}:null}))};
  }else if(name==='lts_browser_card_category_options_v226')data={categories:['Mercado','Presentes','Família','Larissa']};
  else if(name==='lts_browser_expense_classification_v232'){
   assert.equal(a.p_from,'2014-01-15');assert.equal(a.p_to,'2014-01-15');assert.equal(a.p_row_key,'family');assert.equal(a.p_category,'Presentes');
   if(failSave){failSave=false;status=503;data={message:'falha de teste'}}else{rows[0].category=a.p_category;writes++;data={ok:true};}
  }else if(name==='lts_browser_card_detail_v226')data={invoice_amount:888888.88,items:[],source_note:'Composição individual ainda não recebida.'};
  else if(name==='lts_browser_expense_review_queue_v229')data={row_count:0,rows:[],queue_breakdown:{classification_needed:0,historical_context:0},pending_projections:[]};
  else if(/^lts_browser_flow_v/.test(name))data={ok:true,flow:{historical:{days:[],events:[]},current_future:{days:[flowDay(a.p_from),flowDay(a.p_to)],events:[]}}};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture sync disabled'}}
  else if(name==='lts_browser_open_finance_pending_v225')data={transaction_count:0,rows:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto('http://127.0.0.1:8788/releases/'+(process.env.LTS_RELEASE||'v231')+'/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let n=0;n<200;n++){frame=page.frames().find(f=>f.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>!!window.__LTS_V181_REGRESSION_CLOSURE).catch(()=>false))break;await page.waitForTimeout(100)}
  assert(frame);const nav=width<=520?frame.locator('#dx1MobileNav [data-mobile-route="Despesas"]'):frame.locator('.nav [data-v="Despesas"]');await nav.click();
  await frame.locator('[data-v168-exp-range="all"]').click();
  await frame.waitForFunction(()=>window.__LTS_V175_STATE.expense.data?.period?.from==='2013-10-10');
  await frame.waitForSelector('.v231-number-detail');
  const kpi=t=>frame.locator('.v168-expenses .v168-kpi').filter({has:frame.locator(':scope>span').filter({hasText:new RegExp('^'+t+'$')})});
  for(const t of ['Total do período','Cartões','Contas']){
   const box=kpi(t);assert(await box.locator('.v231-number-detail').isVisible());
   const metrics=await box.locator('strong').evaluate(e=>{const r=e.getBoundingClientRect(),s=getComputedStyle(e),range=document.createRange();range.selectNodeContents(e);return{width:e.clientWidth,scroll:e.scrollWidth,overflow:s.overflow,textOverflow:s.textOverflow,rects:[...range.getClientRects()].map(b=>({left:b.left-r.left,right:b.right-r.left,top:b.top-r.top,bottom:b.bottom-r.top})),height:r.height}});
   assert(metrics.scroll<=metrics.width+1,t+' full width '+JSON.stringify(metrics));assert.notEqual(metrics.textOverflow,'ellipsis');assert(metrics.rects.every(r=>r.left>=-1&&r.right<=metrics.width+2&&r.bottom<=metrics.height+2),t+' no cropped text');
   const displayed=norm(await box.locator('strong').innerText());await box.locator('button').click();
   await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);
   const detail=await frame.evaluate(()=>window.__LTS_V178_STATE.detail);assert.equal(detail.error,null);assert.equal(money(detail.total),displayed);assert.equal(detail.rows.length,detail.count);assert.equal(sum(detail.rows),detail.total);
   assert.equal(calls.at(-1).args.p_limit,10000,'headline requests complete bounded history once');await frame.locator('.v178-close').click();
  }
  await page.screenshot({path:'qa/v231-'+label+'-expense-overview.png',fullPage:true});
  await frame.locator('.v178-coverage-open').first().click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(await frame.locator('.v231-edit-classification').count(),0);assert.match(await frame.locator('.v181-aggregate-note').innerText(),/sem composição completa/);assert(await frame.locator('.v231-invoice-detail').isVisible());await frame.locator('.v231-invoice-detail').click();await frame.waitForSelector('#v226-detail');assert(calls.some(c=>c.name==='lts_browser_card_detail_v226'&&c.args.p_month==='2025-09-01'));
  await frame.evaluate(()=>{document.getElementById('v226-detail')?.close();window.__LTS_V178_REVIEW.closeDetail()});
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.openDetail('Família',null,{from:'2013-10-10',to:'2026-09-30'},1500.25));
  await frame.waitForSelector('.v231-edit-classification');assert.match(await frame.locator('.v231-source-note').innerText(),/linha\(s\) 25/);
  await frame.locator('.v231-edit-classification').click();await frame.waitForSelector('#v231Classification select[name=category]');
  assert.equal(writes,0,'opening editor is read only');await frame.locator('#v231Classification [data-close]').first().click();assert.equal(writes,0,'cancel is read only');
  await frame.locator('.v231-edit-classification').click();await frame.waitForSelector('#v231Classification select[name=category]');await frame.locator('#v231Classification [name=category]').selectOption('Presentes');await frame.locator('#v231Classification [type=submit]').click();
  await frame.waitForFunction(()=>document.querySelector('#v231Classification [role=status]')?.textContent.includes('Não foi possível salvar'));assert.equal(writes,0,'failed write never reports success');await frame.locator('#v231Classification [type=submit]').click();
  await frame.waitForFunction(()=>!document.querySelector('#v231Classification')&&window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(writes,1);assert.equal(await frame.evaluate(()=>window.__LTS_V168_STATE.expense.key),'all','classification preserves selected period');assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.count),0,'old group reflects persisted correction');
  await frame.locator('.v178-close').click();await frame.waitForFunction(()=>window.__LTS_V175_STATE.expense.data?.management_groups.some(g=>g.name==='Presentes'));
  await frame.locator('[data-v168-exp-range="12m"]').click();await frame.waitForFunction(()=>window.__LTS_V175_STATE.expense.data?.period.from==='2025-10-01');
  await kpi('Total do período').locator('button').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.total),475.5);await frame.locator('.v178-close').click();
  assert.deepEqual(errors,[]);return{label,pass:true,headline_detail_parity:true,whole_history_read:true,no_clipped_money:true,source_reference:true,aggregate_not_classifiable:true,invoice_link:true,classification_persists:true,save_failure_and_cancel:true,period_preserved:true};
 }catch(e){await page.screenshot({path:'qa/v231-'+label+'-failure.png',fullPage:true});throw e}finally{await ctx.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const browser=await chromium.launch();try{const results=[];for(const [w,label]of[[1440,'desktop'],[390,'mobile']])results.push(await run(browser,w,label));fs.writeFileSync('qa/v231-expense-drilldown.json',JSON.stringify(results,null,2));console.log(JSON.stringify(results))}finally{await browser.close()}})().catch(e=>{console.error(e);process.exitCode=1});
