'use strict';
// Invented records; exercise the shipped app and the native category controls.
process.env.LTS_FLOW_RELEASE='v389';
const {setup,open}=require('./lts_v382_browser.cjs');
const {chromium,webkit}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict');
const out='qa/v389';fs.mkdirSync(out,{recursive:true});
const categories=['Despesas Organon','Reembolso Organon','Presentes','Saúde','Categoria histórica fora dos rankings','Categoria criada em outra tela'];
const card={source_ref:'00000000-0000-4000-8000-000000000389',raw_hash:'a'.repeat(64),event_date:'2026-10-30',amount:10,currency:'BRL',description:'Compra fictícia',account_source:'Cartão fictício',last4:'0000',suggestion:{}};
async function run(browser,engine,width){
 const h=await setup(browser,width,900,'2026-10-31T15:00:00Z'),writes=[];let saved=false,f;
 const send=(route,data)=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
 await h.ctx.route('**/rest/v1/rpc/lts_browser_card_category_options_v226',r=>send(r,{categories,aliases:{'Organon Despesas':'Despesas Organon','Bem-estar':'Saúde'},registry:'shared-v290'}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_card_review_queue_v312',r=>send(r,{ok:true,row_count:saved?0:1,additional_count:saved?0:1,matched_count:saved?0:1,offset:0,next_offset:null,checked_at:'2026-10-31T15:00:00Z',rows:saved?[]:[card],category_options:['Presentes']}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_expense_review_queue_v229',r=>send(r,{row_count:1,matched_count:1,offset:0,next_offset:null,category_options:['Presentes'],pending_projections:[],beneficiary_options:[],rows:[{key:'synthetic-expense',source_table:'lts_open_finance_staging',source_ref:'00000000-0000-4000-8000-000000000390',date:'2026-10-30',amount:10,description:'Despesa fictícia',account_source:'Conta fictícia',category:'A classificar',question_kind:'classification',suggestion:{}}]}));
 await h.ctx.route('**/rest/v1/rpc/lts_browser_card_review_save_v312',async r=>{const args=JSON.parse(r.request().postData());assert.equal(args.p_source_id,card.source_ref);assert.equal(args.p_expected_raw_hash,card.raw_hash);assert.equal(args.p_category,'Despesas Organon');assert.equal(args.p_beneficiary,null);writes.push(args);saved=true;await send(r,{ok:true,category:'Despesas Organon',financial_effect:'none'});});
 try{
  f=await open(h,'v389',true);
  await f.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW?.state.data?.row_count===1);
  await f.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();
  await f.locator('#v312CardReview [data-v312-review]').click();
  const dialog=f.locator('#v312CardDialog'),select=dialog.locator('select[name=category]'),search=dialog.getByRole('searchbox',{name:'Buscar classificação'});
  await search.waitFor();await f.waitForFunction(()=>document.querySelector('#v312CardDialog select[name=category]').options.length===7);
  assert.deepEqual(await select.locator('option').evaluateAll(es=>es.map(e=>e.value).filter(Boolean)),categories);
  await search.fill('organon');
  assert.deepEqual(await select.locator('option').evaluateAll(es=>es.map(e=>e.value).filter(Boolean)),['Despesas Organon','Reembolso Organon']);
  assert.equal(await select.inputValue(),'','search does not choose a classification');
  await search.press('Enter');assert.equal(writes.length,0,'search never submits the enclosing form');
  await search.fill('ORGANON DESPESAS');assert.equal(await select.locator('option[value="Despesas Organon"]').count(),1,'historical alias searchable');
  await search.fill('saude');assert.equal(await select.locator('option[value="Saúde"]').count(),1,'accent-insensitive matching');
  await search.fill('bem-estar');assert.equal(await select.locator('option[value="Saúde"]').count(),1,'catalog alias matching');
  await search.fill('organon');await select.selectOption('Despesas Organon');
  await search.fill('sem-correspondencia-xyz');assert.equal(await select.inputValue(),'Despesas Organon','typing preserves the current selection');
  assert.match(await dialog.locator('.lts-category-search small').innerText(),/Nenhuma classificação encontrada/);
  await search.fill('');assert.equal(await select.locator('option').count(),7,'clearing restores every classification');
  await select.focus();assert(await select.evaluate(el=>{render();return el.isConnected&&document.activeElement===el;}),'native picker survives background render');
  await search.focus();await search.fill('organon');
  const geometry=await search.evaluate(el=>({left:el.getBoundingClientRect().left,right:el.getBoundingClientRect().right,height:el.getBoundingClientRect().height,width:innerWidth,scroll:document.documentElement.scrollWidth}));
  assert(geometry.left>=0&&geometry.right<=geometry.width+2&&geometry.height>=44&&geometry.scroll<=geometry.width+2,JSON.stringify(geometry));
  await h.page.screenshot({path:out+'/'+engine+'-'+width+'-classification-search.png'});
  await dialog.getByRole('button',{name:'Confirmar classificação',exact:true}).click();
  await f.waitForFunction(()=>window.__LTS_V312_CARD_REVIEW.state.data?.row_count===0);assert.equal(writes.length,1);
  const expense=f.locator('[data-v181-review-key="synthetic-expense"]'),expenseSelect=expense.locator('[data-v181-category]'),expenseSearch=expense.getByRole('searchbox',{name:'Buscar classificação'});
  await expenseSearch.waitFor();await expenseSearch.fill('organon');assert.equal(await expenseSelect.locator('option[value="Despesas Organon"]').count(),1,'same complete catalog in expense review');
  await expenseSearch.fill('histórica');assert.equal(await expenseSelect.locator('option[value="Categoria histórica fora dos rankings"]').count(),1,'not limited to rankings or current period');
  await expenseSearch.fill('outra tela');assert.equal(await expenseSelect.locator('option[value="Categoria criada em outra tela"]').count(),1,'shared classifications remain discoverable');
  await expenseSearch.fill('');assert.equal(await expenseSelect.locator('option').count(),7);
  assert.deepEqual(h.errors,[]);assert.deepEqual(h.writes,[]);assert.equal(writes.length,1);
  return{pass:true,engine,width,catalog_complete:true,search_and_aliases:true,selection_preserved:true,canonical_save:true,no_automatic_assignment:true,synthetic_only:true,private_session:false,physical_iphone:false};
 }catch(e){await h.page.screenshot({path:out+'/'+engine+'-'+width+'-failure.png'}).catch(()=>{});if(f)fs.writeFileSync(out+'/'+engine+'-'+width+'-failure.json',JSON.stringify({error:e.stack,body:await f.locator('body').innerText(),reads:h.reads},null,2));throw e;}finally{await h.ctx.close();}
}
(async()=>{const results=[];for(const[engine,type]of[['webkit',webkit],['chromium',chromium]]){const browser=await type.launch({headless:true});try{for(const width of[320,360,393,430,852,1366])results.push(await run(browser,engine,width));}finally{await browser.close();}console.log(JSON.stringify({engine,passed:results.filter(r=>r.engine===engine).length}));}assert.equal(results.length,12);fs.writeFileSync(out+'/classification-search-results.json',JSON.stringify({pass:true,results},null,2));})().catch(e=>{console.error(e);process.exitCode=1;});
