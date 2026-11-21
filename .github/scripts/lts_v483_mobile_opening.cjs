'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {gzipSync} = require('node:zlib');
const {chromium,webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';
const candidate = process.env.LTS_OPENING_COMPARE_RELEASE || 'v483';
assert.ok(['v483','v484','v486','v489','v490','v491','v492','v494','v495'].includes(candidate));
const wait = ms => new Promise(done=>setTimeout(done,ms));
const cash = {status:'complete',as_of:'2026-10-30',version:'cash-today-v179-current-canonical',cash:150,d0:25,brokerage_available:25,available_total:200,bank_positions:[{institution:'Banco de teste',balance:150}]};
const fields = ['projection_build_v438','financial_audit','recurring_audit_v442','projection_summary_v418'];
const sample = Array.from({length:17000},(_,i)=>({row:i,date:'2026-10-30',amount:(i*137)%70219,policy:'audit_fixture'}));
const full=product();
for (const key of fields) full[key]=sample;
const safe=product();
const sizes=new Map();
function compressed(path) {
  if(!sizes.has(path))sizes.set(path,gzipSync(fs.readFileSync(path)).length);
  return sizes.get(path);
}
async function measure(browser,release) {
  const {ctx,page}=await setup(browser,390,844);
  // Fresh contexts have empty HTTP caches and a known test login. A shared
  // 3 Mbit/s transfer budget and a 150 ms RTT apply to both tested versions.
  let queue=0, productReads=0, requestedAt=0;
  const start=performance.now();
  async function download(bytes) {
    await wait(150);
    const end=Math.max(queue,performance.now())+bytes/375;
    queue=end;await wait(Math.max(0,end-performance.now()));
  }
  try {
    await ctx.route(base+'/**',async route=>{
      const path=decodeURIComponent(new URL(route.request().url()).pathname).slice(1);
      if(path==='mobile/current.json'){
        await download(90);
        return route.fulfill({json:{release,entry:'../releases/'+release+'/app.html'}});
      }
      if(path && !path.includes('..') && fs.existsSync(path)&&fs.statSync(path).isFile()) {
        await download(compressed(path));
      }
      return route.continue();
    });
    await ctx.route('**/rpc/lts_browser_product_v1',async route=>{
      const args=route.request().postDataJSON();
      productReads++;if(productReads===1)requestedAt=performance.now()-start;
      if(release===candidate)assert.equal(args.p_mobile_version,483);
      const payload=JSON.stringify({ok:true,mvp:args.p_mobile_version===483?safe:full,refresh:{state:'ready',required:false,cached_available:true,request_version:'1',completed_version:'1'}});
      await wait(3000);await download(gzipSync(payload).length);
      return route.fulfill({contentType:'application/json',body:payload});
    });
    await ctx.route('**/rpc/lts_browser_cash_today_v242',async route=>{
      await wait(200);await download(380);return route.fulfill({json:cash});
    });
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'commit'});
    const frame=page.frameLocator('#wealth').frameLocator('#shell');
    await frame.locator('.opening-position').getByText('Banco de teste',{exact:true}).waitFor({timeout:20000});
    const bankMs=Math.round(performance.now()-start);
    if (release==='v484'||release==='v486'||release==='v489'||release==='v490'||release==='v491'||release==='v492'||release==='v494'||release==='v495') {
      const position=frame.locator('.opening-position');
      assert.ok(await position.getByRole('heading',{name:'Total disponível hoje',exact:true}).isVisible());
      assert.match(await position.innerText(),/200,00/);
    }
    const flow=frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');
    await flow.first().tap({timeout:22000});
    await frame.locator('[data-a="Itaú"]:visible').first().waitFor();
    assert.equal(productReads,1,'one initial product request');
    return {engine:browser.browserType().name(),release,bankMs,flowControlMs:Math.round(performance.now()-start),requestMs:Math.round(requestedAt)};
  } finally {await ctx.close();}
}
(async()=>{
  const rows=[];
  for(const type of [webkit,chromium]){
    const b=await type.launch({executablePath:type===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try {
      for(let i=0;i<3;i++)for(const r of (i%2?[candidate,'v482']:['v482',candidate])){
        const row=await measure(b,r);rows.push(row);console.log('MOBILE_OPEN',JSON.stringify(row));
      }
    }finally{await b.close();}
  }
  fs.writeFileSync('mobile-opening-v483.json',JSON.stringify(rows,null,2));
})().catch(err=>{console.error(err);process.exitCode=1;});
