'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const BASE=`http://127.0.0.1:${process.env.LTS_V172_PORT||8782}`;
const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const brl=value=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value);

function productFixture(){
  const value=baseProduct();
  value.card_operating={...value.card_operating,open_cycles:[{card_name:'Itaú Personnalité Mastercard',due_date:'2030-07-10',amount:10000}],closed_or_due:[],contracted_installment_floor_months:[{reference_month:'2030-07-01',detail:[{card_name:'Itaú Personnalité Mastercard',amount:3500}]},{reference_month:'2030-08-01',detail:[{card_name:'Aeternum Visa Infinite',amount:5000}]}],classification_review:{}};
  return value;
}

function managementGroups(){return[
  {name:'Financiamento imobiliário',total:166114.41,rows:120,subgroups:[{name:'CIPÓ 396',total:150000,rows:100},{name:'Casa',total:16114.41,rows:20}]},
  {name:'Empréstimos e consignado',total:73959.66,rows:31,subgroups:[{name:'Consignado · Coopharma',total:31959.66,rows:7},{name:'Empréstimo familiar · Pai e Mãe',total:42000,rows:24}]},
  {name:'Benjamin — Educação',total:46921.53,rows:25,subgroups:[{name:'Educação',total:46921.53,rows:25}]},
  {name:'Educação',total:19000,rows:9,subgroups:[{name:'Educação',total:19000,rows:9}]},
  {name:'Saúde',total:46054.53,rows:94,subgroups:[{name:'Saúde',total:46054.53,rows:94}]},
  {name:'Rafiki',total:29769.84,rows:20,subgroups:[{name:'Rafiki',total:29769.84,rows:20}]},
  {name:'Investimentos no imóvel — obra e reforma',total:15000,rows:14,subgroups:[{name:'Obra e Reforma',total:12000,rows:10},{name:'Eletrodomésticos',total:3000,rows:4}]},
  ...['Vestuário','Moradia','Restaurantes','Família','Impostos do imóvel','Energia','Mercado'].map((name,index)=>({name,total:34000-index*2500,rows:10,subgroups:[{name,total:34000-index*2500,rows:10}]}))
]}

function expenseFixture(from,to){
  const value=expensePayload(from,to);
  value.summary={...value.summary,selected_total:752104.87,card_total:338718.59,account_total:413386.28};
  value.management_groups=managementGroups();
  value.coverage_disclosure={label:'Compras de cartão ainda sem categoria',total:270849.19,rows:24,by_origin:[{name:'Itaú Personnalité Mastercard',total:180000,rows:16},{name:'Aeternum Visa Infinite',total:90849.19,rows:8}]};
  return value;
}

function monthKeys(from,to){
  const out=[],cursor=new Date(from.slice(0,7)+'-01T12:00:00Z'),end=to.slice(0,7);
  while(cursor.toISOString().slice(0,7)<=end){out.push(cursor.toISOString().slice(0,7)+'-01');cursor.setUTCMonth(cursor.getUTCMonth()+1)}
  return out;
}

function monthlyFixture(from,to){
  const months=monthKeys(from,to),monthly=amount=>months.map(month=>({month,amount})),count=months.length;
  return{version:'monthly-balance-v2-v171-professional-taxonomy',from,to,months,totals:{revenue:100000*count,expenses:90000*count,operating_balance:10000*count,extraordinary:25000*count,cash_after_extraordinary:35000*count},monthly_totals:months.map(month=>({month,revenue:100000,expenses:90000,operating_balance:10000,extraordinary:25000,cash_after_extraordinary:35000})),revenue_groups:[{label:'Salário',total:100000*count,source_rows:count,monthly:monthly(100000)}],extraordinary_groups:[{label:'Venda de bens e ativos',total:25000*count,source_rows:count,monthly:monthly(25000)}],expense_groups:[{label:'Financiamento imobiliário',total:50000*count,source_rows:count,monthly:monthly(50000)},{label:'Benjamin — Educação',total:40000*count,source_rows:count,monthly:monthly(40000)}],expense_unclassified_card_coverage:{label:'Compras de cartão ainda sem categoria',total:5000*count,source_rows:count,monthly:monthly(5000)}};
}

function wealthFixture(){return{
  ...baseWealth,version:'wealth-detail-v5-v171-morgan-reconciled',as_of:'2030-06-15',
  wealth:{...baseWealth.wealth,liquidity:{bank_cash:48000,d0:12000,fgts_contingency:25000},summary:{...baseWealth.wealth.summary,known_debt_total:450000},assets:{cipo_396:{market_central:1700000,documentary_debt:400000},volvo_xc40:{market_central:120000,documented_financed_balance:50000}}},
  wealth_v167:{net_worth_central_including_pensions:1600000,assets_central_including_pensions:2050000},
  pensions:{total_gross_brl:150000,positions:[{name:'Organon Multiprev',as_of:'2030-06-14',gross_balance_brl:100000},{name:'Novartis Previ Plano D',as_of:'2030-05-31',gross_balance_brl:50000}]},
  rsu_summary:{as_of:'2030-06-15',vested_shares_brl:13012.45,brokerage_cash_brl:2900.99,available_total_brl:15913.44,future_regular_brl:1142654.04,future_cash_net_brl:411052.03,future_considered_total_brl:1553706.07},
  morgan_statement:{as_of:'2030-06-15',gross_total_brl:1745784.67,available_total_brl:15913.44,available_components:{vested_shares_brl:13012.45,brokerage_cash_brl:2900.99},future_components:{regular_rsu_gross_brl:1142654.04,cash_rsu_gross_brl:587217.19,cash_rsu_after_reserve_brl:411052.03,future_after_reserve_brl:1553706.07},considered_total_after_reserve_brl:1569619.51,quantities:{future_regular_rsu:16080,future_cash_rsu:8310},planning_schedule_reconciliation:{regular_delta_brl:0,cash_delta_brl:0}},
  financing:{summary:{commitments:[{id:'coopharma',remaining_scheduled_outflow_current_terms:31157.14,remaining_events:7},{id:'pai_mae',remaining_scheduled_outflow_current_terms:80000,remaining_events:10}]},documentary:{items:[]}}
}}

function historicalFlow(){
  const proof={version:'tracked-bank-cash-arithmetic-v1',operating_entries_brl:200,operating_exits_brl:0,internal_transfer_net_brl:0,tracked_bank_net_brl:200,arithmetic_gap_brl:0,balanced:true};
  return{from:'2030-06-10',to:'2030-06-14',available_year_from:2013,available_year_to:2041,version:'daily-flow-browser-v11-fast',historical:{days:[{date:'2030-06-14',historical:true,Consolidado:{bank_balance:1000,economic_net:200,balance_certified:false},'Itaú':{balance:1000,net:200},Bradesco:{balance:0,net:0},C6:{balance:0,net:0},fix86_columns:{saldo_anterior_operacional:800,saldo_final_operacional:1000},summary:{entries:200,exits:0,net:200},v170_cash_arithmetic:proof}],events:[{event_date:'2030-06-14',description:'Entrada histórica recuperada',account:'Itaú',signed_amount:200,source:'historical',source_ref:'fixture:historical'}]},current_future:{days:[],events:[]}};
}

function futureFlow(){
  const day=(date,bank)=>({date,Consolidado:{bank_balance:bank,economic_net:0},'Itaú':{balance:bank},Bradesco:{balance:0},C6:{balance:0},fix86_columns:{saldo_anterior:bank,saldo_final:bank,liq_d0_1_recurso:12000,saldo_apos_d0_1:bank+12000,rsus_vested:15913.44,morgan_available_total_brl:15913.44,saldo_apos_rsu:bank+27913.44,disponivel_total:bank+27913.44,posicao_curto_prazo:bank+27913.44,fgts:25000,saldo_apos_fgts:bank+52913.44,rsus_futuras:1142654.04,cash_awards_futuros:411052.03,posicao_economica_total:bank+1606619.51}});
  return{from:'2030-06-15',to:'2030-12-31',available_year_from:2013,available_year_to:2041,version:'daily-flow-browser-v12-v171-auditable-balances',historical:{days:[],events:[]},current_future:{days:[day('2030-06-15',48000),day('2030-12-31',17000)],events:[]}};
}

async function frameReady(page,label){
  for(let i=0;i<300;i++){
    const frame=page.frames().find(item=>{try{return new URL(item.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V172_V171_REVIEW?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:`v172-${label}-failure.png`,fullPage:true});throw Error(label+': V172 frame not ready');
}

async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const NativeDate=Date,fixedMs=NativeDate.parse(fixed);class FixedDate extends NativeDate{constructor(...args){super(...(args.length?args:[fixedMs]))}static now(){return fixedMs}}window.Date=FixedDate},'2030-06-15T12:00:00Z');
  await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();page.setDefaultTimeout(30000);const errors=[],consoleErrors=[],calls=[];
  page.on('pageerror',error=>errors.push(String(error.message||error)));page.on('console',message=>{if(message.type()==='error')consoleErrors.push(message.text())});page.on('dialog',dialog=>dialog.accept());
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}calls.push({name,args});let body={ok:true,rows:[],items:[]};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(/^lts_browser_expense_executive_v/.test(name))body=expenseFixture(args.p_from||'2030-01-01',args.p_to||'2030-06-15');
    else if(name==='lts_browser_expense_context_lens_v1'||name==='lts_browser_expense_context_nature_v1')body={contexts:[],natures:[],summary:{}};
    else if(/^lts_browser_wealth_detail_v/.test(name))body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_monthly_balance_v2'||name==='lts_browser_monthly_balance_v1')body=monthlyFixture(args.p_from,args.p_to);
    else if(name==='lts_browser_flow_v11')body={ok:true,flow:historicalFlow()};
    else if(name==='lts_browser_flow_v12'){
      if(String(args.p_to)<String('2030-06-15'))return route.fulfill({status:504,contentType:'application/json',body:JSON.stringify({message:'controlled historical timeout'})});
      body={ok:true,flow:futureFlow()};
    }
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(`${BASE}/wip35-v172-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  const frame=await frameReady(page,label),route=name=>viewport.width<=520?frame.locator(`#dx1MobileNav [data-mobile-route="${name}"]`):frame.locator(`.nav [data-v="${name}"]`);
  const brandVersion=await frame.locator('.brand small').evaluate(node=>getComputedStyle(node,'::before').content),scopeVersion=await page.locator('#scope').evaluate(node=>getComputedStyle(node,'::before').content);if(!brandVersion.includes('V172')||!scopeVersion.includes('V172'))throw Error(`${label}: visible version is not V172`);

  await frame.waitForFunction(()=>window.__LTS_V168_STATE?.dashboard?.data?.expense?.management_groups);
  let text=semantic(await frame.locator('.v168-dashboard').innerText());for(const phrase of ['financiamento imobiliário','empréstimos','benjamin — educação','rafiki','faturas conciliadas pelo total'])if(!text.includes(phrase))throw Error(`${label}: Dashboard missing ${phrase}`);if(text.includes('empréstimos e consignado'))throw Error(`${label}: old loan label remains`);if(await frame.locator('.v172-rankrow small').count())throw Error(`${label}: redundant grey subtitles remain`);
  if(label==='desktop')await page.screenshot({path:'v172-desktop-dashboard.png',fullPage:true});

  await route('Despesas').click();await frame.waitForFunction(()=>V==='Despesas'&&window.__LTS_V168_STATE?.expense?.data?.management_groups);
  await frame.locator('.v168-tabs [data-v168-exp-tab="categories"]').click();await frame.locator('.v172-categories details').evaluateAll(nodes=>nodes.forEach(node=>node.open=true));text=semantic(await frame.locator('.v172-categories').innerText());for(const phrase of ['financiamento imobiliário — cipó 396','financiamento imobiliário — casa','empréstimo consignado · coopharma','faturas conciliadas pelo total'])if(!text.includes(phrase))throw Error(`${label}: Categories missing ${phrase}`);
  if(label==='desktop')await page.screenshot({path:'v172-desktop-categories.png',fullPage:true});
  await frame.locator('[data-v168-exp-range="all"]').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.key==='all'&&window.__LTS_V168_STATE?.expense?.data?.management_groups);
  await frame.locator('.v168-tabs [data-v168-exp-tab="monthly"]').click();await frame.waitForFunction(()=>window.__LTS_V169_STATE?.monthly?.data?.version==='monthly-balance-v3-v172-chunked',{timeout:30000});
  const monthlyState=await frame.evaluate(()=>({calls:window.__LTS_V172_STATE.monthlyChunkCalls,months:window.__LTS_V169_STATE.monthly.data.months,totals:window.__LTS_V169_STATE.monthly.data.totals}));if(monthlyState.calls<10||monthlyState.months[0]!=='2013-10-01'||monthlyState.months.at(-1)!=='2030-06-01')throw Error(`${label}: full-period monthly merge failed ${JSON.stringify(monthlyState)}`);text=semantic(await frame.locator('.v172-monthly').innerText());for(const phrase of ['venda de ações, rsus e outros ativos','faturas conciliadas pelo total','out de 13','jun de 30'])if(!text.includes(phrase))throw Error(`${label}: monthly balance missing ${phrase}`);

  await route('Patrimônio').click();await frame.waitForFunction(()=>window.__LTS_V168_STATE?.wealth?.data?.morgan_statement);text=semantic(await frame.locator('.v172-wealth-overview').innerText());for(const phrase of ['patrimônio líquido hoje','bens e ativos atuais','dinheiro e investimentos líquidos','financiamentos e empréstimos','empréstimo consignado · coopharma','empréstimo familiar · pai e mãe'])if(!text.includes(phrase))throw Error(`${label}: wealth overview missing ${phrase}`);for(const phrase of ['obrigações sem saldo','valor central documentado'])if(text.includes(phrase))throw Error(`${label}: wealth overview retains ${phrase}`);
  if(label==='desktop')await page.screenshot({path:'v172-desktop-wealth.png',fullPage:true});
  await frame.locator('[data-v168-wealth-tab="rsu"]').click();text=semantic(await frame.locator('.v168-wealth').innerText());for(const phrase of ['total bruto do extrato',semantic(brl(1745784.67)),'disponível agora',semantic(brl(15913.44)),'a receber líquido projetado','total líquido projetado'])if(!text.includes(phrase))throw Error(`${label}: Morgan panel missing ${phrase}`);if(text.includes('reserva fiscal projetada'))throw Error(`${label}: tax reserve KPI remains`);
  if(label==='desktop')await page.screenshot({path:'v172-desktop-morgan.png',fullPage:true});

  await route('Fluxo Diário').click();try{await frame.waitForFunction(()=>V==='Fluxo Diário'&&!FLOWLOADING&&FLOWFROM==='2030-06-10'&&FLOWTO==='2030-12-31'&&FLOWQ?.historical?.days?.length&&FLOWQ?.current_future?.days?.length,{timeout:30000})}catch(error){const diagnostic=await frame.evaluate(()=>({V,FLOWLOADING,FLOWFROM,FLOWTO,FLOWPRESET,error:FLOWQ?.error,historical:FLOWQ?.historical?.days?.length,future:FLOWQ?.current_future?.days?.length,state:window.__LTS_V172_STATE}));throw Error(`${label}: Flow opening timeout ${JSON.stringify(diagnostic)} calls=${JSON.stringify(calls.filter(call=>call.name.includes('flow')))}`)}
  const flowCalls=calls.filter(call=>/^lts_browser_flow_v1[12]$/.test(call.name)),defaultHistory=flowCalls.filter(call=>call.name==='lts_browser_flow_v11'&&call.args.p_from==='2030-06-10'&&call.args.p_to==='2030-06-14'),defaultFuture=flowCalls.filter(call=>call.name==='lts_browser_flow_v12'&&call.args.p_from==='2030-06-15'&&call.args.p_to==='2030-12-31');if(defaultHistory.length!==1||defaultFuture.length!==1)throw Error(`${label}: resilient Flow calls are duplicated or missing ${JSON.stringify(flowCalls)}`);text=semantic(await frame.locator('.wrap').innerText());if(text.includes('não foi possível carregar este período')||text.includes('histórico auditável'))throw Error(`${label}: Flow blanked or retained audit banner`);const historical=frame.locator('#fv-2030-06-14,#d-2030-06-14').first();await historical.waitFor({state:'visible'});const cells=await historical.locator(':scope > .fx87-cell').allTextContents();if([cells[1],cells[4]].some(value=>String(value).includes('—')))throw Error(`${label}: historical balances are blank ${JSON.stringify(cells)}`);const labels=await frame.locator('.fx87-cons.fx87-head>div').evaluateAll(nodes=>nodes.slice(7,9).map(node=>getComputedStyle(node,'::after').content.replaceAll('"','')));if(labels[0]!=='RSU vested'||labels[1]!=='Saldo c/ RSU')throw Error(`${label}: validated Flow columns changed ${JSON.stringify(labels)}`);

  const dims=await frame.locator('html').evaluate(element=>({scroll:element.scrollWidth,client:element.clientWidth}));if(dims.scroll>dims.client+3)throw Error(`${label}: horizontal overflow ${JSON.stringify(dims)}`);if(errors.length)throw Error(`${label}: page errors ${JSON.stringify(errors)}`);const relevant=consoleErrors.filter(value=>!value.includes('favicon.ico')&&!value.includes('504'));if(relevant.length)throw Error(`${label}: console errors ${JSON.stringify(relevant)}`);
  await page.screenshot({path:`v172-${label}-final.png`,fullPage:true});await context.close();return{label,pass:true,viewport,monthlyChunks:monthlyState.calls,monthlyMonths:monthlyState.months.length,flowCalls};
}

(async()=>{const browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_EXECUTABLE?{executablePath:process.env.LTS_CHROMIUM_EXECUTABLE}:{})});try{const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')],output={pass:true,version:'v172-v171-review',data:'controlled-fixture-not-user-data-validation',results};fs.writeFileSync('v172-v171-review-result.json',JSON.stringify(output,null,2));console.log(JSON.stringify(output,null,2))}catch(error){const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};fs.writeFileSync('v172-v171-review-result.json',JSON.stringify(output,null,2));console.error(output.error);process.exitCode=1}finally{await browser.close()}})();
