'use strict';
const {chromium}=require('playwright');

(async()=>{
  const browser=await chromium.launch({headless:true});
  const page=await browser.newPage({viewport:{width:1440,height:1000}});
  const errors=[];
  page.on('pageerror',error=>errors.push(String(error.message||error)));
  page.on('console',message=>{if(message.type()==='error')errors.push(message.text())});
  await page.goto('http://127.0.0.1:8781/wip35-v166-candidate.html',{waitUntil:'domcontentloaded'});
  await page.waitForTimeout(2500);
  const version=await page.evaluate(()=>window.__LTS_TOP_CANDIDATE_VERSION||null);
  const brand=await page.frameLocator('#shell').locator('.brand small').innerText();
  if(version!=='v166-feedback-closure'||!brand.includes('V166')){
    throw new Error(`V166 shell inactive: version=${version}; brand=${brand}; errors=${JSON.stringify(errors)}`);
  }
  console.log(JSON.stringify({pass:true,version,brand,errors},null,2));
  await browser.close();
})().catch(error=>{console.error(error);process.exit(1)});
