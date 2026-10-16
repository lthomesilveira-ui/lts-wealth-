'use strict';
// Full ordered-stack, synthetic-only regression for the expense date editor.
// Run against loopback repository: LTS_RELEASE=v280 node this-file.cjs.
// The same controlled V175 completion MUST erase the V279 draft and preserve the candidate draft.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {EventEmitter}=require('node:events');
const release=process.env.LTS_RELEASE,baseline=process.env.LTS_EXPENSE_BASELINE||'v279';
assert(release&&/^[a-zA-Z0-9_-]+$/.test(release));assert(/^[a-zA-Z0-9_-]+$/.test(baseline));
const BASE=process.env.LTS_EXPENSE_BASE||'http://127.0.0.1:8788',baseURL=new URL(BASE);
assert.equal(baseURL.protocol,'http:');assert(['127.0.0.1','localhost','[::1]'].includes(baseURL.hostname),'Loopback only');
assert(!baseURL.username&&!baseURL.password&&!baseURL.search&&!baseURL.hash);
const qa=path.resolve(process.env.LTS_EXPENSE_QA_DIR||'qa/expense-draft');
const NOW='2026-10-16T13:00:00Z',DAY='2026-10-16',ORIGIN='https://tadhkamnwtsbdozwkyut.supabase.co';
const MAIN=/^lts_browser_(?:expenses_|expense_executive_)/;
const sources=html=>[...html.matchAll(/<script\b[^>]*\bsrc=["']([^"']+)["'][^>]*>/g)].map(m=>m[1]);
const session={access_token:'synthetic-expense-token-0',refresh_token:'synthetic-expense-refresh-0',token_type:'bearer',expires_in:3600,expires_at:4102444800,user:{id:'synthetic-expense-viewer',email:'viewer@example.invalid'}};
const semantic=text=>String(text||'').replace(/\s+/g,' ').trim();
function descriptor(id,rootOverride,pathOverride){
 const root=path.resolve(rootOverride||path.join('releases',id)),appURL=new URL(pathOverride||'/releases/'+id+'/app.html',baseURL);assert.equal(appURL.origin,baseURL.origin);
 const app=fs.readFileSync(path.join(root,'app.html'),'utf8'),index=fs.readFileSync(path.join(root,'index.html'),'utf8');
 const model=fs.readFileSync(path.join(root,'lts-dashboard-executive-v1.js'),'utf8').match(/const MODEL_SRC=['"]([^'"]+)['"]/);assert(model);
 const expected={outer:sources(app),inner:sources(index),dynamic:[model[1]]},hashes={};
 for(const file of ['app.html','index.html',...new Set([...expected.outer,...expected.inner,...expected.dynamic].map(src=>src.split('?')[0]))]){
  assert(!/^(?:https?:)?\/\//.test(file));const filename=path.resolve(root,file);assert(filename.startsWith(root+path.sep));hashes[file]=crypto.createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
 }
 return{id,root,appURL:appURL.href,expected,hashes};
}
const descriptors={baseline:descriptor(baseline,process.env.LTS_EXPENSE_BASELINE_ROOT,process.env.LTS_EXPENSE_BASELINE_PATH),candidate:descriptor(release,process.env.LTS_EXPENSE_RELEASE_ROOT,process.env.LTS_EXPENSE_APP_PATH)};
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

async function run(browser,build,viewport,label,isBaseline){
 const context=await browser.newContext({viewport,serviceWorkers:'block',reducedMotion:'reduce'});
 await context.addInitScript(({session,now})=>{
  const NativeDate=Date;class TestDate extends NativeDate{constructor(...args){super(...(args.length?args:[now]));}static now(){return NativeDate.parse(now);}}window.Date=TestDate;
  if(!sessionStorage.getItem('expense-fixture-seeded')){sessionStorage.setItem('expense-fixture-seeded','yes');localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));}
  sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
 },{session,now:NOW});
 const page=await context.newPage();page.setDefaultTimeout(15000);page.setDefaultNavigationTimeout(20000);
 const calls=[],blocked=[],errors=[],routeErrors=[],assetErrors=[],assetAudits=[],scriptResponses=new Set(),plans=[],barriers=new Barriers(),checkpoints=[],geometry=[];
 let frame,phase='boot',authSerial=0,marker=0;
 const mark=name=>{phase=name;checkpoints.push({phase,calls:calls.length});};
 page.on('pageerror',error=>errors.push(String(error.stack||error)));
 page.on('response',response=>{
  const url=new URL(response.url());if(url.origin!==baseURL.origin||!url.pathname.endsWith('.js'))return;
  if(response.status()!==200){assetErrors.push({path:url.pathname,status:response.status()});return;}
  scriptResponses.add(url.pathname+url.search);
  assetAudits.push(response.body().then(body=>{const file=path.basename(url.pathname);assert(build.hashes[file],'Unexpected release script '+file);assert.equal(crypto.createHash('sha256').update(body).digest('hex'),build.hashes[file],'Served script '+file+' matches candidate bytes');}).catch(error=>assetErrors.push(String(error.message||error))));
 });
 await context.route('**/*',async route=>{
  try{
   const req=route.request(),url=new URL(req.url());if(url.origin===baseURL.origin&&['GET','HEAD'].includes(req.method()))return route.continue();
   if(url.origin!==ORIGIN){blocked.push({origin:url.origin,path:url.pathname});return route.abort('blockedbyclient');}
   const name=url.pathname.split('/').pop();let args={};try{args=JSON.parse(req.postData()||'{}');}catch{}
   const authSession=Number((req.headers().authorization||'').match(/synthetic-expense-token-(\d+)$/)?.[1]??-1);
   const entry={name,args: name==='token'?{grant:url.searchParams.get('grant_type')}:args,auth_session:authSession,phase,status:null,marker:null};calls.push(entry);
   const fulfill=async(status,body)=>{entry.status=status;return route.fulfill({status,contentType:'application/json',body:JSON.stringify(body)});};
   if(url.pathname==='/auth/v1/token')return fulfill(200,{...session,access_token:'synthetic-expense-token-'+(++authSerial),refresh_token:'synthetic-expense-refresh-'+authSerial});
   if(url.pathname==='/auth/v1/logout')return fulfill(200,{});
   if(!url.pathname.startsWith('/rest/v1/rpc/')||req.method()!=='POST'||/_decision_|_save_|_apply_|_delete_|_confirm_|_mutate_|_classify_|_classification_|_refresh_|_update_|_create_|_upload_/.test(name)){
    blocked.push({origin:url.origin,path:url.pathname,method:req.method()});return route.abort('blockedbyclient');
   }
   let data=name==='lts_browser_product_v1'?{ok:true,mvp:fixture.product(authSerial+1)}:fixture.response(name,args),plan;
   if(MAIN.test(name)){
    if(plans.length&&(plans[0].session===undefined||plans[0].session===authSession)&&(!plans[0].range||(plans[0].range.from===args.p_from&&plans[0].range.to===args.p_to)))plan=plans.shift();
    data={...data,__draftFixtureMarker:plan?.marker??++marker};entry.marker=data.__draftFixtureMarker;
    if(plan?.total!==undefined)data={...data,summary:{...data.summary,selected_total:plan.total,card_total:plan.total,monthly_average:plan.total},management_groups:data.management_groups.map(row=>({...row,total:plan.total})),monthly_detail:data.monthly_detail.map(row=>({...row,total:plan.total}))};
   }
   if(plan?.hold)return barriers.hold(plan.hold,fulfill,data,plan.status??200);
   return fulfill(plan?.status??200,data);
  }catch(error){routeErrors.push(String(error.stack||error));await route.abort('failed').catch(()=>{});}
 });
 const count=()=>calls.filter(call=>MAIN.test(call.name)).length;
 const periodCalls=()=>calls.filter(call=>Object.hasOwn(call.args,'p_from')||Object.hasOwn(call.args,'p_to'));
 const matching=range=>calls.filter(call=>MAIN.test(call.name)&&call.args.p_from===range.from&&call.args.p_to===range.to).length;
 const assertNoDraftRPC=(draft,committedRange,start=0)=>{
  const exposed=calls.slice(start).filter(call=>
   (draft.from&&draft.from!==committedRange.from&&call.args.p_from===draft.from)||
   (draft.to&&draft.to!==committedRange.to&&call.args.p_to===draft.to));
  assert.deepEqual(exposed,[],'No RPC, including monthly/card/context readers, receives an unapplied draft date');
 };
 const settle=()=>frame.evaluate(async()=>{await Promise.resolve();await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));});
 const nav=name=>viewport.width<=520?frame.locator('#dx1MobileNav [data-mobile-route="'+name+'"]'):frame.locator('.nav [data-v="'+name+'"]');
 const inputs=()=>frame.evaluate(()=>({from:document.getElementById('v168ExpenseFrom')?.value??null,to:document.getElementById('v168ExpenseTo')?.value??null}));
 const applied=()=>frame.evaluate(()=>{const s=window.__LTS_V168_STATE.expense;return {key:s.key,from:s.customFrom,to:s.customTo};});
 const snapshot=()=>frame.evaluate(()=>window.__EXPENSE_TEST__.snapshot());
 const reportReady=async(range)=>{
  await frame.waitForFunction(range=>{const a=window.__LTS_V168_STATE.expense,b=window.__LTS_V175_STATE.expense;return !a.loading&&!b.loading&&a.data?.period?.from===range.from&&a.data?.period?.to===range.to&&b.data?.period?.from===range.from&&b.data?.period?.to===range.to;},range);await settle();
 };
 const invalidateCache=()=>frame.evaluate(()=>window.__LTS_V227_TRANSPORT.invalidate(false));
 const preset=key=>frame.locator('[data-v168-exp-range="'+key+'"]');
 const editor=()=>frame.locator('.v168-custom-range');
 const write=async range=>{await frame.locator('#v168ExpenseFrom').fill(range.from);await frame.locator('#v168ExpenseTo').fill(range.to);};
 const assertDraft=async range=>assert.deepEqual(await inputs(),range,'Entered date draft survives the real reader completion');
 const capture=async name=>{
  await editor().scrollIntoViewIfNeeded();await settle();
  const details=await editor().evaluate(element=>{
   const box=node=>{const r=node.getBoundingClientRect();return {left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height,scroll:node.scrollWidth,client:node.clientWidth};};
   return{viewport:{width:innerWidth,height:innerHeight},page:{scroll:document.documentElement.scrollWidth,client:document.documentElement.clientWidth},editor:box(element),controls:[...element.querySelectorAll('input,button,[role="alert"]')].map(node=>({id:node.id,...box(node)}))};
  });
  assert(details.page.scroll<=details.page.client+2,'Expense page has no horizontal overflow');
  for(const item of [details.editor,...details.controls]){assert(item.left>=-1&&item.right<=viewport.width+1,'Expense editor/control fits viewport '+JSON.stringify(item));assert(item.scroll<=item.client+2,'Expense control text does not clip '+JSON.stringify(item));assert(item.height>0);}
  geometry.push({name,...details});await page.screenshot({path:path.join(qa,label+'-'+name+'.png')});
 };
 const assertStack=async()=>{
  await Promise.all(assetAudits);
  assert.deepEqual(await page.locator('script[src]').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('src'))),build.expected.outer);
  assert.deepEqual(await frame.locator('script[src]').evaluateAll(nodes=>nodes.map(node=>node.getAttribute('src'))),[...build.expected.inner,...build.expected.dynamic]);
  for(const [files,url] of [[build.expected.outer,build.appURL],[[...build.expected.inner,...build.expected.dynamic],frame.url()]])for(const file of files){const target=new URL(file,url);assert(scriptResponses.has(target.pathname+target.search),'Real script loaded: '+file);}
  assert.deepEqual(assetErrors,[]);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);assert.deepEqual(routeErrors,[]);
 };
 const ranges={ytd:{from:'2026-01-01',to:DAY},'6m':{from:'2026-05-01',to:DAY},'12m':{from:'2025-11-01',to:DAY}};
 const startHeldPreset=async(key,hold,options={})=>{
  assert.notEqual((await applied()).key,key,'Barrier starts with an effective preset change');
  await invalidateCache();plans.push({hold,range:ranges[key],...options});await preset(key).click();await barriers.seen(hold);
  const request=calls.find(call=>MAIN.test(call.name)&&call.status===null&&call.args.p_from===ranges[key].from&&call.args.p_to===ranges[key].to);assert(request,'Preset read is genuinely unresolved');
  return{committed:await applied(),range:ranges[key],count:count(),marker:request.marker};
 };
 const openEditor=async()=>{const before=count(),beforePeriod=periodCalls().length,old=await applied();await preset('custom').click();await editor().waitFor({state:'visible'});await settle();if(!isBaseline){assert.equal(count(),before,'Opening Custom does not query');assert.equal(periodCalls().length,beforePeriod,'Opening Custom starts no additional period-based RPC');assert.deepEqual(await applied(),old,'Opening Custom does not commit a new period');}return old;};
 const realCompletion=async(hold,range)=>{await barriers.release(hold);await reportReady(range);};
 const expectedErrors={invalid:'Informe um período válido.',history:'O histórico de despesas começa em 10/10/2013. O período escolhido foi preservado.',future:'Despesas realizadas estão disponíveis até 16/10/2026. Para datas futuras, consulte o Fluxo Diário. O período escolhido foi preservado.'};
 const assertError=async(expected=expectedErrors.invalid)=>{const alert=editor().locator('[data-v280-expense-draft-error][role="alert"]');await alert.waitFor({state:'visible'});assert.equal(semantic(await alert.innerText()),expected,'Editor preserves the specific validation guidance');};
 try{
  await page.goto(build.appURL,{waitUntil:'domcontentloaded'});const shell=await page.waitForSelector('#shell');frame=await shell.contentFrame();assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V175_EXPENSE_AUDIT?.installed&&window.__LTS_V178_REVIEW?.installed&&window.__LTS_V225?.installed&&window.__LTS_V257_UI_STATE?.installed&&window.__LTS_FLOW_OVERDUE_PROJECTIONS?.installed);
  await frame.evaluate(()=>window.__LTS_V178_REVIEW.ready());await frame.waitForFunction(()=>!window.__LTS_V225.statusRead&&!window.__LTS_V225.loading&&!window.__LTS_V226.loading);
  await nav('Despesas').click();await reportReady(ranges.ytd);
  // Observation only: original production render function, handlers and readers remain intact.
  await frame.evaluate(()=>{
   const snapshot=()=>{const a=window.__LTS_V168_STATE.expense,b=window.__LTS_V175_STATE.expense;return {view:V,boot:BOOT.generation,inputFrom:document.getElementById('v168ExpenseFrom')?.value??null,inputTo:document.getElementById('v168ExpenseTo')?.value??null,focused:document.activeElement?.id,applied:{key:a.key,from:a.customFrom,to:a.customTo},v168:{loading:a.loading,error:a.error,period:a.data?.period,marker:a.data?.__draftFixtureMarker},v175:{loading:b.loading,error:b.error,key:b.key,token:b.token,period:b.data?.period,marker:b.data?.__draftFixtureMarker}};};
   const test=window.__EXPENSE_TEST__={snapshot,events:[],phase:'boot'};test.bodies=[];const nativeJSON=Response.prototype.json;Response.prototype.json=function(){const stack=new Error('expense-response-consumed').stack;return nativeJSON.call(this).then(data=>{if(data?.__draftFixtureMarker)test.bodies.push({marker:data.__draftFixtureMarker,stack,boot:BOOT.generation});return data;});};
   test.record=(kind,extra={})=>{test.events.push({kind,at:performance.now(),phase:test.phase,...extra,snapshot:snapshot()});};
   for(const type of ['input','change'])document.addEventListener(type,event=>{if(event.target?.matches?.('#v168ExpenseFrom,#v168ExpenseTo'))test.record(type,{target:event.target.id});},true);
   document.addEventListener('click',event=>{if(event.target?.closest?.('#v168ExpenseApply,[data-v168-exp-range]'))test.record('click-before-handler');},true);
   const original=render;render=function(){test.record('before-render',{stack:new Error('reader-render').stack});const result=original.apply(this,arguments);test.record('after-render');return result;};
  });
  await assertStack();

  mark('real-v175-completion-between-input-and-apply');
  const held=await startHeldPreset('6m','initial-expense-response');await openEditor();
  const draft={from:'2026-08-07',to:'2026-09-08'},saved=await applied(),reads=count(),draftCallStart=calls.length;
  await write(draft);await assertDraft(draft);
  await frame.evaluate(()=>{const test=window.__EXPENSE_TEST__;test.beforeRelease=test.events.length;test.inputNode=document.getElementById('v168ExpenseTo');});
  await frame.locator('#v168ExpenseTo').focus();const before=await snapshot();
  await realCompletion('initial-expense-response',held.range);
  const after=await snapshot();
  const callback=await frame.evaluate(()=>window.__EXPENSE_TEST__.events.slice(window.__EXPENSE_TEST__.beforeRelease).filter(event=>event.kind==='before-render'&&/ensureExpense/.test(event.stack||'')));
  assert(callback.length>0,'The held real expense reader invokes the repaint between input and Apply');
  if(isBaseline){
   assert.notDeepEqual(await inputs(),draft,'V279 control reproduces destructive input reset');assert.deepEqual(await inputs(),held.range,'Baseline inputs revert to saved applied range');
   assert.equal(matching(draft),0,'Baseline draft was never applied');await capture('baseline-draft-lost');await assertStack();
   return {build:build.id,label,viewport,baseline_reproduced:true,before,after,callback,geometry,calls};
  }
  await assertDraft(draft);assert.deepEqual(await applied(),saved,'Input/change did not alter applied state');assert.equal(count(),reads,'Input/change and completion cannot query the draft');
  assertNoDraftRPC(draft,held.range,draftCallStart);
  assert.equal(await frame.evaluate(()=>document.getElementById('v168ExpenseTo')===window.__EXPENSE_TEST__.inputNode),true,'Same-screen asynchronous repaint preserves native date input node');
  assert.equal(await frame.locator('#v168ExpenseTo').evaluate(node=>document.activeElement===node),true,'Focused date editor remains focused after asynchronous repaint');
  await capture('draft-survives-real-response');
  await frame.locator('#v168ExpenseApply').click();await reportReady(draft);assert.deepEqual(await applied(),{key:'custom',from:draft.from,to:draft.to});assert.equal(matching(draft),1,'A valid Apply admits exactly one canonical expense read');
  await assertDraft(draft);await capture('valid-applied');

  mark('empty-partial-and-invalid-drafts');
  for(const [name,invalid] of [
   ['empty-from',{from:'',to:'2026-09-10'}],['empty-to',{from:'2026-08-08',to:''}],['both-empty',{from:'',to:''}],
   ['inverted',{from:'2026-09-10',to:'2026-08-01'}],['future',{from:'2026-10-01',to:'2026-11-01'}],['before-history',{from:'2013-01-01',to:'2013-02-01'}]
  ]){
   const key=(await applied()).key==='6m'?'12m':'6m',label='invalid-'+name;
   const pending=await startHeldPreset(key,label);await openEditor();const original=await applied(),beforeCount=count(),start=calls.length;
   await write(invalid);await realCompletion(label,pending.range);await assertDraft(invalid);assert.deepEqual(await applied(),original);assert.equal(count(),beforeCount);
   const beforePeriod=periodCalls().length;
   await frame.locator('#v168ExpenseApply').click();await settle();await assertError(name==='future'?expectedErrors.future:name==='before-history'?expectedErrors.history:expectedErrors.invalid);await assertDraft(invalid);
   assert.deepEqual(await applied(),original,'Invalid Apply leaves the applied period untouched: '+name);assert.equal(count(),beforeCount,'Invalid Apply issues zero expense queries: '+name);
   assert.equal(periodCalls().length,beforePeriod,'Invalid Apply issues zero period-based queries: '+name);assertNoDraftRPC(invalid,pending.range,start);
   await capture(label);
  }

  mark('native-partial-date-segment-survives-repaint');
  const nativeKey=(await applied()).key==='6m'?'12m':'6m',nativeHeld=await startHeldPreset(nativeKey,'native-partial');await openEditor();
  await write({from:'2026-08-07',to:'2026-09-08'});const nativeInput=frame.locator('#v168ExpenseFrom');await nativeInput.focus();await nativeInput.press('Delete');
  const nativeBefore=await nativeInput.evaluate(node=>{window.__EXPENSE_TEST__.partialNode=node;return{value:node.value,badInput:node.validity.badInput};});
  assert.equal(nativeBefore.badInput,true,'The browser has a genuinely incomplete native date segment');
  const nativeCommitted=await applied(),nativeCount=count();await realCompletion('native-partial',nativeHeld.range);
  assert.deepEqual(await nativeInput.evaluate(node=>({value:node.value,badInput:node.validity.badInput})),nativeBefore,'Native partial date is not normalized or replaced');
  assert.equal(await nativeInput.evaluate(node=>node===window.__EXPENSE_TEST__.partialNode&&document.activeElement===node),true,'Native partial edit retains node and focus');
  await frame.locator('#v168ExpenseApply').click();await settle();await assertError();assert.deepEqual(await applied(),nativeCommitted);assert.equal(count(),nativeCount);
  await capture('native-partial-segment');

  mark('tabs-and-navigation-preserve-unapplied-draft');
  const navigationDraft={from:'2026-07-03',to:'2026-07-21'};await write(navigationDraft);const navigationApplied=await applied(),navigationCount=count(),navigationStart=calls.length;
  await frame.locator('[data-v168-exp-tab="categories"]').click();await settle();await assertDraft(navigationDraft);assert.deepEqual(await applied(),navigationApplied);assert.equal(count(),navigationCount);
  await nav('Fluxo Diário').click();await nav('Despesas').click();await editor().waitFor({state:'visible'});await settle();await assertDraft(navigationDraft);assert.deepEqual(await applied(),navigationApplied);assert.equal(count(),navigationCount,'Leaving and returning restores editor without reapplying its draft');
  assertNoDraftRPC(navigationDraft,ranges[navigationApplied.key],navigationStart);
  await capture('draft-after-navigation');

  mark('different-preset-discards-draft');
  const discardKey=(await applied()).key==='6m'?'12m':'6m';await preset(discardKey).click();await reportReady(ranges[discardKey]);assert(await editor().isHidden(),'Selecting a different preset closes the editor');
  const discardCount=count();await openEditor();await assertDraft(ranges[discardKey]);assert.equal(count(),discardCount,'Reopening editor only reflects current applied preset');

  mark('active-preset-and-repeated-nav-bindings');
  // renderNav is the genuine existing navigation binding entrypoint. Repeated
  // calls leave the same editor DOM in place and must not accumulate V175 wrappers.
  const bindingsApplied=await applied(),bindingsCount=periodCalls().length;
  await frame.evaluate(()=>{for(let i=0;i<20;i++)renderNav();});await settle();
  await preset(discardKey).click();await settle();assert.equal(periodCalls().length,bindingsCount,'Selecting the already applied preset admits no period RPC after repeated bindings');
  assert.deepEqual(await applied(),bindingsApplied);await openEditor();
  const bindingsDraft={from:'2026-02-03',to:'2026-02-18'};await write(bindingsDraft);
  await frame.evaluate(()=>{for(let i=0;i<20;i++)renderNav();});await settle();await assertDraft(bindingsDraft);
  const bindingBefore=matching(bindingsDraft);await frame.locator('#v168ExpenseApply').click();await reportReady(bindingsDraft);
  assert.equal(matching(bindingsDraft),bindingBefore+1,'One valid Apply still admits exactly one read after repeated renderNav bindings');

  mark('explicit-report-retry-uses-applied-period-with-unsubmitted-draft');
  const retryKey=discardKey,failedRead=await startHeldPreset(retryKey,'failed-expense-period',{status:503});
  await barriers.release('failed-expense-period',{message:'Falha sintética do relatório.'});
  await frame.waitForFunction(()=>{const a=window.__LTS_V168_STATE.expense,b=window.__LTS_V175_STATE.expense;return !a.loading&&!b.loading&&a.error&&b.error;});await settle();
  await frame.locator('[data-v168-exp-tab="categories"]').click();await settle();
  await openEditor();const retryDraft={from:'2026-08-11',to:'2026-08-29'},retryApplied=await applied(),retryBefore=count(),retryStart=calls.length;
  await write(retryDraft);await settle();assert.equal(count(),retryBefore,'Editing a draft does not auto-retry the failed applied report');
  const retry=frame.locator('[data-v183-expense-retry]');await retry.waitFor({state:'visible'});await retry.click();
  await frame.waitForFunction(range=>{const s=window.__LTS_V175_STATE.expense;return !s.loading&&!s.error&&s.data?.period?.from===range.from&&s.data?.period?.to===range.to;},failedRead.range);await settle();
  assert.equal(count(),retryBefore+1,'Explicit report retry admits exactly one canonical read');
  assert.deepEqual(await applied(),retryApplied,'Retry does not commit editor draft');await assertDraft(retryDraft);assertNoDraftRPC(retryDraft,failedRead.range,retryStart);
  assert.deepEqual(calls.slice(retryStart).filter(call=>MAIN.test(call.name)).map(call=>({from:call.args.p_from,to:call.args.p_to})),[failedRead.range],'Retry queries only the applied range');
  await capture('explicit-retry-preserves-draft');

  mark('stale-reader-cannot-restore-prior-draft-or-report');
  const oldKey=discardKey==='6m'?'12m':'6m',newKey=discardKey;
  const oldRead=await startHeldPreset(oldKey,'stale-period');await openEditor();await write({from:'2026-06-01',to:'2026-06-13'});
  await invalidateCache();plans.push({hold:'latest-period',range:ranges[newKey]});await preset(newKey).click();await openEditor();
  const latestDraft={from:'2026-04-02',to:'2026-04-18'};await write(latestDraft);const latestApplied=await applied();
  await barriers.release('stale-period');await barriers.seen('latest-period');await assertDraft(latestDraft);assert.deepEqual(await applied(),latestApplied);
  assert.notEqual((await snapshot()).v175.marker,oldRead.marker,'Superseded reader cannot become the selected report');
  await barriers.release('latest-period');await reportReady(ranges[newKey]);await assertDraft(latestDraft);assert.deepEqual(await applied(),latestApplied);await capture('stale-reader-rejected');

  for(const mode of ['success','error']){
   mark('logout-login-isolates-report-and-draft-old-'+mode);
   const logoutKey=(await applied()).key==='6m'?'12m':'6m',oldSession=authSerial,nextSession=oldSession+1,oldLabel='old-session-'+mode,newLabel='new-session-'+mode;
   const oldTotal=mode==='success'?717171.25:717172.25,newTotal=mode==='success'?828281.75:828282.75;
   const logoutRead=await startHeldPreset(logoutKey,oldLabel,{session:oldSession,total:oldTotal});
   await frame.waitForFunction(()=>window.__LTS_V168_STATE.expense.loading&&window.__LTS_V175_STATE.expense.loading);
   await openEditor();const priorSessionDraft={from:mode==='success'?'2026-03-04':'2026-03-05',to:mode==='success'?'2026-03-19':'2026-03-20'};await write(priorSessionDraft);
   await frame.evaluate(()=>{const t=window.__EXPENSE_TEST__;t.oldSessionNode=document.getElementById('v168ExpenseFrom');t.oldBoot=BOOT.generation;t.oldTokens=[window.__LTS_V168_STATE.expense.token,window.__LTS_V175_STATE.expense.token];});
   await frame.locator('#logout').click();await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='signed-out');assert.equal(await frame.locator('#v168ExpenseFrom').count(),0);
   plans.push({hold:newLabel,range:logoutRead.range,session:nextSession,total:newTotal});
   await frame.locator('#email').fill('viewer@example.invalid');await frame.locator('#password').fill('synthetic-fixture-only');await frame.locator('#signin').click();await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready');
   if(await frame.evaluate(()=>V!=='Despesas'))await nav('Despesas').click();
   // The new reader is admitted normally while the old response still holds
   // the real transport's heavy slot. No application state is edited by the test.
   await frame.waitForFunction(()=>{const t=window.__EXPENSE_TEST__,a=window.__LTS_V168_STATE.expense,b=window.__LTS_V175_STATE.expense;return BOOT.generation>t.oldBoot&&a.loading&&b.loading&&a.token>t.oldTokens[0]&&b.token>t.oldTokens[1];});
   await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&!window.__LTS_V225.statusRead&&!window.__LTS_V225.loading);await settle();
   assert.equal(await editor().count(),0,'New session does not reopen previous session draft editor');
   const storeBefore=await frame.evaluate(()=>{const t=window.__EXPENSE_TEST__;t.newSessionSlots=[window.__LTS_V168_STATE.expense,window.__LTS_V175_STATE.expense];t.sessionEventStart=t.events.length;t.sessionBodyStart=t.bodies.length;return JSON.stringify(t.newSessionSlots);});
   if(mode==='error')await barriers.release(oldLabel,{message:'Erro sintético da sessão anterior.',__draftFixtureMarker:logoutRead.marker},503);else await barriers.release(oldLabel);
   // Both real consumers parsed the old response before the assertion. This
   // is an explicit completion boundary, not a guessed delay or a forced render.
   await frame.waitForFunction(marker=>{const t=window.__EXPENSE_TEST__;return t.bodies.slice(t.sessionBodyStart).filter(body=>body.marker===marker).length>=2;},logoutRead.marker);
   await barriers.seen(newLabel);await settle();
   const isolated=await frame.evaluate(()=>{const t=window.__EXPENSE_TEST__,slots=[window.__LTS_V168_STATE.expense,window.__LTS_V175_STATE.expense];return{sameIdentity:slots.every((slot,i)=>slot===t.newSessionSlots[i]),store:JSON.stringify(slots),renders:t.events.slice(t.sessionEventStart).filter(event=>event.kind==='before-render'&&/ensureExpense/.test(event.stack||'')),bodies:t.bodies.slice(t.sessionBodyStart)};});
   assert.equal(isolated.sameIdentity,true,'Old '+mode+' cannot replace new-session report slots');
   assert.equal(isolated.store,storeBefore,'Old '+mode+' cannot write data/error/loading/tokens into new-session V168/V175 report slots');
   assert.deepEqual(isolated.renders,[],'Old '+mode+' cannot repaint from its expense reader callback while the new report remains held');
   assert(!semantic(await frame.locator('.v168-expenses').innerText()).includes(semantic(new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(oldTotal))),'Old-session report value is never displayed');
   const newRequest=calls.find(call=>call.auth_session===nextSession&&MAIN.test(call.name)&&call.status===null&&call.args.p_from===logoutRead.range.from&&call.args.p_to===logoutRead.range.to);assert(newRequest,'Held replacement request belongs to the new synthetic session');
   assert.notEqual(newRequest.marker,logoutRead.marker);await barriers.release(newLabel);await reportReady(logoutRead.range);
   const ready=await snapshot();assert.equal(ready.v168.marker,newRequest.marker);assert.equal(ready.v175.marker,newRequest.marker);
   assert(semantic(await frame.locator('.v168-expenses').innerText()).includes(semantic(new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(newTotal))),'New-session report is functional and displayed');
   assert.equal(calls.filter(call=>call.auth_session===nextSession&&MAIN.test(call.name)&&call.args.p_from===logoutRead.range.from&&call.args.p_to===logoutRead.range.to).length,1,'New session uses one canonical expense read');
   await openEditor();await assertDraft(logoutRead.range);
   assert.equal(await frame.evaluate(()=>document.getElementById('v168ExpenseFrom')===window.__EXPENSE_TEST__.oldSessionNode),false,'Old native editor node cannot cross session boundary');
   assert.equal(matching(priorSessionDraft),0,'Unapplied prior-session dates were never queried');await capture('new-session-clean-'+mode);
   checkpoints.push({phase:'session-isolation-'+mode,oldSession,nextSession,oldMarker:logoutRead.marker,newMarker:newRequest.marker,storeBefore,isolated});
  }

  await assertStack();assert.equal(plans.length,0);assert.equal(barriers.pending.size,0);
  return{build:build.id,label,viewport,pass:true,baseline:false,checkpoints,geometry,calls,events:await frame.evaluate(()=>window.__EXPENSE_TEST__.events),auth_sessions:authSerial};
 }catch(error){
  await page.screenshot({path:path.join(qa,label+'-failure.png'),fullPage:true}).catch(()=>{});
  error.expenseEvidence={build:build.id,label,phase,errors,blocked,assetErrors,routeErrors,calls,pending:[...barriers.pending.keys()],snapshot:await snapshot().catch(()=>null),events:await frame?.evaluate(()=>window.__EXPENSE_TEST__?.events).catch(()=>null)};throw error;
 }finally{await barriers.close();await context.close();}
}
(async()=>{
 if(process.argv.includes('--static-check')){console.log(JSON.stringify({status:'static-check-passed',browser_started:false,descriptors},null,2));return;}
 fs.mkdirSync(qa,{recursive:true});const result={status:'running',scope:'Full real release scripts in original order; local loopback only; all financial/account fixtures synthetic',descriptors,results:[]};let browser;
 try{const {chromium}=require('playwright');browser=await chromium.launch({headless:true,...(process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{})});
  for(const [name,viewport]of[['desktop',{width:1440,height:1000}],['mobile',{width:390,height:844}],['narrow',{width:320,height:760}]]){
   result.results.push(await run(browser,descriptors.baseline,viewport,name+'-baseline',true));
   result.results.push(await run(browser,descriptors.candidate,viewport,name+'-candidate',false));
  }result.status='passed';console.log(JSON.stringify(result,null,2));
 }catch(error){result.status='failed';result.error=String(error.stack||error);result.evidence=error.expenseEvidence||null;console.error(JSON.stringify(result,null,2));process.exitCode=1;}
 finally{fs.writeFileSync(path.join(qa,'expense-draft-fullstack-result.json'),JSON.stringify(result,null,2)+'\n');if(browser)await browser.close();}
})();
