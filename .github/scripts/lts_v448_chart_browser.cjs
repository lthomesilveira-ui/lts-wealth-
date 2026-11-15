'use strict';
// Full synthetic app boot/cascade, actual checked-in chart renderer, invented rows.
// Never opens a private session or contacts an unmocked financial endpoint.
process.env.LTS_FLOW_RELEASE='v448';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium,webkit}=require('playwright');
const {setup,open}=require('./lts_v382_browser.cjs');
const fixture=require('./lts_v379_fixtures.cjs');
const release='v448',out=path.resolve('qa/v448');fs.mkdirSync(out,{recursive:true});
const startup=fs.readFileSync('releases/'+release+'/lts-v384-startup-1.js','utf8');
const renderer=startup.split('\n').find(line=>line.trim().startsWith('function expenseBarChart(rows)'));
assert(renderer,'Use the actual checked-in expenseBarChart renderer, not copied HTML');
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x);
const escape=x=>String(x??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const chart=new Function('arr','num','money','clamp','esc','return ('+renderer.trim()+');')(
 x=>Array.isArray(x)?x:[],x=>Number(x)||0,money,(x,a,b)=>Math.max(a,Math.min(b,x)),escape);
function rowsFor(count){return Array.from({length:count},(_,i)=>({label:new Intl.DateTimeFormat('pt-BR',{month:'short',year:'2-digit',timeZone:'UTC'}).format(new Date(Date.UTC(2024+Math.floor(i/12),i%12,1))),total:i===count-1?9876543210.25:i===1?0:i===2?-1234567.89:120000+i*1701.25}));}
function expected(rows){return rows.map(row=>({value:money(row.total).replace(/,\d{2}$/, ''),label:row.label}));}
async function measure(frame){return frame.locator('#chart-fixture-v448 .v168-bars').evaluate(el=>{
 const box=el.getBoundingClientRect(),bars=[...el.querySelectorAll('.v168-bar')];
 const labels=bars.flatMap(bar=>[bar.querySelector('b'),bar.querySelector('span')]);
 const rect=e=>{const r=e.getBoundingClientRect();return{x:r.x,y:r.y,left:r.left,right:r.right,top:r.top,bottom:r.bottom,width:r.width,height:r.height}};
 const values=bars.map(bar=>({value:bar.querySelector('b').textContent,label:bar.querySelector('span').textContent}));
 const overlap=labels.some((a,i)=>labels.some((b,j)=>j>i&&a.getBoundingClientRect().left<b.getBoundingClientRect().right-0.5&&a.getBoundingClientRect().right>b.getBoundingClientRect().left+0.5&&a.getBoundingClientRect().top<b.getBoundingClientRect().bottom-0.5&&a.getBoundingClientRect().bottom>b.getBoundingClientRect().top+0.5));
 return {values,overlap,verticalClipping:labels.some(e=>{const r=e.getBoundingClientRect();return r.top<box.top-1||r.bottom>box.top+el.clientHeight+1}),documentOverflow:document.documentElement.scrollWidth>innerWidth+2,
  chart:rect(el),first:rect(bars[0].querySelector('b')),last:rect(bars.at(-1).querySelector('b')),
  scrollLeft:el.scrollLeft,scrollWidth:el.scrollWidth,clientWidth:el.clientWidth,
  compact:el.classList.contains('compact'),gridFlow:getComputedStyle(el).gridAutoFlow,
  maximumHeight:Math.max(...bars.map(b=>parseFloat(b.querySelector('i').style.height))),
  fontSize:parseFloat(getComputedStyle(bars[0].querySelector('b')).fontSize)};
 });}
async function settle(frame){await frame.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));}
async function run(browser,engine,width){
 const h=await setup(browser,width,980,'2026-11-15T17:00:00Z'),label=engine+'-'+width;let frame;
 const send=(route,value)=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(value)});
 const ready={state:'ready',required:false,cached_available:true,request_version:'1',completed_version:'1',cached_refreshed_at:'2026-11-15T17:00:00Z'};
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_v1',r=>send(r,{ok:true,mvp:fixture.product(),refresh:ready}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_product_refresh_status_v415',r=>send(r,{ok:true,refresh:ready}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_budget_read_v441',r=>send(r,require('./lts_v441_fixture.cjs')()));
 try{
  frame=await open(h,release);
  await frame.locator('#nav [data-v="Despesas"]:visible,#dx1MobileNav [data-mobile-route="Despesas"]:visible').click();
  await frame.locator('.v168-expenses').waitFor({state:'visible'});
  await h.page.waitForLoadState('networkidle');
  await frame.waitForFunction(()=>window.__LTS_V175_STATE?.expense&&!window.__LTS_V175_STATE.expense.loading);
  // The original report stays present. Only a labelled synthetic test chart is
  // appended inside its real grid/card ancestor, after all actual styles loaded.
  const initialProduct=await frame.evaluate(()=>JSON.stringify(D));
  const actualSummary=await frame.locator('.v168-expenses').innerText();
  const cascade=await frame.evaluate(()=>[...document.styleSheets].map(s=>s.href||'inline'));
  assert(cascade.some(url=>url.includes('lts-v168-feedback-package.css')),'Actual chart stylesheet loaded');
  const cases=[];
  for(const count of [12,24])for(const scale of [1,1.5]){
   const rows=rowsFor(count),expectedText=expected(rows),key=label+'-'+count+'-text'+scale;
   await frame.evaluate(({html})=>{
    document.getElementById('chart-fixture-v448')?.remove();
    const fixture=document.createElement('section');fixture.id='chart-fixture-v448';fixture.className='v168-grid two';
    fixture.innerHTML='<article class="v168-card"><div class="v168-cardhead"><h2>Gráfico de teste fictício</h2></div>'+html+'</article><article class="v168-card">Comparação fictícia</article>';
    document.querySelector('.v168-expenses').append(fixture);
   },{html:chart(rows)});
   if(scale!==1)await frame.locator('#chart-fixture-v448 .v168-bar b,#chart-fixture-v448 .v168-bar span').evaluateAll((els,factor)=>els.forEach(el=>{el.style.fontSize=(parseFloat(getComputedStyle(el).fontSize)*factor)+'px'}),scale);
   // Deliberate text-only enlargement, not a claim of physical iOS Dynamic Type.
   const scroller=frame.locator('#chart-fixture-v448 .v168-bars');await scroller.scrollIntoViewIfNeeded();await settle(frame);
   const first=await measure(frame);
   assert.deepEqual(first.values,expectedText,'Renderer values/dates preserved');assert.equal(first.compact,count>18);assert.equal(first.maximumHeight,100,'Tallest bar exercises clipping');
   assert.equal(first.gridFlow,'column','Explicit one-row scroller');assert.equal(first.overlap,false,'No amount/date overlap: '+JSON.stringify(first));assert.equal(first.verticalClipping,false,'No top/bottom clipped labels: '+JSON.stringify(first));assert.equal(first.documentOverflow,false,'No page-level horizontal overflow');
   assert(first.first.left>=first.chart.left-1&&first.first.right<=first.chart.left+first.clientWidth+1,'First amount fully reachable');
   if(width<500)assert(first.scrollWidth>first.clientWidth,'Mobile chart must actually scroll');
   await h.page.screenshot({path:path.join(out,key+'-first.png')});
   await scroller.evaluate(el=>{el.scrollLeft=el.scrollWidth});await settle(frame);const last=await measure(frame);
   assert(last.last.left>=last.chart.left-1&&last.last.right<=last.chart.left+last.clientWidth+1,'Last amount fully reachable');
   assert.equal(last.overlap,false);assert.equal(last.verticalClipping,false);assert.equal(last.documentOverflow,false);assert.deepEqual(last.values,expectedText,'Scrolling changes no values');
   await h.page.screenshot({path:path.join(out,key+'-last.png')});
   await scroller.evaluate(el=>{el.scrollLeft=0});await settle(frame);const returned=await measure(frame);assert(Math.abs(returned.scrollLeft)<=1);assert.deepEqual(returned.values,expectedText);
   cases.push({count,compact:count>18,text_scale:scale,font_size:first.fontSize,scroll_width:first.scrollWidth,client_width:first.clientWidth,maximum_bar_percent:first.maximumHeight,overlap:false,vertical_clipping:false,document_overflow:false,values_and_dates_unchanged:true,first_and_last_reachable:true});
  }
  await frame.locator('#chart-fixture-v448').evaluate(el=>el.remove());
  assert.equal(await frame.locator('.v168-expenses').innerText(),actualSummary,'Original synthetic report untouched');assert.equal(await frame.evaluate(()=>JSON.stringify(D)),initialProduct);
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  const text=await frame.locator('body').innerText();assert(!/SQLSTATE|source_ref|source_fingerprint|RPC|cache state/.test(text));
  return {pass:true,engine,width,cases,full_app_cascade:true,checked_in_chart_renderer:true,synthetic_chart_in_real_report_container:true,original_report_unchanged:true,synthetic_http:true,private_session:false,physical_iphone:false,text_zoom_kind:'explicit 150% label font size, not browser zoom'};
 }catch(error){await h.page.screenshot({path:path.join(out,label+'-chart-failure.png'),fullPage:true}).catch(()=>{});fs.writeFileSync(path.join(out,label+'-chart-failure.json'),JSON.stringify({error:error.stack,errors:h.errors,writes:h.writes,reads:h.reads,body:frame?await frame.locator('body').innerText():null},null,2));throw error}
 finally{await h.ctx.close()}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[320,393,449,1366]){try{results.push(await run(browser,engine,width))}catch(error){results.push({pass:false,engine,width,error:error.stack});process.exitCode=1}fs.writeFileSync(path.join(out,'chart-browser-result.json'),JSON.stringify({pass:results.length===8&&results.every(r=>r.pass),results},null,2));console.log(JSON.stringify(results.at(-1)));}}finally{await browser.close()}}})().catch(error=>{console.error(error);process.exitCode=1});
