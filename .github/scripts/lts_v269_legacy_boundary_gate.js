'use strict';
const {chromium,webkit}=require('playwright'),fs=require('fs'),assert=require('assert/strict');
const {product,wealth}=require('./lts_v165_executive_ux_gate.js');
const session={access_token:'synthetic-v269',refresh_token:'synthetic',expires_at:4102444800,user:{id:'synthetic-user'}};
const shift=(d,n)=>{const x=new Date(d+'T12:00:00Z');x.setUTCDate(x.getUTCDate()+n);return x.toISOString().slice(0,10)};
function day(date,incomplete=false){const future=date>'2026-10-13',unknown=incomplete&&future;return {date,projection_complete:!incomplete,Consolidado:{bank_balance:unknown?null:1234.56,balance:unknown?null:1234.56,economic_net:unknown?null:0,projection_complete:!incomplete},Itaú:{balance:1200,net:0},Bradesco:{balance:34.56,net:0},C6:{balance:unknown?null:0,net:unknown?null:0,projection_complete:!incomplete},summary:{events:0,Consolidado:{entries:0,exits:unknown?null:0}},fix86_columns:{saldo_anterior:unknown?null:1234.56,saldo_final:unknown?null:1234.56,entradas_operacionais:0,saidas_operacionais:unknown?null:0,liq_d0_1_recurso:0,saldo_apos_d0_1:unknown?null:1234.56,rsus_vested:50,saldo_apos_rsu:unknown?null:1284.56,fgts:20,saldo_apos_fgts:unknown?null:1304.56,liq_d30:incomplete?null:1304.56}};}
function flow(from,to,incomplete,meta){const days=[];for(let d=from;d<=to;d=shift(d,1))days.push(day(d,incomplete));return {ok:true,...meta,complete:!incomplete,flow:{from,to,historical:{days:[],events:[]},current_future:{complete:!incomplete,days,events:[]}}};}
function cards(incomplete,meta){return {version:'card-cycles-v226',as_of:'2026-10-13',...meta,complete:!incomplete,cards:[{family:'c6',name:'C6',bank:'C6',last4:'1111',complete:!incomplete,unresolved_items:incomplete?[{source_id:'synthetic-unresolved',description:'Compra sintética sem ciclo',amount:20}]:[],cycles:[{month:'2026-11-01',due_date:'2026-11-05',complete:!incomplete,amount:incomplete?null:20,basis:incomplete?'incomplete_cycle_identity':'open_finance_composition',items:[]}]},{family:'itau_mastercard',name:'Mastercard',bank:'Itaú',last4:'2222',cycles:[{month:'2026-11-01',due_date:'2026-11-10',amount:1200,basis:'open_finance_invoice_v263',items:[]}]}]};}
async function run(browser,engine,width,coldIncomplete){
 let incomplete=coldIncomplete,epoch=1;
 const context=await browser.newContext({viewport:{width,height:950}});
 await context.addInitScript(s=>{localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));const N=Date;class Fixed extends N{constructor(...a){super(...(a.length?a:['2026-10-13T13:00:00Z']))}static now(){return N.parse('2026-10-13T13:00:00Z')}}window.Date=Fixed;},session);
 const page=await context.newPage(),errors=[],calls=[];
 page.on('pageerror',e=>errors.push(String(e)));
 await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
  const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}
  calls.push(name);let status=200,data={ok:true,rows:[],items:[]};
  const prepared=['lts_browser_product_v1','lts_browser_flow_v242','lts_browser_card_cycles_v226','lts_browser_card_cycles_v229','lts_browser_card_detail_v226'];
  const capable=request.headers()['x-client-info']==='lts-wealth-v269-c6-completeness'&&prepared.includes(name);
  const meta={source_complete:!incomplete,source_epoch:epoch,source_revision:'synthetic-'+epoch};
  if(incomplete&&(/lts_browser_(product|flow|card_cycles|card_detail|dashboard_cockpit|wealth_detail|expenses|monthly|planning)/.test(name))&&!capable){status=400;data={code:'P0001',message:'O C6 está em conferência. Abra V269.'};}
  else if(name==='token')data=session;
  else if(name==='lts_browser_product_v1'){const m=product();m.complete=!incomplete;data={ok:true,complete:!incomplete,...meta,mvp:m};}
  else if(/^lts_browser_cash_today/.test(name))data={version:'cash-today-v179-current-canonical',status:'complete',as_of:'2026-10-13',cash:1234.56,d0:0,brokerage_available:50,available_total:1284.56,fgts:20,day:day('2026-10-13')};
  else if(/^lts_browser_wealth_detail/.test(name))data=wealth;
  else if(/^lts_browser_flow_v/.test(name))data=flow(args.p_from,args.p_to,incomplete,meta);
  else if(/^lts_browser_card_cycles/.test(name))data=cards(incomplete,meta);
  else if(name==='lts_browser_card_detail_v226')data={ok:true,...meta,complete:!incomplete,items:[{source_id:'synthetic-detail',description:'Evidência sintética',amount:20}]};
  else if(name==='lts_browser_card_history_v226')data={version:'card-history-v226',invoices:[]};
  else if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))data={period:{from:args.p_from,to:args.p_to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},monthly_detail:[],management_groups:[],coverage_disclosure:{total:0,rows:0}};
  else if(name==='lts_browser_open_finance_status_v1')data={connected:true,connections:[]};
  await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
 });
 const label=engine+'-'+width+'-'+(coldIncomplete?'cold-incomplete':'transition');
 try{
  await page.goto('http://127.0.0.1:8788/releases/v269/app.html');
  await page.waitForFunction(()=>document.getElementById('shell')?.contentWindow?.__LTS_V269_VIEW);
  const f=page.frames().find(x=>x.url().includes('/index.html'));assert(f);
  await f.waitForFunction(()=>window.__LTS_V178_REVIEW?.completeness_contract===269&&window.__LTS_V226?.completeness_contract===269&&window.__LTS_V228_FLOW?.completeness_contract===269);
  await f.evaluate(()=>{V='Dashboard';renderNav();render();});
  await f.waitForFunction(()=>window.__LTS_V178_STATE?.forecast?.status==='ready');
  if(!coldIncomplete){
   await f.evaluate(()=>{const d=document.createElement('dialog');d.id='v226-detail';d.textContent='OLD CERTIFIED TOTAL';document.body.append(d);d.showModal();});
   incomplete=true;epoch++;
   await f.evaluate(()=>window.__LTS_V226.refresh());
   await f.waitForFunction(()=>window.__LTS_V269_COMPLETENESS().incomplete);
   assert.equal(await f.locator('#v226-detail[open]').count(),0,'old modal must close');
   await f.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  }
  await f.waitForFunction(()=>window.__LTS_V178_STATE.forecast.data?.complete===false);
  await f.evaluate(()=>{V='Dashboard';renderNav();render();});
  await f.waitForFunction(()=>document.getElementById('app').dataset.v269Blocked==='false');
  const dashboard=(await f.locator('#app').innerText()).replace(/\s+/g,' ');
  assert.match(dashboard,/1\.234,56/,'observed cash remains');assert.match(dashboard,/incompleta/i);
  await page.screenshot({path:'qa/v269-legacy-'+label+'-dashboard.png',fullPage:true});
  // Planejamento is an existing alias to the prepared Dashboard, not a separate legacy screen.
  await f.evaluate(()=>{V='Planejamento';renderNav();render();});
  await f.waitForFunction(()=>V==='Dashboard'&&document.getElementById('app').dataset.v269Blocked==='false');
  assert.match(await f.locator('#app').innerText(),/incompleta/i);
  for(const view of ['Despesas','Patrimônio']){
   await f.evaluate(v=>{V=v;if(v==='Despesas')window.__LTS_V168_STATE.expense.tab='overview';renderNav();render();},view);
   await f.waitForFunction(()=>document.getElementById('app').dataset.v269Blocked==='true');
   assert(await f.locator('#v269-incomplete-panel').isVisible());assert.equal(await f.locator('#app').evaluate(x=>x.inert),true);
   await page.screenshot({path:'qa/v269-legacy-'+label+'-blocked-'+view.normalize('NFD').replace(/[\u0300-\u036f]/g,'')+'.png',fullPage:true});
  }
  await f.locator('#v269-incomplete-panel button').click();
  await f.waitForFunction(()=>document.getElementById('app').dataset.v269CardsOnly==='true');
  assert.match((await f.locator('.v226-upcoming').innerText()).replace(/\s+/g,' '),/1\.200,00/);assert.match(await f.locator('.v226-upcoming').innerText(),/Total incompleto/);
  await page.screenshot({path:'qa/v269-legacy-'+label+'-cards.png',fullPage:true});
  await f.evaluate(async()=>{V='Fluxo Diário';ACC='Itaú';renderNav();await loadFlowRange('2026-10-13','2026-10-15');render();});
  await f.waitForFunction(()=>document.getElementById('app').dataset.v269Blocked==='false'&&!FLOWLOADING);
  assert.match((await f.locator('#app').innerText()).replace(/\s+/g,' '),/1\.200,00/);
  await page.screenshot({path:'qa/v269-legacy-'+label+'-itau.png',fullPage:true});
  // Warm page refresh is still safe with an incomplete product bootstrap.
  await page.reload();await page.waitForFunction(()=>document.getElementById('shell')?.contentWindow?.__LTS_V269_COMPLETENESS?.().incomplete);
  const fresh=page.frames().find(x=>x.url().includes('/index.html'));
  await fresh.waitForFunction(()=>window.__LTS_V178_REVIEW?.completeness_contract===269);
  incomplete=false;epoch++;
  await fresh.evaluate(async()=>{await S.rpc('lts_browser_product_v1');window.__LTS_V269_RECHECK();});
  await fresh.waitForFunction(()=>!window.__LTS_V269_COMPLETENESS().incomplete&&document.getElementById('app').dataset.v269Blocked==='false');
  assert(!calls.some(n=>/mutate|classify|create_future|create_internal_transfer/.test(n)));
  assert.deepEqual(errors,[]);return {label,pass:true,synthetic:true,full_app:true,cold_bootstrap:true,warm_refresh:true,transitions:true,other_bank:true,legacy_routes_blocked:true};
 }catch(e){await page.screenshot({path:'qa/v269-legacy-'+label+'-failure.png',fullPage:true});fs.writeFileSync('qa/v269-legacy-'+label+'-failure.json',JSON.stringify({error:String(e),errors,calls,runtime:await page.frames().find(x=>x.url().includes('/index.html'))?.evaluate(()=>({view:typeof V==='undefined'?null:V,contract:window.__LTS_V269_COMPLETENESS?.(),blocked:document.getElementById('app')?.dataset.v269Blocked,cardsOnly:document.getElementById('app')?.dataset.v269CardsOnly})).catch(()=>null)},null,2));throw e;}finally{await context.close();}
}
(async()=>{fs.mkdirSync('qa',{recursive:true});const out=[];for(const [engine,launcher]of [['chromium',chromium],['webkit',webkit]]){const b=await launcher.launch();try{for(const width of [390,1440])out.push(await run(b,engine,width,width===390));}finally{await b.close()}}fs.writeFileSync('qa/v269-legacy-result.json',JSON.stringify(out,null,2));console.log(JSON.stringify(out));})().catch(e=>{console.error(e);process.exitCode=1});
