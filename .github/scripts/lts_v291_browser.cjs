'use strict';
// Real ordered release stack; only synthetic API responses. No production auth/data.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_boot_recovery_fixtures.cjs');
const BASE=process.env.LTS_TEST_BASE||'http://127.0.0.1:8788',origin=new URL(BASE),qa=path.resolve('qa/v291');
assert(['127.0.0.1','localhost'].includes(origin.hostname));fs.mkdirSync(qa,{recursive:true});
const root=path.resolve('releases/v291'),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const BANK='00000000-0000-4000-8000-000000000290',CARD='00000000-0000-4000-8000-000000000291';
const signed={access_token:'synthetic-only-access',refresh_token:'synthetic-only-refresh',token_type:'bearer',expires_in:3600,expires_at:4102444800,user:{id:'synthetic-owner',email:'viewer@example.invalid'}};
const shift=data=>JSON.parse(JSON.stringify(data).replaceAll('2026-10-16','2026-10-19'));
const quote={complete:true,revision:'synthetic-pair',mode:'automatic',consulted_at:'2026-10-19T22:00:00Z',refresh:[{symbol:'OGN',status:'available'},{symbol:'USD/BRL',status:'available'}],
 stock:{value:13.75,quoted_at:'2026-10-19T20:00:02Z',received_at:'2026-10-19T21:00:00Z',source_name:'Yahoo Finance · NYSE',source_url:'https://finance.yahoo.com/quote/OGN/'},
 usd_brl:{value:5.0564,quoted_at:'2026-10-19T16:05:47Z',received_at:'2026-10-19T21:00:00Z',source_name:'Banco Central · PTAX venda',source_url:'https://ptax.bcb.gov.br/ptax_internet/consultarUltimaCotacaoDolar.do'}};
const bankEvent={event_date:'2026-10-19',account:'Itaú',description:'Pix fictício',signed_amount:-100,source:'open_finance',source_ref:BANK,open_finance_id:BANK,bank_confirmed:true,category:'A classificar',internal_transfer:false,excluded_from_spend:false};
async function run(browser,viewport,label){
 const context=await browser.newContext({viewport,isMobile:viewport.width<600,hasTouch:viewport.width<600,serviceWorkers:'block'});
 await context.addInitScript(session=>{
  const NativeDate=Date;window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:['2026-10-19T22:00:00Z']));}static now(){return NativeDate.parse('2026-10-19T22:00:00Z');}};
  localStorage.setItem('lts_supabase_session_v1',JSON.stringify(session));sessionStorage.setItem('lts_of_open_refresh_at',String(Date.now()));
 },signed);
 const page=await context.newPage();page.setDefaultTimeout(30000);
 let categories=['Assinaturas','Farmácia','Saúde','Vestuário','Categoria histórica'],mode='automatic',bankCategory='A classificar',cardCategory='A classificar';
 const errors=[],blocked=[],writes=[],assets=new Set(),assetErrors=[],assetReads=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url());if(u.origin===origin.origin&&u.pathname.startsWith('/releases/v291/')){const name=path.basename(u.pathname);if(manifest.files[name])assetReads.push(r.body().then(bytes=>{assert.equal(r.status(),200);assert.equal(sha(bytes),manifest.files[name]);assets.add(name);}).catch(e=>assetErrors.push(String(e))));}});
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());if(u.origin===origin.origin)return route.continue();
  if(u.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co'){blocked.push(u.origin+u.pathname);return route.abort();}
  const name=u.pathname.split('/').pop(),args=JSON.parse(req.postData()||'{}'),send=data=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(data)});
  if(u.pathname==='/auth/v1/token')return send(signed);
  if(u.pathname==='/auth/v1/logout')return send({});
  if(!u.pathname.startsWith('/rest/v1/rpc/')){blocked.push(u.pathname);return route.abort();}
  if(name==='lts_browser_category_create_v1'){writes.push({name,args});const cat=args.p_category==='Assinatura'?'Assinaturas':args.p_category;if(!categories.includes(cat))categories.push(cat);return send({ok:true,category:cat,categories});}
  if(name==='lts_browser_card_classify_v226'){writes.push({name,args});cardCategory=args.p_category;return send({ok:true});}
  if(name==='lts_browser_flow_classification_v290'){writes.push({name,args});bankCategory=args.p_category;return send({ok:true});}
  if(name==='lts_browser_market_mode_v290'){writes.push({name,args});mode=args.p_mode;return send({ok:true,mode});}
  if(/_decision_|_update_|_save_|_apply_|_delete_|_refresh_|_confirm_|_upload_|_mutate_|_classify_|_classification_|_create_/.test(name)){blocked.push(name);return route.abort();}
  if(name==='lts_browser_market_quotes_v290')return send({...quote,mode});
  if(name==='lts_browser_future_bank_v290')return send({rows:[{source_id:'synthetic-scheduled',date:'2026-11-02',bank:'Itaú',description:'Agendamento fictício',amount:-42,status:'scheduled',included_in_realized:false,included_in_flow_totals:false},{source_id:'synthetic-own',date:'2026-11-04',bank:'Itaú',description:'Transferência própria fictícia',amount:-80,status:'scheduled',identity:{own_identity_proven:true},included_in_realized:false,included_in_flow_totals:false}],card_future_received:2});
  if(/^lts_browser_invoice_flow_reconciliation_/.test(name))return send({rows:[{card_name:'Cartão fictício sem fatura',reference_month:'2026-10-01',due_date:'2026-10-05',documented_amount:90,flow_amount:90,difference:0,invoice_status:'projected',reconciliation_status:'reconciled'}],row_count:1,issue_count:0,reconciled_count:1});
  if(name==='lts_browser_card_category_options_v226')return send({categories,aliases:{Assinatura:'Assinaturas'},registry:'shared-v290'});
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:shift(fixture.product())});
  if(/^lts_browser_expense_review_queue_/.test(name))return send({row_count:1,matched_count:1,offset:0,next_offset:null,category_options:categories,pending_projections:[],beneficiary_options:[{value:'Lucas',label:'Minha / sem prefixo'},'Larissa','Benjamin','Rafiki'],rows:[{key:'synthetic-bank-review',source_table:'lts_open_finance_staging',source_ref:BANK,date:'2026-10-19',amount:100,description:'Pix fictício',account_source:'Itaú',category:bankCategory,question_kind:'classification',suggestion:{},beneficiary:null}]});
  if(/^lts_browser_card_cycles_/.test(name))return send({version:'card-cycles-v226',as_of:'2026-10-19',active_billing_accounts:1,cards:[{bank:'Itaú',family:'itau_mastercard',name:'Mastercard fictício',last4:'1234',status:'ACTIVE',cycles:[{month:'2026-10-01',due_date:'2026-10-12',amount:120,basis:'open_finance_invoice_v263',payment_status:'paid',settlement_confirmed:true,items:[]},{month:'2026-11-01',due_date:'2026-11-16',due_date_basis:'owner_confirmed_cycle_rule',amount:90,basis:'open_finance_composition',items:[]}]}]});
  if(/^lts_browser_card_detail_/.test(name))return send({basis:'open_finance_composition',complete:true,detail_total:90,items:[{source_id:CARD,purchase_date:'2026-10-13',description:'Compra fictícia',last4:'1234',amount:100,provider_status:'PENDING',category:cardCategory,category_basis:cardCategory==='A classificar'?'unresolved':'user_decision'},{source_id:'synthetic-credit',purchase_date:'2026-10-15',description:'Crédito fictício',last4:'1234',amount:-10,category:'Créditos / Estornos',category_basis:'user_decision'}]});
  const data=shift(fixture.response(name,args));
  if(/^lts_browser_flow_v/.test(name)){
   data.flow.observed_bank_movements={pending_projections:[],documentary_gaps:{}};
   data.flow.current_future.current_anchor_date='2026-10-19';
   data.flow.current_future.events=[{...bankEvent,category:bankCategory}].filter(e=>e.event_date>=args.p_from&&e.event_date<=args.p_to);
   for(const d of data.flow.current_future.days)if(d.date==='2026-10-19'){
    d.summary.events=1;d.summary.Consolidado.exits=100;
    Object.assign(d.Itaú,{opening_balance:1100,net:-100,balance:1000,balance_basis:'observed_bank_position_and_recent_movements',movements_complete:true});
    d.Consolidado.economic_net=-100;Object.assign(d.fix86_columns,{saldo_anterior:1100,saidas:100,saldo_final:1000});
   }
  }
  return send(data);
 });
 const screenshots=[];
 try{
  await page.goto(BASE+'/releases/v291/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let n=0;n<200;n++){frame=page.frames().find(f=>f.url().includes('/releases/v291/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V290_SOURCES?.installed);
  await frame.locator('#ltsMarketQuotes').waitFor();
  await frame.locator('.v226-upcoming [data-v226-family="itau_mastercard"]').first().waitFor();assert.match(await frame.locator('.v226-upcoming').innerText(),/16\/11\/2026/);assert.doesNotMatch(await frame.locator('.v226-upcoming').innerText(),/12\/10\/2026/,'Verified paid cycle cannot remain the next bill');
  assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/13,75/);assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/5,0564/);
  await frame.getByText('Elas ainda não alteram a projeção por conta.',{exact:false}).waitFor();
  const quoteDetails=frame.locator('#ltsMarketQuotes details');assert.equal(await quoteDetails.getAttribute('open'),null);
  await quoteDetails.locator('summary').click();assert.match(await quoteDetails.innerText(),/Data da cotação/);assert.match(await quoteDetails.innerText(),/Recebida no Wealth/);
  await frame.locator('[data-market-mode]').click();await frame.waitForFunction(()=>window.__LTS_V290_SOURCES.state.quotes?.mode==='manual');assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/Simulação manual ativa/);
  assert.equal(await frame.locator('#ltsMarketQuotes details').getAttribute('open'),'','The chosen update detail stays open after a mode change');
  await frame.locator('[data-market-mode]').click();await frame.waitForFunction(()=>window.__LTS_V290_SOURCES.state.quotes?.mode==='automatic');
  const navigate=async view=>{await frame.evaluate(view=>{V=view;renderNav();render();},view);await page.waitForTimeout(150);};
  await navigate('Atualizações');await frame.locator('[data-v181-category]').waitFor();
  const select=frame.locator('[data-v181-category]').first();await frame.waitForFunction(()=>document.querySelector('[data-v181-category]')?.options.length>=6);
  assert.equal(await select.locator('option',{hasText:/^Assinaturas$/}).count(),1);
  await select.selectOption('Saúde');await select.focus();assert(await select.evaluate(el=>{el.dataset.identity='kept';render();return el.isConnected&&document.activeElement===el;}),'Background render cannot replace an open native picker');
  assert.equal(await select.getAttribute('data-identity'),'kept');
  const create=frame.locator('#v181ReviewQueue .lts-new-category').first();await create.locator('summary').click();await create.locator('input').fill('Nova classificação de teste');
  const before=writes.length;await create.getByRole('button',{name:'Criar classificação',exact:true}).click();
  await frame.waitForFunction(()=>document.querySelector('[data-v181-category]')?.value==='Nova classificação de teste');
  assert.deepEqual(writes.slice(before).map(x=>x.name),['lts_browser_category_create_v1'],'Creating does not silently classify a transaction');
  assert.equal(await frame.locator('[data-v181-beneficiary]').inputValue(),'','No Lucas/Larissa inferred');
  await select.blur();
  await frame.evaluate(()=>window.__LTS_V226.openDetail('itau_mastercard','2026-11-01'));
  await frame.locator('#v226-detail [data-v226-classify]').waitFor({state:'attached'});
  const cardForm=frame.locator('#v226-detail [data-v226-classify]').first();
  await frame.locator('#v226-detail .v226-classify summary').first().click();
  assert.equal(await cardForm.locator('[name=category] option',{hasText:'Nova classificação de teste'}).count(),1);
  await cardForm.locator('[name=category]').selectOption('Nova classificação de teste');await cardForm.getByRole('button',{name:'Salvar categoria',exact:true}).click();
  await page.waitForTimeout(100);assert.equal(writes.findLast(x=>x.name==='lts_browser_card_classify_v226').args.p_beneficiary,null);
  await frame.locator('#v226-detail [data-v226-close]').click();
  await navigate('Fluxo Diário');await frame.evaluate(()=>loadFlowRange('2026-10-19','2026-10-19'));await frame.locator('#d-2026-10-19').waitFor();
  assert.equal(await frame.locator('.v274-ending-label').count(),0);assert.doesNotMatch(await frame.locator('#d-2026-10-19').innerText(),/encerramento do fluxo/i);
  for(const account of ['Consolidado','Itaú','Bradesco']){await frame.evaluate(account=>{ACC=account;render();},account);assert.doesNotMatch(await frame.locator('#d-2026-10-19').innerText(),/encerramento do fluxo/i);}
  await frame.evaluate(()=>{ACC='Itaú';render();});await frame.locator('#d-2026-10-19 .exp').click();await frame.locator('[data-flow-classify]').first().click();
  const flowForm=frame.locator('#ltsFlowClassification');await flowForm.locator('select[name=category]').waitFor();
  assert.equal(await flowForm.locator('option',{hasText:'Nova classificação de teste'}).count(),1);
  await flowForm.locator('[name=category]').selectOption('Nova classificação de teste');await flowForm.getByRole('button',{name:'Salvar classificação',exact:true}).click();
  await flowForm.waitFor({state:'detached'});assert.equal(writes.findLast(x=>x.name==='lts_browser_flow_classification_v290').args.p_beneficiary,null);
  for(const view of ['Dashboard','Fluxo Diário','Cartões','Despesas','Patrimônio','Atualizações']){
   await navigate(view==='Cartões'?'Despesas':view);
   if(view==='Cartões'){
    const tab=frame.getByRole('tab',{name:'Cartões e faturas',exact:true});await tab.click();
    assert.equal(await tab.getAttribute('aria-selected'),'true');await frame.locator('.v226-upcoming').waitFor();
    await frame.getByText('Previsão · compras e parcelas conhecidas',{exact:true}).waitFor();
   }else if(view==='Despesas')await frame.getByRole('tab',{name:'Visão geral',exact:true}).click();
   await page.waitForTimeout(150);
   const dimensions=await frame.locator('html').evaluate(e=>({client:e.clientWidth,scroll:e.scrollWidth}));assert(dimensions.scroll<=dimensions.client+2,view+' has page overflow '+JSON.stringify(dimensions));
   const file=label+'-'+view.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replaceAll(' ','_')+'.png';await page.screenshot({path:path.join(qa,file)});screenshots.push(file);
  }
  await Promise.all(assetReads);assert.deepEqual(assetErrors,[]);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  const required=[...new Set([...fs.readFileSync(path.join(root,'app.html'),'utf8').matchAll(/<script\b[^>]*\bsrc="([^"]+)"/g)].map(x=>x[1].split('?')[0]))];for(const name of required)assert(assets.has(name),'Missing real script '+name);
  return{pass:true,viewport,label,real_assets_checked:assets.size,network_substitutions:'synthetic API only',screenshots,checks:['source price/date/receipt separated','manual and automatic modes','one shared option','first native-picker interaction stable','create without implicit assignment','immediate reuse in Cards and Flow','no inferred beneficiary','clean cash rows across three views','all six screens fit viewport']};
 }catch(error){console.error(JSON.stringify({label,writes,errors,blocked}));await page.screenshot({path:path.join(qa,label+'-failure.png')});throw error;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(qa,'browser-results.json'),JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
