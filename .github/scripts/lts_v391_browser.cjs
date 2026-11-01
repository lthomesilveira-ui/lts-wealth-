'use strict';
// Actual invoice widget, PostgreSQL-produced invented records; no login/session or HTTP.
const fs=require('node:fs'),assert=require('node:assert/strict'),{chromium,webkit}=require('playwright');
const root='releases/v391',out='qa/v391';fs.mkdirSync(out,{recursive:true});
const native=JSON.parse(fs.readFileSync(out+'/native-output.json','utf8'));
const source=fs.readFileSync(root+'/lts-v226-card-composition.js','utf8');
const runtime=source.slice(source.indexOf('  function runtime(){'),source.indexOf('  let tries=0;'));
assert(runtime.startsWith('  function runtime(){'));
const inline=[...fs.readFileSync(root+'/index.html','utf8').matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
const css=fs.readdirSync(root).filter(n=>n.endsWith('.css')).map(n=>fs.readFileSync(root+'/'+n,'utf8')).join('\n');
async function run(browser,engine,width){
 const ctx=await browser.newContext({viewport:{width,height:900},locale:'pt-BR',serviceWorkers:'block'}),page=await ctx.newPage(),requests=[],errors=[],calls=[];
 page.on('pageerror',e=>errors.push(String(e)));await page.route('**/*',r=>{requests.push(r.request().url());return r.abort();});
 try{
  await page.setContent('<style>'+inline+'\n'+css+'</style><nav id="fixture-nav"></nav><main class="v168-dashboard"></main>');
  await page.evaluate(({runtime,native})=>{
   Object.assign(window,{D:{},N:document.getElementById('fixture-nav'),V:'Dashboard',render:()=>{},renderNav:()=>{},openCardSettlement:()=>{},LTSCategoryDisplay:{category:x=>x},__nativeCase:'valid',__fixtureCalls:[]});
   window.S={auth:{},rpc:async name=>{window.__fixtureCalls.push(name);if(name!=='lts_browser_card_cycles_v229')throw Error('Unexpected widget capability '+name);return{data:structuredClone(native[window.__nativeCase]),error:null};}};
   eval(runtime+'\nruntime();');
  },{runtime,native});
  await page.waitForFunction(()=>window.__LTS_V226?.cycles&&!window.__LTS_V226.loading);
  const panel=page.locator('.v226-upcoming');assert.match(await panel.innerText(),/Estimado · 07\/06\/2027/);
  assert.equal(await panel.locator('details[open]').count(),0);
  assert(!(await panel.innerText()).includes('faturas pessoais recebidas'),'source paragraph closed');
  const geometry=await page.evaluate(()=>({width:innerWidth,scroll:document.documentElement.scrollWidth}));assert(geometry.scroll<=geometry.width+2,JSON.stringify(geometry));
  await page.screenshot({path:out+'/'+engine+'-'+width+'-estimated-due.png'});
  await panel.locator('.lts-update-details > summary').first().click();assert.match(await panel.innerText(),/3 faturas pessoais recebidas/);await panel.locator('.lts-update-details > summary').first().click();
  await panel.locator('.v226-future > summary').click();assert.match(await panel.locator('.v226-future').innerText(),/Estimado · 06\/09\/2027/);
  await panel.locator('[data-v226-overview="future"]').click();const dialog=page.getByRole('dialog');assert.match(await dialog.innerText(),/Estimado · 06\/09\/2027/);
  await dialog.locator('[data-v226-family="c6"]').first().click();await dialog.locator('.v391-due-estimate').waitFor();assert.match(await dialog.locator('.v391-due-estimate').innerText(),/Vencimento estimado: 06\/09\/2027/);assert.match(await dialog.innerText(),/4,56/);
  const bounds=await dialog.evaluate(el=>({left:el.getBoundingClientRect().left,right:el.getBoundingClientRect().right,width:innerWidth,scroll:el.scrollWidth,client:el.clientWidth}));assert(bounds.left>=-1&&bounds.right<=bounds.width+1&&bounds.scroll<=bounds.client+2,JSON.stringify(bounds));
  await page.screenshot({path:out+'/'+engine+'-'+width+'-estimated-detail.png'});await dialog.locator('[data-v226-close]').click();
  await page.evaluate(async()=>{window.__nativeCase='invalid';await window.__LTS_V226.refresh();});
  assert.match(await panel.innerText(),/vencimento estimado do C6 precisa ser revisto/);assert.match(await panel.innerText(),/Total incompleto/);assert.match(await panel.innerText(),/Vencimento a confirmar/);
  assert.equal(await page.evaluate(()=>localStorage.length),0,'no session or identity stored');
  const calls=await page.evaluate(()=>window.__fixtureCalls);assert(calls.length>=2&&calls.every(n=>n==='lts_browser_card_cycles_v229'));assert.deepEqual(requests,[]);assert.deepEqual(errors,[]);
  return{pass:true,engine,width,postgres_projection_consumed:true,estimated_date_visible:true,source_failure_visible:true,amounts_unchanged:true,source_disclosures_closed:true,network_requests:0,session_created:false,private_http:false,physical_device:false};
 }catch(e){await page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,errors,requests,body:await page.locator('body').innerText()},null,2));throw e;}finally{await ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[320,393,1366])results.push(await run(browser,engine,width));}finally{await browser.close();}}fs.writeFileSync(out+'/browser-results.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,cases:results.length,no_sessions_or_network:true}));})().catch(e=>{console.error(e);process.exitCode=1;});
