'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'history-audit-fixture',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture-user'}};
const shift=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
function day(date){
 const historical=date<'2026-10-01',unknown=date==='2019-01-03',second=date==='2019-01-02';
 const banks={'Itaú':{opening_balance:second?80:100,balance:unknown?-999999:second?90:80,cash_entries:second?10:5,cash_exits:second?0:25},Bradesco:{opening_balance:200,balance:200,cash_entries:0,cash_exits:0},C6:{opening_balance:second?270:300,balance:270,cash_entries:second?0:15,cash_exits:second?0:45}};
 for(const [b,z]of Object.entries(banks))Object.assign(z,{net:z.cash_entries-z.cash_exits,workbook_cash_reconciled:historical&&!unknown,workbook_evidence_ref:unknown?null:'fixture-evidence-'+b,source_arithmetic_gap:0,balance_basis:unknown?'relative_tracked_bank_ledger':'corroborated_original_workbook_cells'});
 if(second)Object.assign(banks['Itaú'],{workbook_cash_reconciled:false,workbook_evidence_ref:null,documentary_reconstruction:true,documentary_anchor_ref:'fixture-before',balance_basis:'bounded_original_workbook_cash_reconstruction',bounded_workbook_evidence:{before_date:'2018-12-31',after_date:'2019-01-04',before_evidence_ref:'fixture-before',after_evidence_ref:'fixture-after',boundary_gap_brl:0}});
 const closing=second?560:550,opening=second?550:600,en=second?10:20,ex=second?0:70;
 return{date,historical,relative_balance_display:unknown,...banks,Consolidado:{bank_balance:unknown?-999999:closing,net:en-ex,economic_net:en-ex,workbook_cash_reconciled:historical&&!unknown&&!second,documentary_reconstruction:second,balance_basis:unknown?'relative_tracked_bank_ledger':second?'bounded_original_workbooks_and_effective_cash':'corroborated_original_workbook_cells'},v170_cash_arithmetic:{balanced:!unknown},fix86_columns:{saldo_anterior:opening,saldo_anterior_operacional:opening,saldo_final:unknown?-999999:closing,saldo_final_operacional:unknown?-999999:closing,entradas:en,saidas:ex,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:closing+400,saldo_apos_rsu:closing+600,saldo_apos_fgts:closing+650}};
}
function flow(from,to){const days=[];for(let d=from;d<=to;d=shift(d,1))days.push(day(d));return{ok:true,flow:{from,to,historical:{days:days.filter(x=>x.historical),events:from<='2019-01-01'&&to>='2019-01-01'?[{event_date:'2019-01-01',account:'Itaú',signed_amount:-10,source:'fixture_event',source_ref:'fixture',description:'Movimento parcial'}]:[]},current_future:{days:days.filter(x=>!x.historical),events:[]}}}}
const periods=(year)=>Array.from({length:12},(_,i)=>({period_start:year+'-'+String(i+1).padStart(2,'0')+'-01',period_end:year+'-'+String(i+1).padStart(2,'0')+'-28',status:'review',actual_events:0,future_events:0}));
const audit={future_horizon_end:'2031-12-31',horizon_review_count:2,items:[],horizon_checks:[{key:'salary_advance',title:'Adiantamento quinzenal',description:'Adiantamento quinzenal',cadence:'monthly',direction:'income',review_kind:'planning_review',missing_years:[2026,2031],observed_median_amount_brl:100,period_coverage:[{period_start:'2026-10-01',period_end:'2026-10-31',status:'covered',actual_events:1,future_events:0},{period_start:'2026-11-01',period_end:'2026-11-30',status:'review',actual_events:0,future_events:0},...periods(2031)]},{key:'insurance',title:'Seguro Volvo',description:'Seguro Volvo',direction:'expense',cadence:'monthly',review_kind:'planning_review',missing_years:[2026,2031],observed_median_amount_brl:200,period_coverage:[{period_start:'2026-11-01',period_end:'2026-11-30',status:'review',actual_events:0,future_events:0},...periods(2031)]}]};
async function run(browser,width){
 const ctx=await browser.newContext({viewport:{width,height:1000}});await ctx.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const N=Date;class Fixed extends N{constructor(...a){super(...(a.length?a:['2026-10-01T13:00:00Z']))}static now(){return N.parse('2026-10-01T13:00:00Z')}}window.Date=Fixed},session);
 const page=await ctx.newPage(),errors=[],calls=[];page.on('pageerror',e=>errors.push(String(e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const req=route.request(),name=new URL(req.url()).pathname.split('/').pop();let a={};try{a=JSON.parse(req.postData()||'{}')}catch{}calls.push({name,args:a});let data={ok:true,rows:[],items:[]},status=200;
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if((name==='lts_browser_cash_today_v178'||name==='lts_browser_cash_today_v242'))data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-01',cash:550,d0:400,brokerage_available:200,available_total:1150,fgts:50,day:day('2026-10-01')};
  else if(name.startsWith('lts_browser_wealth_detail'))data=wealth;
  else if(/^lts_browser_flow_v/.test(name))data=flow(a.p_from,a.p_to);
  else if(name==='lts_browser_recurring_future_gap_audit_v5')data=audit;
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={period:{from:a.p_from,to:a.p_to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},management_groups:[],monthly_detail:[],coverage_disclosure:{total:0,rows:0}};
  else if(name==='lts_browser_open_finance_refresh_v1'){status=503;data={message:'fixture sync disabled'};}
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:[]};
  else if(name==='lts_browser_open_finance_pending_v225')data={transaction_count:0,rows:[]};
  else if(name==='lts_browser_card_cycles_v229')data={version:'card-cycles-v226',as_of:'2026-10-01',cards:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 let f;
 try{
  await page.goto('http://127.0.0.1:8788/releases/'+(process.env.LTS_RELEASE||'v238')+'/app.html');
  for(let i=0;i<200;i++){f=page.frames().find(x=>x.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V226).catch(()=>false))break;await page.waitForTimeout(100)}assert(f);page.setDefaultTimeout(30000);
  await f.waitForFunction(()=>window.__LTS_V178_STATE?.forecast?.status==='ready'&&window.__LTS_V178_STATE?.dashboardReport?.status==='ready');
  const nav=name=>width<520?f.locator('#dx1MobileNav [data-mobile-route="'+name+'"]'):f.locator('.nav [data-v="'+name+'"]');
  await nav('Fluxo Diário').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ&&!FLOWQ.error);
  await f.locator('#flowFrom').fill('2019-01-01');await f.locator('#flowTo').fill('2019-01-03');await f.locator('#flowApply').click();
  await f.waitForSelector('#d-2019-01-01');await page.waitForTimeout(250);
  let cells=await f.locator('#d-2019-01-01').locator(':scope > *').allTextContents();
  assert.match(cells[1],/600,00/);assert.match(cells[2],/20,00/);assert.match(cells[3],/70,00/);assert.match(cells[4],/550,00/);
  await f.locator('[data-a="Itaú"]').click();cells=await f.locator('#d-2019-01-01').locator(':scope > *').allTextContents();assert.match(cells[1],/100,00/);assert.match(cells[2],/5,00/);assert.match(cells[3],/25,00/);assert.match(cells[4],/80,00/);
  for(const bank of ['Itaú','Bradesco','C6','Consolidado']){await f.locator('[data-a="'+bank+'"]').click();const c=await f.locator('#d-2019-01-03').locator(':scope > *').allTextContents();assert.equal(c[1].trim(),'—');assert.equal(c[4].trim(),'—');}
  await f.evaluate(async()=>{ACC='Consolidado';await loadFlowRange('2019-01-02','2019-01-02')});cells=await f.locator('#d-2019-01-02').locator(':scope > *').allTextContents();assert.match(cells[1],/550,00/);assert.match(cells[4],/560,00/);
  assert.match(await f.locator('#d-2019-01-02').getAttribute('title'),/31\/12\/2018.*04\/01\/2019/);
  await f.locator('[data-a="Itaú"]').click();cells=await f.locator('#d-2019-01-02').locator(':scope > *').allTextContents();assert.match(cells[1],/80,00/);assert.match(cells[4],/90,00/);assert.equal(await f.locator('#d-2019-01-02').getAttribute('data-history-coverage'),'documented_workbook');
  await page.screenshot({path:'qa/v238-'+width+'-bounded.png',fullPage:true});
  await nav('Atualizações').click();await f.waitForSelector('#v237CoverageYear');
  assert.match(await f.locator('#v237CoverageAudit').innerText(),/Adiantamento quinzenal/);assert.match(await f.locator('#v237CoverageAudit').innerText(),/1 de 2 períodos/);assert.match(await f.locator('#v237CoverageAudit').innerText(),/Revisar: nov/);
  await f.locator('#v237CoverageYear').selectOption('2031');assert.match(await f.locator('#v237CoverageAudit').innerText(),/jan, fev, mar, abr, mai, jun, jul, ago, set, out, nov, dez/);
  assert(calls.some(c=>c.name==='lts_browser_recurring_future_gap_audit_v5'&&c.args.p_horizon_end==='2031-12-31'));
  await page.screenshot({path:'qa/v237-'+width+'-audit.png',fullPage:true});
  await f.locator('[data-v237-coverage-from]').first().click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2031-01-01');
  assert(!calls.some(c=>/mutate|create_future|classify|apply_natural/.test(c.name)),'audit never mutates facts or projections');
  assert.deepEqual(errors,[]);return{width,pass:true,documented_history_visible:true,opening_and_gross_cash_from_source:true,slice_invariant:true,unknown_not_zero:true,coverage_year_month:true,no_financial_write:true};
 }catch(e){if(f)await page.screenshot({path:'qa/v237-'+width+'-failure.png',fullPage:true});fs.writeFileSync('qa/v237-'+width+'-failure.json',JSON.stringify({error:String(e),errors,calls,runtime:f?await f.evaluate(()=>({route:V,from:FLOWFROM,to:FLOWTO,loading:FLOWLOADING,rows:mergedFlowDays().map(x=>x.date),body:document.getElementById('app')?.innerText.slice(0,1500)})).catch(()=>null):null},null,2));throw e}finally{await ctx.close()}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const b=await chromium.launch();try{const result=[];for(const width of[1440,390])result.push(await run(b,width));fs.writeFileSync('qa/v237-history-audit.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result));}finally{await b.close()}})().catch(e=>{console.error(e);process.exitCode=1});
