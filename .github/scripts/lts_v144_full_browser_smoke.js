const { chromium } = require('playwright');
const fs = require('fs');

async function run(browser, viewport, label){
  const page=await browser.newPage({viewport});
  const errors=[];
  page.on('pageerror',e=>errors.push('pageerror:'+e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  await page.goto('http://127.0.0.1:8768/wip35-v144-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(8000);
  const outerTop=await page.evaluate(()=>window.__LTS_TOP_CANDIDATE_VERSION||null);
  const chain=[];let f=page.mainFrame();
  for(let i=0;i<8;i++){chain.push(f.url());const kids=f.childFrames();if(!kids.length)break;f=kids[0]}
  const expected=['wip35-v144-candidate.html','wip35-v142-candidate.html','wip35-v141-candidate.html','wip35-v140-candidate.html','wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
  const state=await f.evaluate(()=>{
    const descriptor=name=>{const x=Object.getOwnPropertyDescriptor(window,name)||{};return {exists:!!Object.getOwnPropertyDescriptor(window,name),configurable:x.configurable??null,writable:x.writable??null,hasGetter:typeof x.get==='function',hasSetter:typeof x.set==='function',valueName:typeof x.value==='function'?x.value.name:null,currentName:typeof window[name]==='function'?window[name].name:null}};
    const ptr=name=>({type:typeof window[name],name:typeof window[name]==='function'?window[name].name:null});
    const before=window.V;
    let nav=document.querySelector('.nav');
    let temporary=false;
    if(!nav){nav=document.createElement('div');nav.className='nav';document.body.appendChild(nav);temporary=true}
    try{window.renderNav()}catch(e){}
    const labels=Array.from(nav.querySelectorAll('button')).map(x=>String(x.textContent||'').trim());
    const targets=['Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Planejamento'];
    const clickResults=[];
    for(const t of targets){
      if(!document.querySelector('.nav')){nav=document.createElement('div');nav.className='nav';document.body.appendChild(nav)}
      try{window.renderNav()}catch(e){}
      const b=document.querySelector(`[data-v143-dest="${t}"]`);
      if(b){b.click();clickResults.push({target:t,after:window.V,ok:window.V===t})}
      else clickResults.push({target:t,after:window.V,ok:false});
    }
    if(temporary)document.querySelector('.nav')?.remove();
    return {
      marker:window.LTS_V143_LIFE_REAL||null,
      feedbackMarker:window.LTS_V143_FEEDBACK_POLISH||null,
      ownershipMarker:window.LTS_V143_OWNERSHIP||null,
      ownershipStatus:window.__LTS_V143_OWNERSHIP_STATUS||null,
      bridge:window.LTS_V144_LEXICAL_BRIDGE||null,
      deepHost:window.LTS_V144_DEEP_RUNTIME_HOST||null,
      innerTop:window.__LTS_TOP_CANDIDATE_VERSION||null,
      css:!!document.getElementById('wip35-v143-life-real-css'),
      feedbackCss:!!document.getElementById('wip35-v143-feedback-polish-css'),
      feedbackBound:!!document.__V143_FEEDBACK_BOUND,
      lifeBound:!!document.__V143_BOUND,
      dashboard:typeof window.dashboard==='function'&&String(window.dashboard).includes('v143Dashboard'),
      planning:typeof window.planejamento==='function'&&String(window.planejamento).includes('v143Planning'),
      expenses:typeof window.despesas==='function'&&String(window.despesas).includes('v143Expenses'),
      cards:typeof window.cartoes==='function'&&String(window.cartoes).includes('v143Cards'),
      wealth:typeof window.patrimonio==='function'&&String(window.patrimonio).includes('v143Wealth'),
      pointers:{dashboard:ptr('__v143Dashboard'),planning:ptr('__v143Planning'),expenses:ptr('__v143Expenses'),cards:ptr('__v143Cards'),wealth:ptr('__v143Wealth'),nav:ptr('__v143Nav')},
      inheritedPointers:{dashboard:ptr('__lts_v142_dashboard_fn'),nav:ptr('__lts_v142_dashboard_nav'),planning:ptr('__lts_v142_planning_fn'),planningBridge:ptr('__LTS_V142_PLANNING_RENDERER'),wealth:ptr('__lts_v142_wealth_fn')},
      descriptors:{dashboard:descriptor('dashboard'),planning:descriptor('planejamento'),expenses:descriptor('despesas'),cards:descriptor('cartoes'),wealth:descriptor('patrimonio'),nav:descriptor('renderNav')},
      navLabels:labels,clickResults,before,
      width:document.documentElement.clientWidth,
      scroll:Math.max(document.documentElement.scrollWidth,document.body?document.body.scrollWidth:0)
    }
  });
  const navOk=state.clickResults.every(x=>x.ok)&&['Dashboard','Atualizações','Fluxo Diário','Despesas','Cartões','Patrimônio','Liquidez detalhada'].every(x=>state.navLabels.includes(x));
  const feedbackOk=state.feedbackMarker==='classification-evidence-recurrence-generic-decision-cockpit-v2'&&state.feedbackCss&&state.feedbackBound;
  const ownershipOk=state.ownershipMarker==='redirect-inherited-owners-v2'&&state.ownershipStatus&&Object.values(state.ownershipStatus).every(Boolean);
  const bridgeOk=state.bridge==='v144-lexical-state-bridge-v1'&&state.deepHost==='deep-runtime-host-v1';
  const versionOk=outerTop==='v144'&&state.innerTop==='v143';
  const pass=chainOk&&state.marker==='dashboard-human-expense-drill-card-matrix-rsu-cipo-v1'&&feedbackOk&&ownershipOk&&bridgeOk&&versionOk&&state.css&&state.dashboard&&state.planning&&state.expenses&&state.cards&&state.wealth&&navOk&&state.scroll-state.width<=2&&errors.length===0;
  await page.close();return {label,viewport,pass,chain,chainOk,outerTop,state,navOk,feedbackOk,ownershipOk,bridgeOk,versionOk,errors};
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  const desktop=await run(browser,{width:1440,height:1000},'desktop');
  const mobile=await run(browser,{width:390,height:844},'mobile-390x844');
  await browser.close();
  const result={pass:desktop.pass&&mobile.pass,desktop,mobile,importantLimit:'Runtime composition and real navigation click-through on the unauthenticated v144 shell. The outer wrapper is v144 while the preserved deepest inherited product runtime remains v143 by design. Authenticated data rendering and financial writers remain separately gated; this is not authenticated visual E2E.'};
  fs.writeFileSync('v144-full-browser-smoke-result.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
