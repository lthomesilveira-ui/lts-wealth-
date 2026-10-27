'use strict';
// Actual immutable release assets; isolated synthetic HTTP responses only.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const RELEASE=process.env.LTS_RELEASE||'v333';assert(['v333','v335','v337','v339','v341','v342','v344','v346','v352','v353','v356'].includes(RELEASE));
const fixture=require('./lts_v309_fixtures.cjs'),BASE='http://127.0.0.1:8788',qa=path.resolve('qa/'+RELEASE),root=path.resolve('releases/'+RELEASE),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=x=>crypto.createHash('sha256').update(x).digest('hex');
fs.mkdirSync(qa,{recursive:true});
const session={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',expires_at:4102444800,user:{id:'00000000-0000-4000-8000-000000000001',email:'viewer@example.invalid'}};
const old={title:'Old card cycle · R$ 10,00',maintenance_kind:'card_cycle',detail:'Old due 12/11/2026',amount:10};
const other={title:'Conferir fonte fictícia',detail:'Conferir informação disponível.'};
const cockpit=()=>({...fixture.response('lts_browser_dashboard_cockpit_v1',{}),work:{top_actions:[old,other]}});
const recurring=()=>({...fixture.recurring(),horizon_review_count:17,items:[{description:'Transferência fictícia A',review_kind:'reconciliation_review'},{description:'Transferência fictícia B',review_kind:'reconciliation_review'}]});
async function frameDebug(page){const f=page.frames().find(x=>x.url().includes('/releases/'+RELEASE+'/index.html'));return f?.evaluate(()=>({loading:window.__LTS_V168_STATE?.updates.loading,error:!!window.__LTS_V168_STATE?.updates.error,hasAudit:!!window.__LTS_V168_STATE?.updates.recurring,priorityRows:document.querySelectorAll('#v333PriorityActions .v168-action').length,buttons:[...document.querySelectorAll('[data-v333-actions-refresh]')].map(x=>({text:x.textContent,visible:!!x.getBoundingClientRect().height}))})).catch(()=>null);}
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block',permissions:['clipboard-read','clipboard-write']});
 await context.addInitScript(session=>{const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-16T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-16T22:00:00Z');}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));},session);
 const page=await context.newPage();page.setDefaultTimeout(30000);
 const errors=[],blocked=[],writes=[],assets=new Set(),reads=[];let releaseAudit,auditReleased=false,failAudit=false,cardAmount=1234.56,cardDue='2026-11-16';
 let failMonthly=false,holdMonthly=true,releaseMonthly,monthlyHeld,monthlyRequests=[];
 const monthGate=new Promise(resolve=>releaseMonthly=resolve),monthStarted=new Promise(resolve=>monthlyHeld=resolve);
 const auditGate=new Promise(resolve=>releaseAudit=()=>{auditReleased=true;resolve();});
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url()),name=path.basename(u.pathname);if(u.origin===BASE&&u.pathname.startsWith('/releases/'+RELEASE+'/')&&manifest.files[name])reads.push(r.body().then(bytes=>{assert.equal(r.status(),200);assert.equal(sha(bytes),manifest.files[name]);assets.add(name);}));});
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===BASE)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(session);
  if(['v337','v339','v341','v342','v344','v346','v352','v353','v356'].includes(RELEASE)&&name==='lts_browser_cash_today_v242')return send({...fixture.response(name,args),bank_positions:[{institution_code:'341',balance:600},{institution_code:'237',balance:400},{institution_code:'336',balance:0}]});
  if(['v337','v339','v341','v342','v344','v346','v352','v353','v356'].includes(RELEASE)&&name==='lts_browser_monthly_v229'){
   monthlyRequests.push({...args});
   if(failMonthly&&args.p_from==='2026-08-01')return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({message:'private SQL monthly source_ref must not appear'})});
   const data=fixture.monthly(args.p_from,args.p_to);
   if(holdMonthly&&args.p_from==='2026-09-01'){holdMonthly=false;monthlyHeld();await monthGate;data.monthly_totals[0].revenue=data.monthly_totals[0].cash_after_extraordinary=data.totals.revenue=data.totals.cash_after_extraordinary=777;}
   return send(data);
  }
  if(name==='lts_browser_product_v1'){const p=fixture.product();p.dashboard_cockpit=cockpit();return send({ok:true,mvp:p});}
  if(name==='lts_browser_dashboard_cockpit_v1')return send(cockpit());
  if(/recurring_future_gap/.test(name)){if(!auditReleased)await auditGate;if(failAudit)return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({message:'private SQL source_ref must not appear'})});return send(recurring());}
  if(/^lts_browser_card_cycles_/.test(name))return send({version:'card-cycles-v226',as_of:'2026-10-16',active_billing_accounts:1,cards:[{family:'itau_mastercard',bank:'Itaú',name:'Mastercard Black',last4:'0000',cycles:[{month:'2026-10-01',due_date:'2026-10-12',amount:100,basis:'open_finance_invoice_v263',settlement_confirmed:true},{month:'2026-11-01',due_date:cardDue,amount:cardAmount,basis:'open_finance_composition',items:[]}]}]});
  if(/^lts_browser_card_detail_/.test(name)){assert.equal(args.p_family,'itau_mastercard');assert.equal(args.p_month,'2026-11-01');return send({family:'itau_mastercard',month:'2026-11-01',basis:'open_finance_composition',invoice_amount:cardAmount,detail_total:cardAmount,items:[{description:'Compra fictícia atual',amount:cardAmount,category:'Farmácia',purchase_date:'2026-10-16'}]});}
  if(name==='lts_browser_open_finance_status_v1')return send({connections:[],last_syncs:[]});
  if(name==='lts_browser_future_bank_v293')return send({rows:[],card_future_received:0});
  if(name==='lts_browser_income_review_queue_v296'||name==='lts_browser_card_review_queue_v312'||name==='lts_browser_expense_review_queue_v229')return send({ok:true,row_count:0,matched_count:0,additional_count:0,offset:0,next_offset:null,rows:[],category_options:['Farmácia']});
  if(/_decision_|_update_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_/.test(name)){writes.push(name);return route.abort();}
  if(/^lts_browser_flow_v/.test(name)){
   const data=fixture.response(name,args);
   if(args.p_from<='2027-02-21'&&args.p_to>='2027-02-21')data.flow.current_future.events.push({event_date:'2027-02-21',account:'Corretora',source:'future_rsu_available',signed_amount:900,category:'RSU',asset_movement:true});
   return send(data);
  }
  return send(fixture.response(name,args));
 });
 try{
  await page.goto(BASE+'/releases/'+RELEASE+'/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let i=0;i<200;i++){frame=page.frames().find(f=>f.url().includes('/releases/'+RELEASE+'/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V226?.installed);
  await frame.getByRole('button',{name:'Ver ações',exact:true}).waitFor();
  assert.equal(await frame.getByRole('button',{name:'Ver todas (0)',exact:true}).count(),0,'Unloaded audit must not imply no pending actions');
  releaseAudit();
  await frame.getByRole('button',{name:'Ver todas (21)',exact:true}).waitFor();
  const settled=()=>frame.waitForFunction(()=>{
   const s=window.__LTS_V178_STATE;
   return s&&['cash','forecast','wealth','awards','dashboardReport'].every(k=>s[k]?.status==='ready')&&
    document.querySelector('.v168-dashboard .v168-kpi strong')?.textContent.includes('1.000,00');
  });
  const currentKpis=()=>frame.locator('.v168-dashboard .v168-kpi').evaluateAll(nodes=>nodes.map(n=>({label:n.querySelector('span')?.textContent.trim(),value:n.querySelector('strong')?.textContent.trim()})));
  await settled();const before=await currentKpis();
  assert.match(before.find(x=>x.label==='Contas correntes').value,/1\.000,00/);
  assert.match(before.find(x=>x.label==='Total disponível hoje').value,/1\.500,00/);
  assert.match(before.find(x=>x.label==='Total de despesas do período').value,/100,00/);
  const schedule=frame.locator('#ltsFutureBank');await schedule.waitFor();await frame.waitForFunction(()=>{const e=document.querySelector('#ltsFutureBank'),height=e?.getBoundingClientRect().height;return height>0&&height<175;});
  const dashSize=await frame.locator('html').evaluate(el=>({w:el.clientWidth,s:el.scrollWidth}));assert(dashSize.s<=dashSize.w+2);
  let monthChecks=null;
  if(['v337','v339','v341','v342','v344','v346','v352','v353','v356'].includes(RELEASE)){
   await frame.waitForFunction(()=>window.__LTS_V337_MONTH?.state.status==='ready');
   const overview=frame.locator('#v337Overview'),values=()=>overview.locator('.v337-metric > strong').allTextContents(),month=overview.getByLabel('Mês do resumo');
   assert.deepEqual((await values()).map(x=>x.replace(/[^0-9,-]/g,'')),['150,00','100,00','50,00']);
   assert.equal(await overview.locator('.v337-bank:not(.total)').count(),3);
   assert.deepEqual((await overview.locator('.v337-bank strong').allTextContents()).map(x=>x.replace(/[^0-9,-]/g,'')),['600,00','400,00','0,00','1000,00']);
   for(const detail of await overview.locator('details').all()){assert.equal(await detail.getAttribute('open'),null);assert((await detail.boundingBox()).height<=42,'Source disclosure is closed and compact');}
   assert.match(await overview.locator('.v337-period').innerText(),/01\/10\/2026 a 16\/10\/2026/);
   assert.doesNotMatch(await overview.innerText(),/source_ref|RPC|backend|private SQL|%/i);
   await frame.evaluate(()=>{window.__v337StaleVisible=false;new MutationObserver(()=>{if(document.querySelector('#v337Overview .v337-metrics')?.textContent.includes('777,00'))window.__v337StaleVisible=true;}).observe(document.body,{subtree:true,childList:true,characterData:true});});
   await month.fill('2026-09');await monthStarted;
   await overview.getByLabel('Mês do resumo').fill('2026-07');releaseMonthly();
   await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V337_MONTH.state.data?.month==='2026-07');
   assert.deepEqual((await values()).map(x=>x.replace(/[^0-9,-]/g,'')),['0,00','0,00','0,00']);
   assert.equal(await frame.evaluate(()=>window.__v337StaleVisible),false,'Superseded monthly response never paints');
   assert(monthlyRequests.some(x=>x.p_from==='2026-07-01'&&x.p_to==='2026-07-31'));
   failMonthly=true;await overview.getByLabel('Mês do resumo').fill('2026-08');
   await overview.getByRole('button',{name:'Tentar novamente',exact:true}).waitFor();
   assert.match(await overview.innerText(),/Não foi possível conferir este mês/);assert.doesNotMatch(await overview.innerText(),/private SQL|source_ref/);
   assert.equal(await overview.locator('.v337-metric').count(),0,'Unavailable amount is never shown as zero');
   failMonthly=false;await overview.getByRole('button',{name:'Tentar novamente',exact:true}).click();
   await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V337_MONTH.state.data?.month==='2026-08');
   assert.equal(monthlyRequests.filter(x=>x.p_from==='2026-08-01').length,2,'Explicit retry sends a new read');
   await overview.getByLabel('Mês do resumo').fill('2026-10');
   await frame.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V337_MONTH.state.data?.month==='2026-10');
   assert.deepEqual((await values()).map(x=>x.replace(/[^0-9,-]/g,'')),['150,00','100,00','50,00']);
   await settled();assert.deepEqual(await currentKpis(),before,'Monthly navigation preserves current financial positions');
   const fit=await overview.evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth,metrics:[...el.querySelectorAll('.v337-metric')].map(x=>({w:x.clientWidth,s:x.scrollWidth}))}));assert(fit.scroll<=fit.width+2&&fit.metrics.every(x=>x.s<=x.w+2),'New overview fits desktop and mobile');
   if(['v339','v341','v342','v344','v346','v352','v353','v356'].includes(RELEASE)){const boot=await frame.parentFrame().evaluate(()=>window.LTSV339Boot.snapshot());assert.equal(boot.components.length,32);assert(boot.components.every(x=>x.ready),'All shared component registrations complete');assert.equal(boot.observer_active,false);}
   monthChecks={source_backed_contract:true,bank_rows:3,month_switch:true,actual_zero:true,stale_response_rejected:true,failed_read_not_zero:true,explicit_retry:true,closed_source_disclosures:true};
  }
  await page.screenshot({path:path.join(qa,label+'-dashboard.png')});
  await frame.getByRole('button',{name:'Ver todas (21)',exact:true}).click();
  await frame.locator('#v333PriorityActions .v168-action').nth(20).waitFor();assert.equal(await frame.locator('#v333PriorityActions .v168-action').count(),21);
  let card=frame.locator('#v333PriorityActions .v168-action').filter({hasText:'Mastercard Black · 11/2026'});
  assert.match(await card.innerText(),/1\.234,56/);assert.match(await card.innerText(),/16\/11\/2026/);assert.match(await card.innerText(),/oficial.*ainda não foi recebido/);
  assert.doesNotMatch(await frame.locator('#v333PriorityActions').innerText(),/Old card|12\/11\/2026/);
  await card.getByRole('button',{name:'Abrir',exact:true}).click();
  await frame.locator('#v226-detail').getByText('Compra fictícia atual',{exact:true}).waitFor();assert.match(await frame.locator('#v226-detail').innerText(),/1\.234,56/);
  await frame.locator('#v226-detail [data-v226-close]').click();
  cardAmount=1500;cardDue='2026-11-18';await frame.evaluate(()=>window.__LTS_V226.refresh());
  await frame.waitForFunction(()=>document.querySelector('#v333PriorityActions')?.innerText.includes('1.500,00'));
  card=frame.locator('#v333PriorityActions .v168-action').filter({hasText:'Mastercard Black · 11/2026'});assert.match(await card.innerText(),/18\/11\/2026/);
  await page.screenshot({path:path.join(qa,label+'-actions.png')});
  await frame.evaluate(()=>{V='Dashboard';renderNav();render();});await frame.getByRole('button',{name:'Ver todas (21)',exact:true}).waitFor();
  await settled();assert.deepEqual(await currentKpis(),before,'Action-only refresh preserves populated financial positions');
  failAudit=true;await frame.evaluate(()=>{window.__LTS_V168_STATE.updates.recurring=null;window.__LTS_V168_STATE.dashboard.data.recurring=null;window.__LTS_V168_STATE.updates.openFinance=null;window.__LTS_V227_TRANSPORT.invalidate();V='Atualizações';renderNav();render();});
  await frame.getByRole('button',{name:'Atualizar ações',exact:true}).waitFor();assert.doesNotMatch(await frame.locator('.v168-updates').innerText(),/private SQL|source_ref|Nenhuma ação aberta/);
  failAudit=false;await frame.getByRole('button',{name:'Atualizar ações',exact:true}).click();await frame.locator('#v333PriorityActions .v168-action').nth(20).waitFor();
  await frame.evaluate(()=>{V='Dashboard';renderNav();render();});await frame.getByRole('button',{name:'Ver todas (21)',exact:true}).waitFor();
  await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});
  await frame.locator('.fx87-row[id^="d-"]').first().waitFor();
  const flowBefore=await frame.locator('.fx87-row[id^="d-"]').first().innerText();
  await frame.locator('.fx87-row[id^="d-"]').first().click();await frame.locator('#flowCloseDetails').click();
  assert.equal(await frame.locator('.fx87-row[id^="d-"]').first().innerText(),flowBefore);
  await page.screenshot({path:path.join(qa,label+'-flow.png')});
  await frame.locator('#flowYear').selectOption('2027');
  await frame.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2027-01-01'&&FLOWTO==='2027-12-31');
  await frame.locator('#flowCopyConsolidated').click();
  await frame.waitForFunction(()=>document.querySelector('#flowCopyStatus')?.textContent.includes('365 dia(s)'));
  const copied=await frame.evaluate(()=>navigator.clipboard.readText()),lines=copied.split('\n').map(x=>x.split('\t'));
  assert.equal(lines.length,366);assert(lines.every(x=>x.length===12));assert.equal(lines[1][0],'2027-01-01');assert.equal(lines.at(-1)[0],'2027-12-31');
  assert.equal(lines.find(x=>x[0]==='2027-02-21')[2],'0,00','RSU resource availability is not a bank inflow');
  assert.equal(new Set(lines.slice(1).map(x=>x[0])).size,365);
  const amount=x=>Number(x.replace(',','.'));
  for(const row of lines.slice(1))assert(Math.abs(amount(row[1])+amount(row[2])-amount(row[3])-amount(row[4]))<.021,'Export cash arithmetic '+row[0]);
  const size=await frame.locator('html').evaluate(el=>({width:el.clientWidth,scroll:el.scrollWidth}));assert(size.scroll<=size.width+2,'No global page overflow');
  await Promise.all(reads);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);assert.deepEqual(writes,[]);
  return {pass:true,label,viewport,real_assets_verified:assets.size,synthetic_http:true,production_session:false,physical_device:false,actions:21,monthly_overview:monthChecks,clipboard_rows:365,clipboard_cash_arithmetic:true};
 }catch(e){await page.screenshot({path:path.join(qa,label+'-failure.png')});console.error({label,errors,blocked,writes,actions:await frameDebug(page)});throw e;}finally{releaseAudit();releaseMonthly();await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(qa,'browser-results.json'),JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));}finally{await browser.close();}})().catch(e=>{console.error(e);process.exitCode=1;});
