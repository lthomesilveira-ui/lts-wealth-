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
  await page.goto('http://127.0.0.1:8765/wip35-v140-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
  await page.waitForTimeout(4200);

  const chain=[];let f=page.mainFrame();
  for(let i=0;i<5;i++){chain.push(f.url());const kids=f.childFrames();if(!kids.length)break;f=kids[0]}
  const expected=['wip35-v140-candidate.html','wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
  const inherited=new Set(baselineErrors);
  const bootNewErrors=candidateErrors.filter(e=>!inherited.has(e));

  const innerState=await f.evaluate(()=>({
    bridge:window.__LTS_LEXICAL_BRIDGE||null,
    lexicalSVisible:!!(window.S&&typeof window.S.rpc==='function'),
    lexicalDIsNull:window.D===null,
    css137:!!document.getElementById('wip35-v137-candidate-css'),
    css138:!!document.getElementById('wip35-v138-cockpit-css'),
    css139:!!document.getElementById('wip35-v139-updates-css')||!!document.getElementById('wip35-v139-evidence-css'),
    viewportWidth:document.documentElement.clientWidth,
    bodyScrollWidth:document.body?document.body.scrollWidth:0,
    rootScrollWidth:document.documentElement.scrollWidth,
    appText:String(document.getElementById('app')?.innerText||'').slice(0,180)
  })).catch(()=>({bridge:null,lexicalSVisible:false,lexicalDIsNull:false,css137:false,css138:false,css139:false,viewportWidth:0,bodyScrollWidth:0,rootScrollWidth:0,appText:''}));
  const bridgeOk=innerState.bridge==='v140'&&innerState.lexicalSVisible===true&&innerState.lexicalDIsNull===true;
  const injectionsOk=!!innerState.css137&&!!innerState.css138&&!!innerState.css139;
  const noSyntheticReady=!String(innerState.appText||'').includes('candidate synthetic readiness');
  const newErrors=candidateErrors.filter(e=>!inherited.has(e));
  const rootOverflow=Math.max(innerState.bodyScrollWidth||0,innerState.rootScrollWidth||0)-(innerState.viewportWidth||0);
  const rootWidthOk=rootOverflow<=2;
  const result={label,viewport,pass:chainOk&&bridgeOk&&bootNewErrors.length===0&&injectionsOk&&newErrors.length===0&&rootWidthOk&&noSyntheticReady,chain,chainOk,bridgeOk,injectionsOk,innerState,rootWidthOk,rootOverflow,baselineErrors,candidateErrors,bootNewErrors,newErrors,readinessMode:'real lexical bridge only; no synthetic D/S/render payload; non-authenticated smoke, not authenticated E2E'};
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
  const result={pass:desktop.pass&&mobile.pass,baselineErrors,desktop,mobile,importantLimit:'Non-authenticated browser composition + real lexical-bridge smoke only; not authenticated visual E2E or user homologation.'};
  fs.writeFileSync('candidate-browser-smoke-result.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  await browser.close();
  if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
