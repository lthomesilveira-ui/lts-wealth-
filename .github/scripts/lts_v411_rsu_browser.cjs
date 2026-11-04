'use strict';
process.env.LTS_FLOW_RELEASE||='v411';
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response,rsu=require('./lts_v411_rsu_fixtures.cjs');
const {setup,open}=require('./lts_v382_browser.cjs'),{chromium,webkit}=require('playwright');
const target=process.env.LTS_FLOW_RELEASE,out='qa/v411-rsu';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex'),money=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n);
let current=rsu.policy();
fixture.response=function(name,args){
 if(name==='lts_browser_rsu_policy_v411')return structuredClone(current);
 if(/^lts_browser_wealth_detail_/.test(name))return rsu.wealth(fixture.contracts(baseResponse(name,args)),current);
 if(/^lts_browser_flow_v/.test(name))return rsu.netFlow(baseResponse(name,args));
 if(name==='lts_browser_award_provenance_v183')return{financial_effect:'none',groups:[]};
 if(name==='lts_browser_market_quotes_v290')return{revision:'synthetic-quotes',mode:'manual',stock:{value:20,source_name:'Synthetic equity reference',quoted_at:'2026-11-04T14:00:00Z',received_at:'2026-11-04T14:01:00Z'},usd_brl:{value:5,source_name:'Synthetic FX reference',quoted_at:'2026-11-04T14:00:00Z',received_at:'2026-11-04T14:01:00Z'},consulted_at:'2026-11-04T15:00:00Z',refresh:[]};
 if(name==='lts_browser_awards_v178')return{as_of:'2026-11-04',events:current.future_schedule.map((r,i)=>({id:'SYNTHETIC-'+i,type:r.asset_type,vesting_date:r.eligibility_date,available_date:r.available_date,value:r.net_value_brl,regular_rsu:r.asset_type==='RSU',basis:'synthetic'}))};
 const j=baseResponse(name,args);if(/^lts_browser_cash_today_/.test(name)){j.as_of='2026-11-04';j.day.date='2026-11-04';}return j;
};
async function go(f,view){await f.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await f.waitForFunction(v=>V===v,view);}
async function ready(f){await f.waitForFunction(()=>window.__LTS_V411_RSU?.status==='ready');}
async function geometry(f){return f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,values:[...document.querySelectorAll('.v411-values td,.v411-pair b,.v411-award-values>b')].filter(e=>e.getClientRects().length).map(e=>{const r=e.getBoundingClientRect(),range=document.createRange();range.selectNodeContents(e);return{left:r.left,right:r.right,text:e.textContent,lines:new Set([...range.getClientRects()].map(v=>Math.round(v.top))).size};})}));}
async function run(browser,engine,width){
 current=rsu.policy();const h=await setup(browser,width,width===1366?950:980,'2026-11-04T15:00:00Z');let f,mode='ok',policyReads=0;const allowedWrites=[];
 await h.ctx.route('**/rest/v1/rpc/lts_browser_rsu_policy_v411',async route=>{policyReads++;if(mode==='unauthorized')return route.fulfill({status:401,contentType:'application/json',body:JSON.stringify({message:'Synthetic expired token',code:'PGRST301'})});if(mode==='malformed'){const p=structuredClone(current);p.summary.schedule_net_brl=null;return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});}return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(current)});});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_save_award_assumption_v1',async route=>{const args=JSON.parse(route.request().postData()||'{}');allowedWrites.push({name:'lts_browser_save_award_assumption_v1',args});current=rsu.quoteRegular(current);return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({ok:true})});});
 try{
  f=await open(h,target,true);await ready(f);
  const dashboard=f.locator('.v168-dashboard'),regular=dashboard.locator('.v168-kpi').filter({has:f.locator('span').filter({hasText:/^RSUs futuras$/})});
  assert.equal(await regular.locator('strong').innerText(),money(700));assert.match(await regular.locator('small').innerText(),/bruto.*1\.000,00/);
  const totalKpi=dashboard.locator('.v168-kpi').filter({has:f.locator('span').filter({hasText:/^RSUs e Cash RSUs futuras$/})});assert.equal(await totalKpi.locator('strong').innerText(),money(1050));assert.match(await totalKpi.innerText(),/Retention Award separado/);
  const dlayout=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,detailsOpen:document.querySelectorAll('.v337-source[open]').length}));assert(dlayout.scroll<=width+2);assert.equal(dlayout.detailsOpen,0);
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-dashboard.png'});
  await go(f,'Patrimônio');await f.waitForFunction(()=>window.__LTS_V168_STATE?.wealth?.data&&!window.__LTS_V168_STATE.wealth.loading);
  await f.getByRole('tab',{name:'RSUs e awards',exact:true}).click();await f.waitForFunction(()=>document.querySelectorAll('.v168-award').length===2&&document.querySelectorAll('.v411-component-origin').length===2);
  const root=f.locator('.v168-wealth'),projection=root.locator('[data-v411-projection]'),reference=root.locator('[data-v411-reference]'),condition=root.locator('[data-v411-acceleration]');
  assert.match(await projection.innerText(),/1\.000,00.*700,00.*500,00.*350,00.*1\.500,00.*1\.050,00/s);
  assert.equal(await root.locator('[data-v168-award-date],[data-v168-award-save]').count(),0);assert.equal(await root.locator('[data-v168-award-edit]').count(),2);
  assert.equal(await root.locator('.v411-origin[open]').count(),0);assert.match(await reference.innerText(),/data.*não foi informada/i);assert.match(await reference.innerText(),/Falta identificar R\$\s*2,00/);assert.match(await reference.innerText(),/1\.053,00/);
  assert.match(await condition.innerText(),/Data ainda não confirmada/);assert.match(await condition.innerText(),/700,00.*490,00/s);assert.match(await condition.innerText(),/falta vincular 2/);
  assert.match(await condition.innerText(),/Vestings ocorridos antes do fechamento devem ser excluídos/);
  const retention=root.locator('article').filter({has:f.getByRole('heading',{name:'Acordo separado de RSU',exact:true})});assert.equal(await retention.locator('.v168-cardhead>strong').innerText(),money(5000));
  await condition.locator('summary').click();assert.match(await condition.innerText(),/31\/03\/2025.*incluída.*31\/03\/2026.*fora desta antecipação/s);await condition.locator('summary').click();
  const sourceBefore=hash(await f.evaluate(()=>__LTS_V168_STATE.wealth.data)),layout=await geometry(f);assert(layout.scroll<=width+2,JSON.stringify(layout));assert(layout.values.every(v=>v.left>=0&&v.right<=width+2&&v.lines===1),JSON.stringify(layout));
  await f.evaluate(()=>scrollTo(0,0));await h.page.screenshot({path:out+'/'+engine+'-'+width+'-rsu.png',fullPage:true});
  await f.evaluate(()=>{render();render();});assert.equal(await projection.count(),1);assert.equal(await condition.count(),1);assert.equal(hash(await f.evaluate(()=>__LTS_V168_STATE.wealth.data)),sourceBefore);
  // The real screen includes amounts in the millions; use unrelated fictional values.
  const ordinary=structuredClone(current);function scaleAmounts(value){if(!value||typeof value!=='object')return;for(const[k,v]of Object.entries(value)){if(k.endsWith('_brl')&&typeof v==='number')value[k]=v*10000;else if(v&&typeof v==='object')scaleAmounts(v);}}scaleAmounts(current);
  await f.evaluate(()=>__LTS_V411_RSU.refresh());await ready(f);await f.waitForFunction(()=>document.querySelectorAll('.v411-component-origin').length===2);const largeLayout=await geometry(f);assert(largeLayout.scroll<=width+2,JSON.stringify(largeLayout));assert(largeLayout.values.every(v=>v.left>=0&&v.right<=width+2&&v.lines===1),JSON.stringify(largeLayout));await f.evaluate(()=>scrollTo(0,0));await h.page.screenshot({path:out+'/'+engine+'-'+width+'-large-values.png'});
  current=ordinary;await f.evaluate(()=>__LTS_V411_RSU.refresh());await ready(f);await f.waitForFunction(()=>document.querySelectorAll('.v411-component-origin').length===2);
  await root.locator('[data-v168-award-edit="0"]').click();const modal=f.locator('#v168Modal');assert.match(await modal.innerText(),/RSUs e Cash RSUs.*reserva de 30%/s);assert(!(await modal.innerText()).includes('100%'));await modal.locator('[data-v168-close]').click();
  await go(f,'Fluxo Diário');await f.evaluate(()=>loadFlowRange('2030-02-17','2030-04-04'));await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.to==='2030-04-04');
  const flowBefore=await f.evaluate(()=>structuredClone(FLOWQ)),flowBody=flowBefore.flow||flowBefore,last=flowBody.current_future.days.find(d=>d.date==='2030-04-04');assert.equal(last.fix86_columns.rsus_vested,1350);assert.equal(last.fix86_columns.saldo_apos_rsu,2550);
  const flowUI=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,periodOpen:!!document.querySelector('.v382-period[open]'),height:document.querySelector('.flow-sticky-controls').getBoundingClientRect().height}));assert(flowUI.scroll<=width+2);assert.equal(flowUI.periodOpen,false);assert(flowUI.height<430);
  const basis=f.locator('[data-v411-flow-policy]');assert.equal(await basis.getAttribute('open'),null);await basis.locator('summary').click();assert.match(await basis.innerText(),/base R\$\s*10\.000,00 menos a parcela Coopharma/);await basis.locator('summary').click();assert.equal(hash(await f.evaluate(()=>FLOWQ)),hash(flowBefore));
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-flow.png'});
  // A token rejection after a successful read clears the separate policy model.
  mode='unauthorized';await f.evaluate(()=>__LTS_V411_RSU.load(true));await f.waitForFunction(()=>__LTS_V411_RSU.status==='error');assert.equal(await f.evaluate(()=>__LTS_V411_RSU.model),null);assert.match(await f.locator('[data-v411-flow-policy]').innerText(),/Não foi possível conferir/);
  await go(f,'Patrimônio');await f.getByRole('tab',{name:'RSUs e awards',exact:true}).click();assert.match(await projection.innerText(),/Não foi possível conferir/);assert.equal(await projection.locator('td').first().innerText(),'—');assert.equal(await condition.count(),0);
  mode='malformed';await f.evaluate(()=>__LTS_V411_RSU.load(true));assert.equal(await f.evaluate(()=>__LTS_V411_RSU.status),'error');assert.equal(await projection.locator('td').first().innerText(),'—');
  mode='ok';await projection.locator('[data-v411-refresh]').click();await ready(f);await f.waitForFunction(()=>document.querySelectorAll('.v411-component-origin').length===2);assert.match(await projection.innerText(),/1\.050,00/);
  // The existing quote action still sends only the audited price/fx inputs.
  const readsBefore=policyReads,referenceBefore=hash(current.morgan_reference);await root.locator('[data-v168-award-edit="0"]').click();await modal.locator('#v168AwPrice').fill('40');await modal.locator('#v168AwFx').fill('5');await modal.locator('#v168AwSave').click();
  await f.waitForFunction(()=>__LTS_V411_RSU.status==='ready'&&__LTS_V411_RSU.model?.regular.net===140000&&document.querySelectorAll('.v411-component-origin').length===2);
  assert(policyReads>readsBefore);assert.equal(allowedWrites.length,1);assert.deepEqual(allowedWrites[0].args,{p_group_key:'rsu:2030-03-31',p_unit_price_usd:40,p_fx_rate:5});assert.equal(hash(current.morgan_reference),referenceBefore);assert.match(await projection.innerText(),/2\.000,00.*1\.400,00.*2\.500,00.*1\.750,00/s);
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);assert(!h.reads.some(x=>x.name==='lts_browser_save_vesting_anticipation_v1'));
  await f.locator('#logout').focus();await h.page.keyboard.press('Enter');assert.equal(await f.evaluate(()=>__LTS_V411_RSU.model),null);
  return{pass:true,engine,width,server_net_not_reduced_again:true,reference_date_not_inferred:true,unallocated_net_unknown:true,conditional_grants_2026_excluded:true,closing_balance_qualification_visible:true,retention_preserved:true,calendar_preserved:true,old_group_date_action_absent:true,quote_writer_preserved:true,quote_refresh:true,unauthorized_and_invalid_response_clear_values:true,source_payload_unchanged:true,flow_payload_sha256:hash(flowBefore),flow_controls_height:flowUI.height,geometry:layout,large_value_geometry:largeLayout,explicit_synthetic_quote_writes:allowedWrites.length,other_writes:0,synthetic_http:true,private_session:false,physical_iphone:false};
 }catch(error){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png',fullPage:true}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:error.stack,body:f?await f.locator('body').innerText():null,reads:h.reads.slice(-15),errors:h.errors,allowedWrites},null,2));throw error;}finally{await h.ctx.close();}
}
async function localServer(){
 const base=new URL(process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788');
 const server=http.createServer((req,res)=>{let p=path.resolve('.','.'+new URL(req.url,'http://local').pathname);if(fs.existsSync(p)&&fs.statSync(p).isDirectory())p+='/index.html';if(!p.startsWith(process.cwd()+path.sep)||!fs.existsSync(p)){res.writeHead(404);res.end();return;}const mime={'.js':'application/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.webmanifest':'application/manifest+json'};res.setHeader('Content-Type',mime[path.extname(p)]||'text/html');fs.createReadStream(p).pipe(res);});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(Number(base.port),base.hostname,resolve);});return server;
}
module.exports={run};
if(require.main===module)(async()=>{const results=[],server=process.env.LTS_LOCAL_SERVER==='1'?await localServer():null;try{const engines=process.env.LTS_TEST_ENGINES?.split(',')||['chromium','webkit'];for(const engine of engines){const type={chromium,webkit}[engine],opts={headless:true};if(engine==='chromium'&&process.env.LTS_CHROMIUM_PATH){opts.executablePath=process.env.LTS_CHROMIUM_PATH;opts.args=['--no-sandbox'];}const browser=await type.launch(opts);try{for(const width of(process.env.LTS_TEST_WIDTHS||'320,393,1366').split(',').map(Number)){const result=await run(browser,engine,width);results.push(result);fs.writeFileSync(out+'/result.json',JSON.stringify({pass:false,completed_runs:results.length,results},null,2));console.log(JSON.stringify({pass:true,engine,width}));}}finally{await browser.close();}}fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,runs:results.length,synthetic_only:true}));}finally{server?.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
