'use strict';
process.env.LTS_FLOW_RELEASE||='v412';
const fs=require('node:fs'),path=require('node:path'),http=require('node:http'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response,projection=require('./lts_v412_projection_fixtures.cjs');
const {setup,open}=require('./lts_v382_browser.cjs'),{chromium,webkit}=require('playwright');
const target=process.env.LTS_FLOW_RELEASE,out='qa/v412-projection';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
let current=projection.policy();
fixture.response=function(name,args){
 if(name==='lts_browser_projection_policy_v412')return structuredClone(current);
 if(name==='lts_browser_rsu_policy_v411')return {version:'rsu-policy-v411',schema_version:1,policy:{enabled:false}};
 return baseResponse(name,args);
};
async function go(f,view){await f.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await f.waitForFunction(v=>V===v,view);}
async function ready(f){await f.waitForFunction(()=>__LTS_V412_PROJECTION?.status==='ready');}
async function geometry(f){return f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,
 panel:document.querySelector('[data-v412-policy]')?.getBoundingClientRect().toJSON(),
 controls:document.querySelector('.flow-sticky-controls')?.getBoundingClientRect().toJSON(),
 open:document.querySelectorAll('.v412-origin[open]').length,
 buttons:[...document.querySelectorAll('[data-v412-refresh]')].map(e=>e.getBoundingClientRect().toJSON())}));}
async function run(browser,engine,width){
 current=projection.policy();const h=await setup(browser,width,width===1366?950:980,'2026-11-04T15:00:00Z');
 const initialAuthError=width!==1366;
 let f,mode=initialAuthError?'unauthorized':'ok',reads=0,refreshes=0,releaseDelayed,delayedStarted=false;const allowedWrites=[];
 await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_policy_v412',async route=>{
  reads++;const payload=structuredClone(current);
  if(mode==='unauthorized')return route.fulfill({status:401,contentType:'application/json',body:JSON.stringify({message:'Synthetic expired session',code:'PGRST301'})});
  if(mode==='malformed')payload.series[0].reference_amount_brl=1.005;
  if(mode==='delayed'){payload.series[0].reference_amount_brl=9999;delayedStarted=true;await new Promise(resolve=>{releaseDelayed=resolve;});}
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(payload)});
 });
 await h.ctx.route('**/rest/v1/rpc/lts_browser_projection_refresh_v412',async route=>{
  refreshes++;allowedWrites.push({name:'lts_browser_projection_refresh_v412',args:JSON.parse(route.request().postData()||'{}')});
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({...current,refreshed:true})});
 });
 try{
  f=await open(h,target,true);await f.waitForFunction(()=>__LTS_V412_PROJECTION?.installed);
  const concise=/\/releases\/v(?:417|421|423)\//.test(new URL(f.url()).pathname);
  if(!initialAuthError){await ready(f);await h.page.waitForLoadState('networkidle');
   await f.waitForFunction(()=>!__LTS_V168_STATE.dashboard.loading);
   assert.equal(await f.evaluate(()=>__LTS_V168_STATE.dashboard.data.flow.flow.current_future.days.at(-1).date),
    '2031-12-31','direct Dashboard load reads the entire five-year horizon');}
  const dashboard=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,
   data:__LTS_V168_STATE.dashboard.data,sourceOpen:document.querySelectorAll('.v337-source[open]').length}));
  assert(dashboard.scroll<=width+2);assert.equal(dashboard.sourceOpen,0);
  if(initialAuthError){await f.waitForFunction(()=>__LTS_V412_PROJECTION.status==='error');
   assert.match(await f.locator('[data-v412-policy="dashboard-warning"]').innerText(),/Não foi possível conferir/);}
  else assert.equal(await f.locator('[data-v412-policy]').count(),0,'healthy Dashboard has no extra policy banner');
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-dashboard.png'});
  await go(f,'Fluxo Diário');const panel=()=>f.locator('[data-v412-policy="flow"]');
  if(initialAuthError){await f.waitForFunction(()=>__LTS_V412_PROJECTION.status==='error');
   assert.match(await panel().innerText(),/Não foi possível conferir/);assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model),null);}
  mode='ok';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await ready(f);
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWTO==='2031-12-31');
  const initialRange=await f.evaluate(()=>({from:FLOWFROM,to:FLOWTO}));
  assert.equal(initialRange.to,'2031-12-31','default Flow includes all five complete future years');
  await f.locator('.v382-period>summary').click();
  await f.getByLabel('Data inicial do Fluxo',{exact:true}).fill(initialRange.from);
  await f.getByLabel('Data final do Fluxo',{exact:true}).fill('2030-12-31');await f.locator('#flowApply').click();
  await f.waitForFunction(()=>!FLOWLOADING&&FLOWTO==='2030-12-31');await f.evaluate(()=>render());
  assert.equal(await f.evaluate(()=>FLOWTO),'2030-12-31','an explicit period remains exact, even when it matches the former default');
  await f.locator('#flowDefaultRange').click();await f.waitForFunction(()=>!FLOWLOADING&&FLOWTO==='2031-12-31');
  assert.equal(await f.getByLabel('Ano do período do Fluxo',{exact:true}).locator('option[value="2031"]').count(),1);
  await f.locator('.v382-period>summary').click();
  await f.evaluate(()=>loadFlowRange('2031-01-01','2031-01-31'));await f.waitForFunction(()=>!FLOWLOADING&&FLOWQ?.to==='2031-01-31');
  assert.match(await panel().innerText(),/Projeções até 31\/12\/2031/);assert.equal(await panel().locator('details').getAttribute('open'),null);
  const before=await f.evaluate(()=>structuredClone(FLOWQ)),closed=await geometry(f);
  assert(closed.scroll<=width+2,JSON.stringify(closed));assert(closed.panel.height<=135,JSON.stringify(closed));assert(closed.controls.height<430);
  assert(closed.buttons.every(b=>b.x>=0&&b.right<=width+2&&b.height>=40));
  await panel().locator('summary').click();const text=await panel().innerText();
  if(concise){
   assert.match(text,/Média de 12 meses completos/);
   assert.match(text,/Reajuste estimado de 5% ao ano/);
   assert.match(text,/Salário previsto após o desconto do empréstimo em folha/);
   assert.match(text,/Faturas fechadas prevalecem/);
   assert.match(text,/Parcelas antigas de gastos não recorrentes continuam até terminar/);
   assert.match(text,/reservas de novas compras não são somadas duas vezes/);
   for(const term of ['RPC','SQLSTATE','source_ref','payload','backend'])assert(!text.includes(term),'no raw diagnostic: '+term);
  }else{
   assert.match(text,/Média nominal de 12 meses completos/);assert.match(text,/5% ao ano, aplicada uma vez/);
   assert.match(text,/parcela documentada.*uma única vez/);assert.match(text,/maior entre a média e os valores já conhecidos/);
   assert.match(text,/fatura fechada ou pagamento confirmado/);
  }
  assert.match(text,/12 de 12 meses cobertos; 9 meses com gasto/);assert.match(text,/Valores atípicos foram mantidos/);
  assert.match(text,/Dia de planejamento estimado/);assert.match(text,/ano corrente.*parcial/);
  assert.equal(hash(await f.evaluate(()=>FLOWQ)),hash(before));
  await panel().locator('summary').click();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-flow.png'});
  if(concise){
   const r=current.series[0];r.expected_months=3;r.coverage_months=3;r.observed_months=3;r.months_with_spend=3;
   r.reference_window={from:'2026-08-01',to:'2026-10-31'};r.history_total_brl=360;
   await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await ready(f);
   assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model.series[0].expected),3);
   assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model.series[1].expected),12);
   await panel().locator('summary').click();assert.match(await panel().innerText(),/Média de 3 meses completos/);
   assert.match(await panel().innerText(),/3 de 3 meses cobertos/);await panel().locator('summary').click();
   assert.equal(hash(await f.evaluate(()=>FLOWQ)),hash(before),'rolling reference does not recalculate cash in browser');
   current=projection.policy();await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await ready(f);
  }
  const callsBefore=await f.evaluate(()=>(__flowTestEvents||[]).length);
  await panel().locator('[data-v412-refresh]').click();await ready(f);await f.waitForFunction(()=>!FLOWLOADING);
  assert.equal(refreshes,1);assert.deepEqual(allowedWrites[0].args,{});
  assert((await f.evaluate(()=>(__flowTestEvents||[]).length))>callsBefore,'refresh reloads the same visible Flow period');
  assert.equal(hash(await f.evaluate(()=>FLOWQ)),hash(before),'refresh cannot change server amounts in the browser');
  await f.evaluate(()=>{render();render();});assert.equal(await panel().count(),1);
  await go(f,'Atualizações');await f.waitForFunction(()=>document.querySelector('[data-v412-policy="updates"]'));
  assert.equal(await f.locator('.v412-origin[open]').count(),0);await h.page.screenshot({path:out+'/'+engine+'-'+width+'-updates.png'});
  current=projection.stale();for(const r of current.series)if(r.uses_history){r.coverage_months=0;r.observed_months=12;r.months_with_spend=9;}
  await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await ready(f);
  const updates=f.locator('[data-v412-policy="updates"]');assert.match(await updates.innerText(),/Projeções até 31\/12\/2032/);
  if(concise){assert.match(await updates.innerText(),/Há estimativas a conferir nas premissas/);assert.equal(await updates.locator('details[open]').count(),0);}
  else assert.match(await updates.innerText(),/mantida a última média completa/);
  await updates.locator('summary').click();
  if(concise)assert.match(await updates.innerText(),/usando a última média completa/);
  assert.match(await updates.innerText(),/Revisão atual com 0 de 12 meses cobertos/);assert(!(await updates.innerText()).includes('Revisão atual com 12 de 12 meses cobertos'));
  await updates.locator('summary').click();assert((await geometry(f)).scroll<=width+2);
  current=projection.policy();mode='malformed';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));
  assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.status),'error');assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model),null);
  mode='ok';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await ready(f);
  mode='delayed';await f.evaluate(()=>{__LTS_V412_PROJECTION.load(true);});
  for(let i=0;i<50&&!delayedStarted;i++)await h.page.waitForTimeout(20);assert(delayedStarted);
  mode='ok';await f.evaluate(()=>{BOOT.generation++;render();});await ready(f);releaseDelayed();await h.page.waitForTimeout(100);
  assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model.series[0].amount),12000,'old identity response cannot replace new identity data');
  current={version:'projection-policy-v412',enabled:false};await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));
  assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.status),'disabled');assert.equal(await f.locator('[data-v412-policy]').count(),0);
  await go(f,'Dashboard');await h.page.waitForLoadState('networkidle');
  const dashboardAfter=await f.evaluate(()=>__LTS_V168_STATE.dashboard.data);
  for(const key of ['cockpit','wealth','expense','expenseContext'])assert.deepEqual(dashboardAfter[key],dashboard.data[key]);
  const firstDays=dashboard.data.flow?.flow?.current_future?.days||[],lastDays=dashboardAfter.flow?.flow?.current_future?.days||[];
  const originalDays=new Map(firstDays.map(day=>[day.date,day]));
  for(const day of lastDays)if(originalDays.has(day.date))assert.deepEqual(day,originalDays.get(day.date));
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  await f.locator('#logout').focus();await h.page.keyboard.press('Enter');assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model),null);
  return {pass:true,engine,width,model_policy_reads:reads,explicit_refreshes:refreshes,other_writes:0,
   initial_range:initialRange,future2031_read:true,year2032_reference_fallback:true,missing_coverage_not_zero:true,closed_origin_height:closed.panel.height,
   flow_controls_height:closed.controls.height,financial_response_sha256:hash(before),server_amounts_unchanged:true,
   refresh_reloads_visible_period:true,initial_401_clear_values:initialAuthError,direct_dashboard_full_horizon:!initialAuthError,
   malformed_clear_values:true,obsolete_identity_response_ignored:true,rolling_card_window_rendered:concise,
   no_namespace_legacy_preserved:true,dashboard_unchanged:true,synthetic_http:true,private_session:false,physical_iphone:false};
 }catch(error){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png',fullPage:true}).catch(()=>{});
  fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:error.stack,body:f?await f.locator('body').innerText():null,
   state:f?await f.evaluate(()=>({status:__LTS_V412_PROJECTION?.status,from:FLOWFROM,to:FLOWTO})):null,reads:h.reads.slice(-15),errors:h.errors},null,2));throw error;
 }finally{releaseDelayed?.();await h.ctx.close();}
}
async function localServer(){
 const base=new URL(process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788');
 const server=http.createServer((req,res)=>{let p=path.resolve('.','.'+new URL(req.url,'http://local').pathname);
  if(fs.existsSync(p)&&fs.statSync(p).isDirectory())p+='/index.html';
  if(!p.startsWith(process.cwd()+path.sep)||!fs.existsSync(p)){res.writeHead(404);res.end();return;}
  res.setHeader('Content-Type',({'.js':'application/javascript','.css':'text/css','.json':'application/json','.svg':'image/svg+xml','.png':'image/png','.webmanifest':'application/manifest+json'})[path.extname(p)]||'text/html');fs.createReadStream(p).pipe(res);});
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(Number(base.port),base.hostname,resolve);});return server;
}
module.exports={run};
if(require.main===module)(async()=>{const results=[],server=process.env.LTS_LOCAL_SERVER==='1'?await localServer():null;
 try{for(const engine of(process.env.LTS_TEST_ENGINES||'chromium,webkit').split(',')){
  const opts={headless:true};if(engine==='chromium'&&process.env.LTS_CHROMIUM_PATH){opts.executablePath=process.env.LTS_CHROMIUM_PATH;opts.args=['--no-sandbox'];}
  const browser=await({chromium,webkit}[engine]).launch(opts);try{for(const width of(process.env.LTS_TEST_WIDTHS||'320,393,1366').split(',').map(Number)){
   results.push(await run(browser,engine,width));fs.writeFileSync(out+'/result.json',JSON.stringify({pass:false,completed_runs:results.length,results},null,2));
   console.log(JSON.stringify({pass:true,engine,width}));}}finally{await browser.close();}}
  fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));
 }finally{server?.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
