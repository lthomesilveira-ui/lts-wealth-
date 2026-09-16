'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const {BASE,cockpit,wealth,product,expensePayload,flow}=require('./lts_v165_executive_ux_gate.js');

const wait=milliseconds=>new Promise(resolve=>setTimeout(resolve,milliseconds));

async function dashboardFrame(page){
  for(let attempt=0;attempt<120;attempt++){
    const frame=page.frames().find(candidate=>{try{return new URL(candidate.url()).pathname.endsWith('/index.html')}catch{return false}});
    if(frame&&await frame.evaluate(()=>Boolean(window.__LTS_V167_COMPLETE_REVIEW?.installed&&document.querySelector('.v167-dashboard'))).catch(()=>false))return frame;
    await page.waitForTimeout(100);
  }
  throw new Error('V167 Dashboard did not become visible while detailed readers were pending');
}

(async()=>{
  const executablePath=process.env.LTS_CHROMIUM_EXECUTABLE||undefined;
  const browser=await chromium.launch({headless:true,...(executablePath?{executablePath}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1000}});
  const session={access_token:'fixture-token',refresh_token:'fixture-refresh',expires_at:4102444800,user:{id:'fixture-user'}};
  const errors=[],timings={};
  try{
    await context.addInitScript(fixed=>{const NativeDate=Date,fixedMs=NativeDate.parse(fixed);class FixedDate extends NativeDate{constructor(...args){super(...(args.length?args:[fixedMs]))}static now(){return fixedMs}}window.Date=FixedDate},'2030-06-15T12:00:00Z');
    await context.addInitScript(value=>localStorage.setItem('lts_supabase_session_v1',JSON.stringify(value)),session);
    const page=await context.newPage();
    page.setDefaultTimeout(18000);
    page.on('pageerror',error=>errors.push(String(error.message||error)));
    await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',async route=>{
      const request=route.request(),name=new URL(request.url()).pathname.split('/').pop();
      let args={};try{args=JSON.parse(request.postData()||'{}')}catch{}
      const started=Date.now();let body={ok:true};
      if(name==='token')body=session;
      else if(name==='lts_browser_product_v1')body={ok:true,mvp:product()};
      else if(name==='lts_browser_dashboard_cockpit_v1')body=cockpit;
      else if(name==='lts_browser_flow_v11'){
        const isLong=String(args.p_to||'')==='2031-12-31';
        if(isLong)await wait(8000);
        body={ok:true,flow:flow()};
      }
      else if(name==='lts_browser_expense_executive_v4'){await wait(2500);body=expensePayload(args.p_from||'2030-01-01',args.p_to||'2030-06-15')}
      else if(name==='lts_browser_expense_executive_v3')body=expensePayload(args.p_from||'2030-01-01',args.p_to||'2030-06-15');
      else if(name==='lts_browser_expense_context_nature_v1')body={summary:{},contexts:[],categories:[],unassigned_states:[]};
      else if(name==='lts_browser_wealth_detail_v3'){await wait(3500);body=wealth}
      else if(name==='lts_browser_wealth_detail_v2')body=wealth;
      else if(name==='lts_browser_recurring_future_gap_audit_v5'){await wait(6500);body={horizon_checks:[],items:[]}}
      else if(name==='lts_browser_open_finance_status_v1')body={status:'not_connected'};
      else if(name==='lts_browser_transactions_v2')body={ok:true,total:0,rows:[]};
      timings[name]=Math.max(timings[name]||0,Date.now()-started);
      await route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(body)});
    });
    const started=Date.now();
    await page.goto(`${BASE}/wip35-v167-candidate.html`,{waitUntil:'domcontentloaded',timeout:20000});
    const frame=await dashboardFrame(page),visibleAfterMs=Date.now()-started;
    const snapshot=await frame.evaluate(()=>({
      kpis:document.querySelectorAll('.v167-dashboard .v167-kpi').length,
      cards:document.querySelectorAll('.v167-dashboard .v167-card').length,
      chart:Boolean(document.querySelector('.v167-dashboard .v167-chart svg')),
      loading:Boolean(document.querySelector('.v167-dashboard .v167-loadstatus')),
      hasFlow:Boolean(window.__LTS_V167_STATE?.dashboard?.data?.flow),
      pending:window.__LTS_V167_STATE?.dashboard?.pending,
      text:document.querySelector('.v167-dashboard')?.innerText||''
    }));
    if(visibleAfterMs>=7000)throw new Error(`Dashboard took ${visibleAfterMs}ms to become visible`);
    if(snapshot.kpis!==5||snapshot.cards<4||!snapshot.chart)throw new Error(`Dashboard incomplete during progressive load: ${JSON.stringify(snapshot)}`);
    if(snapshot.hasFlow||!snapshot.loading||snapshot.pending<1)throw new Error(`Slow detailed Flow was not isolated from first paint: ${JSON.stringify(snapshot)}`);
    for(const phrase of ['Contas correntes hoje','Evolução projetada','O que exige decisão','Principais grupos','O que vem pela frente'])if(!snapshot.text.includes(phrase))throw new Error(`Progressive Dashboard missing ${phrase}`);
    await page.screenshot({path:'v167-progressive-dashboard.png',fullPage:true});
    await frame.waitForFunction(()=>window.__LTS_V167_STATE?.dashboard?.pending===0,{timeout:15000});
    const finalState=await frame.evaluate(()=>({pending:window.__LTS_V167_STATE.dashboard.pending,loading:window.__LTS_V167_STATE.dashboard.loading,hasFlow:Boolean(window.__LTS_V167_STATE.dashboard.data.flow),hasExpense:Boolean(window.__LTS_V167_STATE.dashboard.data.expense),hasWealth:Boolean(window.__LTS_V167_STATE.dashboard.data.wealth),hasRecurring:Boolean(window.__LTS_V167_STATE.dashboard.data.recurring)}));
    if(finalState.pending!==0||finalState.loading||!finalState.hasFlow||!finalState.hasExpense||!finalState.hasWealth||!finalState.hasRecurring)throw new Error(`Detailed readers did not complete: ${JSON.stringify(finalState)}`);
    if(errors.length)throw new Error(`Page errors: ${JSON.stringify(errors)}`);
    const output={pass:true,version:'v167-progressive-dashboard',visibleAfterMs,slowFlowDidNotBlock:true,firstPaint:snapshot,finalState,timings};
    fs.writeFileSync('v167-progressive-dashboard-result.json',JSON.stringify(output,null,2));
    console.log(JSON.stringify(output,null,2));
  }catch(error){
    const output={pass:false,error:String(error.stack||error),timings,errors};
    fs.writeFileSync('v167-progressive-dashboard-result.json',JSON.stringify(output,null,2));
    console.error(output.error);process.exitCode=1;
  }finally{await context.close();await browser.close()}
})();
