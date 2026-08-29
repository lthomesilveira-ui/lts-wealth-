const { chromium } = require('playwright');
const fs = require('fs');

async function collect(page,url){
  const errors=[];
  const onPage=e=>errors.push(`pageerror:${e.message}`);
  const onConsole=m=>{if(m.type()==='error')errors.push(`console:${m.text()}`)};
  page.on('pageerror',onPage);page.on('console',onConsole);
  await page.goto(url,{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(2500);
  page.off('pageerror',onPage);page.off('console',onConsole);
  return errors;
}

async function runCandidate(browser,viewport,label,baselineErrors){
  const page=await browser.newPage({viewport});
  const candidateErrors=[];
  const onPage=e=>candidateErrors.push(`pageerror:${e.message}`);
  const onConsole=m=>{if(m.type()==='error')candidateErrors.push(`console:${m.text()}`)};
  page.on('pageerror',onPage);page.on('console',onConsole);
  await page.goto('http://127.0.0.1:8765/wip35-v139-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(2500);

  const chain=[];let f=page.mainFrame();
  for(let i=0;i<4;i++){chain.push(f.url());const kids=f.childFrames();if(!kids.length)break;f=kids[0]}
  const expected=['wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
  const inherited=new Set(baselineErrors);
  const bootNewErrors=candidateErrors.filter(e=>!inherited.has(e));

  // No financial data is fabricated here. This only supplies the minimum
  // readiness contract that exists after authentication. RPC is a local no-op
  // and never calls a backend. This is installation smoke, not authenticated E2E.
  await f.evaluate(()=>{
    if(!window.D)window.D={updates:{items:[],documents:{items:[]}},card_classification_review:{category_options:[]},semantic_review:{items:[]}};
    window.render=()=>{};
    if(!window.S)window.S={};
    window.S.rpc=async()=>({data:null,error:null});
  });
  await page.mainFrame().evaluate(()=>{
    const shell=document.getElementById('shell');
    if(shell)shell.dispatchEvent(new Event('load'));
  });
  await page.waitForTimeout(2600);

  const innerState=await f.evaluate(()=>({
    candidate:window.LTS_CANDIDATE||null,
    css137:!!document.getElementById('wip35-v137-candidate-css'),
    css138:!!document.getElementById('wip35-v138-cockpit-css'),
    css139:!!document.getElementById('wip35-v139-updates-css')||!!document.getElementById('wip35-v139-evidence-css'),
    viewportWidth:document.documentElement.clientWidth,
    bodyScrollWidth:document.body?document.body.scrollWidth:0,
    rootScrollWidth:document.documentElement.scrollWidth
  })).catch(()=>({candidate:null,css137:false,css138:false,css139:false,viewportWidth:0,bodyScrollWidth:0,rootScrollWidth:0}));
  const injectionsOk=!!innerState.css137&&!!innerState.css138&&!!innerState.css139&&String(innerState.candidate||'').includes('v139');
  const newErrors=candidateErrors.filter(e=>!inherited.has(e));
  const rootOverflow=Math.max(innerState.bodyScrollWidth||0,innerState.rootScrollWidth||0)-(innerState.viewportWidth||0);
  // Large tables may scroll inside their own containers; the document root itself must not overflow materially.
  const rootWidthOk=rootOverflow<=2;
  const result={label,viewport,pass:chainOk&&bootNewErrors.length===0&&injectionsOk&&newErrors.length===0&&rootWidthOk,chain,chainOk,injectionsOk,innerState,rootWidthOk,rootOverflow,baselineErrors,candidateErrors,bootNewErrors,newErrors,readinessMode:'neutral synthetic payload + local RPC no-op + render no-op + lifecycle signal; not authenticated E2E'};
  await page.close();
  return result;
}

(async()=>{
  const browser=await chromium.launch({headless:true});
  const baseline=await browser.newPage({viewport:{width:1440,height:1000}});
  const baselineErrors=await collect(baseline,'http://127.0.0.1:8765/index.html?candidate-smoke-baseline');
  await baseline.close();

  const desktop=await runCandidate(browser,{width:1440,height:1000},'desktop',baselineErrors);
  const mobile=await runCandidate(browser,{width:390,height:844},'mobile-390x844',baselineErrors);
  const result={pass:desktop.pass&&mobile.pass,baselineErrors,desktop,mobile,importantLimit:'Non-authenticated browser composition/readiness smoke only; not authenticated visual E2E or user homologation.'};
  fs.writeFileSync('candidate-browser-smoke-result.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  await browser.close();
  if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
