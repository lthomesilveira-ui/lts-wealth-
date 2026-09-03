const { chromium } = require('playwright');
const fs = require('fs');

async function deepest(page){
  let f=page.mainFrame(); const chain=[];
  for(let i=0;i<14;i++){
    chain.push(f.url());
    const kids=f.childFrames(); if(!kids.length) break;
    f=kids[0];
  }
  return {f,chain};
}
function synthetic(){
  return {
    dashboard_cockpit:{
      version:'v150-smoke',as_of:'2026-09-03',
      liquidity:{through_d3:75133.58,bank_cash:19294.43,d0:42929.50,d3_vested:12909.65,fgts_d30:17509.05},
      cards:{open_cycles_total:33328.63,next_due:{due_date:'2026-09-08',amount:960.16,card_name:'C6 Carbon'}},
      work:{actionable_count:20},
      planning_audited:{management_point_date:'2026-12-30',fgts_request_by:'2026-11-30',worst_before_brl:-25582.39,worst_after_brl:6726.66},
      horizons:[{id:'30d',label:'30 dias',date:'2026-10-03',current_liquidity_balance:33219.79},{id:'90d',label:'90 dias',date:'2026-12-02',current_liquidity_balance:-18560.47}]
    },
    updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-09-03'}},
    semantic_review:{pending_groups:0,items:[]},
    card_classification_review:{pending_groups:0,pending_lines:0,pending_value:0,category_options:[],items:[]},
    flow:{days:[],events:[]},card_history:{units:[]},duplicate_quality_gate:{},card_operating:{},expenses:{},wealth:{},planning:{}
  };
}
function expenseMatrix(){
  return {
    version:'expense-context-nature-matrix-v1',
    summary:{rows:629,total:722126.87,unassigned_rows:483,unassigned_total:360902.80},
    contexts:[
      {name:'Benjamin',rows:65,total:64496.10,categories:[{category:'Educação',rows:18,total:45934.53},{category:'Saúde',rows:14,total:7943.31}]},
      {name:'Casa',rows:39,total:201241.45,categories:[{category:'Financiamento Imobiliário',rows:7,total:145393.75},{category:'Moradia',rows:8,total:29719.87}]}
    ],
    categories:[
      {name:'Educação',rows:25,total:50044.03,contexts:[{context:'Benjamin',rows:18,total:45934.53},{context:'Lucas',rows:5,total:2920},{context:'Não atribuído',rows:2,total:1189.50}]},
      {name:'Saúde',rows:44,total:26926.16,contexts:[{context:'Benjamin',rows:14,total:7943.31}]}
    ],
    unassigned_states:[
      {state:'documentary_detail_not_recovered',rows:16,total:186252.10},
      {state:'detail_available_system_review',rows:412,total:165493.93},
      {state:'classification_and_context_pending',rows:55,total:9156.77}
    ]
  };
}
async function forceShell(f){
  await f.evaluate(()=>{
    const force=(el,display)=>{if(!el)return;el.classList.remove('hidden');el.removeAttribute('hidden');el.style.setProperty('display',display,'important');el.style.setProperty('visibility','visible','important');el.style.setProperty('opacity','1','important')};
    force(document.querySelector('.hdr'),'block'); force(document.querySelector('.hdrin'),'block'); force(document.querySelector('.nav'),'flex'); force(document.getElementById('A'),'block'); force(document.querySelector('.wrap'),'block');
  });
}
async function setView(f,v){
  await f.evaluate(view=>{window.V=view;window.renderNav?.();window.render();window.__LTS_V148_INJECT_CHANGES?.();window.__LTS_V149_RENDER_DOCUMENT_REVIEW?.();window.__LTS_V150_AFTER_RENDER?.()},v);
}
async function run(browser,viewport,label){
  const page=await browser.newPage({viewport}); const errors=[];
  page.on('pageerror',e=>errors.push('pageerror:'+String(e.message||e)));
  page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  await page.goto('http://127.0.0.1:8776/wip35-v150-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(4000);
  const {f,chain}=await deepest(page);
  if(!chain[0].includes('wip35-v150-candidate.html')||!chain.some(x=>x.includes('wip35-v147-candidate.html'))) throw new Error('candidate chain invalid '+JSON.stringify(chain));
  await f.evaluate(({data,matrix})=>{
    window.D=data;
    if(!window.S||typeof window.S!=='object') throw new Error('Supabase client missing');
    window.S.rpc=async(name,args)=>{
      window.__V150_RPC_CALLS=(window.__V150_RPC_CALLS||[]).concat([{name,args}]);
      if(name==='lts_browser_expense_context_nature_v1') return {data:matrix,error:null};
      if(name==='lts_browser_expense_drilldown_v1') return {data:{rows:[{date:'2026-09-03',display_name:'Escolinha das Acácias',category:'Educação',center:'Benjamin',counterparty:'Escolinha das Acácias',amount:4925}]},error:null};
      if(name==='lts_browser_flow_v4') return {data:{ok:true,flow:{historical:{events:[{event_date:'2026-09-03',description:'PAG BOLETO ESCOLINHA DAS ACACIAS',account:'Itaú',category:'Educação',amount:-4925}]},current_future:{events:[]}}},error:null};
      return {data:{ok:true},error:null};
    };
    window.V='Dashboard'; window.renderNav?.(); window.render();
    window.__LTS_V150_BOOTSTRAP_RETRY?.();
  },{data:synthetic(),matrix:expenseMatrix()});
  await f.waitForFunction(()=>window.LTS_V150_RECOMPOSITION==='expense-input-dashboard-recomposition-v1'&&window.__LTS_V150_BOOTSTRAP_STATUS?.bounded_retry===true,null,{timeout:12000});
  await setView(f,'Dashboard'); await forceShell(f); await page.waitForTimeout(250);
  let text=await f.locator('#A').innerText();
  for(const needle of ['Sua vida financeira, em uma tela.','Disponível realizável até D+3','75.133,58','19.294,43','42.929,50','12.909,65','Disponível incluindo FGTS','92.642,63','17.509,05']) if(!text.includes(needle)) throw new Error(label+' dashboard missing '+needle+'\n'+text);
  if(/FGTS separado/i.test(text)) throw new Error('legacy FGTS separado still visible');
  const planVisible=await f.locator('.nav [data-v143-dest="Planejamento"]').isVisible().catch(()=>false);
  if(planVisible) throw new Error('Planejamento duplicate nav still visible');
  await f.locator('[data-v150-liq-toggle]').click(); await page.waitForTimeout(150);
  text=await f.locator('#A').innerText();
  if(!text.includes('FGTS · pedir até')||!text.includes('Pior após contingência')) throw new Error('liquidity detail did not open');

  await setView(f,'Despesas'); await page.waitForTimeout(350);
  await f.waitForFunction(()=>document.getElementById('A')?.innerText.includes('Quanto você gasta'),null,{timeout:5000});
  text=await f.locator('#A').innerText();
  for(const needle of ['Benjamin','Casa','Educação','Sem detalhe documental recuperado','Detalhe disponível · LTS investigando','Classificação/contexto ainda pendente','186.252,10','165.493,93','9.156,77']) if(!text.includes(needle)) throw new Error('expense matrix missing '+needle);
  const ben=f.locator('details.v150-context').filter({hasText:'Benjamin'}).first(); await ben.locator('summary').click();
  const edu=ben.locator('button[data-v150-drill-dim]').filter({hasText:'Educação'}).first(); if(!await edu.isVisible()) throw new Error('Benjamin → Educação not visible');
  await edu.click(); await page.waitForTimeout(250);
  text=await f.locator('#A').innerText(); if(!text.includes('Escolinha das Acácias')||!text.includes('4.925,00')) throw new Error('expense drilldown failed');

  await setView(f,'Atualizações'); await page.waitForTimeout(300);
  await f.waitForSelector('#v150Toolbox',{timeout:5000});
  text=await f.locator('#v150Toolbox').innerText();
  if(!text.includes('Lançamento por texto')||!text.includes('Consultar o Fluxo')) throw new Error('updates tools missing');
  await f.locator('#v150Phrase').fill('lançar R$ 250 no Itaú');
  await f.locator('[data-v150-open-input]').click(); await page.waitForTimeout(180);
  const route=await f.evaluate(()=>({V:window.V,phrase:document.querySelector('.phrase')?.value||'',status:document.getElementById('v150InputStatus')?.textContent||''}));
  if(route.V!=='Lançar / Importar'||route.phrase!=='lançar R$ 250 no Itaú') throw new Error('reviewed input route did not reopen '+JSON.stringify(route));
  await setView(f,'Atualizações'); await page.waitForTimeout(180); await f.waitForSelector('#v150Toolbox');
  await f.locator('#v150FlowTerm').fill('escolinha'); await f.locator('[data-v150-flow-query]').click(); await page.waitForTimeout(180);
  const flowText=await f.locator('#v150FlowResults').innerText(); if(!flowText.includes('ESCOLINHA DAS ACACIAS')) throw new Error('flow query failed '+flowText);

  await page.waitForTimeout(900);
  const status=await f.evaluate(()=>({product:window.__LTS_V150_STATUS,bootstrap:window.__LTS_V150_BOOTSTRAP_STATUS,rpcCalls:window.__V150_RPC_CALLS||[],version:window.__LTS_V150_VISIBLE_VERSION_STATUS}));
  if(status.product?.financial_writer_changed!==false||status.product?.classification_inference!==false||status.product?.permanent_polling!==false) throw new Error('v150 guardrails invalid '+JSON.stringify(status.product));
  if(status.bootstrap?.permanent_polling!==false||status.bootstrap?.bounded_retry!==true) throw new Error('bootstrap guardrails invalid');
  if(status.version?.older_version_visible) throw new Error('older visible version won ownership');
  const names=status.rpcCalls.map(x=>x.name);
  const forbidden=names.filter(x=>/apply|approve|write|feedback/i.test(x)); if(forbidden.length) throw new Error('unexpected writer rpc '+forbidden.join(','));
  for(const required of ['lts_browser_expense_context_nature_v1','lts_browser_expense_drilldown_v1','lts_browser_flow_v4']) if(!names.includes(required)) throw new Error('missing expected read rpc '+required);
  if(errors.length) throw new Error('browser errors '+JSON.stringify(errors));
  await page.close();
  return {label,viewport,chain,route,status:{product:status.product,bootstrap:{version:status.bootstrap.version,bounded_retry:status.bootstrap.bounded_retry,permanent_polling:status.bootstrap.permanent_polling},version:status.version},rpcNames:names,pass:true};
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const results=[];
    results.push(await run(browser,{width:1440,height:900},'desktop'));
    results.push(await run(browser,{width:390,height:844},'mobile'));
    const out={pass:true,version:'v150-expense-input-dashboard-recomposition',results};
    fs.writeFileSync('v150-recomposition-smoke-result.json',JSON.stringify(out,null,2));
    console.log(JSON.stringify(out,null,2));
  }catch(e){
    const out={pass:false,error:String(e?.stack||e)}; fs.writeFileSync('v150-recomposition-smoke-result.json',JSON.stringify(out,null,2)); console.error(out.error); process.exitCode=1;
  }finally{await browser.close()}
})();