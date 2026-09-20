'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:8788';
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const pending='Identificações pendentes',coverage='Faturas conciliadas pelo total';
const entries=[{key:'pending-1',description:'  =1+1',amount:10},{key:'pending-2',description:'Item sem pessoa',amount:11},{key:'pending-3',description:'Último registro',amount:-1}].map(r=>({...r,date:null,period:'2026-09-01',date_kind:'month',account_source:'Cartão sintético',beneficiary:null,category:'Saúde — pessoa a confirmar',component:null,subgroup:'Saúde',status:'pending',review_question:'De quem é esta despesa?'}));
const generic=Array.from({length:121},(_,i)=>({name:'Grupo sintético '+String(i+1).padStart(3,'0'),total:1,rows:1,subgroups:[]}));
const groups=[{name:'Saúde — pessoa a confirmar',total:20,rows:3,subgroups:[]},...generic,{name:coverage,total:100,rows:1,subgroups:[]}];
const report=(from,to)=>({version:'expense-executive-v20-v178-review',as_of:to,period:{from,to},summary:{selected_total:241,card_total:120,account_total:121,monthly_average:26.78,rows:125,pending_identification:3},management_groups:groups,monthly_detail:[],coverage_disclosure:{total:100,rows:1}});
function details(a){const rows=a.p_group===pending?entries:[{...entries[1],key:'other',description:'Lançamento sintético',amount:a.p_group===coverage?100:1,status:'identified',review_question:null}];return{version:'expense-detail-v178',group:a.p_group,subgroup:null,from:a.p_from,to:a.p_to,total:rows.reduce((s,r)=>s+r.amount,0),row_count:rows.length,matched_count:rows.length,offset:0,next_offset:null,revision:'stable',rows,components:[]}}
const day=date=>({date,Itaú:{balance:0,net:0},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},Consolidado:{bank_balance:0},fix86_columns:{saldo_final:0,entradas:0,saidas:0,liq_d0_1_recurso:100,rsus_vested:25,rsus_futuras:10,cash_awards_futuros:null,saldo_apos_d0_1:100,saldo_apos_rsu:125,saldo_apos_fgts:125,fgts:0}});
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,acceptDownloads:true});
 await context.addInitScript(()=>{const Native=Date;class Fixed extends Native{constructor(...a){super(...(a.length?a:['2026-09-20T13:00:00Z']))}static now(){return Native.parse('2026-09-20T13:00:00Z')}}window.Date=Fixed});
 await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
 const page=await context.newPage();page.setDefaultTimeout(25000);const errors=[];page.on('pageerror',e=>errors.push(e.message));let completePensions=false;
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const name=new URL(route.request().url()).pathname.split('/').pop();let a={};try{a=JSON.parse(route.request().postData()||'{}')}catch{}let data={ok:true,rows:[],items:[]};
  if(name==='token')data=session;
  else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
  else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
  else if(name==='lts_browser_cash_today_v178')data={version:'cash-today-v178',status:'complete',as_of:'2026-09-20',cash:0,d0:100,brokerage_available:25,available_total:125,fgts:0,day:day('2026-09-20')};
  else if(/^lts_browser_expense_executive_v/.test(name)||name==='lts_browser_expenses_v178')data=report(a.p_from,a.p_to);
  else if(name==='lts_browser_expense_detail_v178')data=details(a);
  else if(name==='lts_browser_awards_v178')data={as_of:'2026-09-20',vested_shares:25,brokerage_cash:0,brokerage_available:25,events:[]};
  else if(/^lts_browser_flow_v/.test(name))data={ok:true,flow:{historical:{days:[],events:[]},current_future:{days:[day(a.p_from),day(a.p_to)],events:[]}}};
  else if(/^lts_browser_wealth_detail/.test(name))data={...wealth,rsu_summary:{future_regular_brl:10,future_cash_net_brl:null,future_considered_total_brl:10},pensions:{positions:[{name:'Organon',gross_balance_brl:0},{name:'Novartis',gross_balance_brl:completePensions?0:null}],total_gross_brl:0}};
  else if(/expense_context/.test(name))data={contexts:[],natures:[],summary:{}};
  await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
 });
 try{
  await page.goto(BASE+'/wip35-v178-candidate.html',{waitUntil:'domcontentloaded'});
  let f;for(let i=0;i<200;i++){f=page.frames().find(f=>f.url().includes('/index.html'));if(f&&await f.evaluate(()=>!!window.__LTS_V178_REVIEW_ACTIONS).catch(()=>false))break;await page.waitForTimeout(100)}
  assert(f&&await f.evaluate(()=>!!window.__LTS_V178_REVIEW_ACTIONS),'review actions installed');
  await f.waitForFunction(()=>window.__LTS_V178_STATE.wealth.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready');
  const value=label=>f.locator('.v168-dashboard .v168-kpi').filter({has:f.locator('span').filter({hasText:new RegExp('^'+label+'$')})}).locator('strong');
  assert.equal((await value('Total em previdências').innerText()).trim(),'—','missing position is not a zero total');
  assert.equal((await value('Total de posições futuras').innerText()).trim(),'—','one missing future component blocks total');
  completePensions=true;await f.evaluate(()=>window.__LTS_V178_REVIEW.refresh());await f.waitForFunction(()=>window.__LTS_V178_STATE.wealth.status==='ready'&&window.__LTS_V178_STATE.wealth.data.pensions.positions[1].gross_balance_brl===0);
  assert((await value('Total em previdências').innerText()).includes('0,00'),'documented zero positions are valid');
  await f.locator('.v178-pending-open').first().click();await f.waitForSelector('.v178-export-pending:not([disabled])');
  assert.equal(await f.locator('#v178Drawer tbody tr').count(),3);assert.equal(await f.locator('.v178-question').count(),3);
  await f.locator('.v178-filter input').fill('Último');assert.equal(await f.locator('#v178Drawer tbody tr').count(),1);assert.equal(await f.locator('.v178-question').count(),1);
  const wait=page.waitForEvent('download');await f.locator('.v178-export-pending').click();const download=await wait;const path='v178-'+label+'-pending-fixture.csv';await download.saveAs(path);const csv=fs.readFileSync(path,'utf8');assert.equal(csv.trim().split(/\r?\n/).length,4,'export includes complete list, not filtered subset');assert(csv.includes("'  =1+1"),'CSV text cannot execute a formula');assert(csv.includes('"-1,00"'),'credits preserve signed amounts');
  await f.locator('.v178-close').click();await f.locator('.v178-coverage-open').first().click();await f.waitForFunction(()=>window.__LTS_V178_STATE.detail?.count===1&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await f.evaluate(()=>window.__LTS_V178_STATE.detail.total),100);await f.locator('.v178-close').click();
  const nav=viewport.width<=520?f.locator('#dx1MobileNav [data-mobile-route="Despesas"]'):f.locator('.nav [data-v="Despesas"]');await nav.click();await f.locator('[data-v168-exp-range="6m"]').click();await f.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await f.waitForFunction(()=>window.__LTS_V175_STATE.expense.data?.period?.from==='2026-04-01');
  assert.equal(await f.locator('.v168-expenses .v178-rankrow').count(),122,'all categories remain accessible beyond first 99');
  await f.locator('.v168-expenses .v178-open.amount[data-group="Grupo sintético 121"]').click();await f.waitForFunction(()=>window.__LTS_V178_STATE.detail?.count===1&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await f.evaluate(()=>window.__LTS_V178_STATE.detail.range.from),'2026-04-01');await f.locator('.v178-close').click();
  assert.deepEqual(errors,[]);return{label,pass:true,exported_rows:3,visible_categories:122};
 }finally{await context.close()}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[await run(browser,{width:1440,height:1000},'desktop-actions'),await run(browser,{width:390,height:844},'mobile-actions')];fs.writeFileSync('v178-actions-result.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify(results))}catch(e){fs.writeFileSync('v178-actions-result.json',JSON.stringify({pass:false,error:String(e.stack||e)},null,2));console.error(e);process.exitCode=1}finally{await browser.close()}})();
