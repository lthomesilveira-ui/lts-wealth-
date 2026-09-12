const { chromium } = require('playwright');
const fs = require('fs');

const PORT = process.env.LTS_FLOW_RECOVERY_PORT || '8778';
const BASE = `http://127.0.0.1:${PORT}`;
const RESULT = 'v162-flow-recovery-result.json';
const TODAY = '2026-09-10';
const WATCHDOG_MS = 210000;

function log(label, detail=''){
  console.log(`[v162-gate] ${label}${detail ? ` · ${detail}` : ''}`);
}

function withTimeout(promise, ms, label){
  let timer;
  return Promise.race([
    promise,
    new Promise((_,reject)=>{timer=setTimeout(()=>reject(new Error(`${label} timed out after ${ms}ms`)),ms)})
  ]).finally(()=>clearTimeout(timer));
}

function write(value){
  fs.writeFileSync(RESULT, JSON.stringify(value, null, 2));
}

function has(text, needle){
  return String(text || '').toLocaleLowerCase('pt-BR').includes(String(needle || '').toLocaleLowerCase('pt-BR'));
}

function product(){
  return {
    dashboard_cockpit:{
      version:'recovery-fixture',as_of:'2026-09-09',
      liquidity:{through_d3:18000,bank_cash:13000,d0:5000,d3_vested:0,fgts_d30:22432.31,accounts:[]},
      cards:{open_cycles_total:1000,next_due:{due_date:TODAY,amount:1000,card_name:'Visa Aeternum'}},
      work:{actionable_count:1,top_actions:[]},planning_audited:{},horizons:[]
    },
    updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-09-09'}},
    semantic_review:{pending_groups:1,items:[]},
    card_classification_review:{pending_groups:1,pending_lines:1,pending_value:125,category_options:[],items:[]},
    card_operating:{open_cycles_total:1000,open_cycles:[],next_due:{due_date:TODAY,amount:1000,card_name:'Visa Aeternum'}},
    card_history:{units:[]},
    wealth_executive:{summary:{},assets:{}},
    duplicate_quality_gate:{},flow:{days:[],events:[]},expenses:{},wealth:{},planning:{}
  };
}

function columns({previous,entries,exits,final,d0,vested,fgts,cashFuture=416106.54}){
  const beforeRsu=final+d0;
  const afterRsu=beforeRsu+vested;
  return {
    saldo_anterior_operacional:previous,
    entradas_operacionais:entries,
    saidas_operacionais:exits,
    saldo_final_operacional:final,
    liq_d0_1_recurso:d0,
    saldo_apos_d0_1:beforeRsu,
    rsus_vested:vested,
    saldo_apos_rsu:afterRsu,
    fgts,
    saldo_apos_fgts:afterRsu+fgts,
    rsus_futuras:1150248.09,
    cash_awards_futuros:cashFuture,
    posicao_economica_total:afterRsu+fgts+1150248.09+cashFuture
  };
}

function flow(){
  const historicalDay={
    date:'2026-09-09',historical:true,
    Consolidado:{bank_balance:11000,net:-1000,economic_net:-1000},
    Itaú:{balance:10500,net:-1000},Bradesco:{balance:500,net:0},C6:{balance:0,net:0},
    fix86_columns:columns({previous:12000,entries:1000,exits:2000,final:11000,d0:5000,vested:0,fgts:22432.31})
  };
  const todayDay={
    date:TODAY,historical:false,
    Consolidado:{bank_balance:13000,net:2000,economic_net:2000},
    Itaú:{balance:12500,net:2000},Bradesco:{balance:500,net:0},C6:{balance:0,net:0},
    fix86_columns:columns({previous:11000,entries:3000,exits:1000,final:13000,d0:5000,vested:0,fgts:22432.31})
  };
  const vestDay={
    date:'2026-09-12',historical:false,
    Consolidado:{bank_balance:13000,net:0,economic_net:0},
    Itaú:{balance:12500,net:0},Bradesco:{balance:500,net:0},C6:{balance:0,net:0},
    fix86_columns:columns({previous:13000,entries:0,exits:0,final:13000,d0:5000,vested:12909.65,fgts:22432.31})
  };
  return {
    from:'2026-09-09',to:'2026-10-09',available_year_from:2013,available_year_to:2041,
    historical:{
      days:[historicalDay],
      events:[
        {event_date:'2026-09-09',account:'Itaú',description:'Pagamento confirmado',signed_amount:-2000,category:'Compromissos',source:'bank_fact',source_ref:'fact-1',confidence:'evidenced'},
        {event_date:'2026-09-09',account:'Itaú',description:'Entrada confirmada',signed_amount:1000,category:'Receita',source:'bank_fact',source_ref:'fact-2',confidence:'evidenced'}
      ]
    },
    current_future:{
      days:[todayDay,vestDay],
      events:[
        {event_date:TODAY,account:'Itaú',description:'Salário',signed_amount:3000,category:'Salário',source:'current_event',source_ref:'salary-1',confidence:'documented_expected'},
        {event_date:TODAY,account:'Itaú',description:'Fatura Visa Aeternum final 5546',signed_amount:-600,category:'Cartão',source:'current_event',source_ref:'visa-1',confidence:'documented_expected'},
        {event_date:TODAY,account:'C6',description:'Fatura C6 Carbon final 8304',signed_amount:-400,category:'A classificar',source:'current_event',source_ref:'c6-1',confidence:'documented_expected'}
      ]
    },
    version:'daily-flow-browser-v11-fixture'
  };
}

function invoice(args){
  const visa=/aeternum/i.test(String(args?.p_description || ''));
  const total=visa?600:400;
  return {
    matched:true,historical_only:false,open_cycle:false,
    card_name:visa?'Visa Aeternum':'C6 Carbon',due_date:TODAY,
    invoice_total:total,invoice_credit:0,detail_lines:2,cash_detail_delta:0,cash_reconciled:true,
    classification_pending_lines:1,classification_pending_value:125,
    purchases:[
      {description:'Mercado',category:'Casa',amount:total-125,card_name:visa?'Visa Aeternum':'C6 Carbon',purchase_date:'2026-09-02'},
      {description:'Compra pendente',category:'A classificar',amount:125,card_name:visa?'Visa Aeternum':'C6 Carbon',purchase_date:'2026-09-05'}
    ],
    guardrail:'Pagamento da fatura explica o caixa; compras representam consumo econômico e não são contadas novamente.'
  };
}

async function deepestReady(page){
  for(let attempt=0;attempt<120;attempt++){
    const all=page.frames();
    const frame=all.find(x=>{try{return new URL(x.url()).pathname.endsWith('/index.html')}catch(e){return false}});
    const chain=all.map(x=>x.url());
    if(!frame){await page.waitForTimeout(100);continue}
    try{
      const ready=await withTimeout(frame.evaluate(()=>typeof window.__LTS_V162_ROUTE_FLOW==='function'&&window.__LTS_V162_FLOW_RECOVERY_STATUS?.installed===true),1000,'deep frame readiness');
      if(ready)return {frame,chain};
    }catch(e){}
    await page.waitForTimeout(100);
  }
  throw new Error('Fluxo recovery frame did not become ready');
}

async function run(browser, viewport, label){
  log(`${label}:start`,`${viewport.width}x${viewport.height}`);
  const context=await browser.newContext({viewport});
  const requested=[];
  await context.addInitScript(session=>{
    localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));
  },{access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}});
  const page=await context.newPage();
  page.setDefaultTimeout(10000);
  page.setDefaultNavigationTimeout(20000);
  const pageErrors=[];
  page.on('pageerror',error=>pageErrors.push(String(error?.message||error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
    const req=route.request();
    const url=new URL(req.url());
    const name=url.pathname.split('/').pop();
    let args={};
    try{args=req.postDataJSON()||{}}catch(e){}
    requested.push(name);
    let body={ok:true};
    if(name==='lts_browser_product_v1')body={ok:true,mvp:product()};
    else if(name==='lts_browser_flow_v11')body={ok:true,flow:flow()};
    else if(name==='lts_browser_card_settlement_detail_v2')body=invoice(args);
    else if(name==='lts_browser_flow_event_editor_v1')body={editable:true,event_date:TODAY,display_amount:400,amount:400,description:'Fatura C6 Carbon final 8304',account:'C6',source:'current_event',source_ref:'c6-1'};
    else if(name==='lts_browser_flow_mutate_v2')body={ok:true};
    else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
    else if(name==='lts_browser_transactions_v1')body={ok:true,total:0,rows:[]};
    await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
  });

  await page.goto(`${BASE}/wip35-v162-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
  log(`${label}:document-loaded`);
  const {frame,chain}=await deepestReady(page);
  log(`${label}:deep-frame-ready`,`${chain.length} frames`);
  await page.waitForFunction(()=>document.getElementById('gate')?.hidden===true,null,{timeout:25000});
  await frame.waitForFunction(()=>window.__LTS_V162_FLOW_RECOVERY_STATUS?.route==='Fluxo Diário'&&window.__LTS_V162_FLOW_RECOVERY_STATUS?.last_flow_ok===true,null,{timeout:25000});
  log(`${label}:flow-ready`);
  await page.screenshot({path:`v162-flow-${label}.png`,fullPage:false});

  if(!chain.some(x=>x.includes('/index.html')))throw new Error(`${label} protected Flow source missing ${JSON.stringify(chain)}`);
  if(chain.some(x=>/wip35-v1(?:3[7-9]|4\d|5[0-2])-candidate\.html/.test(x)))throw new Error(`${label} historical wrapper leaked into clean recovery ${JSON.stringify(chain)}`);
  const status=await frame.evaluate(()=>window.__LTS_V162_FLOW_RECOVERY_STATUS);
  if(status.contract!=='v150-flow-direct-current-read-v3'||status.data_rpc!=='lts_browser_flow_v11'||status.mutation_rpc!=='lts_browser_flow_mutate_v2'||status.financial_writer_changed!==false||status.permanent_polling!==false)throw new Error(`${label} invalid bridge status ${JSON.stringify(status)}`);
  if(!requested.includes('lts_browser_flow_v11'))throw new Error(`${label} current flow reader was not requested`);

  const text=await frame.locator('body').innerText();
  if(!has(text,'Fluxo Diário'))throw new Error(`${label} missing Fluxo Diário`);
  const columnLabels=['Saldo anterior','Entradas','Saídas','Saldo final','D0/D1','Saldo c/ D0/D1','RSU vested','Saldo c/ RSU','FGTS','Saldo total'];
  if(label==='desktop'){
    for(const needle of columnLabels)if(!has(text,needle))throw new Error(`${label} missing ${needle}`);
  }else{
    const mobileLabels=await frame.locator('#d-2026-09-09 .fx87-cell').evaluateAll(nodes=>nodes.map(node=>getComputedStyle(node,'::before').content.replace(/^['"]|['"]$/g,'')));
    for(const needle of columnLabels)if(!mobileLabels.some(value=>has(value,needle)))throw new Error(`${label} missing ${needle}`);
  }
  for(const forbidden of ['Cash Awards futuros','RSUs futuras','Posição econômica total'])if(has(text,forbidden))throw new Error(`${label} leaked non-cash future layer ${forbidden}`);

  const rows=frame.locator('.fx87-row:not(.fx87-head)');
  if(await rows.count()<3)throw new Error(`${label} expected historical, current and vesting rows`);
  const historical=frame.locator('#d-2026-09-09');
  const historicalText=await historical.innerText();
  for(const value of ['12.000,00','1.000,00','2.000,00','11.000,00'])if(!has(historicalText,value))throw new Error(`${label} historical continuity missing ${value}`);
  const todayRow=frame.locator(`#d-${TODAY}`);
  const todayText=await todayRow.innerText();
  if(!has(todayText,'0,00')||!has(todayText,'18.000,00'))throw new Error(`${label} future award leaked into vested/current balance ${todayText}`);
  const vestText=await frame.locator('#d-2026-09-12').innerText();
  if(!has(vestText,'12.909,65')||!has(vestText,'30.909,65'))throw new Error(`${label} vesting date not reflected ${vestText}`);

  await historical.locator('[data-d="2026-09-09"]').click();
  const historyDetails=frame.locator('#d-2026-09-09 + .fx89-details');
  await historyDetails.waitFor({state:'visible',timeout:5000});
  const historyTreeText=await historyDetails.innerText();
  for(const needle of ['Histórico / movimentos','Compromissos','Receita'])if(!has(historyTreeText,needle))throw new Error(`${label} history tree missing ${needle}`);
  if(!has(await historyDetails.locator('.fx89-detail-entry').allInnerTexts(),'1.000,00'))throw new Error(`${label} historical entry left its column`);
  if(!has(await historyDetails.locator('.fx89-detail-exit').allInnerTexts(),'2.000,00'))throw new Error(`${label} historical exit left its column`);
  if(await historyDetails.locator('.floweditbtn,.flowdeletebtn').count())throw new Error(`${label} realized historical fact exposed edit actions`);
  log(`${label}:history-tree-pass`);

  await todayRow.locator(`[data-d="${TODAY}"]`).click();
  const dayDetails=frame.locator('.fx89-details').filter({hasText:'Fatura C6 Carbon'});
  await dayDetails.waitFor({state:'visible',timeout:5000});
  const dayText=await dayDetails.innerText();
  for(const needle of ['Fatura Visa Aeternum','Fatura C6 Carbon','A classificar · revisar','Editar','Duplicar','Excluir'])if(!has(dayText,needle))throw new Error(`${label} projected detail missing ${needle}`);

  for(const cardName of ['Visa Aeternum','C6 Carbon']){
    const event=dayDetails.locator('.fx89-detail-row').filter({hasText:cardName}).first();
    await event.locator('.carddetailbtn').click();
    const invoicePanel=frame.locator('.invoice-inline').filter({hasText:cardName});
    await invoicePanel.waitFor({state:'visible',timeout:5000});
    // A visible loading shell is not a completed invoice. Preserve every content
    // assertion, but wait for the matching asynchronous consumer response first.
    await frame.waitForFunction(name=>!CARDDETAILLOADING&&CARDDETAIL?.matched===true&&CARDDETAIL.card_name===name,cardName,{timeout:5000});
    const invoiceText=await invoicePanel.innerText();
    for(const needle of ['Resumo da fatura','Por categoria','Casa','A classificar','Revisar classificação','Acessar fatura completa'])if(!has(invoiceText,needle))throw new Error(`${label} ${cardName} invoice missing ${needle}`);
    await invoicePanel.locator('#closeCardDetail').click();
  }
  log(`${label}:invoice-parity-pass`);

  const overflow=await page.evaluate(()=>({outer:[document.documentElement.scrollWidth,document.documentElement.clientWidth],candidate:(()=>{const d=document.getElementById('shell')?.contentDocument;return d?[d.documentElement.scrollWidth,d.documentElement.clientWidth]:null})()}));
  const deepOverflow=await frame.evaluate(()=>[document.documentElement.scrollWidth,document.documentElement.clientWidth]);
  if(label==='mobile'){
    if(overflow.outer[0]>overflow.outer[1]+2||deepOverflow[0]>deepOverflow[1]+2)throw new Error(`mobile page overflow ${JSON.stringify({overflow,deepOverflow})}`);
    const dashboardVisible=await page.frameLocator('#shell').locator('.nav [data-v="Dashboard"]').isVisible().catch(()=>false);
    if(dashboardVisible)throw new Error('rejected Dashboard remained exposed in Flow-only mobile gate');
  }

  const screenshot=`v162-flow-${label}.png`;
  await page.screenshot({path:screenshot,fullPage:false});
  if(pageErrors.length)throw new Error(`${label} page errors ${JSON.stringify(pageErrors)}`);
  await context.close();
  log(`${label}:pass`);
  return {label,viewport,pass:true,chain,requested:[...new Set(requested)],bridge:{contract:status.contract,data_rpc:status.data_rpc,last_flow_ok:status.last_flow_ok},screenshot};
}

(async()=>{
  const watchdog=setTimeout(()=>{
    const out={pass:false,error:`V162 Flow recovery gate watchdog exceeded ${WATCHDOG_MS}ms`};
    write(out);
    console.error(out.error);
    process.exit(124);
  },WATCHDOG_MS);
  const browser=await chromium.launch({headless:true});
  try{
    const results=[];
    results.push(await run(browser,{width:1440,height:900},'desktop'));
    results.push(await run(browser,{width:390,height:844},'mobile'));
    const out={pass:true,version:'v162-flow-recovery',results};
    write(out);
    console.log(JSON.stringify(out,null,2));
  }catch(error){
    const out={pass:false,error:String(error?.stack||error)};
    write(out);
    console.error(out.error);
    process.exitCode=1;
  }finally{
    clearTimeout(watchdog);
    await withTimeout(browser.close(),10000,'browser close').catch(error=>console.error(String(error)));
  }
})();
