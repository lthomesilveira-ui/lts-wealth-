'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const PORT=process.env.LTS_V163_PORT||'8779';
const BASE=`http://127.0.0.1:${PORT}`;
const resultFile='v163-dashboard-executive-result.json';
const cockpit={
  version:'v163-controlled-browser-fixture',as_of:'2026-09-15',
  liquidity:{through_d3:150000,bank_cash:100000,d0:20000,d3_vested:30000,fgts_d30:40000,accounts:[{institution:'Itaú',balance:70000},{institution:'Bradesco',balance:25000},{institution:'C6',balance:5000}]},
  planning_audited:{first_negative_date:'2026-12-01',worst_before_brl:-12500,worst_before_date:'2026-12-12',management_point_date:'2026-11-15',fgts_request_by:'2026-11-01',worst_after_brl:27500,covers_horizon:false,fgts_future_accrual_estimated:false},
  horizons:[
    {id:'30d',label:'30 dias',date:'2026-10-15',current_liquidity_balance:80000,conditional_rsu_balance:95000,restricted_total_balance:135000},
    {id:'90d',label:'90 dias',date:'2026-12-14',current_liquidity_balance:-12500,conditional_rsu_balance:2500,restricted_total_balance:42500},
    {id:'year_end',label:'Fim do ano',date:'2026-12-31',current_liquidity_balance:-9000,conditional_rsu_balance:6000,restricted_total_balance:46000}
  ],
  expenses:{current_month:{spend:32000,top_categories:[{category:'Casa',amount:12000},{category:'Educação',amount:8000},{category:'Restaurantes',amount:5000}]},previous_month:{spend:41000}},
  cards:{open_cycles_total:14000,closed_or_due_total:3000,next_due:{due_date:'2026-09-22',amount:3000,card_name:'C6 Carbon'}},
  work:{actionable_count:2,top_actions:[{title:'Revisar documento',description:'Evidência aguardando confirmação'},{title:'Classificar lançamento',description:'Uma categoria está pendente'}]},wealth:{assets_central:1,known_debt_total:1,net_worth_central:0}
};
function product(){return {dashboard_cockpit:cockpit,updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-09-15'}},semantic_review:{pending_groups:0,items:[]},card_classification_review:{pending_groups:0,pending_lines:0,pending_value:0,category_options:[],items:[]},card_operating:{open_cycles_total:14000,open_cycles:[],next_due:cockpit.cards.next_due},card_history:{units:[]},wealth_executive:{summary:{},assets:{}},duplicate_quality_gate:{},flow:{days:[],events:[]},expenses:{},wealth:{},planning:{}}}
function flow(){return {from:'2026-09-10',to:'2026-10-15',available_year_from:2013,available_year_to:2041,historical:{days:[],events:[]},current_future:{days:[],events:[]},bank_evidence_as_of:[],version:'v163-fixture'}}
async function dashboardFrame(page,label){
  let inner=null;
  for(let attempt=0;attempt<240;attempt++){
    inner=page.frames().find(frame=>{try{return new URL(frame.url()).pathname.endsWith('/index.html')}catch(_){return false}})||null;
    if(inner){const ready=await inner.evaluate(()=>Boolean(document.querySelector('.dx1-decision')&&window.__LTS_DASHBOARD_EXECUTIVE_STATUS?.installed)).catch(()=>false);if(ready)return inner}
    await page.waitForTimeout(125);
  }
  const diagnostic=inner?await inner.evaluate(()=>({route:typeof V==='undefined'?null:V,hasData:typeof D!=='undefined'&&Boolean(D),dashboard:window.__LTS_DASHBOARD_EXECUTIVE_STATUS||null,flow:window.__LTS_V162_FLOW_RECOVERY_STATUS||null,body:document.body.innerText.slice(0,1200)})).catch(error=>({error:String(error)})):{frames:page.frames().map(frame=>frame.url())};
  await page.screenshot({path:`v163-dashboard-${label}-failure.png`,fullPage:true});
  throw new Error(`${label} dashboard frame not ready ${JSON.stringify(diagnostic)}`);
}
async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(session=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session)),{access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}});
  const page=await context.newPage();page.setDefaultTimeout(15000);const errors=[];const requested=[];page.on('pageerror',error=>errors.push(String(error.message||error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{const name=new URL(route.request().url()).pathname.split('/').pop();requested.push(name);let body={ok:true};if(name==='lts_browser_product_v1')body={ok:true,mvp:product()};else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;else if(name==='lts_browser_flow_v11')body={ok:true,flow:flow()};else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)})});
  await page.goto(`${BASE}/wip35-v163-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  const frame=await dashboardFrame(page,label);
  await frame.locator('.dx1-decision').waitFor({state:'visible',timeout:5000});
  const text=await frame.locator('.dx1').innerText();
  for(const needle of ['Tenho dinheiro suficiente?','Atenção: o caixa fica negativo','Primeiro saldo negativo','01/12/2026','Caixa coberto até','30/11/2026','Pior saldo projetado','-R$ 12.500,00','Dinheiro em contas','Contas + curto prazo','RSUs vested','FGTS','Despesas (mês)','Total consolidado ainda não certificado'])if(!text.includes(needle))throw new Error(`${label} missing ${needle}`);
  const status=await frame.locator('body').evaluate(()=>window.__LTS_DASHBOARD_EXECUTIVE_STATUS);
  if(!status||status.reader!=='lts_browser_dashboard_cockpit_v1'||status.read_only!==true||status.financial_writer_changed!==false||status.permanent_polling!==false)throw new Error(`${label} invalid status ${JSON.stringify(status)}`);
  if(!requested.includes('lts_browser_dashboard_cockpit_v1'))throw new Error(`${label} dashboard reader not requested`);
  if(await frame.locator('.dx1-kpi').count()!==5)throw new Error(`${label} expected five KPIs`);
  const dims=await frame.locator('html').evaluate(node=>({scroll:node.scrollWidth,client:node.clientWidth}));
  if(dims.scroll>dims.client+2)throw new Error(`${label} overflow ${JSON.stringify(dims)}`);
  if(label==='mobile'){
    const nav=frame.locator('#dx1MobileNav');if(!await nav.isVisible())throw new Error('mobile navigation hidden');if(await nav.locator('button').count()!==6)throw new Error('mobile navigation must have six routes');
    const routes=await nav.locator('button').allTextContents();for(const route of ['Resumo','Fluxo','Despesas','Cartões','Patrimônio','Atualizar'])if(!routes.some(value=>value.includes(route)))throw new Error(`mobile missing ${route}`);
  }
  await page.screenshot({path:`v163-dashboard-${label}.png`,fullPage:true});
  if(errors.length)throw new Error(`${label} page errors ${JSON.stringify(errors)}`);
  await context.close();return {label,viewport,pass:true,requested:[...new Set(requested)],dims};
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];const out={pass:true,version:'v163-dashboard-executive',data:'controlled-fixture-not-user-validation',results};fs.writeFileSync(resultFile,JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2))}catch(error){const out={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-validation'};fs.writeFileSync(resultFile,JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1}finally{await browser.close()}})();
