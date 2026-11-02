'use strict';
process.env.LTS_FLOW_RELEASE='v398';
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response;
const {setup,open}=require('./lts_v382_browser.cjs'),{chromium,webkit}=require('playwright');
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const out='qa/v398';fs.mkdirSync(out,{recursive:true});let mode='indexed';
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
fixture.response=function(name,args){
 const j=baseResponse(name,args);if(!/^lts_browser_wealth_detail_/.test(name))return j;
 fixture.contracts(j);
 const c=j.financing.summary.commitments.find(x=>x.id==='pai_mae');
 c.current_documentary_debt_balance=mode==='indexed'?1030.2:null;c.current_debt_as_of='2026-11-01';
 c.remaining_events=2;c.remaining_scheduled_outflow=50;c.planned_next_payment_date='2027-04-01';c.planned_next_payment_amount=25;
 c.indexation={version:'family-savings-position-v398',status:mode==='indexed'?'indexed_owner_position':'rate_coverage_incomplete',complete:mode==='indexed',original_principal_brl:1000,starts_on:'2025-01-01',balance_brl:c.current_documentary_debt_balance,accrued_savings_brl:mode==='indexed'?30.2:null,confirmed_repayments_brl:0,corrected_through:'2025-03-01'};
 return j;
};
async function run(browser,engine,width,variant){
 mode=variant;const h=await setup(browser,width,width===1366?900:852,'2026-11-01T15:00:00Z');let f;
 try{
  f=await open(h,'v398',true);await f.waitForFunction(()=>window.__LTS_V398_FAMILY?.installed);
  await f.locator('#nav [data-v="Patrimônio"]:visible,#dx1MobileNav [data-mobile-route="Patrimônio"]:visible').click();
  await f.waitForFunction(()=>document.querySelector('[data-v398-family]'));
  const before=hash(await f.evaluate(()=>window.__LTS_V168_STATE.wealth.data)),card=f.locator('[data-v398-family]');
  assert.equal(await card.count(),1);assert.equal(await card.locator('details[open]').count(),0,'origins and cash plan collapsed');
  const text=await card.innerText();assert.match(text,/Sem vencimento definido/);assert.match(text,/1\.000,00/);
  if(variant==='indexed'){assert.match(text,/1\.030,20/);assert.match(text,/30,20/);assert(!(await f.locator('[data-v386-debt="pai_mae"]').innerText()).includes('Falta extrato'));}
  else{assert.match(text,/Falta atualizar o índice/);assert.match(text,/A confirmar/);}
  assert(!/source_ref|raw_hash|metadata|SGS|sha256|backend|jsonb/i.test(text),'no internal vocabulary in visible card');
  assert(!text.includes('50,00'),'cash planning total is collapsed');
  await card.getByText('Planejamento de pagamentos',{exact:true}).click();assert.match(await card.innerText(),/50,00/);assert.match(await card.innerText(),/2 parcelas estimadas/);assert.match(await card.innerText(),/01\/04\/2027/);
  await card.getByText('Planejamento de pagamentos',{exact:true}).click();
  const geometry=await card.evaluate(e=>({width:innerWidth,scroll:document.documentElement.scrollWidth,closedHeight:e.getBoundingClientRect().height,values:[...e.querySelectorAll('.v365-pair>b')].filter(x=>x.getClientRects().length).map(x=>({left:x.getBoundingClientRect().left,right:x.getBoundingClientRect().right}))}));
  assert(geometry.scroll<=width+2,'layout fits viewport');assert(geometry.closedHeight<650,'collapsed card stays compact');assert(geometry.values.every(x=>x.left>=0&&x.right<=width+2),'monetary values remain visible');
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-'+variant+'.png'});
  await f.evaluate(()=>render());assert.equal(await f.locator('[data-v398-family]').count(),1,'re-render does not duplicate card');
  assert.equal(hash(await f.evaluate(()=>window.__LTS_V168_STATE.wealth.data)),before,'UI preserves the financial response');
  assert.deepEqual(h.writes,[]);assert.deepEqual(h.errors,[]);
  return {pass:true,engine,width,variant,closed_height:geometry.closedHeight,source_response_unchanged:true,private_session:false,physical_iphone:false};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,body:await f.locator('body').innerText(),errors:h.errors},null,2));throw e;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of [['webkit',webkit],['chromium',chromium]]){const b=await type.launch();try{for(const width of[320,393,1366])results.push(await run(b,engine,width,'indexed'));results.push(await run(b,engine,393,'missing'));}finally{await b.close();}}fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,scenarios:results.length,synthetic_only:true}));})().catch(e=>{console.error(e);process.exitCode=1});
