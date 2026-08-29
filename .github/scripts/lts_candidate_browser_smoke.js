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

(async()=>{
  const browser=await chromium.launch({headless:true});
  const baseline=await browser.newPage({viewport:{width:1440,height:1000}});
  const baselineErrors=await collect(baseline,'http://127.0.0.1:8765/index.html?candidate-smoke-baseline');
  await baseline.close();

  const page=await browser.newPage({viewport:{width:1440,height:1000}});
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
  // readiness contract that exists after authentication: a payload object,
  // render callback and RPC surface. RPC is a local no-op and never calls a
  // backend. This is an installation smoke, not authenticated E2E.
  await f.evaluate(()=>{
    if(!window.D)window.D={updates:{items:[],documents:{items:[]}},card_classification_review:{category_options:[]},semantic_review:{items:[]}};
    window.render=()=>{};
    if(!window.S)window.S={};
    window.S.rpc=async()=>({data:null,error:null});
  });
  await page.waitForTimeout(2200);

  const innerState=await f.evaluate(()=>({
    candidate:window.LTS_CANDIDATE||null,
    css137:!!document.getElementById('wip35-v137-candidate-css'),
    css138:!!document.getElementById('wip35-v138-cockpit-css'),
    css139:!!document.getElementById('wip35-v139-updates-css')||!!document.getElementById('wip35-v139-evidence-css')
  })).catch(()=>({candidate:null,css137:false,css138:false,css139:false}));
  const injectionsOk=!!innerState.css137&&!!innerState.css138&&!!innerState.css139&&String(innerState.candidate||'').includes('v139');
  const newErrors=candidateErrors.filter(e=>!inherited.has(e));
  const body=await page.locator('body').innerText().catch(()=> '');
  const result={pass:chainOk&&bootNewErrors.length===0&&injectionsOk&&newErrors.length===0,chain,chainOk,injectionsOk,innerState,baselineErrors,candidateErrors,bootNewErrors,newErrors,topBodyChars:body.length,readinessMode:'neutral synthetic payload + local RPC no-op + render no-op; not authenticated E2E'};
  fs.writeFileSync('candidate-browser-smoke-result.json',JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  await browser.close();
  if(!result.pass)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
