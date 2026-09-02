const { chromium } = require('playwright');
const fs = require('fs');

const FINAL_TITLE='Sua vida financeira, em uma tela.';
const FINAL_SUBTITLE='Tenho dinheiro hoje? O que exige ação? Para onde estou indo?';

async function deepest(page){
  const chain=[];let f=page.mainFrame();
  for(let i=0;i<12;i++){
    chain.push(f.url());
    const kids=f.childFrames();
    if(!kids.length)break;
    f=kids[0];
  }
  return {f,chain};
}

async function run(browser,viewport,label){
  const page=await browser.newPage({viewport});
  const errors=[];
  page.on('pageerror',e=>errors.push('pageerror:'+e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  await page.goto('http://127.0.0.1:8771/wip35-v145-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(3200);
  const {f,chain}=await deepest(page);
  const expected=['wip35-v145-candidate.html','wip35-v142-candidate.html','wip35-v141-candidate.html','wip35-v140-candidate.html','wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));

  await f.evaluate(()=>{
    window.D={
      updates:{items:[],maintenance_checks:[],freshness:{position_as_of:'2026-08-31'}},
      semantic_review:{pending_groups:0,items:[]},
      card_classification_review:{
        pending_groups:1,pending_lines:1,pending_value:725.46,safe_suggestion_groups:0,
        category_options:['Restaurantes','Supermercado','Outros'],
        items:[{description_key:'gula-gula-morumbi',merchant_name:'GULA GULA MORUMBI',example_description:'GULA GULA MORUMBI',card_name:'Aeternum',due_date:'2026-09-10',occurrences:2,total_value:725.46,suggested_category:'Restaurantes',suggestion_confidence:.83,suggestion_basis:'estabelecimento_identificado_pesquisa_publica',enrichment_attempted:true,merchant_identified:true,enrichment_confidence:.99,enrichment_evidence:'Gula Gula identificado por fonte oficial como restaurante.',taxonomy_ambiguous:true,enrichment_status:'taxonomy_review'}]
      },
      dashboard_cockpit:{
        version:'v145-smoke',as_of:'2026-08-31',status:'attention',
        liquidity:{through_d3:100000,bank_cash:50000,d0:25000,d3_vested:25000,fgts_d30:17509.05},
        planning_audited:{management_point_date:'2027-01-08',fgts_request_by:'2026-12-09',worst_after_brl:11262.25},
        cards:{open_cycles_total:1000,closed_or_due_total:0,next_due:{}},
        work:{actionable_count:0,top_actions:[]},
        horizons:[],future_liquidity:[]
      }
    };
    window.V='Dashboard';window.renderNav?.();window.render();
  });

  await page.waitForTimeout(1700);
  const pre=await f.evaluate(()=>({
    marker:window.LTS_V145_DASHBOARD_STABILITY||null,
    status:window.__LTS_V145_DASHBOARD_STABILITY_STATUS||null,
    stable:!!window.__v143Dashboard?.__ltsV145Stable,
    owner:window.dashboard===window.__v143Dashboard,
    bridge:window.LTS_V144_LEXICAL_BRIDGE||null,
    updatesHost:!!document.getElementById('v144UpdatesLayoutHost')
  }));

  await f.evaluate(()=>{
    const origRender=window.render;
    window.__v145RenderBaseline=0;
    window.render=function(){window.__v145RenderBaseline++;return origRender.apply(this,arguments)};
    window.__v145DashboardRpcCalls=0;
    if(window.S&&typeof window.S.rpc==='function'){
      const origRpc=window.S.rpc.bind(window.S);
      window.__v145OrigRpc=origRpc;
      window.S.rpc=async function(name,args){
        if(name==='lts_browser_dashboard_cockpit_v1'){
          window.__v145DashboardRpcCalls++;
          return {data:window.D.dashboard_cockpit,error:null};
        }
        return origRpc(name,args);
      };
    }
  });
  await page.waitForTimeout(300);
  const baseline=await f.evaluate(()=>({renders:window.__v145RenderBaseline||0,rpcs:window.__v145DashboardRpcCalls||0}));
  const samples=[];
  for(let i=0;i<30;i++){
    await page.waitForTimeout(100);
    samples.push(await f.evaluate(()=>({
      title:document.querySelector('.v143-head h1')?.textContent||'',
      subtitle:document.querySelector('.v143-head p')?.textContent||''
    })));
  }
  const after=await f.evaluate(()=>({
    renders:window.__v145RenderBaseline||0,
    rpcs:window.__v145DashboardRpcCalls||0,
    guard:window.__LTS_V142_DASHBOARD_LOADING===true
  }));

  await f.evaluate(()=>{window.V='Atualizações';window.renderNav?.();window.render()});
  await page.waitForTimeout(1500);
  const updates=await f.evaluate(()=>{
    const root=document.getElementById('v144UpdatesRoot'),text=root?.innerText||'';
    return {
      marker:window.LTS_V144_UPDATES_LAYOUT||null,
      root:!!root,
      title:text.includes('Resolva o que precisa de você.'),
      suggestion:text.includes('Restaurantes'),
      confidence:text.includes('83% sugestão')&&text.includes('99% identificação'),
      width:document.documentElement.clientWidth,
      scroll:Math.max(document.documentElement.scrollWidth,document.body?.scrollWidth||0)
    };
  });

  const titleSet=[...new Set(samples.map(x=>x.title))];
  const subtitleSet=[...new Set(samples.map(x=>x.subtitle))];
  const renderDelta=after.renders-baseline.renders;
  const rpcDelta=after.rpcs-baseline.rpcs;
  const pass=chainOk&&pre.marker==='single-refresh-title-stable-v1'&&pre.status?.legacy_poll_locked===true&&pre.stable&&pre.owner&&pre.bridge==='v144-lexical-state-bridge-v1'&&pre.updatesHost&&after.guard&&titleSet.length===1&&titleSet[0]===FINAL_TITLE&&subtitleSet.length===1&&subtitleSet[0]===FINAL_SUBTITLE&&renderDelta===0&&rpcDelta===0&&updates.marker==='classification-action-center-v2'&&updates.root&&updates.title&&updates.suggestion&&updates.confidence&&updates.scroll-updates.width<=2&&errors.length===0;
  await page.close();
  return {label,viewport,pass,chain,chainOk,pre,baseline,after,renderDelta,rpcDelta,titleSet,subtitleSet,updates,errors};
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  const desktop=await run(browser,{width:1440,height:1000},'desktop');
  const mobile=await run(browser,{width:390,height:844},'mobile-390x844');
  await browser.close();
  const result={pass:desktop.pass&&mobile.pass,desktop,mobile,importantLimit:'Temporal browser smoke proves stable Dashboard title/subtitle and no inherited v142 dashboard RPC/render loop under synthetic data, plus preservation of the v144 Updates action center. It is unauthenticated and does not execute backend financial writes.'};
  fs.writeFileSync('v145-dashboard-stability-smoke-result.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
