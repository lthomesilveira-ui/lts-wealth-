'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require('playwright');
const root=path.resolve(process.env.LTS_PROJECTION_OUTPUT_DIR||'projection-coverage-browser-artifacts');fs.mkdirSync(root,{recursive:true});
const BASE=path.resolve(process.env.LTS_PROJECTION_BASE_ROOT||path.join(__dirname,'../../releases/v283'));
const CANDIDATE=path.resolve(process.env.LTS_PROJECTION_CANDIDATE_ROOT||BASE);
const TODAY='2026-10-16',TO='2027-12-31';
const rows=[];for(let x=Date.parse(TODAY+'T12:00Z');x<=Date.parse(TO+'T12:00Z');x+=86400000)rows.push({date:new Date(x).toISOString().slice(0,10),fix86_columns:{saldo_apos_d0_1:100,saldo_apos_rsu:120,saldo_apos_fgts:130}});
function payload(days,flags={}){return{ok:true,...flags,flow:{from:TODAY,to:TO,current_future:{days,events:[]}}}}
function runtime(candidate){const s=fs.readFileSync(path.join(candidate?CANDIDATE:BASE,'lts-v179-cash-recovery.js'),'utf8');const body=s.slice(s.indexOf('function runtime()'),s.indexOf('\n function install()')).trim();return '('+body.slice(0,-1)+'\nwindow.__test={loadForecast};\n})();'}
(async()=>{
 const browser=await chromium.launch({...(process.env.LTS_CHROMIUM_EXECUTABLE?{executablePath:process.env.LTS_CHROMIUM_EXECUTABLE}:{}),headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});const result=[];
 try{for(const width of [320,390,768,1440])for(const candidate of [false,true]){
  const page=await browser.newPage({viewport:{width,height:900}});let requests=0;await page.route('**/*',async route=>{requests++;await route.abort()});
  await page.setContent('<!doctype html><html lang="pt-BR"><meta charset="UTF-8"><title>Projection coverage test</title><div id="app"></div></html>');
  await page.addStyleTag({content:fs.readFileSync(path.join(BASE,'lts-v168-feedback-package.css'),'utf8')+'\n'+fs.readFileSync(path.join(BASE,'lts-v178-integrated-review.css'),'utf8')+'body{margin:0;padding:16px;background:#f3f5f9;font:15px Arial;color:#15243b} .v168-dashboard{max-width:1000px;margin:auto}.v168-card{margin:20px 0;padding:20px;background:white;border-radius:12px}.v178-empty{white-space:normal;line-height:1.5}button{white-space:normal;min-height:44px}'});
  await page.evaluate(({today})=>{
   const RealDate=Date;window.Date=class extends RealDate{constructor(...args){super(...(args.length?args:[today+'T12:00:00Z']))}static now(){return RealDate.parse(today+'T12:00:00Z')}};
   Object.assign(window,{D:false,V:'Dashboard',BOOT:{generation:1},N:document.createElement('div'),U:'https://invented.invalid',K:'invented-key',EXP:new Set(),__LTS_V176_FLOW_EXPENSE_AUDIT:{installed:true},__LTS_V168_STATE:{dashboard:{},wealth:{},expense:{key:'ytd'},updates:{}},__LTS_V175_STATE:{expense:{},monthly:{}},__LTS_V181_STATE:{review:{}},renderNav:()=>'',despesas:()=>'',mergedFlowDays:()=>[],flowVals:()=>({}),flowSemanticTitle:()=>'',flowSemanticMeta:()=>'',today:()=>today,dayEvents:()=>[],loadFlowRange:()=>{}});
   window.fetch=async url=>new Response(JSON.stringify(String(url).endsWith('lts_browser_flow_v242')?window.fixture:String(url).endsWith('lts_browser_cash_today_v242')?window.cashFixture:{ok:true,summary:{selected_total:0},rows:[],events:[]}),{status:200,headers:{'Content-Type':'application/json'}});
   window.S={auth:{getSession:async()=>({data:{session:{access_token:'invented-token'}}}),onAuthStateChange:()=>{}}};
   window.dashboard=()=>'<main class="v168-dashboard"><header class="v168-pagehead"><h1>Planejamento</h1></header><article class="v168-card"><header class="v168-cardhead"><h2>Evolução projetada</h2></header><div data-chart>Horizonte até 31/12/2027</div></article><article class="v168-card"><header class="v168-cardhead"><h2>O que exige decisão</h2></header><p data-coverage>'+(window.__LTS_V168_STATE.dashboard.data?.planningUI?.fgts_covers_horizon===true?'FGTS cobre o horizonte.':'Conferindo cobertura.')+'</p></article></main>';
   window.render=()=>{document.getElementById('app').innerHTML=dashboard();};
  },{today:TODAY});
  await page.addScriptTag({content:runtime(candidate)});
  await page.evaluate(({today})=>{const c={cash:600,d0:40,brokerage_available:60,available_total:700,fgts:0,as_of:today,status:'complete',version:'cash-today-v179-current-canonical',day:{date:today,fix86_columns:{}}};window.cashFixture=c;Object.assign(__LTS_V178_STATE.cash,{status:'ready',date:today,data:c,sessionGeneration:1,authEpoch:0});}, {today:TODAY});
  const scenarios=[['truncated',payload(rows.slice(0,2)),candidate?'incomplete':'ready'],['full',payload(rows),'ready'],['server-incomplete',payload(rows,{complete:false,incomplete_families:['C6']}),candidate?'incomplete':'ready']];
  for(const [name,fixture,status]of scenarios){
   await page.evaluate(async data=>{window.fixture=data;await __test.loadForecast(true);document.getElementById('app').innerHTML=dashboard();},fixture);
   const s=await page.evaluate(()=>({status:__LTS_V178_STATE.forecast.status,planning:__LTS_V178_STATE.planningUI.status,claim:__LTS_V178_STATE.planningUI.data?.fgts_covers_horizon,text:document.body.innerText,overflow:document.documentElement.scrollWidth>innerWidth+1,chart:!!document.querySelector('[data-chart]'),buttons:[...document.querySelectorAll('.v178-refresh')].map(b=>({w:b.getBoundingClientRect().width,h:b.getBoundingClientRect().height}))}));
   assert.equal(s.status,status);assert.equal(s.overflow,false);
   if(name==='truncated'&&candidate){assert.equal(s.claim,undefined);assert.equal(s.chart,false);assert(s.text.includes('Projeção incompleta. Atualize para conferir todo o período.'));assert(!s.text.includes('C6'));assert.equal(s.buttons.length,2);assert(s.buttons.every(b=>b.w>0&&b.h>=44));await page.screenshot({path:path.join(root,'coverage-incomplete-'+width+'.png'),fullPage:true});}
   if(name==='truncated'&&!candidate){assert.equal(s.claim,true);assert.equal(s.chart,true)}
   if(name==='full'){assert.equal(s.claim,true);assert.equal(s.chart,true);assert(!s.text.includes('Projeção incompleta'))}
   if(name==='server-incomplete'){assert.equal(s.planning,'incomplete');assert(s.text.includes('C6 em conferência'));assert.equal(s.chart,false)}
   if(name==='truncated'&&candidate){
    await page.evaluate(({full,today})=>{window.fixture=full;__LTS_V178_STATE.date=today;__LTS_V178_STATE.awards.status='ready';window.D={};window.V='Fluxo Diário';render();},{full:payload(rows),today:TODAY});
    await page.locator('.v178-refresh').first().click();
    await page.waitForFunction(()=>__LTS_V178_STATE.forecast.status==='ready'&&__LTS_V178_STATE.planningUI.status==='ready'&&document.querySelector('[data-coverage]')?.textContent==='FGTS cobre o horizonte.');
    assert.equal(await page.locator('[data-chart]').count(),1);
    assert.equal(await page.locator('.v178-empty').count(),0);
    await page.evaluate(()=>{window.D=false;window.V='Dashboard'});
    result.push({width,version:'candidate',scenario:'real retry button incomplete to complete',pass:true});
   }
   result.push({width,version:candidate?'candidate':'baseline',scenario:name,pass:true,status:s.status,planning:s.planning,shows_coverage:s.claim===true});
  }
  assert.equal(requests,0);await page.close();
 }
 }finally{await browser.close()}
 const receipt={pass:true,cases:result.length,scope:'Chromium local: exact dashboard wrapper and forecast runtime, synthetic predecessor markup and fixtures, four widths; not full application or authenticated QA',network_requests:0,results:result};fs.writeFileSync(path.join(root,'coverage-browser-results.json'),JSON.stringify(receipt,null,2));console.log(JSON.stringify(receipt,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
