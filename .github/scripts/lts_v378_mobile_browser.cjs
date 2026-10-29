'use strict';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const fixture=require('./lts_v309_fixtures.cjs'),base='http://127.0.0.1:8788',out='qa/v378';fs.mkdirSync(out,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
(async()=>{
 const results=[];
 for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){
  const browser=await type.launch({headless:true});
  try{for(const[width,height]of[[390,844],[360,800],[844,390],[1366,768]]){
   const ctx=await browser.newContext({viewport:{width,height},isMobile:width<1000,hasTouch:width<1000,serviceWorkers:'block'});
   await ctx.addInitScript(s=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:['2026-10-16T15:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T15:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));Object.defineProperty(navigator,'standalone',{get:()=>true});},session);
   const page=await ctx.newPage(),errors=[],writes=[];page.setDefaultTimeout(25000);page.on('pageerror',e=>errors.push(String(e)));
   await ctx.route('**/*',route=>{const req=route.request(),url=new URL(req.url());if(url.origin===new URL(base).origin)return route.continue();if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.abort();const name=url.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=j=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(j)});
    if(url.pathname==='/auth/v1/token')return send(session);
    if(name==='lts_browser_product_v1')return send({ok:true,mvp:fixture.product()});
    if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:[]});
    if(/recurring_future_gap/.test(name))return send(fixture.recurring());
    if(/^lts_browser_monthly_/.test(name))return send(fixture.monthly(args.p_from,args.p_to));
    if(name==='lts_browser_recurring_plans_v366')return send({ok:true,rules:[]});
    if(/_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_|_update_/.test(name)){writes.push(name);return route.abort();}
    const mapped=({lts_browser_expense_detail_v374:'lts_browser_expense_detail_v346',lts_browser_expense_scope_detail_v374:'lts_browser_expense_detail_v353'})[name]||name;
    return send(fixture.response(mapped,args));
   });
   try{
    await page.goto(base+'/mobile/?source=home-screen',{waitUntil:'domcontentloaded'});
    await page.waitForFunction(()=>document.getElementById('wealth')?.contentDocument?.getElementById('shell')?.contentDocument?.body?.dataset.ltsBootState==='ready');
    const frame=page.frames().find(f=>/releases\/v[0-9]+\/index.html/.test(f.url()));assert(frame);
    await frame.waitForFunction(()=>window.__LTS_V365?.installed&&D&&!N.classList.contains('hidden'));
    await page.waitForLoadState('networkidle');
    const screens=[];
    for(const view of['Dashboard','Fluxo Diário','Patrimônio','Despesas','Atualizações']){
     await frame.evaluate(v=>{V=v;renderNav();render();},view);await page.waitForLoadState('networkidle');
     if(view==='Fluxo Diário'){await frame.evaluate(async()=>{await loadFlowRange('2026-10-16','2026-10-20');});await frame.locator('#d-2026-10-16').waitFor();}
     const metrics=await frame.evaluate(()=>({width:innerWidth,height:innerHeight,scroll:document.documentElement.scrollWidth,bodyWidth:document.body.getBoundingClientRect().width,header:document.querySelector('header')?.getBoundingClientRect().toJSON(),overflow:[...document.querySelectorAll('body *')].filter(e=>{const r=e.getBoundingClientRect();const s=getComputedStyle(e);return r.width>0&&r.right>innerWidth+2&&s.position!=='fixed'&&!e.closest('dialog,.fx87-scroll,.mscroll,.v168-tablewrap,.ledgerwrap')}).slice(0,12).map(e=>({tag:e.tagName,cls:e.className,width:Math.round(e.getBoundingClientRect().width),right:Math.round(e.getBoundingClientRect().right)}))}));
     await page.screenshot({path:out+'/'+engine+'-'+width+'-'+view.replaceAll(' ','-')+'.png'});
     assert(metrics.scroll<=metrics.width+2,engine+' '+width+' '+view+' must fit the viewport');
     assert.equal(metrics.width,width);
     screens.push({view,...metrics});
    }
    const outer=await page.evaluate(()=>({width:innerWidth,height:innerHeight,frame:document.getElementById('wealth').getBoundingClientRect().toJSON()}));
    assert.deepEqual(errors,[]);assert.deepEqual(writes,[]);
    await page.addStyleTag({content:':root{--wealth-safe-top:47px;--wealth-safe-right:0px;--wealth-safe-bottom:34px;--wealth-safe-left:0px}'});
    const inset=await page.locator('#wealth').boundingBox();assert.equal(Math.round(inset.y),47);assert.equal(Math.round(inset.height),height-81);
    await page.addStyleTag({content:':root{--wealth-safe-top:0px;--wealth-safe-right:47px;--wealth-safe-bottom:21px;--wealth-safe-left:47px}'});
    const landscape=await page.locator('#wealth').boundingBox();assert.equal(Math.round(landscape.x),47);assert.equal(Math.round(landscape.width),width-94);assert.equal(Math.round(landscape.height),height-21);
    const field=frame.locator('input:not([type=checkbox]):not([type=radio]),select,textarea').first();if(width<=900&&await field.count())assert(Number.parseFloat(await field.evaluate(e=>getComputedStyle(e).fontSize))>=16);
    const row={engine,width,height,outer,screens,errors,writes,safe_area_simulated:{portrait:inset,landscape},physical_iphone_verified:false,private_session_verified:false};results.push(row);console.log(JSON.stringify(row));
   }finally{await ctx.close();}
  }}finally{await browser.close();}
 }
 fs.writeFileSync(out+'/result.json',JSON.stringify(results,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
