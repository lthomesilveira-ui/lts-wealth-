const { chromium } = require('playwright');
const fs = require('fs');

async function deepest(page){
  let f=page.mainFrame(),chain=[];
  for(let i=0;i<18;i++){chain.push(f.url());const kids=f.childFrames();if(!kids.length)break;f=kids[0]}
  return {f,chain};
}
const has=(t,n)=>String(t||'').toLocaleLowerCase('pt-BR').includes(String(n||'').toLocaleLowerCase('pt-BR'));

function data(){
  return {
    dashboard_cockpit:{
      version:'v151-smoke',as_of:'2026-09-03',
      liquidity:{through_d3:75133.58,bank_cash:19294.43,d0:42929.50,d3_vested:12909.65,fgts_d30:17509.05,accounts:[
        {institution:'Itaú',balance:14500.10},{institution:'Bradesco',balance:3500.20},{institution:'C6',balance:1294.13}
      ]},
      cards:{open_cycles_total:33328.63,closed_or_due_total:960.16,next_due:{due_date:'2026-09-08',amount:960.16,card_name:'C6 Carbon'}},
      work:{actionable_count:20,classification_groups:3,top_actions:[{title:'Revisar documento pendente',description:'Documento aguardando revisão'}]},
      planning_audited:{management_point_date:'2027-01-08',fgts_request_by:'2026-12-09',worst_before_brl:-21046.80,worst_after_brl:11262.25},
      horizons:[
        {id:'30d',label:'30 dias',date:'2026-10-03',current_liquidity_balance:33219.79},
        {id:'90d',label:'90 dias',date:'2026-12-02',current_liquidity_balance:18560.47},
        {id:'year_end',label:'Fim do ano',date:'2026-12-31',current_liquidity_balance:4200.11},
        {id:'feb',label:'fev/2027',date:'2027-02-28',current_liquidity_balance:11262.25}
      ],
      wealth:{assets_central:5462642.63,known_debt_total:1890398.31,net_worth_central:3572244.32},
      expenses:{current_month:{spend:68000},previous_month:{spend:62000}}
    },
    wealth_executive:{summary:{assets_central:5462642.63,known_debt_total:1890398.31,net_worth_central:3572244.32},assets:{cipo_396:{market_central:5200000},volvo_xc40:{market_central:170000}}},
    updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-09-03'}},
    semantic_review:{pending_groups:0,items:[]},
    card_classification_review:{
      pending_groups:3,pending_lines:3,pending_value:1610.41,all_suggestion_groups:1,safe_suggestion_groups:0,
      category_options:['Restaurantes','Moradia','Saúde','Vestuário','Outros'],
      items:[
        {description_key:'lavandex lavanderia lt',example_description:'LAVANDEX LAVANDERIA LT',card_name:'Visa Aeternum',due_date:'2026-08-25',occurrences:1,total_value:380,merchant_name:'Lavandex Lavanderia LTDA',merchant_identified:true,enrichment_attempted:true,enrichment_status:'identified_needs_taxonomy',enrichment_confidence:.99,enrichment_evidence:'CNPJ ativo; CNAE principal 96.01-7-01 Lavanderias',suggested_category:null},
        {description_key:'dufry lojas francas',example_description:'DUFRY LOJAS FRANCAS',card_name:'Visa Aeternum',due_date:'2026-09-25',occurrences:1,total_value:297.64,merchant_name:'Dufry Lojas Francas',merchant_identified:true,enrichment_attempted:true,enrichment_status:'identified_needs_context',enrichment_confidence:.99,enrichment_evidence:'Receita Federal identifica Dufry como loja franca/duty free. O mix é multategoria.',suggested_category:null},
        {description_key:'sal gastronomia',example_description:'SAL GASTRONOMIA',card_name:'Visa Aeternum',due_date:'2026-09-25',occurrences:1,total_value:933.38,merchant_name:'Sal Gastronomia',merchant_identified:true,enrichment_attempted:true,enrichment_status:'taxonomy_review',enrichment_confidence:.99,enrichment_evidence:'Site oficial identifica restaurante.',suggested_category:'Restaurantes',suggestion_confidence:.99,taxonomy_ambiguous:true}
      ]
    },
    flow:{days:[],events:[]},card_history:{units:[]},duplicate_quality_gate:{},card_operating:{},expenses:{},wealth:{},planning:{}
  };
}
function matrix(){
  return {
    version:'expense-context-nature-matrix-v1',
    summary:{rows:629,total:722126.87,unassigned_rows:483,unassigned_total:360902.80},
    contexts:[
      {name:'Não atribuído',rows:483,total:360902.80,categories:[{category:'A classificar',rows:55,total:9156.77}]},
      {name:'Casa',rows:39,total:201241.45,categories:[{category:'Moradia',rows:8,total:29719.87}]},
      {name:'Benjamin',rows:65,total:64496.10,categories:[{category:'Educação',rows:18,total:45934.53}]}
    ],
    categories:[{name:'Moradia',rows:8,total:29719.87,contexts:[{context:'Casa',rows:8,total:29719.87}]}],
    unassigned_states:[
      {state:'documentary_detail_not_recovered',rows:16,total:186252.10},
      {state:'detail_available_system_review',rows:412,total:165493.93},
      {state:'classification_and_context_pending',rows:55,total:9156.77}
    ],
    unassigned_categories:[]
  };
}
async function forceShell(f){
  await f.evaluate(()=>{
    const force=(el,display)=>{if(!el)return;el.classList.remove('hidden');el.removeAttribute('hidden');el.style.setProperty('display',display,'important');el.style.setProperty('visibility','visible','important');el.style.setProperty('opacity','1','important')};
    force(document.querySelector('.hdr'),'block');force(document.querySelector('.hdrin'),'block');force(document.querySelector('.nav'),'flex');force(document.getElementById('A'),'block');force(document.querySelector('.wrap'),'block');
  });
}
async function view(f,v){
  await f.evaluate(x=>{window.V=x;window.renderNav?.();window.render();window.__LTS_V150_AFTER_RENDER?.();window.__LTS_V151_AFTER_RENDER?.()},v);
}
async function run(browser,viewport,label){
  const page=await browser.newPage({viewport}),errors=[];
  page.on('pageerror',e=>errors.push('pageerror:'+String(e.message||e)));
  page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  await page.goto('http://127.0.0.1:8777/wip35-v151-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(4300);
  const {f,chain}=await deepest(page);
  if(!chain[0].includes('wip35-v151-candidate.html')||!chain.some(x=>x.includes('wip35-v150-candidate.html')))throw Error('candidate chain invalid '+JSON.stringify(chain));
  const D=data(),M=matrix();
  await f.evaluate(({D,M})=>{
    window.D=D;
    if(!window.S||typeof window.S!=='object')throw Error('Supabase client missing');
    window.S.rpc=async(name,args)=>{
      window.__V151_RPC_CALLS=(window.__V151_RPC_CALLS||[]).concat([{name,args}]);
      if(name==='lts_browser_product_v1')return {data:{mvp:D},error:null};
      if(name==='lts_browser_expense_context_nature_v1')return {data:M,error:null};
      if(name==='lts_browser_expense_drilldown_v1')return {data:{rows:[{date:'2026-09-03',display_name:'Condomínio O Parque',category:'Moradia',center:'Casa',counterparty:'Condomínio O Parque',amount:4000}]},error:null};
      if(name==='lts_browser_flow_v4')return {data:{ok:true,flow:{historical:{events:[]},current_future:{events:[]}}},error:null};
      return {data:{ok:true},error:null};
    };
    window.V='Dashboard';window.renderNav?.();window.render();window.__LTS_V150_BOOTSTRAP_RETRY?.();
  },{D,M});
  await f.waitForFunction(()=>window.LTS_V151_COCKPIT==='dashboard-updates-cockpit-v1'&&window.__LTS_V151_STATUS?.dashboard_recomposed===true,null,{timeout:12000});
  await f.evaluate(D=>{window.D=D;window.__V150_EXP=null;window.dashboard=window.__LTS_V151_DASHBOARD_FN;window.__v143Dashboard=window.__LTS_V151_DASHBOARD_FN},D);
  await view(f,'Dashboard');await forceShell(f);await page.waitForTimeout(350);
  let text=await f.locator('body').innerText();
  for(const needle of ['Sua vida financeira, em uma tela.','Disponível D+3','FGTS','Cartões em aberto','Patrimônio líquido','Menor saldo projetado','Liquidez','Total contas correntes','Itaú','Bradesco','C6','Cofrinho','RSU disponível D+3','Compromissos próximos','Evolução do caixa','Patrimônio e posição financeira','O que exige minha atenção','08/01/2027'])if(!has(text,needle))throw Error(label+' dashboard missing '+needle+'\n'+text);
  if(has(text,'Disponível incluindo FGTS'))throw Error('legacy giant FGTS composition still visible');

  await view(f,'Atualizações');await page.waitForTimeout(450);
  await f.waitForSelector('#v151UpdateSummary',{timeout:5000});
  text=await f.locator('body').innerText();
  for(const needle of ['Com sugestão','Estabelecimento já identificado','Lavandex','Lavanderia','Dufry','Duty free / loja franca','falta a finalidade desta compra','Restaurantes'])if(!has(text,needle))throw Error(label+' updates evidence missing '+needle+'\n'+text);
  const lav=await f.locator('[data-v146-key="lavandex lavanderia lt"]').innerText();
  if(has(lav,'Sugestão do LTS')||has(lav,'Restaurantes'))throw Error('Lavendex got invented financial category '+lav);
  const duf=await f.locator('[data-v146-key="dufry lojas francas"]').innerText();
  if(has(duf,'Sugestão do LTS'))throw Error('Dufry got invented financial category '+duf);

  await view(f,'Despesas');await page.waitForTimeout(500);
  await f.waitForSelector('#v151ExpenseState',{timeout:6000});
  text=await f.locator('body').innerText();
  for(const needle of ['Histórico sem detalhe recuperado','186.252,10','LTS ainda investigando','165.493,93','Realmente para classificar/contextualizar','9.156,77','Casa é contexto','Moradia é natureza'])if(!has(text,needle))throw Error(label+' expense clarity missing '+needle+'\n'+text);

  await page.waitForTimeout(700);
  const st=await f.evaluate(()=>({s:window.__LTS_V151_STATUS,v:window.__LTS_V151_VISIBLE_VERSION_STATUS,calls:window.__V151_RPC_CALLS||[]}));
  if(st.s?.financial_writer_changed!==false||st.s?.classification_inference!==false||st.s?.classification_writer_added!==false||st.s?.navigation_owner_changed!==false||st.s?.permanent_polling!==false)throw Error('guardrails invalid '+JSON.stringify(st.s));
  const forbidden=st.calls.map(x=>x.name).filter(x=>/apply|approve|write|feedback/i.test(x));if(forbidden.length)throw Error('writer RPC '+forbidden.join(','));
  if(errors.length)throw Error('browser errors '+JSON.stringify(errors));
  await page.close();
  return {label,viewport,chain,pass:true,rpc:st.calls.map(x=>x.name),status:st.s};
}
(async()=>{
  const browser=await chromium.launch({headless:true});
  try{
    const results=[await run(browser,{width:1440,height:900},'desktop'),await run(browser,{width:390,height:844},'mobile')];
    const out={pass:true,version:'v151-dashboard-updates-cockpit',results};
    fs.writeFileSync('v151-dashboard-updates-smoke-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out,null,2));
  }catch(e){
    const out={pass:false,error:String(e?.stack||e)};fs.writeFileSync('v151-dashboard-updates-smoke-result.json',JSON.stringify(out,null,2));console.error(out.error);process.exitCode=1;
  }finally{await browser.close()}
})();
