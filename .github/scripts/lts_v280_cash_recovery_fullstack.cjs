'use strict';
// FULLSTACK LOCAL/CI gate. Entire release, genuine script order, synthetic data only.
// CI: serve repository on loopback, then LTS_RELEASE=v280 node this-file.cjs.
// Local candidate: LTS_CASH_RELEASE_ROOT=/absolute/candidate LTS_CASH_APP_PATH=/candidate/app.html.
// Requires Playwright. No server/browser is started by --static-check.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const release=process.env.LTS_RELEASE;
assert(release&&/^[a-zA-Z0-9_-]+$/.test(release),'LTS_RELEASE is required (for example v280)');
const BASE=process.env.LTS_CASH_BASE||'http://127.0.0.1:8788';
const baseURL=new URL(BASE);
assert.equal(baseURL.protocol,'http:','HTTP loopback only');
assert(['127.0.0.1','localhost','[::1]'].includes(baseURL.hostname),'Loopback only');
assert(!baseURL.username&&!baseURL.password&&!baseURL.search&&!baseURL.hash,'Plain loopback origin required');
const root=path.resolve(process.env.LTS_CASH_RELEASE_ROOT||path.join('releases',release));
const appPath=process.env.LTS_CASH_APP_PATH||'/releases/'+release+'/app.html';
const appURL=new URL(appPath,baseURL);assert.equal(appURL.origin,baseURL.origin);
const html={app:fs.readFileSync(path.join(root,'app.html'),'utf8'),index:fs.readFileSync(path.join(root,'index.html'),'utf8')};
const sources=body=>[...body.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/g)].map(m=>m[1]);
const expected={outer:sources(html.app),inner:sources(html.index)};
// The executive layer injects its genuine read model into the iframe after the three static scripts.
const modelSource=fs.readFileSync(path.join(root,'lts-dashboard-executive-v1.js'),'utf8').match(/const MODEL_SRC=['"]([^'"]+)['"]/);
assert(modelSource,'Real executive read-model source declaration missing');
expected.dynamic=[modelSource[1]];
const hashes={};
for(const filename of ['app.html','index.html',...new Set([...expected.outer,...expected.inner,...expected.dynamic].map(src=>src.split('?')[0]))]){
 assert(!/^(?:https?:)?\/\//.test(filename),'Every release script must be a real local file: '+filename);
 const file=path.resolve(root,filename);assert(file.startsWith(root+path.sep),'Release path traversal');
 hashes[filename]=crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}
assert(fs.readFileSync(path.join(root,'lts-v179-cash-recovery.js'),'utf8').includes('refreshCashOnly'),'Candidate cash-only API absent');
const qa=path.resolve(process.env.LTS_CASH_QA_DIR||'qa/cash-recovery');
const DAY='2026-10-16',NOW='2026-10-16T13:00:00Z';
const CASH='lts_browser_cash_today_v242',FLOW='lts_browser_flow_v242',REFRESH='lts_browser_open_finance_refresh_v1',STATUS='lts_browser_open_finance_status_v1';
const ORIGIN='https://tadhkamnwtsbdozwkyut.supabase.co';
const HEAVY=/^lts_browser_(?:wealth_detail_|awards_|expenses_|expense_executive_|planning_ui_|monthly_|flow_v)/;
const session={access_token:'synthetic-only-cash-gate-token-0',refresh_token:'synthetic-only-refresh-0',token_type:'bearer',expires_in:3600,expires_at:4102444800,user:{id:'synthetic-cash-viewer',email:'viewer@example.invalid'}};
const semantic=text=>String(text||'').replace(/\s+/g,' ').trim();
const money=value=>semantic(new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(value));
// Small boot fixtures are copied locally from the established boot gate. No live account data.
const fixture=(()=>{
// Entirely synthetic data. No account exports, real balances, names or document IDs.
const AS_OF='2026-10-16';
function day(date){return {date,historical:false,summary:{events:0,Consolidado:{entries:0,exits:0}},Consolidado:{bank_balance:1000,economic_net:0},Itaú:{net:0,balance:1000},Bradesco:{net:0,balance:0},C6:{net:0,balance:0},fix86_columns:{saldo_anterior:1000,entradas:0,saidas:0,saldo_final:1000,liq_d0_1_recurso:200,rsus_vested:300,fgts:500,saldo_apos_d0_1:1200,saldo_apos_rsu:1500,saldo_apos_fgts:2000}};}
const cockpit={as_of:AS_OF,liquidity:{bank_cash:1000,d0:200,through_d3:1500,d3_vested:300,fgts_d30:500,accounts:[{institution:'Banco de teste',balance:1000}]},planning_audited:{first_negative_date:null,first_uncovered_gap_date:null,worst_before_brl:1000,worst_after_brl:1500,covers_horizon:true},horizons:[],expenses:{current_month:{spend:100,top_categories:[{category:'Categoria de teste',amount:100}]},previous_month:{spend:100}},cards:{open_cycles_total:100,closed_or_due_total:0,next_due:{due_date:'2026-10-25',amount:100,card_name:'Cartão de teste'}},work:{actionable_count:0,top_actions:[]}};
const wealth={version:'synthetic-boot-wealth',as_of:AS_OF,wealth:{as_of:AS_OF,summary:{net_worth_central:2000,net_worth_low:2000,net_worth_high:2000,assets_central:2000,known_debt_total:0,liquidity_through_d3:1500,restricted_contingency:500,future_awards_excluded:0},liquidity:{bank_cash:1000,d0:200,d3:300,fgts_contingency:500},assets:{}},rsu:{vested_positions:[],future_schedule:[],future_schedule_count:0},employment_awards:{retention:{gross_total_brl:0,installments:[]},retention_projected_events:[]},volvo_financing:{remaining_installments:0,future_schedule_total:0},documentary_commitments:{items:[]},pensions:{positions:[],total_gross_brl:0},current_liquidity:{brokerage_available:300}};
function product(revision=1){return {__bootFixtureRevision:revision,dashboard_cockpit:cockpit,dashboard:{position:{bank_cash:1000,liquid_d0_assets:200,liquid_d1_d3_assets:300,restricted_assets:500},horizons:[],risk_layers:{}},planning_executive:{summary:{gap_episode_count:0,fgts_covers_horizon:true},gap_episodes:[]},wealth_executive:wealth.wealth,updates:{items:[],maintenance_checks:[],freshness:{position_as_of:AS_OF}},semantic_review:{pending_groups:0,items:[]},card_classification_review:{pending_groups:0,pending_lines:0,pending_value:0,category_options:[],items:[]},expense_universe_qa:{bank_documented_through:AS_OF},card_operating:{as_of:AS_OF,closed_or_due_total:0,closed_or_due:[],open_cycles_total:100,open_cycles:[],next_due:cockpit.cards.next_due,contracted_installment_floor_total:0,contracted_installment_floor_months:[],detail_coverage:{reconciled_invoices:0,detail_lines:0,zero_delta_invoices:0},classification_review:{pending_lines:0,pending_value:0,safe_suggestion_groups:0}},card_history:{monthly:[]},expense_drilldown:{rows:[]},wealth:{asset_layers:{derived_future_schedule:[]}},flow:{days:[day(AS_OF)],events:[]},expenses:{},commitments:{commitments:[]},documentary_commitments:{items:[]}};}
function flow(from=AS_OF,to=AS_OF){const days=[];for(let d=new Date(from+'T12:00:00Z');d.toISOString().slice(0,10)<=to;d.setUTCDate(d.getUTCDate()+1)){if(days.length>12000)throw Error('Synthetic range unexpectedly large');days.push(day(d.toISOString().slice(0,10)));}return {ok:true,flow:{from,to,available_year_from:2013,available_year_to:2041,historical_balance_truth_contract:{consolidated_first_complete_opening:'2026-01-01',itau_first_documentary_opening:'2026-01-01',bradesco_first_documentary_opening:'2026-01-01',c6_first_documentary_opening:'2026-01-01'},historical:{days:[],events:[]},current_future:{from,to,complete:true,days,events:[]}}};}
function report(from='2026-01-01',to=AS_OF){return {version:'expense-executive-v20-v178-review',as_of:to,period:{from,to,last_available:to,months_in_selection:1},summary:{selected_total:100,card_total:100,account_total:0,monthly_average:100,rows:1,pending_identification:0},management_groups:[{name:'Categoria de teste',total:100,rows:1,subgroups:[]}],monthly_detail:[{month:to.slice(0,7)+'-01',total:100}],coverage_disclosure:{total:0,rows:0}};}
function response(name,a={}){
 if(name==='lts_browser_dashboard_cockpit_v1')return cockpit;
 if(/^lts_browser_flow_v/.test(name))return flow(a.p_from,a.p_to);
 if(/^lts_browser_cash_today_/.test(name))return {version:'cash-today-v179-current-canonical',status:'complete',as_of:AS_OF,cash:1000,d0:200,brokerage_available:300,available_total:1500,fgts:500,day:day(AS_OF)};
 if(/^lts_browser_expenses_|^lts_browser_expense_executive_/.test(name))return report(a.p_from,a.p_to);
 if(/^lts_browser_expense_detail_/.test(name))return {version:'synthetic-detail',from:a.p_from,to:a.p_to,group:a.p_group,subgroup:null,total:100,row_count:1,matched_count:1,offset:0,next_offset:null,revision:'synthetic-1',rows:[{key:'synthetic-expense-1',date:AS_OF,date_kind:'day',description:'Despesa fictícia',account_source:'Conta de teste',amount:100,category:'Categoria de teste'}],components:[]};
 if(/^lts_browser_wealth_detail_/.test(name))return wealth;
 if(/^lts_browser_awards_/.test(name))return {version:'synthetic-awards',as_of:AS_OF,vested_shares:300,brokerage_cash:0,brokerage_available:300,events:[]};
 if(/^lts_browser_planning_ui_contract_/.test(name))return {version:'planning-ui-contract-v2',period_to:'2027-12-31',fgts_covers_horizon:true,fgts_first_negative:null,labels:{d01:'Cobertura de teste',rsu:'Cobertura de teste',fgts:'Cobertura de teste'}};
 if(/^lts_browser_card_cycles_/.test(name))return {version:'card-cycles-v226',as_of:AS_OF,active_billing_accounts:1,cards:[{bank:'Itaú',family:'itau_mastercard',name:'Cartão de teste',last4:'0000',status:'ACTIVE',cycles:[{month:'2026-10-01',due_date:'2026-10-25',amount:100,basis:'open_finance_composition',payment_status:'payment_not_reported',items:[{source_id:'synthetic-purchase-1',description:'Compra fictícia',amount:100,last4:'0000',purchase_date:'2026-10-01',category:'Categoria de teste',category_basis:'user_decision'}]}]}]};
 if(/^lts_browser_card_detail_/.test(name))return {invoice_amount:100,detail_total:100,items:[{source_id:'synthetic-purchase-1',description:'Compra fictícia',amount:100,last4:'0000',purchase_date:'2026-10-01',category:'Categoria de teste'}]};
 if(/^lts_browser_card_history_/.test(name))return {version:'card-history-v226',invoices:[]};
 if(/^lts_browser_card_flow_schedule_/.test(name))return {inventory:{cards:[]},months:[],summary:{}};
 if(/^lts_browser_open_finance_status_/.test(name))return {connections:[]};
 if(/^lts_browser_open_finance_pending_/.test(name))return {version:'pending-expense-v225',transaction_count:0,net_expense:0,rows:[]};
 if(/^lts_browser_expense_review_queue_/.test(name))return {row_count:0,matched_count:0,offset:0,next_offset:null,category_options:[],beneficiary_options:[],rows:[]};
 if(/expense_context/.test(name))return {contexts:[],natures:[],summary:{}};
 if(/invoice_documentary_only|legacy_invoice_gap/.test(name))return {financial_effect:'none',invoices:[]};
 if(/recurring_future_gap/.test(name))return {horizon_checks:[],items:[]};
 return {ok:true,items:[],rows:[],total:0,summary:{}};
}
return {AS_OF,product,response};

})();
function syntheticDay(date,cash=1666.5){
 const row=fixture.response(CASH).day;
 row.date=date;row.summary={events:1,Consolidado:{entries:25,exits:0}};
 row.Consolidado={bank_balance:cash,economic_net:25};row['Itaú']={net:25,balance:cash-500};row.Bradesco={net:0,balance:200};row.C6={net:0,balance:300};
 Object.assign(row.fix86_columns,{saldo_anterior:cash-25,entradas:25,saidas:0,saldo_final:cash,saldo_apos_d0_1:cash+200,saldo_apos_rsu:cash+500,saldo_apos_fgts:cash+1000});
 return row;
}
function cashBody(marker,date=DAY,positionTime='2026-10-15T16:21:00Z'){
 const row=syntheticDay(date,marker);row.summary.events=0;
 return {version:'cash-today-v179-current-canonical',status:'complete',as_of:date,cash:marker,d0:200,brokerage_available:300,available_total:marker+500,fgts:500,day:row,
 bank_positions:[['341','Itaú'],['237','Bradesco'],['336','C6']].map(([institution_code,institution],i)=>({institution_code,institution,balance:row[institution].balance,as_of:positionTime,source_id:'synthetic-position-'+marker+'-'+i}))};
}
function flowBody(args){
 const body=fixture.response(FLOW,args);
 body.flow.observed_bank_movements={};
 for(const key of ['historical','current_future'])if(body.flow[key]){
  body.flow[key].days=body.flow[key].days.map(row=>syntheticDay(row.date));
  body.flow[key].events=body.flow[key].days.map(row=>({source:'current_event',source_ref:'synthetic-event-'+row.date,event_date:row.date,account:'Itaú',category:'Categoria de teste',description:'Entrada sintética para expandir',signed_amount:25,status:'expected',is_projection:true}));
 }
 return body;
}
function connectionBody(flags){
 return {connections:['341','237','336'].map((institution_code,i)=>({id:'synthetic-connection-'+i,provider:'synthetic-provider',institution_code,status:'connected',
 last_success_at:flags.collection==='confirmed'?flags.requestedAt:flags.receivedAt,provider_item_updated_at:flags.originAt,
 ...(flags.collection==='failed'&&i===1?{last_error_code:'SYNTHETIC_COLLECTION_ERROR',last_attempt_at:flags.requestedAt}:{})}))};
}
class Barriers {
 constructor(){this.events=new EventEmitter();this.pending=new Map();this.used=new Set();}
 async hold(label,fulfill,defaultBody,status=200){
  assert(!this.used.has(label),'Duplicate barrier '+label);this.used.add(label);
  await new Promise(resolve=>{this.pending.set(label,{fulfill,defaultBody,status,resolve});this.events.emit(label);});
 }
 async seen(label){
  if(this.pending.has(label))return;
  await new Promise((resolve,reject)=>{const on=()=>{clearTimeout(timer);resolve();};const timer=setTimeout(()=>{this.events.off(label,on);reject(Error('Network barrier never reached: '+label));},15000);this.events.once(label,on);});
 }
 async release(label,body,status){
  await this.seen(label);const item=this.pending.get(label);assert(item,'Missing barrier '+label);this.pending.delete(label);
  try{await item.fulfill(status??item.status,body??item.defaultBody);}finally{item.resolve();}
 }
 async close(){for(const label of [...this.pending.keys()])await this.release(label).catch(()=>{});}
}
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,serviceWorkers:'block',reducedMotion:'reduce'});
 await context.addInitScript(({session,now})=>{
  const NativeDate=Date;window.__CASH_TEST_NOW__=now;
  class TestDate extends NativeDate{constructor(...args){super(...(args.length?args:[NativeDate.parse(window.__CASH_TEST_NOW__)]));}static now(){return NativeDate.parse(window.__CASH_TEST_NOW__);}}
  window.Date=TestDate;
  if(!sessionStorage.getItem('cash-gate-seeded')){sessionStorage.setItem('cash-gate-seeded','yes');localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));}
  sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
  const nativeTimeout=setTimeout.bind(window),nativeClear=clearTimeout.bind(window),polls=new Map();let serial=0;
  const state=window.__CASH_TEST__={invalidations:0,nativeFetch:[],polls,applied:[],promises:{}};
  addEventListener('lts:data-invalidated',()=>state.invalidations++);
  const nativeFetch=fetch.bind(window);
  window.fetch=(input,init)=>{const url=typeof input==='string'?input:input.url;if(url.includes('/rest/v1/rpc/'))state.nativeFetch.push({name:url.split('/').pop(),body:init?.body||''});return nativeFetch(input,init);};
  // Keep every production timer intact except V225's exact named poll callback.
  // Its real body is invoked explicitly; neither poll criteria nor timeout logic is replaced.
  window.setTimeout=function(fn,ms,...args){if(ms===5000&&typeof fn==='function'&&fn.name==='poll'){const id=-(++serial);polls.set(id,()=>fn(...args));return id;}return nativeTimeout(fn,ms,...args);};
  window.clearTimeout=function(id){if(polls.delete(id))return;return nativeClear(id);};
  state.runPoll=async()=>{if(polls.size!==1)throw Error('Expected exactly one scheduled collection poll, got '+polls.size);const [id,fn]=polls.entries().next().value;polls.delete(id);await fn();};
 },{session,now:NOW});
 const page=await context.newPage();page.setDefaultTimeout(15000);page.setDefaultNavigationTimeout(20000);
 const barriers=new Barriers(),cashPlans=[],refreshPlans=[],forecastPlans=[],calls=[],errors=[],blocked=[],badAssets=[],routeErrors=[],scriptResponses=new Set(),assetAudits=[],phases=[],geometry=[];
 const flags={day:DAY,marker:1234.5,positionTime:'2026-10-15T16:21:00Z',requestedAt:'2026-10-16T12:59:30Z',receivedAt:'2026-10-16T12:00:00Z',originAt:'2026-10-16T12:43:00Z',collection:'pending'};
 let frame,phase='boot',authSerial=0;
 const mark=name=>{phase=name;phases.push({name,calls:calls.length});};
 page.on('pageerror',error=>errors.push(String(error.stack||error)));
 page.on('response',response=>{
  const url=new URL(response.url());
  if(url.origin===baseURL.origin&&url.pathname.endsWith('.js')){
   if(response.status()!==200){badAssets.push({path:url.pathname,status:response.status()});return;}
   scriptResponses.add(url.pathname+url.search);
   // A correct on-disk candidate is insufficient if the loopback server serves another build.
   assetAudits.push(response.body().then(body=>{
    const name=path.basename(url.pathname),expectedHash=hashes[name];
    assert(expectedHash,'Unexpected local script outside declared release: '+name);
    assert.equal(crypto.createHash('sha256').update(body).digest('hex'),expectedHash,'Served script must exactly match local release: '+name);
   }).catch(error=>{badAssets.push({path:url.pathname,error:String(error.message||error)});}));
  }
 });
 await context.route('**/*',async route=>{
  try{
   const req=route.request(),url=new URL(req.url());
   if(url.origin===baseURL.origin&&['GET','HEAD'].includes(req.method()))return route.continue();
   if(url.origin!==ORIGIN){blocked.push({origin:url.origin,path:url.pathname,method:req.method()});return route.abort('blockedbyclient');}
   const name=url.pathname.split('/').pop();let args={};try{args=JSON.parse(req.postData()||'{}');}catch{}
   const entry={name,args,phase,status:null};calls.push(entry);
   const fulfill=async(status,body)=>{entry.status=status;return route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});};
   if(url.pathname==='/auth/v1/token')return fulfill(200,{...session,access_token:'synthetic-only-cash-gate-token-'+(++authSerial),refresh_token:'synthetic-only-refresh-'+authSerial});
   if(url.pathname==='/auth/v1/logout')return fulfill(200,{});
   if(!url.pathname.startsWith('/rest/v1/rpc/')||req.method()!=='POST'||(/_decision_|_save_|_apply_|_delete_|_confirm_|_mutate_|_classify_|_classification_|_refresh_|_update_|_create_|_upload_/.test(name)&&name!==REFRESH)){
    blocked.push({origin:url.origin,path:url.pathname,method:req.method()});return route.abort('blockedbyclient');
   }
   let body,status=200,plan;
   if(name===CASH){plan=cashPlans.shift();body=plan?.body??cashBody(flags.marker,flags.day,flags.positionTime);status=plan?.status??200;}
   else if(name===REFRESH){plan=refreshPlans.shift();assert(plan,'Unexpected collection mutation: no synthetic plan');body=plan.body??{ok:true,requested_at:flags.requestedAt};status=plan.status??200;}
   else if(name===FLOW){if(args.p_to===String(Number(flags.day.slice(0,4))+1)+'-12-31')plan=forecastPlans.shift();body=flowBody(args);}
   else if(name===STATUS)body=connectionBody(flags);
   else if(name==='lts_browser_product_v1')body={ok:true,mvp:fixture.product(authSerial+1)};
   else body=fixture.response(name,args);
   if(plan?.hold)return barriers.hold(plan.hold,fulfill,body,status);
   return fulfill(status,body);
  }catch(error){routeErrors.push(String(error.stack||error));await route.abort('failed').catch(()=>{});}
 });
 const count=name=>calls.filter(call=>call.name===name).length;
 const heavyCount=()=>calls.filter(call=>HEAVY.test(call.name)).length;
 const flowHash=async()=>crypto.createHash('sha256').update(await frame.evaluate(()=>JSON.stringify(FLOWQ))).digest('hex');
 const settle=async()=>frame.evaluate(async()=>{await Promise.resolve();await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});
 const current=()=>frame.evaluate(()=>{const s=window.__LTS_V178_STATE.cash;return {status:s.status,value:s.data?.cash??null,date:s.date??null,complete:window.__LTS_V178_REVIEW.cashComplete(s),token:s.token??null,sessionGeneration:s.sessionGeneration??null,authEpoch:s.authEpoch??null};});
 const cashReady=async(marker=flags.marker)=>{await frame.waitForFunction(marker=>{const s=window.__LTS_V178_STATE?.cash;return s?.status==='ready'&&s.data?.cash===marker&&window.__LTS_V178_REVIEW.cashComplete(s);},marker);await settle();};
 const waitCash=async()=>frame.evaluate(()=>window.__LTS_V178_REVIEW.refreshCashOnly());
 const invalidate=async(n=1)=>frame.evaluate(n=>{for(let i=0;i<n;i++)window.__LTS_V227_TRANSPORT.invalidate();},n);
 const selection=()=>frame.evaluate(()=>({account:ACC,from:FLOWFROM,to:FLOWTO,preset:FLOWPRESET,expanded:[...EXP].sort(),zero:SHOWZERO,forceZero:FLOWFORCEZERO,fromInput:document.getElementById('flowFrom')?.value,toInput:document.getElementById('flowTo')?.value}));
 const assertSelection=async expectedSelection=>assert.deepEqual(await selection(),expectedSelection,'Cash recovery preserves account, applied period, draft period, expansion and zero filter');
 const renderStorm=async()=>{
  const before={cash:count(CASH),heavy:heavyCount()};
  await frame.evaluate(async()=>{for(let i=0;i<100;i++)render();await Promise.resolve();await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});
  assert.equal(count(CASH),before.cash,'100 renders do not request/retry cash');assert.equal(heavyCount(),before.heavy,'100 renders do not start heavy data readers');
 };
 const clickStorm=async()=>{
  const before={cash:count(CASH),heavy:heavyCount()},beforeSelection=await selection();
  // The shipped V162 bank-scope contract intentionally closes days on bank changes.
  // Test that contract, then restore the user's expansion through actual controls
  // before checking preservation across cash-only recovery.
  for(const account of ['Bradesco','C6','Consolidado','Itaú']){
   await frame.locator('[data-a="'+account+'"]').click();
   assert.deepEqual(await frame.evaluate(()=>[...EXP]),[],'Changing bank closes the previous bank disclosure');
  }
  if(beforeSelection.account!=='Itaú')await frame.locator('[data-a="'+beforeSelection.account+'"]').click();
  const exp=frame.locator('.exp[data-d="'+DAY+'"]').first();
  await exp.click();assert.equal(await frame.evaluate(date=>EXP.has(date),DAY),true,'Expand control opens the selected day');
  await exp.click();assert.equal(await frame.evaluate(date=>EXP.has(date),DAY),false,'Second expand control click closes that day');
  for(const date of beforeSelection.expanded)await frame.locator('.exp[data-d="'+date+'"]').first().click();
  await settle();await assertSelection(beforeSelection);
  assert.equal(count(CASH),before.cash,'Bank selection/expansion cannot request cash');assert.equal(heavyCount(),before.heavy,'Bank selection/expansion cannot start heavy readers');
 };
 const assertFreshness=async(time=flags.positionTime)=>{
  const box=frame.locator('.v225-balance-freshness[data-view="Fluxo Diário"]');await box.waitFor({state:'visible'});
  const times=await box.locator('.v225-freshness-bank time').evaluateAll(nodes=>nodes.map(node=>({text:node.textContent,title:node.title})));
  assert(times.length>0,'Position timestamps visible');
  const expectedTitle=new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit',hour12:false}).format(new Date(time));
  for(const item of times)assert.equal(semantic(item.title),semantic(expectedTitle+' BRT'),'Displayed timestamp is the balance position, never connection origin/receipt');
  assert.doesNotMatch(times.map(t=>t.title).join(' '),/09:43|09:00/,'Connection/receipt time cannot replace position time');
 };
 const capture=async name=>{
  const target=frame.locator('#v274ReceivedPosition');await target.scrollIntoViewIfNeeded();await settle();
  const dimensions=await frame.evaluate(()=>{
   const box=node=>{const r=node.getBoundingClientRect();return {x:r.x,y:r.y,width:r.width,height:r.height,right:r.right,bottom:r.bottom};};
   const position=document.querySelector('#v274ReceivedPosition'),freshness=document.querySelector('.v225-balance-freshness');
   return {viewport:{width:innerWidth,height:innerHeight},page:{client:document.documentElement.clientWidth,scroll:document.documentElement.scrollWidth},position:{...box(position),client:position.clientWidth,scroll:position.scrollWidth},freshness:freshness?{...box(freshness),client:freshness.clientWidth,scroll:freshness.scrollWidth}:null};
  });
  assert(dimensions.page.scroll<=dimensions.page.client+2,'Page horizontal overflow '+JSON.stringify(dimensions));
  for(const element of [dimensions.position,dimensions.freshness].filter(Boolean)){
   assert(element.x>=-1&&element.right<=viewport.width+1,'Balance/freshness fit the viewport horizontally');assert(element.scroll<=element.client+2,'Balance/freshness text is not clipped');assert(element.height>0);
  }
  assert(dimensions.position.y>=-1&&dimensions.position.bottom<=viewport.height+1,'Balance feedback is fully visible after scrolling');
  geometry.push({name,...dimensions});await page.screenshot({path:path.join(qa,label+'-'+name+'.png')});
 };
 const assertStack=async()=>{
  await Promise.all(assetAudits);
  assert.deepEqual(await page.locator('script[src]').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('src'))),expected.outer,'All outer scripts preserve release DOM order');
  assert.deepEqual(await frame.locator('script[src]').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('src'))),[...expected.inner,...expected.dynamic],'Static inner scripts and genuine dynamically injected read model preserve release DOM order');
  for(const [sources,documentURL] of [[expected.outer,appURL.href],[[...expected.inner,...expected.dynamic],frame.url()]])for(const source of sources){const url=new URL(source,documentURL);assert(scriptResponses.has(url.pathname+url.search),'Real release script response missing: '+source);}
  assert.deepEqual(badAssets,[]);assert.deepEqual(blocked,[],'No unmatched external access');assert.deepEqual(routeErrors,[]);assert.deepEqual(errors,[],'No uncaught errors from complete real stack');
 };
 const startCollection=async label=>{
  refreshPlans.push({hold:label});await frame.evaluate(()=>{window.__CASH_TEST__.promises.collection=window.__LTS_V225.refresh();});await barriers.seen(label);
 };
 const pendingPoll=async()=>{await frame.waitForFunction(()=>window.__CASH_TEST__.polls.size===1&&window.__LTS_V225.syncing&&!window.__LTS_V225.statusRead);};
 try{
  await page.goto(appURL.href,{waitUntil:'domcontentloaded'});
  const shell=await page.waitForSelector('#shell');frame=await shell.contentFrame();assert(frame,'Real release iframe available');
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V178_REVIEW?.refreshCashOnly&&window.__LTS_V225?.installed&&window.__LTS_V228_FLOW?.installed&&window.__LTS_V227_TRANSPORT?.installed&&window.__LTS_V183_FLOW_PERIOD_STATE?.installed&&window.__LTS_V257_UI_STATE?.installed&&window.__LTS_FLOW_OVERDUE_PROJECTIONS?.installed);
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());
  await frame.waitForFunction(()=>!window.__LTS_V225.statusRead&&!window.__LTS_V225.loading&&!window.__LTS_V226?.loading);
  await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});
  await frame.locator('#flowFrom').fill(DAY);await frame.locator('#flowTo').fill('2026-10-18');await frame.locator('#flowApply').click();
  await frame.waitForFunction(()=>!FLOWLOADING&&FLOWFROM==='2026-10-16'&&FLOWTO==='2026-10-18'&&document.querySelector('#d-2026-10-16'));
  await frame.locator('[data-a="Itaú"]').click();await frame.locator('.exp[data-d="'+DAY+'"]').first().click();
  await cashReady();await assertStack();await assertFreshness();await capture('initial-position');
  // Observe actual applied cash values without altering data, slots or renderers.
  await frame.evaluate(()=>{
   const observe=()=>{const s=window.__LTS_V178_STATE?.cash;if(s?.status==='ready')window.__CASH_TEST__.applied.push({value:s.data?.cash,date:s.date,session:s.sessionGeneration});};
   const observer=new MutationObserver(observe);observer.observe(document.getElementById('app'),{childList:true,subtree:true});observe();
  });
  const selected=await selection();
  mark('render-and-interaction-do-not-load');await renderStorm();await clickStorm();await assertSelection(selected);

  mark('pending-collection-cash-bypasses-old-forecast');
  const pendingFlowHash=await flowHash();
  await startCollection('collection-before-old-forecast');
  forecastPlans.push({hold:'old-forecast'});
  await frame.evaluate(()=>{const state=window.__CASH_TEST__;state.oldForecastDone=false;state.promises.dashboard=window.__LTS_V178_REVIEW.refresh().finally(()=>{state.oldForecastDone=true;});});
  await barriers.seen('old-forecast');
  flags.marker=2234.5;cashPlans.push({hold:'pending-cash',body:cashBody(flags.marker,flags.day,flags.positionTime)});
  const pendingCounts={cash:count(CASH),heavy:heavyCount()};
  await barriers.release('collection-before-old-forecast');await barriers.seen('pending-cash');await pendingPoll();
  assert.equal(await frame.evaluate(()=>window.__CASH_TEST__.oldForecastDone),false,'Old full dashboard is genuinely unresolved');
  assert.equal(count(CASH),pendingCounts.cash+1,'One replacement cash read while old forecast remains blocked');
  assert.equal((await current()).status,'loading');await settle();
  assert.match(await frame.locator('#v274ReceivedPosition').innerText(),/Atualizando a posição recebida/);
  assert.doesNotMatch(await frame.locator('#v274ReceivedPosition').innerText(),/R\$/,'No superseded amount presented during the new read');
  await capture('cash-loading-old-forecast-held');
  await barriers.release('pending-cash');await cashReady();
  assert.equal(await frame.evaluate(()=>window.__CASH_TEST__.oldForecastDone),false,'Cash restored before old forecast resolves');
  assert.equal(await frame.evaluate(()=>window.__LTS_V225.syncing),true,'Collection is still pending when cash restores');
  assert.equal(heavyCount(),pendingCounts.heavy,'Cash recovery does not launch heavy dashboard readers');
  assert.equal(await flowHash(),pendingFlowHash,'Cash-only recovery preserves every financial field/event in the already displayed Flow payload');
  assert(semantic(await frame.locator('#v274ReceivedPosition').innerText()).includes(money(flags.marker-500)));
  await assertFreshness();await assertSelection(selected);await renderStorm();await capture('cash-restored-collection-pending');
  await barriers.release('old-forecast');await frame.evaluate(()=>window.__CASH_TEST__.promises.dashboard);await settle();
  const beforeTimeout=count(CASH);await frame.evaluate(()=>{window.__CASH_TEST_NOW__='2026-10-16T13:02:00Z';});
  await frame.evaluate(()=>window.__CASH_TEST__.runPoll());
  assert.equal(await frame.evaluate(()=>window.__LTS_V225.syncing),false);assert.match(await frame.evaluate(()=>window.__LTS_V225.message),/a coleta ainda não foi confirmada/);
  await cashReady();await renderStorm();assert.equal(count(CASH),beforeTimeout,'Collection timeout does not discard a valid replacement or loop');

  mark('confirmed-collection-refreshes-visible-flow');
  flags.requestedAt='2026-10-16T13:01:50Z';flags.collection='pending';
  await startCollection('confirmed-request');await barriers.release('confirmed-request');await pendingPoll();await waitCash();
  // A known request completes pending first; confirmation is a later genuine poll.
  const confirmedBefore={cash:count(CASH),heavy:heavyCount(),invalidations:await frame.evaluate(()=>window.__CASH_TEST__.invalidations)};
  flags.collection='confirmed';flags.marker=3234.5;flags.positionTime='2026-10-16T12:27:00Z';
  cashPlans.push({hold:'confirmed-cash',body:cashBody(flags.marker,flags.day,flags.positionTime)});
  await frame.evaluate(()=>window.__CASH_TEST__.runPoll());await barriers.seen('confirmed-cash');
  assert.equal(await frame.evaluate(()=>window.__CASH_TEST__.invalidations),confirmedBefore.invalidations+1,'refreshScreens owns exactly one notified invalidation');
  await barriers.release('confirmed-cash');await cashReady();
  await frame.waitForFunction(()=>!FLOWLOADING&&!window.__LTS_V226.loading);await settle();
  assert.equal(count(CASH),confirmedBefore.cash+1,'Confirmed refresh has one current cash read');
  const heavyNew=calls.filter(call=>HEAVY.test(call.name)).slice(confirmedBefore.heavy);
  assert(heavyNew.every(call=>call.name===FLOW&&call.args.p_from===selected.from&&call.args.p_to===selected.to),'Confirmed Flow refresh only reloads the visible Flow range, never full forecast/wealth/awards/expenses');
  assert.equal(await frame.evaluate(()=>window.__LTS_V225.syncing),false);await assertFreshness();await assertSelection(selected);await capture('collection-confirmed');

  mark('collection-bank-failure-does-not-orphan-cash');
  flags.receivedAt=flags.requestedAt;flags.requestedAt='2026-10-16T13:01:55Z';flags.collection='pending';
  await startCollection('failed-bank-request');flags.collection='failed';flags.marker=4234.5;
  await barriers.release('failed-bank-request');await frame.evaluate(()=>window.__CASH_TEST__.promises.collection);await cashReady();
  assert.equal(await frame.evaluate(()=>window.__LTS_V225.syncing),false);assert.match(await frame.evaluate(()=>window.__LTS_V225.error),/um banco falhou/);await renderStorm();
  flags.collection='pending';

  mark('coalesced-invalidations-discard-old-response');
  const coalescedFlowHash=await flowHash();
  const oldMarker=9334.5,newMarker=5234.5;
  cashPlans.push({hold:'stale-cash',body:cashBody(oldMarker,flags.day,flags.positionTime)});await invalidate();await barriers.seen('stale-cash');
  const staleCount=count(CASH);cashPlans.push({hold:'latest-cash',body:cashBody(newMarker,flags.day,flags.positionTime)});
  await invalidate(2);await renderStorm();assert.equal(count(CASH),staleCount,'Latest generation waits for the single old cash RPC, never parallel cash calls');
  await barriers.release('stale-cash');await barriers.seen('latest-cash');
  assert.equal(count(CASH),staleCount+1,'Two synchronous invalidations produce exactly one latest replacement');
  assert.equal((await current()).value,null,'Superseded cash response is not applied even briefly');
  await barriers.release('latest-cash');flags.marker=newMarker;await cashReady();await renderStorm();await assertSelection(selected);
  assert.equal(await flowHash(),coalescedFlowHash,'Coalesced cash recovery does not rewrite Flow financial facts');
  assert(!await frame.evaluate(value=>window.__CASH_TEST__.applied.some(row=>row.value===value),oldMarker),'Observed DOM commits never contain superseded cash');

  mark('draft-period-survives-cash-rerender');
  await frame.locator('#flowFrom').fill('2026-10-17');await frame.locator('#flowTo').fill('2026-10-19');
  const draft=await selection();flags.marker=5334.5;await invalidate();await cashReady();await assertSelection(draft);
  await frame.locator('#flowFrom').fill(selected.from);await frame.locator('#flowTo').fill(selected.to);await settle();

  mark('invalid-payloads-stay-unavailable');
  for(const invalid of [
   {name:'missing-cash',edit:body=>{body.cash=null;}},
   {name:'sum-mismatch',edit:body=>{body.available_total+=1;}},
   {name:'wrong-day',edit:body=>{body.as_of='2026-10-15';}},
   {name:'wrong-version',edit:body=>{body.version='unsupported-synthetic-version';}}
  ]){
   const body=cashBody(6334.5,flags.day,flags.positionTime);invalid.edit(body);cashPlans.push({body});const before=count(CASH);
   await invalidate();await waitCash();await settle();assert.equal(count(CASH),before+1,invalid.name+' reads once');
   assert.equal((await current()).complete,false,invalid.name+' rejected');
   assert.match(await frame.locator('#v274ReceivedPosition').innerText(),/indisponível/i);assert.doesNotMatch(await frame.locator('#v274ReceivedPosition').innerText(),/R\$/);
   assert(await frame.locator('.v225-freshness-bank time').evaluateAll(nodes=>nodes.every(node=>node.textContent==='indisponível')),'Invalid cash hides position dates');
   await renderStorm();
  }
  await capture('invalid-payload');

  mark('missing-position-time-never-borrows-connection');
  const noPosition=cashBody(6434.5,flags.day,flags.positionTime);delete noPosition.bank_positions;
  cashPlans.push({body:noPosition});await invalidate();await cashReady(6434.5);
  assert(await frame.locator('.v225-freshness-bank time').evaluateAll(nodes=>nodes.every(node=>node.textContent==='indisponível')),'Missing metadata stays unavailable despite valid connection time');
  assert.match(await frame.locator('.v225-balance-freshness').innerText(),/Conexão:/);await capture('position-time-unavailable');

  mark('terminal-error-has-no-render-retry');
  cashPlans.push({status:400,body:{code:'22023',message:'SYNTHETIC_PRIVATE_DETAIL_INVALID_ARGUMENT'}});let before=count(CASH);
  await invalidate();await waitCash();await settle();assert.equal(count(CASH),before+1);assert.equal((await current()).status,'error');
  await renderStorm();await clickStorm();assert.equal(count(CASH),before+1,'Terminal HTTP 400 does not retry');
  assert.match(await frame.locator('#v274ReceivedPosition').innerText(),/indisponível/i);assert.doesNotMatch(await frame.locator('#v274ReceivedPosition').innerText(),/SYNTHETIC_PRIVATE_DETAIL|R\$/);await capture('terminal-error');

  mark('transient-retry-budget-is-two-attempts');
  cashPlans.push({status:503,body:{code:'57014',message:'synthetic retry one'}},{status:503,body:{code:'57014',message:'synthetic retry exhausted'}});before=count(CASH);
  await invalidate();await waitCash();await settle();assert.equal(count(CASH),before+2,'One initial attempt plus exactly one transient retry');assert.equal((await current()).status,'error');
  await renderStorm();await clickStorm();assert.equal(count(CASH),before+2,'Exhausted generation cannot restart from renders/interactions');
  flags.marker=7234.5;const revision=await frame.evaluate(()=>window.__LTS_V227_TRANSPORT.revision);
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.refreshCashOnly(true));await cashReady();
  assert.equal(count(CASH),before+3,'Explicit retry admits one new attempt');assert.equal(await frame.evaluate(()=>window.__LTS_V227_TRANSPORT.revision),revision,'Cash-only API never invalidates itself');

  mark('logout-login-rejects-old-cash');
  const sessionOld=9434.5;cashPlans.push({hold:'session-old-cash',body:cashBody(sessionOld,flags.day,flags.positionTime)});await invalidate();await barriers.seen('session-old-cash');
  await frame.locator('#logout').click();await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='signed-out');
  assert.equal((await current()).value,null);assert.equal(await frame.evaluate(()=>D),null,'Logout clears authenticated product');
  flags.marker=8234.5;await frame.locator('#email').fill('viewer@example.invalid');await frame.locator('#password').fill('synthetic-fixture-only');await frame.locator('#signin').click();
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready');
  await barriers.release('session-old-cash');await cashReady();
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});
  await frame.locator('#flowFrom').fill(DAY);await frame.locator('#flowTo').fill('2026-10-18');await frame.locator('#flowApply').click();await frame.waitForFunction(()=>!FLOWLOADING);
  assert(!await frame.evaluate(value=>window.__CASH_TEST__.applied.some(row=>row.value===value),sessionOld),'Old authenticated response never becomes visible in the new session');
  assert.equal((await current()).sessionGeneration,await frame.evaluate(()=>BOOT.generation),'Ready cash belongs to current boot generation');await capture('logout-login-recovered');

  mark('old-global-refresh-intent-cannot-restart-after-login');
  forecastPlans.push({hold:'old-session-forecast'});
  await frame.evaluate(()=>{window.__CASH_TEST__.promises.oldSessionDashboard=window.__LTS_V178_REVIEW.refresh();});
  await barriers.seen('old-session-forecast');
  // This second explicit refresh is genuinely queued behind the unresolved old dashboard.
  await frame.evaluate(()=>{window.__CASH_TEST__.promises.oldSessionQueued=window.__LTS_V178_REVIEW.refresh();});
  await waitCash();await cashReady();
  await frame.locator('#logout').click();await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='signed-out');
  flags.marker=8284.5;await frame.locator('#email').fill('viewer@example.invalid');await frame.locator('#password').fill('synthetic-fixture-only');await frame.locator('#signin').click();
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready');await cashReady();
  assert.equal(await frame.evaluate(()=>V),'Fluxo Diário','New session stays on Flow while old full-dashboard intent is pending');
  const newSessionRange=await selection(),afterLoginHeavy=heavyCount();
  await barriers.release('old-session-forecast');
  await frame.evaluate(()=>Promise.all([window.__CASH_TEST__.promises.oldSessionDashboard,window.__CASH_TEST__.promises.oldSessionQueued]));
  await frame.waitForFunction(()=>!FLOWLOADING);await settle();
  const resumedHeavy=calls.filter(call=>HEAVY.test(call.name)).slice(afterLoginHeavy);
  assert(resumedHeavy.every(call=>call.name===FLOW&&call.args.p_from===newSessionRange.from&&call.args.p_to===newSessionRange.to),'Zero heavy reads from old global intents after new login; only the new session visible Flow request may resume');
  assert.deepEqual(await frame.evaluate(()=>['forecast','wealth','dashboardReport'].map(key=>({key,status:window.__LTS_V178_STATE[key].status,data:window.__LTS_V178_STATE[key].data??null}))),
   ['forecast','wealth','dashboardReport'].map(key=>({key,status:'idle',data:null})),'Old global flight cannot repopulate or restart heavy slots in a newer session');
  await cashReady();await capture('old-global-intent-rejected');

  mark('brt-day-rollover-rejects-old-cash');
  const dayOld=9534.5;cashPlans.push({hold:'previous-day-cash',body:cashBody(dayOld,flags.day,flags.positionTime)});await invalidate();await barriers.seen('previous-day-cash');
  flags.day='2026-10-17';flags.marker=8334.5;flags.positionTime='2026-10-17T03:00:00Z';
  cashPlans.push({hold:'next-day-cash',body:cashBody(flags.marker,flags.day,flags.positionTime)});
  await frame.evaluate(()=>{window.__CASH_TEST_NOW__='2026-10-17T03:01:00Z';render();});await settle();
  assert.equal((await current()).value,null,'BRT midnight immediately hides old-day cash');
  await barriers.release('previous-day-cash');await barriers.seen('next-day-cash');assert.equal((await current()).value,null);
  await barriers.release('next-day-cash');await cashReady();assert.equal((await current()).date,'2026-10-17');
  assert(!await frame.evaluate(value=>window.__CASH_TEST__.applied.some(row=>row.value===value),dayOld),'Previous-day response never applies');
  await frame.evaluate(()=>{V='Dashboard';renderNav();render();});await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());
  await frame.waitForFunction(()=>['cash','forecast','wealth','awards','dashboardReport'].every(key=>window.__LTS_V178_STATE[key].status==='ready'));
  assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.date),'2026-10-17','Cash-only day change does not suppress global Dashboard day rollover');
  assert.equal((await current()).date,'2026-10-17');await frame.evaluate(()=>{V='Fluxo Diário';renderNav();render();});await cashReady();await assertFreshness();await capture('next-brt-day');

  await assertStack();assert.equal(cashPlans.length,0,'Every scripted cash response consumed');assert.equal(refreshPlans.length,0);assert.equal(forecastPlans.length,0);assert.equal(barriers.pending.size,0,'Every held request explicitly released');
  return {label,viewport,pass:true,phases,geometry,calls,real_outer_scripts:expected.outer.length,real_inner_scripts:expected.inner.length,real_dynamic_scripts:expected.dynamic.length,financial_data:'entirely synthetic',cash_reads:count(CASH),auth_sessions:authSerial};
 }catch(error){
  await page.screenshot({path:path.join(qa,label+'-failure.png'),fullPage:true}).catch(()=>{});
  error.cashEvidence={label,phase,errors,blocked,badAssets,routeErrors,calls,pending_barriers:[...barriers.pending.keys()],cash:await current().catch(()=>null),selection:await selection().catch(()=>null)};throw error;
 }finally{await barriers.close();await context.close();}
}
(async()=>{
 if(process.argv.includes('--static-check')){console.log(JSON.stringify({status:'static-check-passed',release,root,outer_scripts:expected.outer.length,inner_scripts:expected.inner.length,dynamic_scripts:expected.dynamic.length,hashes,browser_started:false},null,2));return;}
 fs.mkdirSync(qa,{recursive:true});const result={status:'running',release,hashes,network:'Loopback release assets; all external HTTP intercepted and fulfilled with synthetic data',timer_override:'Only named V225 poll at 5000ms; callback body and 90s decision unchanged',results:[]};
 let browser;
 try{
  const {chromium}=require('playwright');browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{})});
  for(const [label,viewport] of [['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}],['narrow',{width:320,height:760}]])result.results.push(await run(browser,viewport,label));
  result.status='passed';console.log(JSON.stringify(result,null,2));
 }catch(error){result.status='failed';result.error=String(error.stack||error);result.evidence=error.cashEvidence||null;console.error(JSON.stringify(result,null,2));process.exitCode=1;}
 finally{fs.writeFileSync(path.join(qa,'cash-recovery-fullstack-result.json'),JSON.stringify(result,null,2)+'\n');if(browser)await browser.close();}
})();
