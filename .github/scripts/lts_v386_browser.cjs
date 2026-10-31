'use strict';
// Invented identities and amounts. These fixtures are never private acceptance.
process.env.LTS_FLOW_RELEASE='v386';
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response,{setup,open}=require('./lts_v382_browser.cjs');
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const out='qa/v386';fs.mkdirSync(out,{recursive:true});let mode='withdrawn';
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
function wealth(){
 const j=fixture.contracts(structuredClone(baseResponse('lts_browser_wealth_detail_v242')));
 j.wealth={assets:{cipo_396:{market_central:2000,documentary_debt:900,equity_central:1100},volvo_xc40:{market_central:500,documented_financed_balance:100,equity_central:null}},summary:{assets_central:2803,known_debt_total:900,debt_total_complete:mode==='complete'||mode==='contradiction',net_worth_central:null},liquidity:{bank_cash:200,d0:100,fgts_contingency:0}};
 j.wealth_v167={assets_central_including_pensions:3003,net_worth_central_including_pensions:null};j.pensions={total_gross_brl:200,positions:[]};
 j.rsu_summary={as_of:'2026-10-06',available_total_brl:3,future_regular_brl:60,future_cash_net_brl:28,future_considered_total_brl:88};
 j.fgts_position={version:'fgts-position-evidence-v386',as_of:'2026-10-31',status:'position_after_withdrawal_unavailable',balance_brl:null,balance_as_of:null,last_documented_balance_brl:5010,last_documented_as_of:'2026-10-01',withdrawal:{confirmed:true,date:'2026-10-08',amount_brl:5010}};
 if(['zero','positive','complete'].includes(mode)){j.fgts_position={...j.fgts_position,status:'dated_documentary_position',balance_brl:mode==='zero'?0:55,balance_as_of:'2026-10-30'};j.wealth.liquidity.fgts_contingency=mode==='zero'?0:55;}
 if(mode==='missing'){delete j.fgts_position;}
 if(mode==='complete'){
  j.financing.summary.commitments.forEach((c,i)=>{c.current_documentary_debt_balance=[900,100,200,300][i];c.current_debt_as_of='2026-10-30';});
  j.wealth.summary.known_debt_total=1500;j.wealth_v167={assets_central_including_pensions:3058,net_worth_central_including_pensions:1558};
 }
 return j;
}
fixture.response=function(name,args){if(/^lts_browser_wealth_detail_/.test(name))return wealth();return baseResponse(name,args);};
async function navigate(f){const route=f.locator('#nav [data-v="Patrimônio"]:visible,#dx1MobileNav [data-mobile-route="Patrimônio"]:visible');assert.equal(await route.count(),1);await route.click();await f.waitForFunction(()=>V==='Patrimônio'&&window.__LTS_V168_STATE?.wealth?.data&&!window.__LTS_V168_STATE?.wealth?.loading&&document.querySelector('.v365-wealth-totals'));}
async function run(browser,engine,width,variant='withdrawn',baseline=false){
 mode=variant;const h=await setup(browser,width,width===1366?900:852,'2026-10-31T15:00:00Z'),label=engine+'-'+width+'-'+variant+(baseline?'-before':'');let f;
 try{
  f=await open(h,baseline?'v385':'v386',!baseline);await navigate(f);const root=f.locator('.v168-wealth'),text=await root.innerText();
  if(baseline){assert.match(text,/Schiavalli/);const oldFgts=root.locator('.v365-pair').filter({has:root.locator('span',{hasText:/^FGTS/})});assert((await oldFgts.allTextContents()).some(t=>t.includes('0,00')));return{pass:true,engine,width,baseline_regression_reproduced:true};}
  assert(!/Schiavalli/i.test(text));const before=hash(await f.evaluate(()=>window.__LTS_V168_STATE.wealth.data));
  const fgts=root.locator('[data-v386-fgts]'),value=fgts.locator(':scope>.v365-pair>b'),totals=root.locator('.v365-wealth-totals');
  assert.equal(await fgts.count(),1);assert.equal(await fgts.locator('details[open]').count(),0,'origin closed by default');
  if(['zero','positive','complete'].includes(variant)){assert.equal(await value.innerText(),money(variant==='zero'?0:55));assert.match(await fgts.innerText(),/30\/10\/2026/);}
  else{assert.equal(await value.innerText(),'—');assert.match(await fgts.innerText(),/Saldo atual a confirmar/);assert(!(await fgts.innerText()).includes(money(0)));}
  if(variant==='complete'){assert.match(await totals.innerText(),/1\.558,00/);assert(!(await totals.innerText()).includes('Em apuração'));assert.equal(await root.locator('.v365-material').count(),0);}
  else{
   assert.match(await totals.innerText(),/Em apuração/);assert.match(await totals.innerText(),/3\.003,00/);assert.match(await totals.innerText(),/900,00/);assert.match(await totals.innerText(),/1 de 4 saldos documentados/);
   for(const id of ['volvo','coopharma','pai_mae']){const d=root.locator('[data-v386-debt="'+id+'"]');assert.equal(await d.locator('b').innerText(),'—');assert.match(await d.innerText(),/Falta extrato com saldo devedor atual/);}
  }
  assert.match(await root.locator('.v386-debt-basis').innerText(),/não são somados/);
  const geometry=await root.evaluate(e=>({width:innerWidth,scroll:document.documentElement.scrollWidth,cards:[...e.querySelectorAll('.v365-pair>b')].map(b=>{const range=document.createRange();range.selectNodeContents(b);const r=b.getBoundingClientRect();return{text:b.textContent,left:r.left,right:r.right,lines:new Set([...range.getClientRects()].map(x=>Math.round(x.top))).size};})}));
  assert(geometry.scroll<=width+2,'fits viewport '+JSON.stringify(geometry));assert(geometry.cards.every(x=>x.left>=0&&x.right<=width+2&&x.lines===1),'all monetary values whole and inside viewport');
  await h.page.screenshot({path:out+'/'+label+'-overview.png'});
  if(variant==='withdrawn'&&[393,1366].includes(width)){const preview=await h.page.screenshot({type:'jpeg',quality:80});console.log('V386_VISUAL '+JSON.stringify({label:label+'-overview',mime:'image/jpeg',base64:preview.toString('base64')}));}
  await fgts.locator('summary').click();if(variant!=='missing'){assert.match(await fgts.innerText(),/5\.010,00/);assert.match(await fgts.innerText(),/08\/10\/2026/);assert.match(await fgts.innerText(),/já incorporado ao caixa/);}await fgts.locator('summary').click();
  await root.locator('[data-v168-wealth-tab="assets"]').click();assert.equal(await root.locator('[data-v309-contract]').count(),4);assert(!/Schiavalli/i.test(await root.innerText()));
  await root.locator('[data-v168-wealth-tab="overview"]').click();assert.equal(await root.locator('[data-v386-fgts] details[open]').count(),0);assert(!/Schiavalli/i.test(await root.innerText()));assert.equal(hash(await f.evaluate(()=>window.__LTS_V168_STATE.wealth.data)),before,'tab changes and disclosures preserve all received financial data');
  assert.deepEqual(h.writes,[]);assert.deepEqual(h.errors,[]);
  return{pass:true,engine,width,variant,excluded_asset_absent:true,fgts_balance_semantics:true,missing_debts_explicit:true,no_double_counting:true,financial_response_sha256:before,source_values_unchanged:true,origin_collapsed:true,synthetic_only:true,physical_iphone:false,private_session:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,body:await f.locator('body').innerText(),reads:h.reads},null,2));throw error;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of [['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{
 results.push(await run(browser,engine,393,'withdrawn',true));
 for(const width of[320,360,393,430,852,1366])results.push(await run(browser,engine,width));
 for(const variant of['zero','positive','complete','missing','contradiction'])results.push(await run(browser,engine,393,variant));
 }finally{await browser.close();}fs.writeFileSync(out+'/patrimony-result.json',JSON.stringify({pass:results.every(x=>x.pass),results},null,2));console.log(JSON.stringify({engine,passed:results.filter(x=>x.engine===engine).length}));}assert.equal(results.length,24);})().catch(error=>{console.error(error);process.exitCode=1});
