'use strict';
process.env.LTS_FLOW_RELEASE='v425';
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v379_fixtures.cjs'),baseResponse=fixture.response,projection=require('./lts_v412_projection_fixtures.cjs');
const {setup,open}=require('./lts_v382_browser.cjs'),out='qa/v425';fs.mkdirSync(out,{recursive:true});
const hash=x=>crypto.createHash('sha256').update(JSON.stringify(x)).digest('hex');
function policy(){const p=projection.policy();p.series[0].reference_stale=true;p.series[0].coverage_months=11;p.series[0].observed_months=11;p.series[0].months_with_spend=11;p.series[0].warnings=['partial_history','previous_complete_window'];return p;}
const rsu={version:'rsu-policy-v411',schema_version:1,policy:{enabled:true,reserve_rate:.3,net_factor:.7,scope:['RSU','Cash RSU'],cash_already_available_untouched:true,retention_award_excluded:true},summary:{schedule_gross_brl:0,schedule_net_brl:0,schedule_reserve_brl:0,regular_gross_brl:0,regular_net_brl:0,cash_gross_brl:0,cash_net_brl:0},future_schedule:[],morgan_reference:null,acceleration:null,payroll_policy:{monthly_base_brl:10000,coopharma_treatment:'subtract_documented_schedule_once',actual_net_preserved:true,forecasts_only:true}};
fixture.response=function(name,args){
 if(name==='lts_browser_projection_policy_v412')return policy();
 if(name==='lts_browser_rsu_policy_v411')return structuredClone(rsu);
 const j=baseResponse(name,args);
 if(/^lts_browser_flow_/.test(name)&&j?.flow)for(const part of ['historical','current_future'])for(const d of j.flow[part]?.days||[]){
  Object.assign(d.fix86_columns,{d0_composition:{has_anchor:true,complete:true,snapshot_date:'2026-11-01',snapshot_brl:700,available_brl:700,recorded_movements:[],bank_redemptions:[]}});
 }
 return j;
};
async function go(f,view){await f.locator('#nav [data-v="'+view+'"]:visible,#dx1MobileNav [data-mobile-route="'+view+'"]:visible').click();await f.waitForFunction(v=>V===v,view);}
async function start(h,version){const f=await open(h,version,false);await f.waitForFunction(()=>__LTS_V412_PROJECTION?.status==='ready'&&__LTS_V411_RSU?.status==='ready');await go(f,'Fluxo Diário');await f.waitForFunction(()=>!FLOWLOADING&&!!FLOWQ&&!!document.getElementById('v399-d01-origin'));await h.page.waitForLoadState('networkidle');return f;}
async function run(browser,engine,width){
 const before=await setup(browser,width,width<1000?852:1000,'2026-11-04T15:00:00Z'),after=await setup(browser,width,width<1000?852:1000,'2026-11-04T15:00:00Z');let f,mode='normal',refreshes=0;
 await after.ctx.route('**/rest/v1/rpc/lts_browser_projection_policy_v412',route=>{
  if(mode==='failed')return route.fulfill({status:503,contentType:'application/json',body:JSON.stringify({message:'Synthetic unavailability'})});
  const p=policy();if(mode==='incomplete'){p.series[0].reference_amount_brl=null;p.series[0].warnings=['history_unavailable'];}
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});
 });
 await after.ctx.route('**/rest/v1/rpc/lts_browser_projection_refresh_v412',route=>{refreshes++;return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(policy())});});
 try{
  const baseline=await start(before,'v423');f=await start(after,'v425');await f.waitForFunction(()=>__LTS_V425_FLOW_OPTIONS?.installed);
  const data=hash(await f.evaluate(()=>FLOWQ));assert.equal(data,hash(await baseline.evaluate(()=>FLOWQ)),'presentation preserves full financial response');
  const selectors=['[data-v412-policy="flow"]','[data-v411-flow-policy]','#v399-d01-origin','.v425-options .lts-update-details'];
  const tools=f.locator('.v425-options'),toggle=tools.locator(':scope>summary');
  assert.equal(await tools.getAttribute('open'),null);
  for(const s of selectors){assert.equal(await f.locator(s).count(),1,s);assert.equal(await f.locator(s).isVisible(),false,'not in default report: '+s);assert.equal(await f.locator(s).evaluate(n=>!!n.closest('.v425-options')),true);}
  const text=await f.locator('body').innerText();
  for(const forbidden of ['Há estimativas a conferir nas premissas.','Premissas das projeções','Premissas de RSU e salário','D0/D1 · composição'])assert(!text.includes(forbidden),'hidden by hierarchy, not visible: '+forbidden);
  assert.equal(await f.locator('#v425-flow-attention').count(),0,'a last complete average is not a failed forecast');
  assert.deepEqual(await f.locator('.lts-freshness-alert').allInnerTexts(),await baseline.locator('.lts-freshness-alert').allInnerTexts(),'bank freshness warning preserved');
  const geometry=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth,period:document.querySelector('.v382-period').getBoundingClientRect().toJSON(),day:document.querySelector('.day')?.getBoundingClientRect().toJSON()}));
  assert(geometry.scroll<=width+2);const baselineY=await baseline.locator('.day').first().evaluate(n=>n.getBoundingClientRect().top),afterY=await f.locator('.day').first().evaluate(n=>n.getBoundingClientRect().top);
  assert(baselineY-afterY>=160,'removed panel stack moves first day up: '+JSON.stringify({baselineY,afterY}));
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-default.png'});
  await toggle.click();for(const s of selectors)assert(await f.locator(s).isVisible());
  assert.equal(await f.locator('[data-v412-refresh]').evaluate(n=>typeof n.onclick),'function');
  await f.locator('.v412-origin>summary').click();assert.match(await f.locator('.v412-origin').innerText(),/última média completa|última base completa/);
  assert.match(await f.locator('.v412-origin').innerText(),/Cartão de teste/);
  const bounds=await tools.locator('.v382-tool-body').evaluate(n=>n.getBoundingClientRect().toJSON());assert(bounds.x>=0&&bounds.right<=width+2&&bounds.height<=852*.66+2);
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-options.png'});
  await after.page.keyboard.press('Escape');assert.equal(await tools.getAttribute('open'),null);
  await toggle.focus();await after.page.keyboard.press('Enter');assert(await tools.getAttribute('open')!==null);
  await f.locator('.v412-origin>summary').click();
  await f.locator('[data-v411-flow-policy]>summary').click();assert.match(await f.locator('[data-v411-flow-policy]').innerText(),/reserva de 30%/);
  await f.locator('[data-v411-flow-policy]>summary').click();
  await f.locator('#v399-d01-origin>summary').click();assert.match(await f.locator('#v399-d01-origin').innerText(),/700,00/);
  assert.equal(hash(await f.evaluate(()=>FLOWQ)),data,'consulting assumptions cannot recalculate values');
  await f.locator('[data-v412-refresh]').click();await f.waitForFunction(()=>__LTS_V412_PROJECTION.status==='ready');assert.equal(refreshes,1,'original refresh handler works once');
  await after.page.keyboard.press('Escape');
  await f.locator('[data-a="Bradesco"]').click();await f.waitForFunction(()=>ACC==='Bradesco');assert.equal(await f.locator('.v425-options[open]').count(),0);
  await f.locator('[data-a="Consolidado"]').click();await f.waitForFunction(()=>ACC==='Consolidado');
  await toggle.click();await go(f,'Dashboard');await go(f,'Fluxo Diário');assert.equal(await f.locator('.v425-options[open]').count(),0,'ordinary navigation resets menu closed');
  await f.evaluate(()=>{render();render();render()});for(const s of selectors)assert.equal(await f.locator(s).count(),1,'no duplicate control after renders');
  mode='failed';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await f.waitForFunction(()=>__LTS_V412_PROJECTION.status==='error');
  assert.match(await f.locator('#v425-flow-attention').innerText(),/Projeções não verificadas/);assert(await f.locator('#v425-flow-attention').isVisible());
  await after.page.screenshot({path:out+'/'+engine+'-'+width+'-failed.png'});
  await f.locator('#v425-flow-attention button').click();assert(await f.locator('.v425-options[open]').count()===1);assert(await f.locator('[data-v412-refresh]').isVisible());
  mode='incomplete';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));await after.page.keyboard.press('Escape');assert.match(await f.locator('#v425-flow-attention').innerText(),/previsões incompletas/);
  assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model.series[0].amount),null,'unknown reference does not become zero');
  mode='normal';await f.evaluate(()=>__LTS_V412_PROJECTION.load(true));assert.equal(await f.locator('#v425-flow-attention').count(),0);
  assert.deepEqual(after.errors,[]);assert.deepEqual(after.writes,[]);assert.deepEqual(before.errors,[]);assert.deepEqual(before.writes,[]);
  return {pass:true,engine,width,normal_before_first_day_y:baselineY,normal_after_first_day_y:afterY,vertical_space_saved:baselineY-afterY,financial_response_sha256:data,financial_response_identical:true,sections_in_options:4,bank_warning_preserved:true,failure_visible:true,unknown_preserved:true,original_refresh_handler_once:true,menu_keyboard_and_escape:true,navigation_closes_menu:true,duplicates:0,financial_writes:0,private_session:false,physical_iphone:false};
 }catch(e){if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.txt',e.stack+'\n'+JSON.stringify({errors:after.errors,reads:after.reads.slice(-12)})+'\n'+await f.locator('body').innerText());await after.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});throw e;}
 finally{await before.ctx.close();await after.ctx.close();}
}
(async()=>{const results=[];const types=process.env.LOCAL_CHROMIUM?[['chromium',chromium]]:[['chromium',chromium],['webkit',webkit]];
 for(const[engine,type]of types){const b=await type.launch({headless:true,...(process.env.LOCAL_CHROMIUM?{executablePath:'/usr/bin/chromium'}:{})});try{for(const width of(process.env.SMOKE_ONLY?[393]:[320,393,430,1366])){results.push(await run(b,engine,width));fs.writeFileSync(out+'/result.json',JSON.stringify({pass:false,results},null,2));console.log(JSON.stringify(results.at(-1)));}}finally{await b.close();}}
 fs.writeFileSync(out+'/result.json',JSON.stringify({pass:true,results},null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
