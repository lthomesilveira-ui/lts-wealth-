'use strict';process.env.LTS_FLOW_RELEASE='v442';
const fs=require('node:fs'),assert=require('node:assert/strict');const{chromium,webkit}=require('playwright'),fixture=require('./lts_v379_fixtures.cjs'),projection=require('./lts_v412_projection_fixtures.cjs');
const old=fixture.response;fixture.response=(n,a)=>n==='lts_browser_projection_policy_v412'?projection.policy():old(n,a);
const{setup,open}=require('./lts_v382_browser.cjs'),out='qa/v442';fs.mkdirSync(out,{recursive:true});
async function run(browser,engine,width){const h=await setup(browser,width,980,'2026-11-11T15:00:00Z'),reads=[];let f;
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',route=>{const a=JSON.parse(route.request().postData());reads.push(a.p_year);const b=JSON.parse(fs.readFileSync('qa/v441/budget-fixture.json'));b.year=a.p_year;b.months.forEach(m=>{m.month=a.p_year+m.month.slice(4);if(a.p_year>2026){for(const key of['actual','pending','income_regular','income_extraordinary','income_bonus'])m[key]=0;m.started=false;m.complete=false;}});b.rows.forEach(r=>r.months.forEach(m=>{m.month=a.p_year+m.month.slice(4);if(a.p_year>2026){m.actual=0;m.pending=0;}}));return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(b)});});
 try{f=await open(h,'v442',true);await f.waitForFunction(()=>__LTS_V441_BUDGET?.state.status==='ready');assert.deepEqual(reads,[2026]);
  await f.locator('[data-mode=year]').click();await f.getByLabel('Ano do orçamento',{exact:true}).fill('2027');
  await f.waitForFunction(()=>__LTS_V441_BUDGET.state.status==='ready'&&__LTS_V441_BUDGET.state.data.year===2027);
  assert.deepEqual(reads,[2026,2027]);let text=await f.locator('#v441Budget').innerText();assert.match(text,/2027 · período ainda não iniciado/);assert.match(text,/R\$\s*18\.000,00/);assert(!text.includes('20.000,00'));
  await f.locator('[data-mode=month]').click();await f.getByLabel('Mês do orçamento',{exact:true}).fill('2027-02');
  await f.waitForFunction(()=>__LTS_V441_BUDGET.state.month==='2027-02');assert.deepEqual(reads,[2026,2027],'Same-year month selection reuses the validated year');
  text=await f.locator('#v441Budget').innerText();assert.match(text,/2027-02 · período ainda não iniciado/);assert.match(text,/R\$\s*1\.500,00/);assert(!text.includes('15.000,00'));
  await f.locator('#v441Budget').scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-future-month.png'});
  await f.getByLabel('Mês do orçamento',{exact:true}).fill('2026-11');await f.waitForFunction(()=>__LTS_V441_BUDGET.state.status==='ready'&&__LTS_V441_BUDGET.state.data.year===2026);assert.deepEqual(reads,[2026,2027,2026]);assert.match(await f.locator('#v441Budget').innerText(),/R\$\s*50,00/);
  const g=await f.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert(g.scroll<=g.width+2);assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return{pass:true,engine,width,native_input_without_blur:true,year_isolation:true,month_reuses_year:true,future_actuals_not_invented:true,flow_provision_not_added:true,synthetic:true};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});throw e;}finally{await h.ctx.close();}}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const b=await type.launch({headless:true});try{for(const w of[320,393,1366]){let r;try{r=await run(b,engine,w);}catch(e){r={pass:false,engine,width:w,error:e.stack};process.exitCode=1;}results.push(r);console.log(JSON.stringify(r));fs.writeFileSync(out+'/period-result.json',JSON.stringify({pass:results.length===6&&results.every(x=>x.pass),results},null,2));}}finally{await b.close();}}})().catch(e=>{console.error(e);process.exitCode=1;});
