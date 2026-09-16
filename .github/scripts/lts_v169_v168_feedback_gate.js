'use strict';

const {chromium}=require('playwright');
const fs=require('node:fs');
const {BASE,cockpit,wealth:baseWealth,product:baseProduct,expensePayload,semantic}=require('./lts_v165_executive_ux_gate.js');

const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
const transferRef='financial_events:11111111-1111-4111-8111-111111111111';

function productFixture(){
  const data=baseProduct();
  data.card_operating={
    as_of:'2030-06-15',
    open_cycles_total:18000,
    open_cycles:[
      {card_name:'Visa Aeternum',account:'Bradesco',amount:9000,due_date:'2030-06-25',detail_preview:[{description:'Assinatura',category:'Assinaturas',amount:300}]},
      {card_name:'Personnalite Black',account:'Itaú',amount:7000,due_date:'2030-07-08',detail_preview:[{description:'Mercado',category:'Alimentação',amount:700}]},
      {card_name:'Cartão C6',account:'C6',amount:2000,due_date:'2030-07-12',detail_preview:[{description:'Transporte',category:'Transporte',amount:200}]}
    ],
    closed_or_due_total:0,closed_or_due:[],paid_recent:[],
    contracted_installment_floor_total:6500,
    contracted_installment_floor_months:[
      {reference_month:'2030-07-01',amount:4000,detail:[{card_name:'Visa Aeternum',amount:2500},{card_name:'Personnalite Black',amount:1500}]},
      {reference_month:'2030-08-01',amount:2500,detail:[{card_name:'Cartão C6',amount:2500}]}
    ],
    classification_review:{pending_lines:0,pending_value:0}
  };
  return data;
}

function wealthFixture(){
  return {
    ...baseWealth,
    as_of:'2030-06-15',
    wealth:{
      ...baseWealth.wealth,
      liquidity:{bank_cash:48000,d0:12000,d3:18000,fgts_contingency:25000},
      summary:{...baseWealth.wealth.summary,known_debt_total:450000,restricted_contingency:25000},
      assets:{
        cipo_396:{market_central:1700000,documentary_debt:400000,equity_central:1300000,historical_purchase_plus_reform:900000},
        volvo_xc40:{market_central:120000,documented_financed_balance:50000,equity_central:70000}
      }
    },
    wealth_v167:{net_worth_central_including_pensions:1600000,assets_central_including_pensions:2050000},
    rsu_summary:{as_of:'2030-06-15',vested_shares_brl:15000,brokerage_cash_brl:2500,available_total_brl:17500,future_regular_brl:321250,future_cash_net_brl:78750,future_considered_total_brl:400000},
    pensions:{total_gross_brl:150000,positions:[
      {name:'Organon Multiprev',as_of:'2030-06-14',gross_balance_brl:100000,participant_balance_brl:60000,sponsor_balance_brl:40000,profile:'Moderado'},
      {name:'Novartis Previ Plano D',as_of:'2030-05-31',gross_balance_brl:50000,participant_balance_brl:30000,sponsor_balance_brl:20000,profile:'Moderado'}
    ]},
    rsu:{...baseWealth.rsu,future_schedule:baseWealth.rsu.future_schedule},
    financing:{summary:{commitments:[
      {id:'cipo_396',label:'CIPÓ 396',current_documentary_debt_balance:400000,current_debt_as_of:'2030-06-14',remaining_scheduled_outflow_current_terms:900000,total_events:360,remaining_events:300},
      {id:'volvo',label:'Volvo XC40',current_documentary_debt_balance:50000,current_debt_as_of:'2030-06-01',remaining_scheduled_outflow_current_terms:76000,total_events:48,remaining_events:38},
      {id:'coopharma',label:'Coopharma',current_documentary_debt_balance:null,remaining_scheduled_outflow_current_terms:31157.14,total_events:24,remaining_events:7},
      {id:'pai_mae',label:'Pai e Mãe',current_documentary_debt_balance:null,remaining_scheduled_outflow_current_terms:80000,total_events:20,remaining_events:10}
    ]},documentary:{items:[]}},
    cipo_detail:{historical_purchase_plus_reform_brl:900000,current_payoff_brl:400000,contractual_outflow_current_terms_brl:900000,components:[
      {component_class:'historical_basis_summary',description:'Compra Imóvel (pago)',source_paid:300000},
      {component_class:'historical_basis_summary',description:'Reformas',source_paid:600000},
      {component_class:'improvement',category:'Marcenaria',description:'Armários',source_paid:250000,origin:'Planilha de obra'}
    ]}
  };
}

function flowFixture(){
  const row=(date,bank,base,vested,fgts)=>({date,Consolidado:{bank_balance:bank},fix86_columns:{saldo_apos_d0_1:base,saldo_apos_rsu:vested,saldo_apos_fgts:fgts}});
  return {ok:true,flow:{
    from:'2030-06-15',to:'2031-12-31',historical:{days:[],events:[]},
    current_future:{
      days:[
        row('2030-06-15',48000,60000,78000,103000),row('2030-09-30',42000,24000,44000,69000),
        row('2030-12-20',18000,-5000,12000,37000),row('2030-12-31',17000,-7000,9000,34000),
        row('2031-03-10',15000,-8000,-2000,23000),row('2031-06-30',14000,-9000,-3000,19000),
        row('2031-12-31',12000,-12000,-4000,11000)
      ],
      events:[
        {event_date:'2030-06-15',description:'Transferência Itaú para Bradesco',account:'Itaú',category:'Transferência interna',signed_amount:-20665,source:'internal_transfer',source_ref:transferRef,confidence:'user_flow_editable',internal_transfer:true},
        {event_date:'2030-06-15',description:'Transferência Itaú para Bradesco',account:'Bradesco',category:'Transferência interna',signed_amount:20665,source:'internal_transfer',source_ref:transferRef,confidence:'user_flow_editable',internal_transfer:true},
        {event_date:'2030-06-25',description:'Visa Aeternum',account:'Bradesco',signed_amount:-9000,source:'current_event',source_ref:'card:one',confidence:'documented_expected'}
      ]
    },
    bank_evidence_as_of:[{bank:'Itaú',date:'2030-06-14'}],version:'v169-fixture'
  }};
}

function expenseFixture(from,to){
  const data=expensePayload(from,to),years=[];
  for(let year=2013;year<=2030;year++)years.push({year,total:(year-2012)*12000,monthly_average:(year-2012)*1000,months:12});
  data.period={from,to,last_available:'2030-06-15',months_in_selection:data.monthly_detail.length||1};
  data.yearly_detail=years;
  data.rankings={
    categories:[
      {name:'Detalhe histórico não recuperado',total:186252.10},
      {name:'Financiamento imobiliário',total:170000},
      {name:'Compromissos financeiros',total:31157.14},
      {name:'Saúde',total:46000},{name:'Educação',total:42000}
    ],
    centers:[{name:'Casa',total:310000},{name:'Benjamin',total:77000},{name:'Lucas',total:39000}]
  };
  return data;
}

function contextFixture(){return {contexts:[
  {name:'Benjamin',total:77000,categories:[{name:'Educação',total:42000},{name:'Saúde',total:35000}]},
  {name:'Casa',total:310000,categories:[{name:'Financiamento imobiliário',total:170000},{name:'Obra e reforma · CIPÓ 396',total:140000}]},
  {name:'Lucas',total:39000,categories:[{name:'Saúde',total:11000},{name:'Outros',total:28000}]}
]};}

function monthKeys(from,to){
  const out=[],d=new Date(String(from).slice(0,7)+'-01T12:00:00Z'),end=String(to).slice(0,7);
  while(d.toISOString().slice(0,7)<=end&&out.length<36){out.push(d.toISOString().slice(0,10));d.setUTCMonth(d.getUTCMonth()+1)}
  return out;
}

function monthlyFixture(from,to){
  const months=monthKeys(from,to),monthly=(amount)=>months.map(month=>({month,amount}));
  const revenue=months.map((month,index)=>({month,revenue:20000,expenses:30000,operating_balance:-10000,extraordinary:index===0?5000:0,cash_after_extraordinary:index===0?-5000:-10000}));
  const revenueTotal=months.length*20000,expenseTotal=months.length*30000,extraordinaryTotal=months.length?5000:0;
  return {
    version:'monthly-balance-v1',period:{from,to},months,
    totals:{revenue:revenueTotal,expenses:expenseTotal,operating_balance:revenueTotal-expenseTotal,extraordinary:extraordinaryTotal,cash_after_extraordinary:revenueTotal-expenseTotal+extraordinaryTotal},
    monthly_totals:revenue,
    revenue_groups:[{label:'Remuneração',source_rows:months.length,total:revenueTotal,monthly:monthly(20000)}],
    extraordinary_groups:[{label:'FGTS e venda de bens',source_rows:1,total:extraordinaryTotal,monthly:months.map((month,index)=>({month,amount:index===0?5000:0}))}],
    expense_groups:[
      {label:'Moradia e financiamentos',source_rows:months.length,total:months.length*18000,monthly:monthly(18000)},
      {label:'Empréstimo consignado · Coopharma',source_rows:months.length,total:months.length*4451.02,monthly:monthly(4451.02)},
      {label:'Faturas históricas sem compras individualizadas',source_rows:7,total:186252.10,monthly:months.map((month,index)=>({month,amount:index<7?26607.44:0}))}
    ],
    coverage:{historical_invoice_aggregate:186252.10,historical_invoice_months:7,excluded_internal_or_investment:630033.62,excluded_internal_or_investment_rows:62},
    guardrails:{internal_transfers_excluded:true,card_bill_payments_excluded:true,investments_excluded:true,card_purchases_count_once:true,accounting_identity_operating_ok:true,accounting_identity_cash_ok:true}
  };
}

function transferEditorFixture(){return {
  editable:true,kind:'internal_transfer_pair',source:'internal_transfer',source_ref:transferRef,
  transfer_group:'fixture-transfer',event_date:'2030-06-15',description:'Transferência Itaú para Bradesco',
  amount:20665,display_amount:20665,from_account:'Itaú',to_account:'Bradesco',consolidated_effect:0,
  actions:['edit','cancel'],legs:[
    {id:'11111111-1111-4111-8111-111111111111',event_date:'2030-06-15',account:'Itaú',signed_amount:-20665},
    {id:'22222222-2222-4222-8222-222222222222',event_date:'2030-06-15',account:'Bradesco',signed_amount:20665}
  ]
};}

async function frameReady(page,label){
  for(let attempt=0;attempt<240;attempt++){
    const frame=page.frames().find(candidate=>{try{return new URL(candidate.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V169_V168_FEEDBACK?.installed&&document.querySelector('.v168-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  await page.screenshot({path:`v169-${label}-failure.png`,fullPage:true});
  throw new Error(`${label}: V169 frame did not become ready`);
}

async function run(browser,viewport,label){
  const context=await browser.newContext({viewport});
  await context.addInitScript(fixed=>{const NativeDate=Date,fixedMs=NativeDate.parse(fixed);class FixedDate extends NativeDate{constructor(...args){super(...(args.length?args:[fixedMs]))}static now(){return fixedMs}}window.Date=FixedDate},'2030-06-15T12:00:00Z');
  await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
  const page=await context.newPage();page.setDefaultTimeout(24000);
  const errors=[],consoleErrors=[],requested=[],monthlyCalls=[],mutations=[];
  page.on('pageerror',error=>errors.push(String(error.message||error)));
  page.on('console',message=>{if(message.type()==='error')consoleErrors.push(message.text())});
  page.on('dialog',dialog=>dialog.accept());
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();requested.push(name);
    let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}
    let body={ok:true};
    if(name==='token')body=session;
    else if(name==='lts_browser_product_v1')body={ok:true,mvp:productFixture()};
    else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
    else if(name==='lts_browser_flow_v11')body=flowFixture();
    else if(name==='lts_browser_expense_executive_v4'||name==='lts_browser_expense_executive_v3')body=expenseFixture(args.p_from||'2030-01-01',args.p_to||'2030-06-15');
    else if(name==='lts_browser_expense_context_lens_v1')body=contextFixture();
    else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
    else if(name==='lts_browser_expense_drilldown_v1')body={summary:{total:4200},rows:[{event_date:'2030-05-10',description:'Escola',category:'Educação',center_cost:'Benjamin',amount:4200}]};
    else if(name==='lts_browser_wealth_detail_v3'||name==='lts_browser_wealth_detail_v2')body=wealthFixture();
    else if(name==='lts_browser_recurring_future_gap_audit_v5')body={horizon_checks:[],items:[]};
    else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
    else if(name==='lts_browser_transactions_v2')body={ok:true,total:2,rows:flowFixture().flow.current_future.events.slice(0,2).map(x=>({date:x.event_date,...x,amount:x.signed_amount}))};
    else if(name==='lts_browser_monthly_balance_v1'){monthlyCalls.push(args);body=monthlyFixture(args.p_from,args.p_to)}
    else if(name==='lts_browser_internal_transfer_editor_v1')body=transferEditorFixture();
    else if(name==='lts_browser_internal_transfer_mutate_v1'){mutations.push(args);body={ok:true,action:args.p_action,source_ref:args.p_source_ref,consolidated_effect:0}}
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(`${BASE}/wip35-v169-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  const frame=await frameReady(page,label);
  await frame.waitForFunction(()=>window.__LTS_V168_STATE?.dashboard?.pending===0);
  let text=await frame.locator('.v168-dashboard').innerText(),lower=semantic(text);
  for(const phrase of ['total disponível hoje','total de posições futuras','total em previdências','total de despesas do período','faturas históricas sem compras individualizadas','empréstimo consignado · coopharma'])if(!lower.includes(phrase))throw new Error(`${label}: Dashboard missing ${phrase}`);
  if(lower.includes('detalhe histórico não recuperado'))throw new Error(`${label}: misleading aggregate label leaked`);
  const primaryLabels=await frame.locator('.v168-dashboard .v168-kpi.primary span').allTextContents();
  for(const labelText of ['Total disponível hoje','Total de posições futuras','Total em previdências','Total de despesas do período'])if(!primaryLabels.includes(labelText))throw new Error(`${label}: total is not emphasized: ${labelText}`);
  if(!(await frame.locator('.brand small').innerText()).includes('V169'))throw new Error(`${label}: brand was not stamped V169`);
  if(!(await frame.locator('.v168-release').innerText()).includes('V169'))throw new Error(`${label}: release badge was not stamped V169`);
  if(label==='desktop'){
    const navMetrics=await frame.locator('.nav [data-v="Dashboard"]').evaluate(button=>{
      const svg=button.querySelector('svg'),span=button.querySelector('span'),style=getComputedStyle(button),a=svg?.getBoundingClientRect(),b=span?.getBoundingClientRect();
      return {justify:style.justifyContent,gap:parseFloat(style.gap||'0'),iconWidth:a?.width||0,centerDelta:a&&b?Math.abs((a.top+a.bottom-b.top-b.bottom)/2):99};
    });
    if(navMetrics.justify!=='flex-start'||navMetrics.gap<10||navMetrics.iconWidth<18||navMetrics.centerDelta>3)throw new Error(`desktop: Dashboard nav misaligned ${JSON.stringify(navMetrics)}`);
    await page.screenshot({path:'v169-desktop-dashboard.png',fullPage:true});
  }

  const route=name=>viewport.width<=520?frame.locator(`#dx1MobileNav [data-mobile-route="${name}"]`):frame.locator(`.nav [data-v="${name}"]`);
  await route('Despesas').click();
  await frame.locator('.v168-expenses').waitFor({state:'visible'});
  await frame.waitForFunction(()=>window.__LTS_V168_STATE?.expense?.loading===false);
  await frame.locator('[data-v168-exp-tab="monthly"]').click();
  await frame.locator('.v169-monthly').waitFor({state:'visible'});
  await frame.waitForFunction(()=>window.__LTS_V169_STATE?.monthly?.loading===false&&window.__LTS_V169_STATE?.monthly?.data);
  text=await frame.locator('.v169-monthly').innerText();lower=semantic(text);
  for(const phrase of ['total de receitas','total de despesas','saldo mensal operacional','receitas mês a mês','principais grupos de despesa','saldo de cada mês','transferências internas, aplicações e pagamentos de fatura não entram como consumo'])if(!lower.includes(phrase))throw new Error(`${label}: monthly balance missing ${phrase}`);
  if(label==='desktop'){
    await frame.locator('[data-v168-exp-range="12m"]').click();
    await frame.waitForFunction(()=>window.__LTS_V169_STATE?.monthly?.loading===false&&window.__LTS_V169_STATE?.monthly?.key.startsWith('2029-07-01'));
    if(!monthlyCalls.some(call=>call.p_from==='2029-07-01'&&call.p_to==='2030-06-15'))throw new Error('desktop: monthly balance did not follow period filter');
    await page.screenshot({path:'v169-desktop-monthly-balance.png',fullPage:true});
  }

  await frame.locator('[data-v168-exp-tab="cards"]').click();
  await frame.locator('.v169-cards').waitFor({state:'visible'});
  await frame.locator('[data-v169-card-bank="Itaú"]').click();
  text=await frame.locator('.v169-cards').innerText();lower=semantic(text);
  for(const phrase of ['considerado no fluxo','valores futuros mês a mês','personnalite black','valor usado no fluxo','regra de conferência'])if(!lower.includes(phrase))throw new Error(`${label}: future cards missing ${phrase}`);
  const monthText=semantic(await frame.locator('.v169-card-months').innerText());
  if(monthText.includes('aeternum')||monthText.includes('cartão c6'))throw new Error(`${label}: bank filter leaked another bank`);
  if(label==='desktop')await page.screenshot({path:'v169-desktop-cards.png',fullPage:true});

  await route('Patrimônio').click();
  await frame.locator('.v168-wealth').waitFor({state:'visible'});
  await frame.waitForFunction(()=>window.__LTS_V168_STATE?.wealth?.loading===false);
  text=await frame.locator('.v168-wealth').innerText();lower=semantic(text);
  for(const phrase of ['dívidas com saldo atual','obrigações remanescentes','empréstimo consignado · coopharma','empréstimo familiar · pai e mãe','obrigações sem saldo de quitação informado','não são somados ao patrimônio líquido central'])if(!lower.includes(phrase))throw new Error(`${label}: wealth passives missing ${phrase}`);
  if(label==='desktop')await page.screenshot({path:'v169-desktop-wealth.png',fullPage:true});

  await route('Fluxo Diário').click();
  await frame.waitForFunction(()=>V==='Fluxo Diário');
  const day=frame.locator('#fv-2030-06-15,#d-2030-06-15').first();
  await day.waitFor({state:'visible'});
  const expand=day.locator('[data-expand],.exp[data-d]').first();
  if(await expand.count())await expand.click();
  await frame.getByText('Editar transferência',{exact:true}).first().waitFor({state:'visible'});
  if(await frame.getByText('Excluir transferência',{exact:true}).count()<1)throw new Error(`${label}: transfer delete action missing`);
  if(await frame.getByText('Duplicar',{exact:true}).count())throw new Error(`${label}: transfer duplicate action should not exist`);
  const flowText=await day.innerText();if(!flowText.includes('R$ 20.665,00')&&!flowText.includes('R$ 20.665,00'))throw new Error(`${label}: transfer amount is not formatted as BRL: ${flowText}`);
  await frame.getByText('Editar transferência',{exact:true}).first().click();
  await frame.locator('.v169-transfer-editor').waitFor({state:'visible'});
  text=await frame.locator('.v169-transfer-editor').innerText();lower=semantic(text);
  for(const phrase of ['duas pernas vinculadas','efeito consolidado r$ 0,00','operação atômica','salvar transferência','excluir transferência'])if(!lower.includes(phrase))throw new Error(`${label}: transfer editor missing ${phrase}`);
  if(label==='desktop'){
    await frame.locator('#flowEditAmount').fill('21000');
    await frame.locator('#flowEditSave').click();
    await frame.waitForFunction(()=>!document.querySelector('.v169-transfer-editor'));
    if(!mutations.some(x=>x.p_action==='edit'&&x.p_source_ref===transferRef&&x.p_payload?.amount===21000))throw new Error('desktop: paired transfer edit RPC was not called correctly');
    const dayAgain=frame.locator('#fv-2030-06-15,#d-2030-06-15').first();
    const expandAgain=dayAgain.locator('[data-expand],.exp[data-d]').first();if(await expandAgain.count())await expandAgain.click();
    await frame.getByText('Excluir transferência',{exact:true}).first().click();
    await frame.waitForTimeout(200);
    if(!mutations.some(x=>x.p_action==='cancel'&&x.p_source_ref===transferRef))throw new Error('desktop: paired transfer cancel RPC was not called correctly');
    await page.screenshot({path:'v169-desktop-transfer-crud.png',fullPage:true});
  }

  const dims=await frame.locator('html').evaluate(element=>({scroll:element.scrollWidth,client:element.clientWidth}));
  if(dims.scroll>dims.client+3)throw new Error(`${label}: horizontal overflow ${JSON.stringify(dims)}`);
  const overlay=await page.locator('[data-nextjs-dialog],.vite-error-overlay,#webpack-dev-server-client-overlay').count();
  if(overlay)throw new Error(`${label}: framework error overlay detected`);
  if(errors.length)throw new Error(`${label}: page errors ${JSON.stringify(errors)}`);
  const relevantConsoleErrors=consoleErrors.filter(x=>!x.includes('favicon.ico'));
  if(relevantConsoleErrors.length)throw new Error(`${label}: console errors ${JSON.stringify(relevantConsoleErrors)}`);
  if(label==='mobile')await page.screenshot({path:'v169-mobile-final.png',fullPage:true});
  await context.close();
  return {label,pass:true,viewport,monthlyCalls:monthlyCalls.length,mutations:mutations.map(x=>x.p_action),requested:[...new Set(requested)]};
}

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined;
  const browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  try{
    const results=[await run(browser,{width:1440,height:1000},'desktop'),await run(browser,{width:390,height:844},'mobile')];
    const output={pass:true,version:'v169-v168-feedback-closure',data:'controlled-fixture-not-user-data-validation',results};
    fs.writeFileSync('v169-v168-feedback-result.json',JSON.stringify(output,null,2));
    console.log(JSON.stringify(output,null,2));
  }catch(error){
    const output={pass:false,error:String(error.stack||error),data:'controlled-fixture-not-user-data-validation'};
    fs.writeFileSync('v169-v168-feedback-result.json',JSON.stringify(output,null,2));
    console.error(output.error);process.exitCode=1;
  }finally{await browser.close()}
})();
