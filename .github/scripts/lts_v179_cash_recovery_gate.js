'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V179_PORT||8788);
const session={access_token:'fixture-access-token',refresh_token:'fixture-refresh-token',expires_at:4102444800,user:{id:'fixture-user'}};
const readers=new Set(['lts_browser_cash_today_v178','lts_browser_expenses_v178','lts_browser_wealth_detail_v4','lts_browser_awards_v178','lts_browser_flow_v12']);
const cash=date=>({version:'cash-today-v178',status:'complete',as_of:date,cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:50,day:{date,Consolidado:{bank_balance:600},fix86_columns:{saldo_final:600,entradas:0,saidas:0,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:1000,saldo_apos_rsu:1200,saldo_apos_fgts:1250}}});
const report=(from,to)=>({version:'expense-executive-v20-v178-review',as_of:to,period:{from,to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},management_groups:[{name:'Teste',total:10,rows:1,subgroups:[]}],monthly_detail:[],coverage_disclosure:{total:0,rows:0}});
const flow=(from,to)=>({ok:true,flow:{historical:{days:[],events:[]},current_future:{days:[cash(from).day,cash(to).day],events:[]}}});
const semantic=value=>String(value||'').replace(/\s+/g,' ').trim();
(async()=>{
 const browser=await chromium.launch({headless:true});let context,page,frame;
 const calls=[];let mode='recover',cashCalls=0;
 try{
  context=await browser.newContext({viewport:{width:1440,height:1000}});
  await context.addInitScript(()=>{const Native=Date;class Fixed extends Native{constructor(...args){super(...(args.length?args:['2026-09-21T13:00:00Z']))}static now(){return Native.parse('2026-09-21T13:00:00Z')}}window.Date=Fixed});
  await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
  page=await context.newPage();page.setDefaultTimeout(30000);const pageErrors=[];page.on('pageerror',error=>pageErrors.push(String(error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
   const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}
   calls.push(name);let status=200,data={ok:true,rows:[],items:[]};
   if(name==='token')data=session;
   else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
   else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
   else if(name==='lts_browser_cash_today_v178'){
    cashCalls++;
    if(mode==='recover'&&cashCalls===1){status=500;data={code:'57014',message:'canceling statement due to statement timeout'}}
    else if(mode==='fail'){status=503;data={code:'57014',message:'temporary cash timeout'}}
    else if(mode==='incomplete')data={...cash('2026-09-21'),cash:null,available_total:null};
    else data=cash('2026-09-21');
   }
   else if(name==='lts_browser_expenses_v178'||/^lts_browser_expense_executive_v/.test(name))data=report(args.p_from,args.p_to);
   else if(name==='lts_browser_wealth_detail_v4'||/^lts_browser_wealth_detail_v/.test(name))data={...wealth,pensions:{positions:[],total_gross_brl:0}};
   else if(name==='lts_browser_awards_v178')data={as_of:'2026-09-21',vested_shares:200,brokerage_cash:0,brokerage_available:200,events:[]};
   else if(/^lts_browser_flow_v/.test(name))data=flow(args.p_from,args.p_to);
   else if(/expense_context/.test(name))data={contexts:[],natures:[],summary:{}};
   await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  });
  await page.goto(BASE+'/wip35-v179-candidate.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<200;i++){frame=page.frames().find(candidate=>candidate.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>window.__LTS_V178_REVIEW?.version==='v179-cash-recovery').catch(()=>false))break;await page.waitForTimeout(100)}
  assert(frame,'V179 frame available');
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.forecast.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready');
  const ordered=calls.filter(name=>readers.has(name));
  assert.equal(cashCalls,2,'one automatic retry recovers the first transient cash failure');
  const value=label=>frame.locator('.v168-dashboard .v168-kpi').filter({has:frame.locator('span').filter({hasText:new RegExp('^'+label+'$')})}).locator('strong');
  assert.match(semantic(await value('Total disponível hoje').innerText()),/1\.200,00/,'complete recovered cash is rendered');
  const diagnostic=await frame.locator('html').getAttribute('data-lts-v179-cash-diagnostic');
  assert(diagnostic&&!diagnostic.includes(session.access_token)&&!diagnostic.includes(session.refresh_token)&&!diagnostic.includes('Authorization'),'diagnostic is redacted');
  const parsed=JSON.parse(diagnostic);assert.deepEqual(parsed.history.slice(0,2).map(item=>item.outcome),['http_error','success']);
  assert.deepEqual(parsed.concurrent.slice(0,2).map(item=>item.name),['lts_browser_cash_today_v178','lts_browser_cash_today_v178'],'the V179 layer finishes cash and its bounded retry before heavy readers');
  assert(await frame.evaluate(()=>window.__LTS_V178_REVIEW.retryableCashFailure({status:'error',outcome:'client_timeout'})),'authenticated client timeout is retryable');

  mode='incomplete';let before=cashCalls;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.cash.data?.cash===null);
  assert.equal(cashCalls-before,1,'an incomplete payload is never retried as though it were transient');
  assert.equal(semantic(await value('Total disponível hoje').innerText()),'—','an incomplete payload never becomes a partial total');

  mode='fail';before=cashCalls;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='error');
  assert.equal(cashCalls-before,2,'a persistent transient failure is bounded to one retry');
  assert.equal(semantic(await value('Total disponível hoje').innerText()),'—','a persistent failure never substitutes zero or stale cash');

  mode='success';before=cashCalls;await frame.evaluate(()=>window.__LTS_V178_REVIEW.refresh());
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready');
  assert.equal(cashCalls-before,1,'manual recovery remains available after the bounded failure');
  assert.match(semantic(await value('Total disponível hoje').innerText()),/1\.200,00/);
  assert.deepEqual(pageErrors,[],'no uncaught page errors');
  const result={pass:true,version:'v179-cash-recovery',cash_calls:cashCalls,initial_order:ordered.slice(0,6),automatic_retry:true,incomplete_payload_blocked:true,persistent_failure_bounded:true,manual_recovery:true};
  fs.writeFileSync('v179-cash-recovery-result.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
 }catch(error){fs.writeFileSync('v179-cash-recovery-result.json',JSON.stringify({pass:false,error:String(error.stack||error),calls},null,2));console.error(error);process.exitCode=1}
 finally{await context?.close();await browser.close()}
})();
