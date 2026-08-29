const { chromium } = require('playwright');

(async()=>{
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[];
  page.on('pageerror', e=>errors.push(`pageerror:${e.message}`));
  page.on('console', m=>{ if(m.type()==='error') errors.push(`console:${m.text()}`); });
  await page.goto('http://127.0.0.1:8765/wip35-v139-candidate.html', {waitUntil:'domcontentloaded', timeout:30000});
  await page.waitForTimeout(2500);
  const chain=[];
  let f=page.mainFrame();
  for(let i=0;i<4;i++){
    chain.push(f.url());
    const kids=f.childFrames();
    if(!kids.length) break;
    f=kids[0];
  }
  const expected=['wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
  const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
  const body=await page.locator('body').innerText().catch(()=> '');
  const result={pass:chainOk && errors.length===0, chain, chainOk, errors, topBodyChars:body.length};
  require('fs').writeFileSync('candidate-browser-smoke-result.json', JSON.stringify(result,null,2));
  console.log(JSON.stringify(result,null,2));
  await browser.close();
  if(!result.pass) process.exit(1);
})().catch(e=>{ console.error(e); process.exit(1); });
