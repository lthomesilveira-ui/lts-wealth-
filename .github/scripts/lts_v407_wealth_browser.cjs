'use strict';
process.env.LTS_FLOW_RELEASE||='v407';
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response,{setup,open}=require('./lts_v382_browser.cjs');
const {chromium,webkit}=require('playwright'),target=process.env.LTS_FLOW_RELEASE,out='qa/'+target;
fs.mkdirSync(out,{recursive:true});const money=v=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(v),hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
function payload(){
 const j=fixture.contracts(structuredClone(baseResponse('lts_browser_wealth_detail_v242')));
 j.as_of='2026-11-04';j.financing.summary.as_of='2026-11-04';j.wealth={assets:{cipo_396:{market_central:2000},volvo_xc40:{market_central:500}},summary:{assets_central:2803,known_debt_total:900,debt_total_complete:false},liquidity:{bank_cash:200,d0:100,fgts_contingency:0}};
 j.wealth_v167={assets_central_including_pensions:3003,net_worth_central_including_pensions:null};j.pensions={total_gross_brl:200,positions:[]};
 j.rsu_summary={as_of:'2026-10-06',available_total_brl:3,future_regular_brl:60,future_cash_net_brl:28,future_considered_total_brl:88};
 j.fgts_position={version:'fgts-position-evidence-v386',as_of:'2026-11-04',status:'position_after_withdrawal_unavailable',balance_brl:null,balance_as_of:null};return j;
}
fixture.response=function(name,args){if(/^lts_browser_wealth_detail_/.test(name))return payload();const j=baseResponse(name,args);if(/^lts_browser_cash_today_/.test(name)){j.as_of='2026-11-04';j.day.date='2026-11-04';}return j;};
async function go(f,view){await f.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await f.waitForFunction(v=>V===v,view);}
async function geometry(f){return f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,values:[...document.querySelectorAll('.v365-wealth-totals>article>strong')].map(e=>{const r=e.getBoundingClientRect(),t=document.createRange();t.selectNodeContents(e);return{left:r.left,right:r.right,lines:new Set([...t.getClientRects()].map(v=>Math.round(v.top))).size};})}));}
async function run(browser,engine,width){
 const h=await setup(browser,width,width===1366?950:980,'2026-11-04T15:00:00Z');let f;
 try{
  f=await open(h,target,true);await f.waitForFunction(()=>window.__LTS_V407_WEALTH?.installed&&window.__LTS_V178_STATE?.cash?.status==='ready');
  const bank=f.locator('.v168-dashboard .v168-kpi').filter({has:f.locator('span').filter({hasText:/^Contas correntes$/})});assert.equal(await bank.locator('strong').innerText(),money(1000),'Dashboard retains useful current cash');
  const dashboard=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,open:document.querySelectorAll('.v337-source[open]').length}));assert(dashboard.scroll<=width+2);assert.equal(dashboard.open,0);await h.page.screenshot({path:out+'/'+engine+'-'+width+'-dashboard.png'});
  await go(f,'Patrimônio');await f.waitForFunction(()=>window.__LTS_V168_STATE?.wealth?.data&&!window.__LTS_V168_STATE.wealth.loading&&document.querySelector('[data-v407-partial]'));
  const original=await f.evaluate(()=>structuredClone(window.__LTS_V168_STATE.wealth.data)),before=hash(original),root=f.locator('.v168-wealth'),card=root.locator('[data-v407-partial]');
  assert.equal(await card.locator(':scope>span').innerText(),'Patrimônio líquido parcial');assert.equal(await card.locator(':scope>strong').innerText(),money(2103));
  assert.match(await root.locator('.v365-material').innerText(),/Volvo XC40.*Coopharma.*Pai e Mãe.*FGTS/);assert.equal(await root.locator('[data-v386-fgts]>.v365-pair>b').innerText(),'—');
  assert.equal(await card.locator('details[open]').count(),0);await card.locator('summary').click();assert.equal(await card.locator('.v407-wealth-pair').count(),3);assert.match(await card.locator('details').innerText(),/3\.003,00.*900,00.*2\.103,00/s);await card.locator('summary').click();
  const layout=await geometry(f);assert(layout.scroll<=width+2,JSON.stringify(layout));assert(layout.values.every(v=>v.left>=0&&v.right<=width+2&&v.lines===1),'whole monetary amounts fit');await h.page.screenshot({path:out+'/'+engine+'-'+width+'-wealth.png'});
  const variants=[
   ['zero',j=>{j.wealth_v167.assets_central_including_pensions=0;j.wealth.summary.known_debt_total=0;j.financing.summary.commitments[0].current_documentary_debt_balance=0;},0],
   ['negative',j=>{j.wealth_v167.assets_central_including_pensions=500;},-400],
   ['missing-summary',j=>{j.wealth.summary.known_debt_total=null;},null],
   ['mismatched-components',j=>{j.wealth.summary.known_debt_total=901;},null],
   ['duplicate-contract',j=>{j.financing.summary.commitments.push(structuredClone(j.financing.summary.commitments[0]));},null],
   ['all-unknown',j=>{for(const c of j.financing.summary.commitments)c.current_documentary_debt_balance=null;j.wealth.summary.known_debt_total=0;},null],
   ['invalid-number',j=>{j.wealth.summary.known_debt_total='';},null],
   ['undated-position',j=>{j.financing.summary.commitments[0].current_debt_as_of=null;},null],
   ['future-position',j=>{j.financing.summary.as_of='2026-11-04';j.financing.summary.commitments[0].current_debt_as_of='2027-01-01';},null],
   ['missing-as-of',j=>{delete j.as_of;delete j.financing.summary.as_of;},null],
   ['invalid-as-of',j=>{j.as_of='invalid';j.financing.summary.as_of='invalid';},null],
   ['valid-fallback-as-of',j=>{j.financing.summary.as_of='invalid';},2103],
   ['fractional-cent',j=>{j.wealth_v167.assets_central_including_pensions='1.005';},null],
   ['fractional-cent-below-half',j=>{j.wealth_v167.assets_central_including_pensions=1.004;},null],
   ['cent-addition',j=>{j.wealth_v167.assets_central_including_pensions=1;j.wealth.summary.known_debt_total=.3;j.financing.summary.commitments[0].current_documentary_debt_balance=.1;j.financing.summary.commitments[1].current_documentary_debt_balance=.2;j.financing.summary.commitments[1].current_debt_as_of='2026-10-30';},.7],
   ['complete',j=>{j.financing.summary.commitments.forEach((c,i)=>{c.current_documentary_debt_balance=[900,100,200,300][i];c.current_debt_as_of='2026-10-30';});j.wealth.summary.known_debt_total=1500;j.wealth.summary.debt_total_complete=true;j.wealth_v167={assets_central_including_pensions:3058,net_worth_central_including_pensions:1558};j.fgts_position={version:'fgts-position-evidence-v386',status:'dated_documentary_position',balance_brl:55,balance_as_of:'2026-10-30'};},'complete']
  ];
  for(const[name,change,expected]of variants){const j=structuredClone(original);change(j);const digest=hash(j);await f.evaluate(j=>{__LTS_V168_STATE.wealth.data=j;render();},j);const totals=root.locator('.v365-wealth-totals');
   if(expected==='complete'){assert.equal(await card.count(),0);assert.match(await totals.innerText(),/1\.558,00/);assert(!(await totals.innerText()).includes('Em apuração'));}
   else if(expected===null){assert.equal(await card.count(),0,name);assert.match(await totals.innerText(),/Em apuração/,name);}
   else{assert.equal(await card.locator(':scope>strong').innerText(),money(expected),name);assert.equal(await card.locator('details[open]').count(),0);}
   assert.equal(hash(await f.evaluate(()=>__LTS_V168_STATE.wealth.data)),digest,'source data unchanged '+name);
  }
  await f.evaluate(j=>{__LTS_V168_STATE.wealth.data=j;render();render();},original);assert.equal(await card.count(),1);assert.equal(hash(await f.evaluate(()=>__LTS_V168_STATE.wealth.data)),before);
  await root.locator('[data-v168-wealth-tab="assets"]').click();await root.locator('[data-v168-wealth-tab="overview"]').click();assert.equal(await card.count(),1);assert.equal(await card.locator('details[open]').count(),0);
  await go(f,'Fluxo Diário');await f.evaluate(()=>loadFlowRange('2026-10-25','2026-11-28'));await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.to==='2026-11-28');
  const flow=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,periodOpen:!!document.querySelector('.v382-period[open]'),height:document.querySelector('.flow-sticky-controls').getBoundingClientRect().height,financial:JSON.stringify(FLOWQ)}));assert(flow.scroll<=width+2);assert.equal(flow.periodOpen,false);assert(flow.height<430,'collapsed controls remain compact');await h.page.screenshot({path:out+'/'+engine+'-'+width+'-flow.png'});
  await go(f,'Dashboard');assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,semantic_cases:variants.length+1,wealth_layout:layout,flow_controls_height:flow.height,financial_payloads_unchanged:true,write_requests:0,synthetic_only:true,private_session:false,physical_iphone:false};
 }catch(error){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:error.stack,body:f?await f.locator('body').innerText():null,reads:h.reads.slice(-12),errors:h.errors},null,2));throw error;}finally{await h.ctx.close();}
}
module.exports={run,payload};
if(require.main===module)(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch();try{for(const width of[320,393,1366])results.push(await run(browser,engine,width));}finally{await browser.close();}}fs.writeFileSync(out+'/wealth-results.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,runs:results.length,semantic_cases:results.reduce((s,r)=>s+r.semantic_cases,0)}));})().catch(e=>{console.error(e);process.exitCode=1;});
