'use strict';
// Actual monthly runtime, PostgreSQL-produced invented rows. No login, JWT or network.
const fs=require('node:fs'),assert=require('node:assert/strict'),{chromium,webkit}=require('playwright');
const root='releases/v393',out='qa/v393';fs.mkdirSync(out,{recursive:true});
const native=JSON.parse(fs.readFileSync(out+'/native-output.json','utf8'));
const source=fs.readFileSync(root+'/lts-v337-month-overview.js','utf8');
const runtime=source.slice(source.indexOf(' function runtime(){'),source.indexOf(' function install(){'));
const model=fs.readFileSync(root+'/lts-v337-month-model.js','utf8');
const css=fs.readdirSync(root).filter(n=>n.endsWith('.css')).map(n=>fs.readFileSync(root+'/'+n,'utf8')).join('\n');
const inline=[...fs.readFileSync(root+'/index.html','utf8').matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
async function run(browser,engine,width){
 const ctx=await browser.newContext({viewport:{width,height:980},locale:'pt-BR',serviceWorkers:'block'}),page=await ctx.newPage(),network=[],errors=[];
 page.on('pageerror',e=>errors.push(String(e)));await page.route('**/*',r=>{network.push(r.request().url());return r.abort();});
 try{
  await page.setContent('<style>'+inline+'\n'+css+'</style><nav id="fixture-nav"></nav><main class="v168-dashboard"><div class="v168-kpis"></div></main>');
  await page.addScriptTag({content:model});
  await page.evaluate(({runtime,native})=>{
   const NativeDate=Date;window.__clock=NativeDate.parse('2026-11-01T15:00:00Z');window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[window.__clock]));}static now(){return window.__clock;}};
   Object.assign(window,{D:{},BOOT:{generation:1},N:document.getElementById('fixture-nav'),V:'Dashboard',render:()=>{},__LTS_V312_CARD_REVIEW:{},__case:'default',__calls:[],__hold:false,__late:[],__invalidations:0,__LTS_V227_TRANSPORT:{invalidate:()=>window.__invalidations++}});
   window.S={auth:{onAuthStateChange:fn=>{window.__authEvent=fn;}},rpc:async(name,args)=>{
    window.__calls.push({name,args});if(name!=='lts_browser_month_overview_v393')throw Error('Unexpected capability '+name);
    let payload=structuredClone(window.__clock>=NativeDate.parse('2026-11-02T03:00:00Z')?native.next_day:native[window.__case]);
    if(window.__hold){window.__hold=false;await new Promise(resolve=>window.__late.push(resolve));}
    if(args.p_from==='2026-11-10'&&args.p_to==='2026-11-20')return{data:structuredClone(native.partial),error:null};
    if(args.p_from!=='2026-11-01'||args.p_to!=='2026-11-30')return{data:null,error:true};
    return{data:payload,error:null};
   }};
   eval(runtime+'\nruntime();');
  },{runtime,native});
  const overview=page.locator('#v337Overview');await page.waitForFunction(()=>window.__LTS_V337_MONTH?.state.status==='ready');
  assert.match(await overview.locator('.v337-period').innerText(),/01\/11\/2026 a 30\/11\/2026/);
  assert.match(await overview.innerText(),/Realizado até 01\/11\/2026/);assert.match(await overview.innerText(),/1\.100,00/);assert.match(await overview.innerText(),/500,00/);
  const detailButton=overview.getByRole('button',{name:/Ver lançamentos de caixa/});const contrast=await detailButton.evaluate(el=>{const c=getComputedStyle(el),rgb=s=>(s.match(/[\d.]+/g)||[]).slice(0,3).map(Number),lum=s=>rgb(s).map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;}).reduce((n,v,i)=>n+v*[.2126,.7152,.0722][i],0),a=lum(c.color),b=lum(c.backgroundColor),r=el.getBoundingClientRect();return{ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05),height:r.height,visible:r.width>0&&r.height>0};});assert(contrast.visible&&contrast.height>=44&&contrast.ratio>=4.5,JSON.stringify(contrast));
  assert.equal(await overview.locator('details[open]').count(),0);assert(!(await overview.innerText()).includes('Referência:'));
  await overview.getByRole('button',{name:'Realizado',exact:true}).click();assert.match(await overview.locator('.v337-metrics').innerText(),/0,00/);assert(!(await overview.locator('.v337-metrics').innerText()).includes('303,57'));
  await overview.getByRole('button',{name:'Previsto',exact:true}).click();assert.match(await overview.locator('.v337-metrics').innerText(),/500,00/);
  await page.screenshot({path:out+'/'+engine+'-'+width+'-cash.png'});
  await overview.getByRole('button',{name:'Competência',exact:true}).click();assert.match(await overview.locator('.v337-metrics').innerText(),/303,57/);assert.match(await overview.innerText(),/não comprovam pagamento/);
  await overview.getByRole('button',{name:/Ver composição/}).click();const dialog=page.getByRole('dialog');
  assert.match(await dialog.innerText(),/Compra em 19\/10\/2026/);assert.match(await dialog.innerText(),/Competência nov/);assert.equal(await dialog.locator('details[open]').count(),0);
  await dialog.getByLabel('Buscar no detalhamento').fill('fictícia B');assert.match(await dialog.innerText(),/Exibindo 1 de 1/);assert(!(await dialog.innerText()).includes('Compra fictícia A'));
  await dialog.getByLabel('Buscar no detalhamento').fill('');await dialog.locator('details > summary').first().click();assert.match(await dialog.innerText(),/Referência: a/);
  const geometry=await dialog.evaluate(el=>({left:el.getBoundingClientRect().left,right:el.getBoundingClientRect().right,width:innerWidth,scroll:el.scrollWidth,client:el.clientWidth}));assert(geometry.left>=-1&&geometry.right<=geometry.width+1&&geometry.scroll<=geometry.client+2,JSON.stringify(geometry));
  await dialog.locator('details > summary').first().click();await page.screenshot({path:out+'/'+engine+'-'+width+'-competence-detail.png'});await dialog.getByRole('button',{name:'Fechar detalhamento'}).click();
  await overview.getByRole('button',{name:'Caixa',exact:true}).click();await overview.getByRole('button',{name:/Ver lançamentos de caixa/}).click();
  assert.match(await page.getByRole('dialog').innerText(),/Previsto/);assert(!(await page.getByRole('dialog').innerText()).includes('vesting'));
  await page.getByRole('dialog').getByRole('button',{name:'Fechar detalhamento'}).click();
  await page.evaluate(async()=>{window.__case='unconfirmed';await window.__LTS_V337_MONTH.refresh();});await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');
  assert.match(await overview.innerText(),/sem confirmação/);await overview.getByRole('button',{name:'A confirmar',exact:true}).click();assert.match(await overview.locator('.v337-metrics').innerText(),/20,00/);
  await overview.getByRole('button',{name:'Realizado',exact:true}).click();assert(!(await overview.locator('.v337-metrics').innerText()).includes('20,00'));
  await page.evaluate(async()=>{window.__case='incomplete';await window.__LTS_V337_MONTH.refresh();});await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');assert.match(await overview.innerText(),/total projetado pode estar incompleto/);
  await page.evaluate(async()=>{window.__case='undated';await window.__LTS_V337_MONTH.refresh();});await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');assert.match(await overview.innerText(),/Cobranças sem data de pagamento/);assert.match(await overview.innerText(),/12,34/);assert.match(await overview.innerText(),/ainda não está no total de caixa/);
  await page.evaluate(async()=>{window.__case='projected';await window.__LTS_V337_MONTH.refresh();});await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');await overview.getByRole('button',{name:'Competência',exact:true}).click();assert.match(await overview.locator('.v337-metrics').innerText(),/303,57/);assert.match(await overview.locator('.v337-metrics').innerText(),/25,00/);assert.match(await overview.locator('.v337-metrics').innerText(),/328,57/);
  await overview.getByRole('button',{name:/Ver composição/}).click();assert.match(await page.getByRole('dialog').innerText(),/Exibindo 20 de 27/);assert.match(await page.getByRole('dialog').innerText(),/Parcela prevista/);await page.getByRole('dialog').getByRole('button',{name:'Mostrar mais 20'}).click();assert.match(await page.getByRole('dialog').innerText(),/Exibindo 27 de 27/);await page.getByRole('dialog').getByRole('button',{name:'Fechar detalhamento'}).click();await overview.getByRole('button',{name:'Caixa',exact:true}).click();
  await overview.getByRole('button',{name:'Período',exact:true}).click();await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');await overview.getByLabel('Data inicial do balanço').fill('2026-11-10');await overview.getByLabel('Data final do balanço').fill('2026-11-20');assert.equal(await page.evaluate(()=>window.__LTS_V337_MONTH.state.data.from),'2026-11-01');await overview.getByRole('button',{name:'Aplicar intervalo',exact:true}).click();await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.data?.from==='2026-11-10');assert.match(await overview.locator('.v337-period').innerText(),/10\/11\/2026 a 20\/11\/2026/);await overview.getByRole('button',{name:'Competência',exact:true}).click();assert.match(await overview.innerText(),/01\/11\/2026 a 30\/11\/2026/);await overview.getByRole('button',{name:'Mês',exact:true}).click();await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');await overview.getByRole('button',{name:'Caixa',exact:true}).click();
  // An unavailable reader never falls back to an invented zero or stale previous data.
  await overview.getByLabel('Mês do resumo').fill('2026-12');await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='error');assert.equal(await overview.locator('.v337-metrics').count(),0);
  await overview.getByLabel('Mês do resumo').fill('2026-11');await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');
  await page.evaluate(()=>{window.__hold=true;window.__LTS_V337_MONTH.refresh();});await page.waitForFunction(()=>window.__late.length===1);
  await overview.getByLabel('Mês do resumo').fill('2026-12');await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='error');
  await page.evaluate(()=>window.__late.shift()());assert.equal(await overview.locator('.v337-metrics').count(),0);
  await overview.getByLabel('Mês do resumo').fill('2026-11');await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready');const beforeDay=await page.evaluate(()=>({calls:window.__calls.length,invalidations:window.__invalidations}));await page.evaluate(()=>{window.__clock+=86400000;render();});await page.waitForFunction(()=>window.__LTS_V337_MONTH.state.status==='ready'&&window.__LTS_V337_MONTH.state.data.as_of==='2026-11-02');assert.equal(await page.evaluate(()=>window.__invalidations),beforeDay.invalidations+1);assert.equal(await page.evaluate(()=>window.__calls.length),beforeDay.calls+1);assert.match(await overview.innerText(),/Realizado até 02\/11\/2026/);
  const oldCalls=await page.evaluate(()=>window.__calls.length);await page.evaluate(()=>window.__authEvent('SIGNED_OUT'));assert.equal(await overview.count(),0);assert.equal(await page.evaluate(()=>window.__calls.length),oldCalls);
  assert.deepEqual(network,[]);assert.deepEqual(errors,[]);const storage=await ctx.storageState();assert.equal(storage.cookies.length,0);assert(storage.origins.every(x=>x.localStorage.length===0));
  return{pass:true,engine,width,full_month:true,realized_separated:true,competence_details:true,search:true,source_closed:true,unconfirmed_preserved:true,incomplete_visible:true,late_response_rejected:true,signed_out_cleared:true,network:0,session_created:false,private_http:false,physical_iphone:false};
 }catch(e){await page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,errors,network,body:await page.locator('body').innerText()},null,2));throw e;}finally{await ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[320,393,1366])results.push(await run(browser,engine,width));}finally{await browser.close();}}fs.writeFileSync(out+'/browser-results.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,cases:results.length,no_sessions_or_network:true}));})().catch(e=>{console.error(e);process.exitCode=1;});
