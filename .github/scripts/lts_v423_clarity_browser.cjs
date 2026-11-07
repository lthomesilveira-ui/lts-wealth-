'use strict';
process.env.LTS_FLOW_RELEASE='v423';
const fs=require('node:fs'),assert=require('node:assert/strict'),{chromium,webkit}=require('playwright');
const fixture=require('./lts_v379_fixtures.cjs'),{setup,open}=require('./lts_v382_browser.cjs');
const out='qa/v423';fs.mkdirSync(out,{recursive:true});
const detailRows=[['a','Consulta de exemplo','Consultas',30],['b','Farmácia de exemplo','Farmácia',50],['c','Crédito de exemplo','Farmácia',-10]].map(([key,description,subgroup,amount])=>({key,description,subgroup,amount,category:'Saúde',current_category:'Saúde',original_category:'Saúde',event_date:'2026-11-01',date:'2026-11-01',date_kind:'day',period:'2026-11-01',account_source:'Cartão fictício',beneficiary:null,source_table:'synthetic',source_ref:key,coverage_mode:'direct_cash'}));
const evidence={version:'pending-bank-evidence-v423',as_of:'2026-11-07',accounts:[{bank:'Bradesco',balance_brl:980.5,source_date:'2026-11-06',pending_count:2,pending_total_brl:-19.5,complete:true,movements:[{key:'example-pending-1',date:'2026-11-06',amount:-20,description:'Parcela fictícia',status:'PENDING'},{key:'example-pending-2',date:'2026-11-06',amount:.5,description:'Crédito fictício',status:'PENDING'}]}]};
async function run(browser,engine,width){
 const h=await setup(browser,width,width<1000?900:1100,'2026-11-07T15:00:00Z');let f,bankReads=0,detailReads=0;
 await h.ctx.route('**/rest/v1/rpc/lts_browser_expenses_v229',route=>{const args=JSON.parse(route.request().postData()||'{}'),p=fixture.response('lts_browser_expenses_v229',args);p.management_groups=[{name:'Saúde',total:70,rows:3,subgroups:[]}];Object.assign(p.summary,{selected_total:70,card_total:70,account_total:0,rows:3,monthly_average:70});p.monthly_detail=[{month:'2026-11-01',total:70}];return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});});
 for(const endpoint of ['lts_browser_expense_detail_v374','lts_browser_expense_scope_detail_v374'])await h.ctx.route('**/rest/v1/rpc/'+endpoint,route=>{detailReads++;const a=JSON.parse(route.request().postData()||'{}'),offset=a.p_offset||0;return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify({version:'expense-detail-v353',from:a.p_from,to:a.p_to,total:70,matched_total:70,row_count:3,matched_count:3,offset,next_offset:offset===0?2:null,revision:'invented-fixed-detail',rows:detailRows.slice(offset,offset===0?2:3),components:[]})})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_pending_bank_evidence_v423',route=>{bankReads++;return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(evidence)})});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_flow_v242',route=>{
  const a=JSON.parse(route.request().postData()||'{}'),p=fixture.response('lts_browser_flow_v242',a),part=p.flow.current_future;
  for(const d of part.days){if(d.date!=='2026-11-07')continue;d.Bradesco={opening_balance:1000,balance:980.5,observed_balance:980.5,unposted_projection_net:0,movements_complete:false,cash_position_guard:{unexplained_balance_difference:-19.5,position_delta:-19.5,ledger_reconstruction:{balance:1000,net:0}}};d.movements_complete=false;d.cash_position_guard={unexplained_bank_differences:{Bradesco:-19.5}};Object.assign(d.fix86_columns,{saldo_anterior:2000,saldo_final:1980.5,entradas:null,saidas:null});}
  const cardDay=part.days.find(d=>d.date==='2026-11-16');if(cardDay){cardDay.summary={...cardDay.summary,events:2,exits:700,entries:0,net:-700};cardDay.Itaú={...cardDay.Itaú,net:-700};Object.assign(cardDay.fix86_columns,{saidas:700,entradas:0});}
  if(a.p_from<='2026-11-16'&&a.p_to>='2026-11-16')part.events.push({event_date:'2026-11-16',description:'Fatura cartão de exemplo',signed_amount:-500,account:'Itaú',source:'card_invoice',source_ref:'example-card:2030',confidence:'documented_projected_snapshot'},{event_date:'2026-11-16',description:'Mastercard',signed_amount:-200,account:'Itaú',source:'planning_projection_v412',source_ref:'projection:v412:card_itau:2026-11-16',confidence:'owner_authorized_3m_history'});
  return route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(p)});
 });
 try{
  f=await open(h,'v423',false);await f.waitForFunction(()=>window.__LTS_V423_CLARITY?.installed&&window.__LTS_V178_STATE?.dashboardReport.status==='ready');
  await h.page.waitForLoadState('networkidle');
  await f.locator('.v178-open.title[data-group="Saúde"]').first().click();
  await f.waitForFunction(()=>document.querySelector('.v423-subgroups')&&document.querySelector('#v178Drawer footer').textContent.includes('lista completa'));
  const box=f.locator('.v423-subgroups');assert.match(await box.innerText(),/Consultas/);assert.match(await box.innerText(),/Farmácia/);assert.match(await box.innerText(),/40,00/);assert(detailReads>=2,'all detail pages read');
  assert.equal(await f.locator('#v178Drawer tbody tr[data-row-key]').count(),3);
  await box.getByRole('button').filter({hasText:'Farmácia'}).click();assert.equal(await f.locator('#v178Drawer tbody tr[data-row-key]').count(),2);
  assert.equal(await f.locator('#v178Drawer tbody tr[data-row-key="c"]').count(),1,'credit preserved');
  assert((await box.boundingBox()).height<=300,'subgroups do not dominate viewport');
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-subgroups.png'});
  await box.getByRole('button').filter({hasText:'Todos os lançamentos'}).click();assert.equal(await f.locator('#v178Drawer tbody tr[data-row-key]').count(),3);
  await f.locator('#v178Drawer .v178-close').click();
  await f.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible').click();
  await f.waitForFunction(()=>V==='Fluxo Diário'&&!FLOWLOADING);
  const before=await f.evaluate(()=>JSON.stringify(mergedFlowDays().find(x=>x.date===today()).fix86_columns));
  await f.locator('#d-2026-11-07 .exp').click();await f.waitForSelector('.v423-bank-evidence');
  const bridge=f.locator('.v423-bank-evidence');assert.match(await bridge.innerText(),/Parcela fictícia/);assert.match(await bridge.innerText(),/Crédito fictício/);assert.match(await bridge.innerText(),/980,50/);assert.match(await bridge.innerText(),/confirmação.*pendente/);assert.equal(await bridge.locator('details[open]').count(),0);
  assert.equal(await f.evaluate(()=>JSON.stringify(mergedFlowDays().find(x=>x.date===today()).fix86_columns)),before,'no balance changed to create explanation');
  assert.equal(bankReads,1);await bridge.scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-reconciliation.png'});
  await f.locator('#d-2026-11-16 .exp').click();
  const cardDetail=f.locator('#d-2026-11-16 + .fx89-details');assert.match(await cardDetail.innerText(),/complemento do orçamento/);assert.match(await cardDetail.innerText(),/não é outra fatura/);assert.match(await cardDetail.innerText(),/500,00/);assert.match(await cardDetail.innerText(),/200,00/);
  const cardEvents=await f.evaluate(()=>dayEvents('2026-11-16').filter(x=>['card_invoice','planning_projection_v412'].includes(x.source)).map(x=>x.signed_amount));assert.deepEqual(cardEvents,[-500,-200]);
  await cardDetail.scrollIntoViewIfNeeded();await h.page.screenshot({path:out+'/'+engine+'-'+width+'-card-budget.png'});
  const text=await f.locator('body').innerText();for(const word of ['SQLSTATE','source_ref','source_fingerprint','lts_browser_pending_bank','payload'])assert(!text.includes(word));
  assert(await f.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+2));assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);
  return {passed:true,engine,width,complete_subgroup_totals:true,all_pages_used:true,credit_preserved:true,pending_evidence_not_settlement:true,source_balances_unchanged:true,invoice_plus_budget_labelled:true,financial_writes:0,physical_iphone:false,private_session:false};
 }catch(e){if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,errors:h.errors,body:await f.locator('body').innerText()},null,2));await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png',fullPage:true}).catch(()=>{});throw e;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const engine of(process.env.LTS_TEST_ENGINES||'chromium,webkit').split(',')){const opts={headless:true};if(engine==='chromium'&&process.env.LTS_CHROMIUM_PATH){opts.executablePath=process.env.LTS_CHROMIUM_PATH;opts.args=['--no-sandbox'];}const b=await({chromium,webkit}[engine]).launch(opts);try{for(const width of(process.env.LTS_TEST_WIDTHS||'393,1366').split(',').map(Number)){results.push(await run(b,engine,width));fs.writeFileSync(out+'/browser.json',JSON.stringify({passed:false,results},null,2));}}finally{await b.close();}}fs.writeFileSync(out+'/browser.json',JSON.stringify({passed:true,results},null,2));console.log(JSON.stringify({passed:true,runs:results.length}));})().catch(e=>{console.error(e);process.exitCode=1});
