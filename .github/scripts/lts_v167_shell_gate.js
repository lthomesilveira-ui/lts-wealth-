'use strict';
const {chromium}=require('playwright');

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined;
  const browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[];
  page.on('pageerror',error=>errors.push(String(error.message||error)));
  await page.goto('http://127.0.0.1:8781/wip35-v167-candidate.html',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(2600);
  const state=await page.evaluate(()=>({
    version:window.__LTS_TOP_CANDIDATE_VERSION||null,
    scope:document.getElementById('scope')?.textContent||'',
    shell:document.getElementById('shell')?.getAttribute('src')||''
  }));
  if(state.version!=='v167-complete-review'||!state.scope.includes('V167')||!state.shell.includes('index.html')){
    throw new Error(`V167 shell inactive: ${JSON.stringify({state,errors})}`);
  }
  console.log(JSON.stringify({pass:true,...state,errors},null,2));
  await browser.close();
})().catch(error=>{console.error(error);process.exit(1)});
