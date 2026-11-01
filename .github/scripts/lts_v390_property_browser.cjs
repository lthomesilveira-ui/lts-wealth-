'use strict';
// Render the shipped modal function in an isolated component harness, without login or a session.
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const {sample}=require('./lts_v390_fixtures.cjs'),model=require('../../releases/v390/lts-property-reconciliation-model.js');
const root='releases/v390',out='qa/v390';fs.mkdirSync(out,{recursive:true});
const script=fs.readFileSync(root+'/lts-v179-cash-recovery.js','utf8');
const draw=script.slice(script.indexOf('  function drawCipo(c,m){'),script.indexOf('  function rememberDetail(){'));
assert(draw.startsWith('  function drawCipo'));
const inline=[...fs.readFileSync(root+'/index.html','utf8').matchAll(/<style[^>]*>([\s\S]*?)<\/style>/g)].map(m=>m[1]).join('\n');
const css=fs.readdirSync(root).filter(n=>n.endsWith('.css')).map(n=>fs.readFileSync(root+'/'+n,'utf8')).join('\n');
async function run(browser,engine,width,explained){
 const ctx=await browser.newContext({viewport:{width,height:900},locale:'pt-BR',serviceWorkers:'block'}),page=await ctx.newPage(),errors=[],requests=[];
 page.on('pageerror',e=>errors.push(String(e)));await page.route('**/*',r=>{requests.push(r.request().url());return r.abort();});
 const s=sample();if(!explained)delete s.wealth.wealth.cipo_reconciliation.consortium.itau_source_audit.snapshot_scope.works_cash_coverage_explanation;
 const m=model.build(s.wealth,s.page,s.range);
 try{
  await page.setContent('<style>'+inline+'\n'+css+'</style><div class="v168-modal-bg"><section class="v168-modal v359-property" role="dialog"><header><h2>Composição dos gastos · dados fictícios</h2></header><div class="v359-content"></div></section></div>');
  await page.evaluate(({draw,m})=>{
   const escape=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
   const money=n=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(n),dateLabel=s=>s.split('-').reverse().join('/');
   const cipoCurrent=()=>false;
   eval(draw+'\ndrawCipo({host:document.querySelector(".v168-modal-bg")},m);');
  },{draw,m});
  const modal=page.getByRole('dialog');assert.equal(await modal.locator('details[open]').count(),0);
  const visible=await modal.innerText();
  if(explained){assert.match(visible,/2,00/);assert.match(visible,/constam como pagos no Excel, fora do fluxo de caixa/);assert.match(visible,/Confirmação bancária não recuperada/);assert(!visible.includes('ainda sem vínculo suficiente'));}
  else{assert.match(visible,/ainda sem vínculo suficiente/);assert.equal(await modal.locator('.v390-coverage').count(),0);}
  assert(!visible.includes('Synthetic.xlsm'),'source details closed');
  const geometry=await modal.evaluate(el=>({height:el.getBoundingClientRect().height,screen:innerHeight,width:el.scrollWidth,client:el.clientWidth}));assert(geometry.height<=geometry.screen+2&&geometry.width<=geometry.client+2,JSON.stringify(geometry));
  await page.screenshot({path:out+'/'+engine+'-'+width+'-'+explained+'.png'});
  await modal.locator('.v359-unlinked > summary').click();assert.equal(await modal.locator('.v359-unlinked tbody tr').count(),2,'distinct original rows, copies counted once');
  if(explained){await modal.locator('.v359-unlinked > .v359-origin > summary').click();assert.match(await modal.innerText(),/Saldo inicial/);assert.match(await modal.innerText(),/Synthetic.xlsm/);}
  assert.deepEqual(errors,[]);assert.deepEqual(requests,[]);
  return{pass:true,engine,width,explained,coverage_visible:true,source_details_initially_closed:true,modal_height:geometry.height,network_requests:0,session_created:false,private_http:false,physical_device:false};
 }finally{await ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['chromium',chromium],['webkit',webkit]]){const browser=await type.launch({headless:true});try{for(const width of[320,393,1366])for(const explained of[true,false])results.push(await run(browser,engine,width,explained));}finally{await browser.close();}}fs.writeFileSync(out+'/property-browser-results.json',JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,cases:results.length,no_sessions_or_network:true}));})().catch(e=>{console.error(e);process.exitCode=1;});
