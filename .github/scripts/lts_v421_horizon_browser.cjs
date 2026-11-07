'use strict';
process.env.LTS_FLOW_RELEASE='v421';
const assert=require('node:assert/strict'),fs=require('node:fs'),{chromium,webkit}=require('playwright');
const fixture=require('./lts_v379_fixtures.cjs'),{setup,open}=require('./lts_v382_browser.cjs');
const out='qa/v421';fs.mkdirSync(out,{recursive:true});
async function run(browser,engine,width){
 const h=await setup(browser,width,width<1000?900:1000,'2026-11-07T15:00:00Z');let mode='normal',f;const calls=[];
 await h.ctx.route('**/rest/v1/rpc/lts_browser_flow_v242',async route=>{
  const args=JSON.parse(route.request().postData()||'{}');calls.push(args);
  const p=structuredClone(fixture.response('lts_browser_flow_v242',args)),days=p?.flow?.current_future?.days;
  assert(Array.isArray(days),'existing complete flow fixture required');
  for(const d of days){let a=1000,b=2000,c=3000;
   if(d.date==='2028-02-01')a=-10;if(d.date==='2031-06-30')a=-900;
   if(d.date==='2029-03-01')b=-5;if(d.date==='2030-09-01')b=-100;
   if(d.date==='2031-11-11')c=19;
   Object.assign(d.fix86_columns,{saldo_apos_d0_1:a,saldo_apos_rsu:b,saldo_apos_fgts:c});
  }
  if(mode==='missing')days.splice(Math.min(5,days.length-1),1);
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});
 });
 try{
  f=await open(h,'v421',false);
  await f.waitForFunction(()=>__LTS_V178_STATE?.forecast.status==='ready'&&__LTS_V178_STATE.forecast.data?.coverage?.to==='2031-12-31');
  await h.page.waitForLoadState('networkidle');
  const cards=f.locator('.v168-dashboard .v168-decision');assert.equal(await cards.count(),3);
  const texts=await cards.allInnerTexts();
  assert.match(texts[0],/01\/02\/2028/);assert.match(texts[0],/30\/06\/2031/);assert.match(texts[0],/900,00/);
  assert.match(texts[1],/01\/03\/2029/);assert.match(texts[1],/01\/09\/2030/);assert.match(texts[1],/100,00/);
  assert.match(texts[2],/Sem saldo negativo até 31\/12\/2031/);assert.match(texts[2],/11\/11\/2031/);assert.match(texts[2],/19,00/);
  for(const text of texts){assert.match(text,/Menor saldo no horizonte/);assert.match(text,/Projeção até 31\/12\/2031/);assert(!text.includes('Projeção até 31/12/2027'));}
  assert(calls.some(x=>x.p_from==='2026-11-02'&&x.p_to==='2031-12-31'));
  assert(await f.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));
  await cards.first().scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-scenarios.png'});
  const source=await f.evaluate(()=>JSON.stringify(__LTS_V178_STATE.forecast.data));
  await f.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
  await f.waitForFunction(()=>V==='Fluxo Diário'&&!FLOWLOADING);
  if(!await f.locator('.v382-period').getAttribute('open'))await f.locator('.v382-period>summary').click();
  await f.getByLabel('Data inicial do Fluxo',{exact:true}).fill('2026-11-07');
  await f.getByLabel('Data final do Fluxo',{exact:true}).fill('2027-12-31');
  await f.locator('#flowApply').click();
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2026-11-07'&&FLOWTO==='2027-12-31');
  await f.locator('#nav [data-v="Dashboard"]:visible,#dx1MobileNav [data-mobile-route="Dashboard"]:visible').click();
  await f.waitForFunction(()=>V==='Dashboard');
  assert.equal(await f.evaluate(()=>JSON.stringify(__LTS_V178_STATE.forecast.data)),source,'explicit Flow filter cannot replace the full dashboard horizon');
  mode='missing';await f.evaluate(()=>__LTS_V178_REVIEW.refreshForecast());
  await f.waitForFunction(()=>__LTS_V178_STATE.forecast.status==='incomplete');
  assert.equal(await cards.locator('.v385-scenario-stats').count(),0,'no definitive minima from incomplete data');
  assert.equal(await cards.locator('.v385-scenario-unavailable').count(),3);
  await cards.first().scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-incomplete.png'});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{passed:true,engine,width,horizon:'2031-12-31',policy_metadata_required:false,positive_minimum:true,late_deficit:true,explicit_flow_range_preserved:true,incomplete_not_certified:true,financial_writes:0,private_session:false,physical_iphone:false};
 }catch(error){if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.txt',String(error.stack)+'\n'+await f.locator('body').innerText());await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});throw error;}
 finally{await h.ctx.close();}
}
(async()=>{let results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){let b=await type.launch({headless:true});try{for(const w of[320,393,1366]){results.push(await run(b,engine,w));fs.writeFileSync(out+'/result.json',JSON.stringify({passed:false,results},null,2));}}finally{await b.close();}}fs.writeFileSync(out+'/result.json',JSON.stringify({passed:true,results},null,2));console.log(JSON.stringify({passed:true,runs:results.length}));})().catch(e=>{console.error(e);process.exitCode=1});
