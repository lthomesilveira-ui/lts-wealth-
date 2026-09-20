'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {product:baseProduct,cockpit,wealth:baseWealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V178_PORT||8788);
const session={access_token:'controlled-fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const groups=[['Apartamento · CIPÓ 396',804,10],['Rafiki',1207,1],['Benjamin — Saúde',3,20],['Larissa — Saúde',2,30],['Lucas — Saúde',4,40],['Saúde — pessoa a confirmar',1,80],['Benjamin — Educação',5,50],['Lucas — Educação',2,60],['Benjamin — Vestuário',2,9],['Lucas — Vestuário',1,70],['Larissa — despesas',2,100],['Empréstimos',2,200]];
const components=['Aquisição do imóvel','Obra e reforma','Custos de moradia','Impostos do imóvel'];
const sum=xs=>xs.reduce((a,b)=>a+b,0);
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x).replace(/\s+/g,' ');
const semantic=x=>String(x||'').replace(/\s+/g,' ').trim();
function records(group){const spec=groups.find(g=>g[0]===group);if(!spec)return[];return Array.from({length:spec[1]},(_,i)=>({key:group+':'+i,date:'2026-09-01',period:'2026-09-01',date_kind:i%13===0?'month':'day',description:'Registro sintético '+String(i+1).padStart(4,'0'),account_source:i%2?'Cartão de teste':'Conta de teste',beneficiary:group.includes('Benjamin')?'Benjamin':group.includes('Larissa')?'Larissa':group.includes('Lucas')?'Lucas':null,amount:spec[2],category:group,component:group===groups[0][0]?components[i%4]:null,subgroup:group===groups[0][0]?components[i%4]:group,status:group.includes('confirmar')?'pending':'identified'}))}
function details(args){const all=records(args.p_group).filter(r=>!args.p_subgroup||r.subgroup===args.p_subgroup),offset=args.p_offset||0,limit=args.p_limit||500;return{version:'expense-detail-v178',from:args.p_from,to:args.p_to,group:args.p_group,subgroup:args.p_subgroup,total:sum(all.map(r=>r.amount)),row_count:all.length,matched_count:all.length,offset,next_offset:offset+limit<all.length?offset+limit:null,revision:'stable-'+args.p_group+args.p_subgroup,rows:all.slice(offset,offset+limit),components:args.p_group===groups[0][0]?components.map(n=>({name:n,total:2010,rows:201})):[]}}
function report(from,to){const total=sum(groups.map(g=>g[1]*g[2]));return{version:'expense-executive-v20-v178-review',as_of:to,period:{from,to,last_available:to,months_in_selection:9},summary:{selected_total:total,card_total:total/2,account_total:total/2,monthly_average:total/9,rows:sum(groups.map(g=>g[1])),pending_identification:1},management_groups:groups.map(([name,n,value])=>({name,total:n*value,rows:n,subgroups:name===groups[0][0]?components.map(n=>({name:n,total:2010,rows:201})):[]})),monthly_detail:[{month:to.slice(0,7)+'-01',total}],coverage_disclosure:{total:0,rows:0}}}
function months(from,to){const d=new Date(from.slice(0,7)+'-01T12:00:00Z'),out=[];while(d.toISOString().slice(0,7)<=to.slice(0,7)){out.push(d.toISOString().slice(0,10));d.setUTCMonth(d.getUTCMonth()+1)}return out}
function monthly(from,to){const m=months(from,to),amount=sum(groups.map(g=>g[1]*g[2])),mt=m.map((key,i)=>({month:key,revenue:10000,expenses:i===m.length-1?amount:0,operating_balance:10000-(i===m.length-1?amount:0),extraordinary:0,cash_after_extraordinary:10000-(i===m.length-1?amount:0)}));return{version:'monthly-v178-person-integrity',from,to,months:m,monthly_totals:mt,totals:{revenue:10000*m.length,expenses:amount,operating_balance:10000*m.length-amount,extraordinary:0,cash_after_extraordinary:10000*m.length-amount},expense_groups:groups.map(g=>({label:g[0],total:g[1]*g[2],source_rows:g[1],monthly:m.map((key,i)=>({month:key,amount:i===m.length-1?g[1]*g[2]:0}))})),revenue_groups:[],extraordinary_groups:[],expense_unclassified_card_coverage:{total:0,monthly:m.map(k=>({month:k,amount:0}))},stock_sale_supplement:{total:0,monthly:[]},open_audit_issues:[]}}
function dayRow(date,en=0,ex=0,cash=-1000,available=1100){return{date,historical:false,summary:{events:en||ex?1:0,Consolidado:{entries:en,exits:ex}},Consolidado:{bank_balance:cash,economic_net:en-ex},Itaú:{net:en-ex,balance:cash},Bradesco:{net:0,balance:0},C6:{net:0,balance:0},fix86_columns:{saldo_anterior:cash-en+ex,entradas:en,saidas:ex,saldo_final:cash,liq_d0_1_recurso:100,rsus_vested:available,fgts:5000,saldo_apos_d0_1:cash+100,saldo_apos_rsu:cash+100+available,saldo_apos_fgts:cash+5100+available}}}
function flow(from,to){
 const ds=[];for(let d=new Date(from+'T12:00:00Z');d.toISOString().slice(0,10)<=to;d.setUTCDate(d.getUTCDate()+1)){const date=d.toISOString().slice(0,10);ds.push(dayRow(date,date==='2026-11-09'?300:0,date==='2026-11-05'?100:date==='2026-11-09'?300:0,date>='2026-11-05'?-1100:-1000,date>='2026-11-10'?2300:date>='2026-11-08'?1600:1100))}
 const events=[{source:'future_award_vesting_marker',event_date:'2026-11-05',account:'Corretora',category:'RSU',description:'Vesting',signed_amount:0},{source:'future_rsu_available',event_date:'2026-11-08',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:500},{source:'future_rsu_available',event_date:'2026-11-10',account:'Corretora',category:'RSU',description:'RSU disponível',signed_amount:700},{source:'legacy_fix86',source_ref:'cash-1',event_date:'2026-11-05',account:'Itaú',category:'Despesas',description:'Saída comprovada',signed_amount:-100},{source:'legacy_fix86',source_ref:'cash-2',event_date:'2026-11-09',account:'Itaú',category:'Receitas',description:'Entrada comprovada',signed_amount:300},{source:'legacy_fix86',source_ref:'cash-3',event_date:'2026-11-09',account:'Itaú',category:'Despesas',description:'Saída comprovada',signed_amount:-300}].filter(e=>e.event_date>=from&&e.event_date<=to);
 return{ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical:{days:[],events:[]},current_future:{from,to,days:ds,events}}}
}
function awards(){return{version:'awards-v178',as_of:'2026-09-17',vested_shares:1000,brokerage_cash:100,brokerage_available:1100,events:[{id:'award1',type:'RSU',regular_rsu:true,vesting_date:'2026-11-05',available_date:'2026-11-08',value:500},{id:'award2',type:'RSU',regular_rsu:true,vesting_date:'2026-11-07',available_date:'2026-11-10',value:700}]}}
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport});
 await context.addInitScript(()=>{const Native=Date;window.__TEST_NOW__='2026-09-20T13:00:00Z';class TestDate extends Native{constructor(...args){super(...(args.length?args:[Native.parse(window.__TEST_NOW__)]))}static now(){return Native.parse(window.__TEST_NOW__)}}window.Date=TestDate});
 await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 const page=await context.newPage();page.setDefaultTimeout(20000);const errors=[],calls=[];
 const flags={cashFail:true,forecastFail:true,date:'2026-09-20',cash:-1000,incomplete:false,pageFailure:false};
 page.on('pageerror',e=>errors.push(String(e.stack||e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,items:[],rows:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:baseProduct()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v178'){
   if(flags.cashFail){data={message:'deliberate cash failure'};status=503}else data={version:'cash-today-v178',status:'complete',as_of:flags.date,cash:flags.incomplete?null:flags.cash,d0:100,brokerage_available:1100,fgts:5000,available_total:flags.incomplete?1200:flags.cash+1200,day:dayRow(flags.date,0,0,flags.cash)};
  }
  else if(name==='lts_browser_expenses_v178'||/^lts_browser_expense_executive_v/.test(name))data=report(a.p_from,a.p_to);
  else if(name==='lts_browser_expense_detail_v178'){
   if(flags.pageFailure&&a.p_offset===500){data={message:'deliberate page failure'};status=503;flags.pageFailure=false}else{await new Promise(r=>setTimeout(r,a.p_group==='Rafiki'?80:5));data=details(a)}
  }
  else if(name==='lts_browser_property_archive_v178')data={rows:[{key:'component1',description:'Obra documentada',amount:10000,component:'Obra e reforma',date_kind:'historical'},{key:'component2',description:'Consórcio documentado',amount:500,component:'Consórcio',date_kind:'historical'}]};
  else if(name==='lts_browser_awards_v178')data=awards();
  else if(name==='lts_browser_monthly_v178'||/^lts_browser_monthly_balance_v/.test(name))data=monthly(a.p_from,a.p_to);
  else if(/^lts_browser_flow_v/.test(name)){
   if(flags.forecastFail){data={message:'deliberate forecast failure'};status=503}else data=flow(a.p_from,a.p_to);
  }
  else if(/^lts_browser_wealth_detail_v/.test(name))data={...baseWealth,pensions:{positions:[],total_gross_brl:0}};
  else if(name==='lts_browser_recurring_future_gap_audit_v5')data={horizon_checks:[],items:[]};
  else if(/expense_context/.test(name))data={contexts:[],natures:[],summary:{}};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 let frame;
 try{
  await page.goto(BASE+'/wip35-v178-candidate.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<180;i++){frame=page.frames().find(f=>f.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>!!window.__LTS_V178_REVIEW?.installed).catch(()=>false))break;await page.waitForTimeout(100)}
  assert(await frame.evaluate(()=>!!window.__LTS_V178_REVIEW?.installed),'V178 installed');
  const nav=n=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+n+'"]'):frame.locator('.nav [data-v="'+n+'"]');
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='error'&&window.__LTS_V178_STATE.forecast.status==='error');
  const kpi=label=>frame.locator('.v168-kpi').filter({has:frame.locator('span').filter({hasText:new RegExp('^'+label+'$')})});
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','partial sum must not masquerade as complete');
  assert((await frame.locator('.v168-dashboard').innerText()).includes('Projeção indisponível'),'failed forecast is not stale risk date');
  flags.cashFail=false;flags.forecastFail=false;
  await frame.locator('.v178-refresh').first().click();
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.forecast.status==='ready');
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),money(200),'negative cash is included');
  flags.cash=0;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===0);
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),money(1200),'zero cash is valid');
  flags.incomplete=true;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===null);
  assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','null cash blocks total');
  flags.incomplete=false;flags.cash=-1000;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data.cash===-1000);
  await frame.locator('.v178-open.amount[data-group="Rafiki"]').first().click();
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===1207&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1207);
  const scroll=frame.locator('.v178-detail-scroll');await scroll.evaluate(e=>e.scrollTop=e.scrollHeight);await page.waitForTimeout(100);
  const geometry=await scroll.evaluate(e=>({top:e.scrollTop,height:e.clientHeight,scroll:e.scrollHeight,bottom:e.getBoundingClientRect().bottom,last:e.querySelector('tbody tr:last-child').getBoundingClientRect().bottom}));
  assert(geometry.top>0&&geometry.height>0&&geometry.last<=geometry.bottom+2,'last detail row visible '+JSON.stringify(geometry));
  const before=geometry.top;await frame.evaluate(()=>render());assert.equal(await scroll.evaluate(e=>e.scrollTop),before,'background render must preserve scroll');
  await page.screenshot({path:'v178-'+label+'-last-row.png'});
  await frame.locator('.v178-filter input').fill('1207');assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1,'search full list including last row');
  await frame.locator('.v178-close').click();
  const group=groups[0][0];await frame.locator('.v178-open.amount[data-group="'+group+'"]').first().click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===804&&!window.__LTS_V178_STATE.detail.loading);
  assert(await frame.locator('.v178-detail-scroll').isHidden(),'apartment starts by components, not mixed list');
  await frame.locator('[data-component="Custos de moradia"]').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.subgroup==='Custos de moradia'&&!window.__LTS_V178_STATE.detail.loading);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),201);assert(await scroll.isVisible());await frame.locator('.v178-close').click();
  await frame.evaluate(()=>{window.__LTS_V178_REVIEW.openDetail('Rafiki',null,{from:'2020-01-01',to:'2026-09-20'},1207);setTimeout(()=>window.__LTS_V178_REVIEW.openDetail('Benjamin — Educação',null,{from:'2020-01-01',to:'2026-09-20'},250),5)});
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.group==='Benjamin — Educação'&&!window.__LTS_V178_STATE.detail.loading);await page.waitForTimeout(150);assert.equal(await frame.locator('#v178Drawer tbody tr').count(),5,'late previous response discarded');await frame.locator('.v178-close').click();
  flags.pageFailure=true;await frame.evaluate(()=>window.__LTS_V178_REVIEW.openDetail('Rafiki',null,{from:'2021-01-01',to:'2026-09-20'},1207));await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.error);
  assert.equal(await frame.locator('#v178Drawer tbody tr').count(),500,'partial data remains visible');assert(await frame.locator('.v178-retry').isVisible());await frame.locator('.v178-retry').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail?.rows.length===1207&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.locator('#v178Drawer tbody tr').count(),1207);await frame.locator('.v178-close').click();
  await nav('Despesas').click();await frame.locator('[data-v168-exp-range="6m"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.waitForSelector('.v178-rank');
  await frame.locator('.v178-open.amount[data-group="Benjamin — Saúde"]').click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-04-01');assert.equal(await frame.locator('#v178Drawer tbody tr').count(),3);await frame.locator('.v178-close').click();
  await frame.locator('[data-v168-exp-range="all"]').click();await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();await frame.waitForFunction(()=>window.__LTS_V175_STATE.monthly.data?.months?.length===156&&!window.__LTS_V175_STATE.monthly.loading);
  assert((await frame.locator('.v175-monthly').innerText()).includes('Benjamin — Educação'));
  await nav('Dashboard').click();await frame.locator('.v178-open.amount[data-group="Larissa — despesas"]').first().click();await frame.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-01-01','Dashboard detail uses own YTD, not all-history expense filter');await frame.locator('.v178-close').click();
  await nav('Fluxo de caixa').click().catch(()=>nav('Fluxo Diário').click());await frame.evaluate(()=>loadFlowRange('2026-11-04','2026-11-12'));await frame.waitForSelector('#d-2026-11-07');
  const val=async(date,index)=>semantic(await frame.locator('#d-'+date+' .fx87-cell').nth(index).innerText());
  assert.equal(await val('2026-11-05',2),money(0));assert.equal(await val('2026-11-05',7),money(1500));assert.equal(await val('2026-11-07',7),money(2200));assert.equal(await val('2026-11-08',7),money(2200),'no duplicate vesting on settlement');assert.equal(await val('2026-11-10',2),money(0));
  assert.equal(await frame.locator('.v176-rsu-delta').count(),0,'no extra inline vesting row');
  const h=await frame.locator('#d-2026-11-05').evaluate(e=>e.getBoundingClientRect().height),h2=await frame.locator('#d-2026-11-06').evaluate(e=>e.getBoundingClientRect().height);assert(Math.abs(h-h2)<1,'RSU does not change row height');
  await frame.locator('#d-2026-11-05 .exp').click();assert.equal(await frame.locator('.v178-award-detail').count(),1);assert((await frame.locator('.v178-award-detail').innerText()).includes('08/11/2026'));
  await frame.locator('#flowZero').click();await page.waitForTimeout(50);assert.equal(await frame.locator('#d-2026-11-07').count(),0);assert.equal(await frame.locator('#d-2026-11-08').count(),0);assert.equal(await frame.locator('#d-2026-11-09').count(),1,'real in and out with zero net must remain');assert.equal(await frame.locator('#d-2026-11-05').count(),1);
  await page.screenshot({path:'v178-'+label+'-flow.png'});
  await nav('Dashboard').click();flags.date='2026-09-21';await frame.evaluate(()=>{window.__TEST_NOW__='2026-09-21T13:00:00Z';render()});assert.equal(semantic(await kpi('Total disponível hoje').locator('strong').innerText()),'—','day rollover does not present stale complete total');await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.data?.as_of==='2026-09-21'&&window.__LTS_V178_STATE.cash.status==='ready');
  const dims=await frame.locator('html').evaluate(e=>({width:e.clientWidth,scroll:e.scrollWidth}));assert(dims.scroll<=dims.width+3,'no horizontal page overflow');
  assert.deepEqual(errors,[],'no uncaught errors');await page.screenshot({path:'v178-'+label+'-dashboard.png'});
  return{label,pass:true,scroll:geometry,calls:calls.length,financial_data:'synthetic fixtures; live SQL checks separate'};
 }catch(error){console.error('ORIGINAL FAILURE',String(error.stack||error));await page.screenshot({path:'v178-'+label+'-failure.png'}).catch(e=>console.error('SCREENSHOT FAILED',e.message));console.error(JSON.stringify({label,error:String(error.stack||error),errors,calls:calls.slice(-15),state:await frame?.evaluate(()=>({cash:window.__LTS_V178_STATE?.cash,detail:window.__LTS_V178_STATE?.detail?{group:window.__LTS_V178_STATE.detail.group,error:window.__LTS_V178_STATE.detail.error,rows:window.__LTS_V178_STATE.detail.rows.length}:null})).catch(()=>null)}));throw error}
 finally{await context.close()}
}
(async()=>{
 const hash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');assert.equal(hash,'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b');
 const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{} )});
 try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];const out={pass:true,version:'v178',results};fs.writeFileSync('v178-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}
 catch(e){fs.writeFileSync('v178-result.json',JSON.stringify({pass:false,error:String(e.stack||e)},null,2));process.exitCode=1}
 finally{await browser.close()}
})();
