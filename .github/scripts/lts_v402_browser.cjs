'use strict';
process.env.LTS_FLOW_RELEASE='v402';
const fixture=require('./lts_v379_fixtures.cjs'),base=fixture.response;
const {setup,open}=require('./lts_v382_browser.cjs'),{chromium,webkit}=require('playwright');
const fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto'),out='qa/v402';fs.mkdirSync(out,{recursive:true});
fixture.response=function(name,args){
 const j=base(name,args);if(!/^lts_browser_flow_/.test(name)||!j.flow)return j;
 for(const part of ['historical','current_future'])for(const d of j.flow[part]?.days||[]){
  const later=d.date>='2026-10-30',value=later?750:700;
  d.Itaú.balance=77;d.Consolidado.bank_balance=77;
  Object.assign(d.fix86_columns,{saldo_final:77,liq_d0_1_recurso:value,saldo_apos_d0_1:77+value,rsus_vested:10,saldo_apos_rsu:87+value,fgts:500,saldo_apos_fgts:587+value,
   d0_composition:{has_anchor:true,complete:true,components:[{code:'SYNTHETIC-A',net_brl:later?250:320},{code:'SYNTHETIC-B',net_brl:later?500:680}],source_observed_at:'2026-11-01T15:00:00Z',source_date_field_used:false,snapshot_date:later?'2026-10-30':'2026-10-27',snapshot_brl:later?750:1000,available_brl:value,recorded_movements:later?[]:[{event_date:'2026-10-04',asset_delta_brl:-100}],bank_redemptions:later?[]:[{event_date:'2026-10-04',bank_amount_brl:100,represented_by_recorded_movement:true},{event_date:'2026-10-27',bank_amount_brl:200,represented_by_recorded_movement:false,representation_conflict:false}]}});
 }
 return j;
};
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
async function run(browser,engine,width){
 const h=await setup(browser,width,width===1366?900:852,'2026-11-01T15:00:00Z');let f;
 try{
  f=await open(h,'v402',true);await f.waitForFunction(()=>window.__LTS_V402_D01?.installed);
  await f.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
  await f.evaluate(()=>loadFlowRange('2026-10-27','2026-11-02'));await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.from==='2026-10-27'&&document.getElementById('v402-d01-origin'));
  const box=f.locator('#v402-d01-origin'),before=hash(await f.evaluate(()=>FLOWQ));
  assert.equal(await box.locator('details[open]').count(),0);assert.equal(await box.getAttribute('open'),null);
  const height=await box.evaluate(e=>e.getBoundingClientRect().height);assert(height<70,'compact collapsed source');
  assert.equal((await box.innerText()).trim(),'D0/D1 · composição');await box.locator('summary').click();
  const text=await box.innerText();assert.match(text,/1\.000,00/);assert.match(text,/700,00/);assert.match(text,/777,00/);assert.match(text,/SYNTHETIC-A/);assert.match(text,/320,00/);assert.match(text,/Consultado em/);
  assert.equal(await box.locator('.v402-d01-pair').count(),8,'components and represented receipt appear once');
  assert(!/source_ref|raw_hash|metadata|jsonb|backend|staging_id/i.test(text),'human source language');
  await f.getByLabel('Data da composição D0/D1',{exact:true}).selectOption('2026-10-30');assert.match(await box.innerText(),/750,00/);assert(!(await box.innerText()).includes('1.000,00'),'later confirmation replaces prior withdrawals');
  await f.getByLabel('Data da composição D0/D1',{exact:true}).selectOption('2026-10-27');assert.match(await box.innerText(),/700,00/);
  const geometry=await box.evaluate(e=>({width:innerWidth,scroll:document.documentElement.scrollWidth,values:[...e.querySelectorAll('b')].map(x=>({left:x.getBoundingClientRect().left,right:x.getBoundingClientRect().right}))}));
  assert(geometry.scroll<=width+2);assert(geometry.values.every(x=>x.left>=0&&x.right<=width+2));
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-flow-composition.png'});
  await f.evaluate(()=>render());assert.equal(await f.locator('#v402-d01-origin').count(),1);assert.equal(hash(await f.evaluate(()=>FLOWQ)),before,'presentation never changes financial response');
  await f.evaluate(()=>{const d=[...(FLOWQ.historical?.days||[]),...(FLOWQ.current_future?.days||[])].find(x=>x.date==='2026-11-01');d.fix86_columns.d0_composition.complete=false;render();});await f.locator('#v402-d01-warning').waitFor({state:'visible'});assert.equal((await f.locator('#v402-d01-warning').innerText()).trim(),'Saldo do Cofrinho a conferir no banco.');
  await f.evaluate(()=>{const d=[...(FLOWQ.historical?.days||[]),...(FLOWQ.current_future?.days||[])].find(x=>x.date==='2026-11-01');d.fix86_columns.d0_composition.complete=true;d.fix86_columns.d0_composition.daily_provider_position_available=false;render();});assert.equal((await f.locator('#v402-d01-warning').innerText()).trim(),'Atualização do saldo do Cofrinho pendente.');
  await f.locator('#nav [data-v="Dashboard"]:visible,#dx1MobileNav [data-mobile-route="Dashboard"]:visible').click();await f.waitForFunction(()=>V==='Dashboard');
  assert.equal(await f.locator('#v402-d01-origin').count(),0);await h.page.screenshot({path:out+'/'+engine+'-'+width+'-dashboard.png'});
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,closed_height:height,composition_once:true,later_position_does_not_rewrite_prior:true,response_unchanged:true,private_session:false,physical_iphone:false};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,body:await f.locator('body').innerText(),reads:h.reads.slice(-6)},null,2));throw e;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){const b=await type.launch();try{for(const width of[320,393,1366])results.push(await run(b,engine,width));}finally{await b.close();}}fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,scenarios:results.length}));})().catch(e=>{console.error(e);process.exitCode=1});
