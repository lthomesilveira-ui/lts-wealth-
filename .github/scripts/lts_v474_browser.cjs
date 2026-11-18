'use strict';
const assert = require('node:assert/strict');
const {chromium,webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const {product} = require('./lts_v379_fixtures.cjs');
const base = 'http://127.0.0.1:8788';
const release = process.env.LTS_MOBILE_RELEASE || 'v474';

async function landing(browser) {
  const page = await browser.newPage({viewport:{width:320,height:740}});
  try {
    await page.goto(base+'/mobile/');
    await page.getByText(release.toUpperCase(),{exact:true}).waitFor();
    assert.equal(await page.getByRole('button',{name:'Abrir Wealth'}).isEnabled(),true);
    assert.equal(await page.locator('#appViewport').isHidden(),true);
  } finally { await page.close(); }
}
async function verify(browser, width) {
  const s=await setup(browser,width,845,'2026-11-17T17:00:00Z');
  let incomeCalls=0;
  try {
    const refresh={state:'ready',required:false,cached_available:true,request_version:'2',completed_version:'2'};
    await s.ctx.route('**/rpc/lts_browser_product_v1',r=>r.fulfill({json:{ok:true,mvp:product(),refresh}}));
    await s.ctx.route('**/rpc/lts_browser_product_refresh_status_v415',r=>r.fulfill({json:{ok:true,refresh}}));
    const empty={ok:true,rows:[],row_count:0,matched_count:0,offset:0,next_offset:null,additional_count:0};
    await s.ctx.route('**/rpc/lts_browser_income_review_queue_v296',r=>++incomeCalls===1
      ?r.fulfill({status:503,json:{message:'Test service unavailable'}}):r.fulfill({json:empty}));
    await s.ctx.route('**/rpc/lts_browser_expense_review_queue_v229',r=>r.fulfill({json:empty}));
    await s.page.goto(base+'/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    await s.page.waitForFunction(()=>document.querySelector('#wealth')?.contentDocument
      ?.querySelector('#shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
    const frame=s.page.frames().find(f=>new URL(f.url()).pathname.endsWith('/releases/'+release+'/index.html'));
    assert(frame,'active release frame');
    const label=frame.locator('header #lts-release-header');
    async function visibleVersion() {
      await label.waitFor({state:'visible'});
      assert.equal(await label.innerText(),release.toUpperCase());
      const clear=await label.evaluate(el=>{
        const rect=el.getBoundingClientRect(),button=document.querySelector('#logout').getBoundingClientRect();
        const hit=document.elementFromPoint(rect.left+rect.width/2,rect.top+rect.height/2);
        return rect.width>20&&rect.height>=12&&rect.left>=0&&rect.right<=innerWidth&&rect.top>=0
          &&rect.bottom<=innerHeight&&el.contains(hit)
          &&(rect.right<=button.left||button.right<=rect.left||rect.bottom<=button.top||button.bottom<=rect.top);
      });
      assert.equal(clear,true,'release label is in the viewport and clear of the sign-out control');
    }
    await visibleVersion();
    await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS?.state?.data?.row_count===0
      &&window.__LTS_V296_CLASSIFICATIONS.state.expense===0&&!window.__LTS_V296_CLASSIFICATIONS.state.error);
    assert.equal(incomeCalls,2,'one transient failure recovered without pressing retry');
    await frame.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
    await visibleVersion();
    assert.deepEqual(s.writes,[]);
  } finally { await s.ctx.close(); }
}
(async()=>{
  for(const type of [chromium,webkit]){
    const browser=await type.launch();
    try{
      await landing(browser);
      for(const width of [320,393,1366]) await verify(browser,width);
    }finally{await browser.close();}
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
