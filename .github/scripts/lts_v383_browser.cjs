'use strict';
process.env.LTS_FLOW_RELEASE='v383';
const {setup,open,geometry}=require('./lts_v382_browser.cjs');
const {chromium,webkit}=require('playwright'),assert=require('node:assert/strict'),fs=require('node:fs');
const out='qa/v383-default';fs.mkdirSync(out,{recursive:true});
const cases=[['2026-10-31T15:00:00Z','2026-10-31','2026-10-26','2030-12-31'],['2027-01-01T15:00:00Z','2027-01-01','2026-12-27','2031-12-31'],['2028-03-01T15:00:00Z','2028-03-01','2028-02-25','2032-12-31'],['2027-01-01T02:00:00Z','2026-12-31','2026-12-26','2030-12-31']];
async function navigate(frame,name){const route=frame.locator('#nav [data-v="'+name+'"]:visible,#dx1MobileNav [data-mobile-route="'+name+'"]:visible');assert.equal(await route.count(),1);await route.click();await frame.waitForFunction(v=>V===v,name);}
async function run(browser,engine,width,c){
 const[now,today,from,to]=c,h=await setup(browser,width,width===393?852:900,now);let f;
 try{
  f=await open(h,'v383',true);assert.equal(await f.evaluate(()=>today()),today,'São Paulo calendar day');
  // Reproduce a valid period inherited from another screen before first Flow entry.
  await f.evaluate(()=>{FLOWFROM=today();FLOWTO=shift(today(),29);});
  await navigate(f,'Fluxo Diário');await f.waitForFunction(r=>!FLOWLOADING&&FLOWQ?.from===r.from&&FLOWQ?.to===r.to,{from,to});
  assert.equal(await f.locator('#flowFrom').inputValue(),from);assert.equal(await f.locator('#flowTo').inputValue(),to);
  const g=await geometry(f);assert(g.scroll<=width+2);assert.equal(await f.locator('.v382-period>summary').count(),1);assert.equal(await f.locator('.v382-period[open]').count(),0);assert.equal(g.visiblePresets,0);assert(g.filters.height<=118);
  assert.equal(await f.evaluate(()=>SHOWZERO),false,'unchanged empty-day filter');
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+today+'-flow.png'});
  await f.locator('.v382-period>summary').click();await f.getByLabel('Data inicial do Fluxo',{exact:true}).fill('2025-12-15');await f.getByLabel('Data final do Fluxo',{exact:true}).fill('2026-01-10');await f.locator('#flowApply').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2025-12-15'&&FLOWQ?.to==='2026-01-10');
  await navigate(f,'Dashboard');await h.page.waitForLoadState('networkidle');const text=await f.locator('body').innerText();assert(!text.includes('Obrigação mais antiga'));const dashboard=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,open:document.querySelectorAll('.v337-source[open]').length}));assert(dashboard.scroll<=width+2);assert.equal(dashboard.open,0);await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+today+'-dashboard.png'});
  await navigate(f,'Fluxo Diário');await f.waitForFunction(()=>!FLOWLOADING);assert.equal(await f.locator('#flowFrom').inputValue(),'2025-12-15','chosen period survives returning to Flow');assert.equal(await f.locator('#flowTo').inputValue(),'2026-01-10');
  if(!await f.locator('.v382-period[open]').count())await f.locator('.v382-period>summary').click();await f.locator('#flowDefaultRange').click();await f.waitForFunction(r=>!FLOWLOADING&&FLOWQ?.from===r.from&&FLOWQ?.to===r.to,{from,to});
  assert.deepEqual(h.writes,[]);assert.deepEqual(h.errors,[]);
  return {pass:true,engine,width,calendar_day:today,default_from:from,default_to:to,closed_single_period_button:true,dashboard_fit:true,chosen_period_preserved:true,default_reset:true,synthetic_only:true,physical_iphone:false,private_session:false};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,state:await f.evaluate(()=>({V,FLOWFROM,FLOWTO,FLOWLOADING,FLOWQ}))},null,2));throw e;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{for(const width of[393,1366])for(const c of cases){const result=await run(browser,engine,width,c);results.push(result);console.log(JSON.stringify(result));fs.writeFileSync(out+'/result.json',JSON.stringify({pass:results.length===16&&results.every(x=>x.pass),results},null,2));}}finally{await browser.close();}}})().catch(e=>{console.error(e);process.exitCode=1});
