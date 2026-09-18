'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const BASE=`http://127.0.0.1:${process.env.LTS_V173_PORT||8783}`;
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const norm=value=>String(value||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();

function productFixture(){
  const value=baseProduct();
  value.card_operating={...value.card_operating,open_cycles:[],closed_or_due:[],contracted_installment_floor_months:[],classification_review:{}};
  return value;
}
function managementGroups(){return[
  {name:'Financiamento imobiliário',total:1700952.62,rows:90,subgroups:[{name:'Casa',total:1680231.96,rows:89},{name:'CIPÓ 396',total:20720.66,rows:1}],source_categories:[{name:'Financiamento Imobiliário',total:1700952.62,rows:90}]},
  {name:'Empréstimos e consignado',total:651990.34,rows:42,subgroups:[{name:'Consignado · Coopharma',total:31959.66,rows:7},{name:'Empréstimo · Itaú',total:620030.68,rows:35}],source_categories:[{name:'Empréstimos',total:620030.68,rows:35},{name:'Compromissos Financeiros',total:31959.66,rows:7}]},
  {name:'Benjamin — Educação',total:56267.53,rows:25,subgroups:[{name:'Educação',total:56267.53,rows:25}],source_categories:[{name:'Educação',total:56267.53,rows:25}]},
  {name:'Energia',total:22000,rows:15,subgroups:[{name:'Enel',total:22000,rows:15}],source_categories:[{name:'Enel',total:22000,rows:15}]},
  {name:'Financiamento de veículo',total:14813.73,rows:12,subgroups:[{name:'Financiamento Carro',total:11927.30,rows:11},{name:'Não identificado',total:2886.43,rows:1}],source_categories:[{name:'Financiamento veículo',total:14813.73,rows:12}]},
  {name:'Família',total:263909.54,rows:202,subgroups:[{name:'Família',total:263909.54,rows:202}],source_categories:[{name:'Família',total:263909.54,rows:202}]},
  {name:'Saúde',total:46054.53,rows:94,subgroups:[{name:'Saúde',total:46054.53,rows:94}],source_categories:[{name:'Saúde',total:46054.53,rows:94}]}
]}
function expenseFixture(from,to){
  const value=expensePayload(from,to);
  value.summary={...value.summary,selected_total:2759990.29,card_total:1000000,account_total:1759990.29};
  value.management_groups=managementGroups();
  value.coverage_disclosure={total:0,rows:0,by_origin:[]};
  return value;
}
function wealthFixture(){return{
  ...baseWealth,
  wealth:{...baseWealth.wealth,liquidity:{bank_cash:48000,d0:12000,fgts_contingency:25000},summary:{...baseWealth.wealth.summary,known_debt_total:450000},assets:{cipo_396:{market_central:1700000,documentary_debt:400000},volvo_xc40:{market_central:120000,documented_financed_balance:50000}}},
  wealth_v167:{net_worth_central_including_pensions:1600000,assets_central_including_pensions:2050000},
  pensions:{total_gross_brl:150000,positions:[]},
  rsu_summary:{available_total_brl:15913.44,future_considered_total_brl:1553706.07},
  morgan_statement:{available_total_brl:15913.44,future_components:{future_after_reserve_brl:1553706.07},considered_total_after_reserve_brl:1569619.51},
  financing:{summary:{commitments:[]},documentary:{items:[]}}
}}
function flowFixture(from,to){return{ok:true,flow:{from,to,historical:{days:[],events:[]},current_future:{days:[],events:[]}}}}

async function frameReady(page,label){
  for(let i=0;i<300;i++){
    const frame=page.frames().find(item=>{try{return new URL(item.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V173_V172_FEEDBACK?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:`v173-${label}-failure.png`,fullPage:true});throw Error(label+': V173 frame not ready');
}

async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const NativeDate=Date,fixedMs=NativeDate.parse(fixed);class FixedDate extends NativeDate{constructor(...args){super(...(args.length?args:[fixedMs]))}static now(){return fixedMs}}window.Date=FixedDate},'2030-09-18T12:00:00Z');
  await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],calls=[];
  page.on('pageerror',error=>errors.push(String(error.message||error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}calls.push({name,args});
    if(name==='lts_browser_apply_reviewed_input_v1')return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({message:'writer must not be called by V173 gate'})});
    let body={ok:true,rows:[],items:[]};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from||'2030-01-01',args.p_to||'2030-09-18');
    else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
    else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_flow_v11'||name==='lts_browser_flow_v12')body=flowFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_transactions_v2')body={rows:[]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(`${BASE}/wip35-v173-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  const frame=await frameReady(page,label),route=name=>viewport.width<=520?frame.locator(`#dx1MobileNav [data-mobile-route="${name}"]`):frame.locator(`.nav [data-v="${name}"]`);
  const version=await frame.evaluate(()=>window.__LTS_V173_V172_FEEDBACK);if(!version?.category_select||version?.base_version!=='v172')throw Error(label+': V173 contract missing');

  await route('Atualizações').click();
  await frame.locator('#v168NlPhrase').fill('registrar entrada conta corrente Itaú 420,00 classificado como Família em 17/09/2030');
  await frame.locator('#v168NlPreview').click();
  const category=frame.locator('select#v168NlCategory');await category.waitFor({state:'visible'});
  const categoryState=await category.evaluate(node=>({tag:node.tagName,value:node.value,options:[...node.options].map(x=>x.value)}));
  if(categoryState.tag!=='SELECT'||categoryState.value!=='Família')throw Error(label+': Família was not inferred into canonical select '+JSON.stringify(categoryState));
  if(categoryState.options.filter(x=>x==='Família').length!==1||categoryState.options.includes('A classificar'))throw Error(label+': category list is not canonical '+JSON.stringify(categoryState));
  const writerCalls=calls.filter(x=>x.name==='lts_browser_apply_reviewed_input_v1');if(writerCalls.length)throw Error(label+': interpretation wrote data');
  if(label==='desktop')await page.screenshot({path:'v173-desktop-natural-entry.png',fullPage:true});

  await route('Despesas').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.data?.management_groups);
  await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v172-categories').waitFor({state:'visible'});
  const rows=await frame.locator('.v172-categories .v172-rankrow').evaluateAll(nodes=>nodes.map(node=>({
    name:node.querySelector(':scope > div > b')?.textContent?.trim()||'',
    hasDetails:Boolean(node.querySelector('details')),
    children:[...node.querySelectorAll('details em span')].map(x=>x.textContent.trim())
  })));
  const get=name=>rows.find(x=>norm(x.name)===norm(name));
  for(const name of ['Financiamento imobiliário','Benjamin — Educação','Energia']){
    const row=get(name);if(!row||row.hasDetails)throw Error(label+': redundant composition remains for '+name+' '+JSON.stringify(row));
  }
  const loans=get('Empréstimos');if(!loans?.hasDetails||loans.children.length<2)throw Error(label+': useful loan composition was removed '+JSON.stringify(loans));
  const vehicle=get('Financiamento de veículo');if(!vehicle?.hasDetails||!vehicle.children.includes('Volvo XC40')||vehicle.children.some(x=>norm(x)==='nao identificado'))throw Error(label+': vehicle identity not corrected '+JSON.stringify(vehicle));
  if(label==='desktop')await page.screenshot({path:'v173-desktop-categories.png',fullPage:true});

  const dims=await frame.locator('html').evaluate(element=>({scroll:element.scrollWidth,client:element.clientWidth}));if(dims.scroll>dims.client+3)throw Error(label+': horizontal overflow '+JSON.stringify(dims));
  if(errors.length)throw Error(label+': page errors '+JSON.stringify(errors));
  await page.screenshot({path:`v173-${label}-final.png`,fullPage:true});await context.close();
  return{label,pass:true,category:categoryState.value,composition:rows.filter(x=>['Financiamento imobiliário','Empréstimos','Benjamin — Educação','Energia','Financiamento de veículo'].includes(x.name))};
}

(async()=>{
  const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_EXECUTABLE?{executablePath:process.env.LTS_CHROMIUM_EXECUTABLE}:{})});
  try{
    const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];
    const output={pass:true,version:'v173-v172-feedback',data:'controlled-fixture-not-user-data-validation',results};fs.writeFileSync('v173-v172-feedback-result.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2));
  }catch(error){
    const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};fs.writeFileSync('v173-v172-feedback-result.json',JSON.stringify(output,null,2));console.error(output.error);process.exitCode=1;
  }finally{await browser.close()}
})();