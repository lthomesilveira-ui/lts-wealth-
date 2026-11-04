'use strict';
process.env.LTS_FLOW_RELEASE='v404';
const fixture=require('./lts_v379_fixtures.cjs'),base=fixture.response;
fixture.response=function(name,args){const j=base(name,args);if(/wealth_detail/.test(name))j.fgts_position={version:'fgts-position-evidence-v386',status:'position_after_withdrawal_unavailable',balance_brl:null};return j};
const {setup,open}=require('./lts_v382_browser.cjs'),{chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const out='qa/v404';fs.mkdirSync(out,{recursive:true});
async function run(browser,engine,width){const h=await setup(browser,width,980,'2026-11-02T15:00:00Z');let f;try{
 f=await open(h,'v404',true);await f.waitForFunction(()=>window.__LTS_V178_STATE?.wealth.status==='ready');
 const fgts=()=>f.locator('.v168-dashboard .v168-kpi').filter({has:f.locator('span').filter({hasText:/^FGTS$/})});
 assert.equal(await fgts().locator('strong').innerText(),'—');assert.match(await fgts().innerText(),/confirmar no extrato/);
 const source=await f.evaluate(()=>JSON.stringify({cash:__LTS_V178_STATE.cash.data,forecast:__LTS_V178_STATE.forecast.data}));
 for(const [status,balance,expected] of [['ready',0,'R$ 0,00'],['ready',123,'R$ 123,00'],['loading',123,'—'],['error',123,'—'],['ready',123,'R$ 123,00']]){
  await f.evaluate(({status,balance})=>{const s=window.__LTS_V178_STATE.wealth;s.status=status;s.data.fgts_position={version:'fgts-position-evidence-v386',status:'dated_documentary_position',balance_as_of:'2026-10-31',balance_brl:balance};render()},{status,balance});
  assert.equal(await fgts().locator('strong').innerText(),expected);
 }
 await f.evaluate(()=>{const s=__LTS_V178_STATE.wealth;s.status='ready';s.data.fgts_position={version:'fgts-position-evidence-v386',status:'position_after_withdrawal_unavailable',balance_brl:null};render();render()});
 assert.equal(await fgts().count(),1);assert.equal(await fgts().locator('strong').innerText(),'—');
 await f.locator('#nav [data-v="Patrimônio"]:visible,#dx1MobileNav [data-mobile-route="Patrimônio"]:visible').click();await f.waitForFunction(()=>V==='Patrimônio');
 assert.match(await f.locator('[data-v386-fgts]').innerText(),/Saldo atual a confirmar/);
 await f.locator('#nav [data-v="Dashboard"]:visible,#dx1MobileNav [data-mobile-route="Dashboard"]:visible').click();await f.waitForFunction(()=>V==='Dashboard');assert.equal(await fgts().locator('strong').innerText(),'—');
 assert.equal(await f.evaluate(()=>JSON.stringify({cash:__LTS_V178_STATE.cash.data,forecast:__LTS_V178_STATE.forecast.data})),source,'financial source payloads unchanged');
 await fgts().evaluate(e=>e.scrollIntoView({block:'center',behavior:'instant'}));
 const geometry=await fgts().evaluate(e=>{const r=e.getBoundingClientRect();return{width:innerWidth,scroll:document.documentElement.scrollWidth,left:r.left,right:r.right,height:r.height}});
 assert(geometry.scroll<=width+2&&geometry.left>=-1&&geometry.right<=width+2,JSON.stringify(geometry));
 await h.page.screenshot({path:out+'/'+engine+'-'+width+'-dashboard.png',fullPage:true});assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
 return{pass:true,engine,width,full_application:true,documented_zero:true,unknown_not_zero:true,state_transitions:true,repeated_render:true,wealth_navigation:true,financial_sources_unchanged:true,synthetic_only:true,physical_iphone:false};
}catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,errors:h.errors,reads:h.reads.slice(-10),body:f?await f.locator('body').innerText():null},null,2));throw e}finally{await h.ctx.close()}}
(async()=>{const results=[];for(const [engine,type]of[['chromium',chromium],['webkit',webkit]]){const b=await type.launch();try{for(const width of[320,393,1366])results.push(await run(b,engine,width))}finally{await b.close()}}fs.writeFileSync(out+'/app-results.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,cases:results.length,full_application:true}));})().catch(e=>{console.error(e);process.exitCode=1});
