'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const {product,cockpit,wealth}=require('./lts_v165_executive_ux_gate.js');
const BASE='http://127.0.0.1:'+(process.env.LTS_V179_PORT||8788);
const session={access_token:'fixture-access-token',refresh_token:'fixture-refresh-token',expires_at:4102444800,user:{id:'fixture-user'}};
const v242=['v242','v244','v245','v257','v258','v259'].includes(process.env.LTS_RELEASE);
const cashReader=v242?'lts_browser_cash_today_v242':'lts_browser_cash_today_v178';
const wealthReader=v242?'lts_browser_wealth_detail_v242':'lts_browser_wealth_detail_v4';
const modern=['v240','v241','v242','v244','v245','v257','v258','v259'].includes(process.env.LTS_RELEASE);
const flowReader=modern?'lts_browser_flow_'+(['v244','v245','v257','v258','v259'].includes(process.env.LTS_RELEASE)?'v242':process.env.LTS_RELEASE):'lts_browser_flow_v229';
const planningReader=modern?'lts_browser_planning_ui_contract_'+(['v244','v245','v257','v258','v259'].includes(process.env.LTS_RELEASE)?'v242':process.env.LTS_RELEASE):'lts_browser_planning_ui_contract_v1';
const readers=new Set([planningReader,cashReader,'lts_browser_expenses_v229',wealthReader,'lts_browser_awards_v178',flowReader]);
const cash=date=>({version:'cash-today-v179-current-canonical',status:'complete',as_of:date,cash:600,d0:400,brokerage_available:200,available_total:1200,fgts:50,reader_revision:'v230-independent-current-position',day:{date,position_only:true,Consolidado:{bank_balance:600},fix86_columns:{saldo_anterior:null,saldo_final:600,entradas:null,saidas:null,liq_d0_1_recurso:400,rsus_vested:200,fgts:50,saldo_apos_d0_1:1000,saldo_apos_rsu:1200,saldo_apos_fgts:1250}}});
const report=(from,to)=>({version:'expense-executive-v20-v178-review',as_of:to,period:{from,to},summary:{selected_total:10,card_total:5,account_total:5,monthly_average:10,rows:1,pending_identification:0},management_groups:[{name:'Teste',total:10,rows:1,subgroups:[]}],monthly_detail:[],coverage_disclosure:{total:0,rows:0}});
const forecastDay=date=>({...cash(date).day,position_only:false,fix86_columns:{...cash(date).day.fix86_columns,saldo_anterior:600,entradas:0,saidas:0}});
const flow=(from,to)=>({ok:true,flow:{historical:{days:[],events:[]},current_future:{days:[forecastDay(from),forecastDay(to)],events:[]}}});
const semantic=value=>String(value||'').replace(/\s+/g,' ').trim();
(async()=>{
 const browser=await chromium.launch({headless:true});let context,page,frame;
 let activeReports=0,maxActiveReports=0,finishedReports=0;
 const calls=[];let mode='recover',cashCalls=0,syncMode='fail',statusPolls=0,refreshCalls=0;
 try{
  context=await browser.newContext({viewport:{width:1440,height:1000}});
  await context.addInitScript(()=>{const Native=Date;class Fixed extends Native{constructor(...args){super(...(args.length?args:['2026-09-21T13:00:00Z']))}static now(){return Native.parse('2026-09-21T13:00:00Z')}}window.Date=Fixed});
  await context.addInitScript(s=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s)),session);
  page=await context.newPage();page.setDefaultTimeout(30000);const pageErrors=[];page.on('pageerror',error=>pageErrors.push(String(error)));
  await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
   const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}
   const tracked=cashCalls>0&&readers.has(name)&&name!==cashReader;
   if(tracked){activeReports++;maxActiveReports=Math.max(maxActiveReports,activeReports);await new Promise(resolve=>setTimeout(resolve,60));}
   calls.push(name);let status=200,data={ok:true,rows:[],items:[]};
   if(name==='token')data=session;
   else if(name==='lts_browser_product_v1')data={ok:true,mvp:product()};
   else if(name==='lts_browser_dashboard_cockpit_v1')data=cockpit;
   else if(name===planningReader)data={version:'planning-ui-contract-v2',period_to:'2027-12-31',fgts_covers_horizon:true,fgts_first_negative:null,labels:{d01:'Cobertura D0 de teste',rsu:'Cobertura RSU de teste',fgts:'Com FGTS, sem ruptura até 31/12/2027'}};
   else if(name==='lts_browser_open_finance_pending_v225')data={version:'pending-expense-v225',transaction_count:syncMode==='complete'?0:4,net_expense:syncMode==='complete'?0:37,rows:syncMode==='complete'?[]:[{key:'1',institution_code:'341',date:'2026-09-21',description:'Compra provisória A',expense:25},{key:'2',institution_code:'237',date:'2026-09-21',description:'Compra provisória B',expense:12},{key:'3',institution_code:'336',date:'2026-09-21',description:'Compra provisória C',expense:10},{key:'4',institution_code:'336',date:'2026-09-21',description:'Crédito provisório C',expense:-10}]};
   else if(name==='lts_browser_open_finance_status_v1'){statusPolls++;data={connections:['341','237','336'].map((code,i)=>({institution_code:code,status:'connected',last_success_at:syncMode==='complete'||(syncMode==='partial'&&i<2)?'2026-09-21T13:00:01Z':'2026-09-21T11:00:00Z'}))};}
   else if(name==='lts_browser_open_finance_refresh_v1') {assert.equal(activeReports,0,'bank reconciliation waits for active initial reports');assert(finishedReports>=(v242?4:5),'initial reports finish before bank reconciliation');refreshCalls++;if(syncMode==='fail'){status=503;data={message:'test refresh failure'};}else data={ok:true,requested_at:'2026-09-21T13:00:00Z'};}
   else if(name===cashReader){
    cashCalls++;
    if(mode==='recover'&&cashCalls===1){status=500;data={code:'57014',message:'canceling statement due to statement timeout'}}
    else if(mode==='fail'){status=503;data={code:'57014',message:'temporary cash timeout'}}
    else if(mode==='incomplete')data={...cash('2026-09-21'),cash:null,available_total:null};
    else data={...cash('2026-09-21'),cash:syncMode==='complete'?500:600,available_total:syncMode==='complete'?1100:1200};
   }
   else if(name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_v/.test(name))data=report(args.p_from,args.p_to);
   else if(name===wealthReader||/^lts_browser_wealth_detail_v/.test(name))data={...wealth,wealth:{...wealth.wealth,liquidity:{...wealth.wealth.liquidity,bank_cash:syncMode==='complete'?500:600,d0:400}},pensions:{positions:[],total_gross_brl:0}};
   else if(name==='lts_browser_awards_v178')data={as_of:'2026-09-21',vested_shares:200,brokerage_cash:0,brokerage_available:200,events:[]};
   else if(/^lts_browser_flow_v/.test(name))data=flow(args.p_from,args.p_to);
   else if(/expense_context/.test(name))data={contexts:[],natures:[],summary:{}};
   if(tracked){activeReports--;finishedReports++;}
   await route.fulfill({status,contentType:'application/json',body:JSON.stringify(data)});
  });
  await page.goto(BASE+'/releases/'+(process.env.LTS_RELEASE||'v225-1')+'/app.html',{waitUntil:'domcontentloaded'});
  for(let i=0;i<200;i++){frame=page.frames().find(candidate=>candidate.url().includes('/index.html'));if(frame&&await frame.evaluate(()=>window.__LTS_V178_REVIEW?.version==='v179-cash-recovery').catch(()=>false))break;await page.waitForTimeout(100)}
  assert(frame,'V179 frame available');
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready'&&window.__LTS_V178_STATE.forecast.status==='ready'&&window.__LTS_V178_STATE.dashboardReport.status==='ready');
  assert.equal(maxActiveReports,1,'cold Dashboard reports must run sequentially');
  const ordered=calls.filter(name=>readers.has(name));
  assert.equal(ordered.filter(name=>name===flowReader).length,1,'one complete Dashboard projection range runs at startup');
  assert.equal(ordered.filter(name=>name===wealthReader).length,1,'wealth has one startup owner');
  assert.equal(ordered.filter(name=>name==='lts_browser_expenses_v229').length,1,'expense report has one startup owner');
  assert.equal(cashCalls,2,'one automatic retry recovers the first transient cash failure');
  const value=label=>frame.locator('.v168-dashboard .v168-kpi').filter({has:frame.locator('span').filter({hasText:new RegExp('^'+label+'$')})}).locator('strong');
  assert.match(semantic(await value('Total disponível hoje').innerText()),/1\.200,00/,'complete recovered cash is rendered');
  assert(await frame.evaluate(()=>window.__LTS_V178_STATE.cash.data.day.position_only),'current position renders without manufacturing daily movements');
  assert.equal(await frame.evaluate(()=>window.__LTS_V178_STATE.cash.data.day.fix86_columns.entradas),null);
  const diagnostic=await frame.locator('html').getAttribute('data-lts-v179-cash-diagnostic');
  assert(diagnostic&&!diagnostic.includes(session.access_token)&&!diagnostic.includes(session.refresh_token)&&!diagnostic.includes('Authorization'),'diagnostic is redacted');
  const parsed=JSON.parse(diagnostic);assert.deepEqual(parsed.history.slice(0,2).map(item=>item.outcome),['http_error','success']);
  assert.deepEqual(parsed.concurrent.slice(0,2).map(item=>item.name),[cashReader,cashReader],'the V179 layer finishes cash and its bounded retry before heavy readers');
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
  await page.screenshot({path:'qa/v229-dashboard-desktop.png',fullPage:true});
  assert.deepEqual(pageErrors,[],'no uncaught page errors');
  const routes=await frame.locator('.nav button').evaluateAll(nodes=>nodes.map(n=>n.dataset.v));assert.deepEqual(routes,['Dashboard','Fluxo Diário','Despesas','Patrimônio','Atualizações']);
  assert((await frame.locator('.v168-dashboard').innerText()).includes(v242?'Cobertura até 31/12/2027':'Com FGTS, sem ruptura até 31/12/2027'));
  assert(await frame.locator('[data-v225-refresh]').isVisible());
  console.log('Navigation contract and current Planning presentation PASS');
  await frame.waitForFunction(()=>window.__LTS_V225.pending.data?.transaction_count===4);
  await frame.locator('[data-pending-detail]').click();
  assert.equal(await frame.locator('#v225-pending-dialog tbody tr').count(),4,'provisional expenses and credits are visible');
  assert((await frame.locator('#v225-pending-dialog').innerText()).includes('37,00'),'credits are deducted from provisional consumption');
  await frame.locator('#v225-pending-dialog [data-close]').click();
  await frame.locator('.nav [data-v="Despesas"]').click();
  assert.equal(await frame.locator('.v225-provisional').count(),0,'expense report does not show processing banner');
  await frame.locator('.nav [data-v="Atualizações"]').click();
  await frame.waitForSelector('.v225-provisional [data-pending-detail]');
  assert.match(await frame.locator('.v225-provisional').innerText(),/Compras aguardando confirmação/);
  await frame.locator('.v225-provisional [data-pending-detail]').click();
  assert.equal(await frame.locator('#v225-pending-dialog tbody tr').count(),4,'pending items remain accessible in Updates');
  await frame.locator('#v225-pending-dialog [data-close]').click();
  await frame.locator('.nav [data-v="Dashboard"]').click();
  assert.equal(refreshCalls,1,'opening authenticated app automatically requests bank refresh once');
  assert((await frame.locator('.v225-sync').innerText()).includes('Não foi possível solicitar'),'failed refresh is visible');
  await frame.locator('.nav [data-v="Patrimônio"]').click();await frame.waitForSelector('.v172-wealth-overview');
  const bankLine=()=>frame.locator('.v172-value-list>div').filter({hasText:'Contas + aplicações D0'}).locator('b');
  assert.match(semantic(await bankLine().innerText()),/1\.000,00/,'wealth is opened with the prior bank position');
  await frame.locator('.nav [data-v="Dashboard"]').click();
  syncMode='partial';await frame.locator('[data-v225-refresh]').click();
  await frame.waitForFunction(()=>window.__LTS_V225.syncing&&window.__LTS_V225.status?.connections.length===3);
  assert(!(await frame.locator('.v225-sync').innerText()).includes('Bancos atualizados'),'two of three banks cannot claim completion');
  syncMode='complete';before=cashCalls;
  await frame.waitForFunction(()=>window.__LTS_V225.message==='Bancos atualizados');
  await frame.waitForFunction(()=>window.__LTS_V178_STATE.cash.status==='ready');
  assert(cashCalls>before,'confirmed bank refresh reloads current cash');
  assert.match(semantic(await value('Total disponível hoje').innerText()),/1\.100,00/,'Dashboard receives the newer bank position');
  await frame.locator('.nav [data-v="Patrimônio"]').click();
  await frame.waitForFunction(()=>window.__LTS_V168_STATE.wealth.data?.wealth?.liquidity?.bank_cash===500);
  assert.match(semantic(await bankLine().innerText()),/900,00/,'previously opened Wealth reloads after bank confirmation');
  await frame.locator('.nav [data-v="Dashboard"]').click();
  assert.equal(refreshCalls,2,'manual refresh sent exactly once without parallel duplicates');
  await frame.locator('.v225-bankstatus summary').click();
  assert.equal(await frame.locator('.v225-bank').count(),3,'last update is shown for each bank');
  assert(statusPolls>=2,'success waits for provider confirmation');
  await frame.waitForFunction(()=>window.__LTS_V225.pending.data?.transaction_count===0);
  assert(await frame.locator('.v225-provisional').isHidden(),'provider reconciliation removes provisional effects without creating another obligation');
  assert.deepEqual(pageErrors,[],'no uncaught errors during bank refresh');
  await page.screenshot({path:'qa/v229-dashboard-desktop.png',fullPage:true});
  const result={pass:true,version:'v227-1',max_initial_active_reports:maxActiveReports,bank_waits_for_initial_reads:true,wealth_refresh:true,open_refresh:true,manual_refresh:true,three_bank_confirmation:true,pending_visible_reversible:true,cash_calls:cashCalls,initial_order:ordered.slice(0,6),automatic_retry:true,incomplete_payload_blocked:true,persistent_failure_bounded:true,manual_recovery:true};
  fs.writeFileSync('qa/v229-startup-result.json',JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
 }catch(error){fs.writeFileSync('qa/v229-startup-result.json',JSON.stringify({pass:false,error:String(error.stack||error),calls},null,2));console.error(error);process.exitCode=1}
 finally{await context?.close();await browser.close()}
})();
