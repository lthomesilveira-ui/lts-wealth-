'use strict';
// All identities, categories and amounts below are invented browser fixtures.
process.env.LTS_FLOW_RELEASE='v385';
const fixture=require('./lts_v379_fixtures.cjs'),{setup,open}=require('./lts_v382_browser.cjs');
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const out='qa/v385';fs.mkdirSync(out,{recursive:true});
const groups=['Patrimônio e financiamentos','Saúde','Alimentação','Vida pessoal e familiar','Moradia','Mobilidade','Educação e formação','Lazer e cultura','Assinaturas e serviços','Despesas administrativas','Outras despesas com nome longo para testar a leitura','Compensações de teste'];
const values=[333333.33,222222.22,111111.11,99999.99,88888.88,77777.77,66666.66,55555.55,44444.44,33333.33,22222.22,-12345.67];
const rows=groups.map((name,i)=>({key:'synthetic-'+i,date:'2026-10-05',event_date:'2026-10-05',date_kind:'day',period:'2026-10-01',description:'Despesa fictícia '+i,account_source:'Conta fictícia',amount:values[i],category:name,current_category:name,original_category:name,taxonomy:{macrogroup:name,group:'Grupo fictício',category:name,is_tax:false},property_code:null,beneficiary:null,center_cost:null,source_table:'fixture',source_ref:String(i),coverage_mode:'direct_cash'}));
const money=x=>new Intl.NumberFormat('pt-BR',{style:'currency',currency:'BRL'}).format(x),sum=xs=>xs.reduce((s,r)=>s+r.amount,0),baseResponse=fixture.response,keys=['saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts'],day='2026-10-31',iso=i=>new Date(Date.parse(day+'T12:00:00Z')+i*86400000).toISOString().slice(0,10);
let mode='presentation',detailRequests=[];
function presentation(args){return{version:'expense-presentation-v353',period:{from:args.p_from,to:args.p_to},scope:{},summary:{gross:values.filter(x=>x>0).reduce((a,b)=>a+b,0),compensations:-values.filter(x=>x<0).reduce((a,b)=>a+b,0),net:sum(rows),rows:12},cells:rows.map(r=>({macrogroup:r.category,group_name:'Grupo fictício',category:r.category,property:'__missing__',person:'__missing__',center_cost:'__missing__',is_tax:false,gross:Math.max(r.amount,0),compensations:-Math.min(r.amount,0),net:r.amount,rows:1})),dimensions:{property:[],person:[],center_cost:[]}};}
fixture.response=function(name,args){
 if(name==='lts_browser_expenses_v229'||/^lts_browser_expense_executive_/.test(name)){
  const p=structuredClone(baseResponse('lts_browser_expenses_v229',args));p.summary={...p.summary,selected_total:sum(rows),rows:12};p.management_groups=rows.map(r=>({name:r.category,total:r.amount,rows:1,subgroups:[]}));
  if(mode!=='legacy')p.presentation=presentation(args);else delete p.presentation;return p;
 }
 if(name==='lts_browser_expense_detail_v353'){
  detailRequests.push({name,args});const filtered=rows.filter(r=>!args.p_scope?.macrogroup||r.category===args.p_scope.macrogroup);
  return{version:'expense-detail-v353',revision:'synthetic-v385',total:sum(filtered),row_count:filtered.length,matched_count:filtered.length,offset:0,next_offset:null,rows:filtered,components:[]};
 }
 const p=baseResponse(name,args);
 if(/^lts_browser_flow_v/.test(name)&&p?.flow?.current_future?.days){
  for(const d of p.flow.current_future.days){
   const t=Math.round((Date.parse(d.date+'T12:00:00Z')-Date.parse(day+'T12:00:00Z'))/86400000);if(t<0)continue;
   for(const [k,column]of keys.entries())d.fix86_columns[column]=mode==='positive'&&k===2?(t===0?0:1000):t===2+k?[-12.34,-23.45,-34.56][k]:t===5+2*k?[-9876.54,-8765.43,-7654.32][k]:1000+k*100;
  }
 }
 return p;
};
async function rankGeometry(frame){return frame.locator('.v168-dashboard .v178-rankrow').evaluateAll(es=>es.map(e=>{
 const amount=e.children[2],range=document.createRange();range.selectNodeContents(amount);const lines=new Set([...range.getClientRects()].filter(r=>r.width>.1&&r.height>.1).map(r=>Math.round(r.top*2)/2));const card=e.closest('.v168-card'),r=amount.getBoundingClientRect(),c=card.getBoundingClientRect();
 return{text:amount.textContent,name:e.children[1].textContent.trim(),lines:lines.size,width:r.width,height:r.height,left:r.left,right:r.right,cardLeft:c.left,cardRight:c.right,rowHeight:e.getBoundingClientRect().height};
}));}
async function ready(frame){await frame.waitForFunction(()=>window.__LTS_V178_STATE?.forecast?.status==='ready'&&window.__LTS_V178_STATE?.dashboardReport?.status==='ready'&&document.querySelectorAll('.v168-dashboard .v178-rankrow').length===12);}
function decision(frame){return frame.locator('.v168-card').filter({has:frame.locator('h2',{hasText:'O que exige decisão'})});}
async function stats(frame,positive=false){
 const boxes=decision(frame).locator('.v168-decision');assert.equal(await boxes.count(),3);
 const result=[];
 for(let i=0;i<3;i++){
  const box=boxes.nth(i),dl=box.locator('.v385-scenario-stats');assert.equal(await dl.count(),1,'visible summary for each scenario');
  const times=await dl.locator('time').evaluateAll(es=>es.map(e=>e.dateTime)),amounts=await dl.locator('strong').allTextContents(),cover=await box.locator(':scope>div>span').innerText();
  if(positive&&i===2){assert.match(await dl.innerText(),/Sem saldo negativo no período/);assert.deepEqual(times,[day]);assert.deepEqual(amounts,[money(0)]);assert.match(cover,/31\/12\/2030/);}
  else{assert.deepEqual(times,[iso(2+i),iso(5+2*i)]);assert.deepEqual(amounts,[money([-12.34,-23.45,-34.56][i]),money([-9876.54,-8765.43,-7654.32][i])]);assert(cover.includes(iso(1+i).split('-').reverse().join('/')),'coverage date preserved');}
  assert.equal(await dl.locator('details').count(),0);assert(await dl.isVisible());result.push({label:await box.locator(':scope>div>b').innerText(),times,amounts,coverage:cover});
 }
 return result;
}
async function run(browser,engine,width,variant,baseline=false){
 mode=variant;detailRequests=[];const h=await setup(browser,width,width===1366?900:852,'2026-10-31T15:00:00Z'),label=engine+'-'+width+'-'+variant+(baseline?'-before':'');let f;
 try{
  f=await open(h,baseline?'v384':'v385',!baseline);await ready(f);
  const geometry=await rankGeometry(f);assert.equal(geometry.length,12);assert.deepEqual(geometry.map(x=>x.name),groups);assert.deepEqual(geometry.map(x=>x.text),values.map(money));
  if(baseline){assert(geometry.some(x=>x.lines>1),'negative control reproduces crushed mobile numbers');return{pass:true,engine,width,variant,negative_control_reproduced:true,geometry};}
  for(const x of geometry){assert.equal(x.lines,1,'unbroken monetary value '+JSON.stringify(x));assert(x.left>=x.cardLeft-1&&x.right<=x.cardRight+1,'value inside card');assert(x.rowHeight<140,'compact row');}
  const current=await stats(f,variant==='positive'),financial=await f.evaluate(()=>({forecast:window.__LTS_V178_STATE.forecast.data,report:window.__LTS_V178_STATE.dashboardReport.data})),hash=crypto.createHash('sha256').update(JSON.stringify(financial)).digest('hex');
  for(const index of[0,5,11]){await f.locator('.v168-dashboard .v178-rankrow').nth(index).scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+label+'-groups-'+index+'.png'});}
  await decision(f).scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+label+'-scenarios.png'});
  if(variant==='presentation'){
   const top=f.locator('.v168-dashboard .v178-rankrow').first();await top.locator(':scope>button').click();await f.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.equal(await f.locator('#v178Drawer tbody tr').count(),1);assert.equal(detailRequests.at(-1).args.p_scope.macrogroup,groups[0]);const scope=detailRequests.at(-1).args;
   await f.locator('#v178Drawer .v344-back').click();await top.locator(':scope>div>button').click();await f.waitForFunction(()=>window.__LTS_V178_STATE.detail&&!window.__LTS_V178_STATE.detail.loading);assert.deepEqual(detailRequests.at(-1).args,scope,'group and amount open the same scoped entries');await f.locator('#v178Drawer .v344-back').click();
   if(width===393){await f.locator('.v178-rank').evaluate(e=>e.style.fontSize='150%');for(const x of await rankGeometry(f)){assert.equal(x.lines,1,'enlarged text preserves whole number');assert(x.right<=x.cardRight+1);}await f.evaluate(()=>render());}
  }
  assert.equal(crypto.createHash('sha256').update(JSON.stringify(await f.evaluate(()=>({forecast:window.__LTS_V178_STATE.forecast.data,report:window.__LTS_V178_STATE.dashboardReport.data})))).digest('hex'),hash,'rendering and drilldown never alter financial response');
  assert.deepEqual(h.writes,[]);assert.deepEqual(h.errors,[]);
  return{pass:true,engine,width,variant,all_twelve_names_and_values_intact:true,scenarios:current,financial_response_sha256:hash,source_values_unchanged:true,synthetic_only:true,physical_iphone:false,private_session:false};
 }catch(error){await h.page.screenshot({path:out+'/'+label+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+label+'-failure.json',JSON.stringify({error:error.stack,geometry:await rankGeometry(f).catch(()=>[]),body:(await f.locator('body').innerText()).slice(0,9000),reads:h.reads},null,2));throw error;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{
 results.push(await run(browser,engine,393,'presentation',true));
 for(const width of[320,360,393,430,852,1366])results.push(await run(browser,engine,width,'presentation'));
 for(const width of[393,1366])results.push(await run(browser,engine,width,'legacy'));
 results.push(await run(browser,engine,393,'positive'));
 }finally{await browser.close();}fs.writeFileSync(out+'/result.json',JSON.stringify({pass:results.every(x=>x.pass),results},null,2));console.log(JSON.stringify({engine,passed:results.filter(x=>x.engine===engine).length}));}assert.equal(results.length,20);})().catch(error=>{console.error(error);process.exitCode=1});
