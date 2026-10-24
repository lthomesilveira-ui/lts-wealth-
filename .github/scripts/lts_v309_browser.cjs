'use strict';
// Real ordered release stack; only synthetic API responses. No production auth/data.
const {chromium}=require('playwright'),fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const fixture=require('./lts_v309_fixtures.cjs');
const BASE=process.env.LTS_TEST_BASE||'http://127.0.0.1:8788',origin=new URL(BASE),qa=path.resolve('qa/v309');
assert(['127.0.0.1','localhost'].includes(origin.hostname));fs.mkdirSync(qa,{recursive:true});
const root=path.resolve('releases/v309'),manifest=JSON.parse(fs.readFileSync(path.join(root,'manifest.json'))),sha=b=>crypto.createHash('sha256').update(b).digest('hex');
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
 let categories=['Assinaturas','Farmácia','Saúde','Vestuário','Categoria histórica','Reembolso plano de saúde'],mode='automatic',bankCategory='A classificar',cardCategory='A classificar',incomeFailure=false,expenseZero=false;
 const incomes=Array.from({length:30},(_,i)=>({source:'open_finance',source_ref:'synthetic-income-'+i,open_finance_id:'synthetic-income-'+i,event_date:'2026-10-19',account:'Itaú',description:'Recebimento fictício de finalidade não identificada '+i,signed_amount:100+i,category:'A classificar',editable:true,review_key:'synthetic-income-'+i}));
 const errors=[],blocked=[],writes=[],assets=new Set(),assetErrors=[],assetReads=[];
 page.on('pageerror',e=>errors.push(String(e)));
 page.on('response',r=>{const u=new URL(r.url());if(u.origin===origin.origin&&u.pathname.startsWith('/releases/v309/')){const name=path.basename(u.pathname);if(manifest.files[name])assetReads.push(r.body().then(bytes=>{assert.equal(r.status(),200);assert.equal(sha(bytes),manifest.files[name]);assets.add(name);}).catch(e=>assetErrors.push(String(e))));}});
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
  if(name==='lts_browser_income_review_queue_v296'){
   if(incomeFailure)return route.fulfill({status:500,contentType:'application/json',body:JSON.stringify({message:'RPC synthetic backend source_ref must never be rendered'})});
   const pending=incomes.filter(e=>e.category==='A classificar'),filtered=pending.filter(e=>!args.p_query||e.description.includes(args.p_query)),offset=Number(args.p_offset||0),limit=Number(args.p_limit||25);
   return send({ok:true,row_count:pending.length,matched_count:filtered.length,offset,next_offset:offset+limit<filtered.length?offset+limit:null,rows:filtered.slice(offset,offset+limit)});
  }
  if(name==='lts_browser_income_category_v183'){
   const e=incomes.find(e=>e.source_ref===args.p_source_ref);
   if(!e)return send({ok:false});
   if(args.p_category){writes.push({name,args});e.category=args.p_category;return send({ok:true,saved:true,cash_changed:false,category:e.category});}
   return send({ok:true,editable:e.category==='A classificar',options:categories,token:'synthetic-token',event:e});
  }
  if(/recurring_future_gap/.test(name))return send(fixture.recurring());
  if(/^lts_browser_monthly_/.test(name))return send(fixture.monthly(args.p_from,args.p_to));
  if(name==='lts_browser_market_quotes_v290')return send({...quote,mode});
  if(name==='lts_browser_future_bank_v293')return send({"rows":[{"source_id":"synthetic-scheduled","date":"2026-11-02","bank":"Itaú","description":"Agendamento fictício","amount":-42,"status":"scheduled","included_in_realized":false,"included_in_flow_totals":false},{"source_id":"synthetic-own","date":"2026-11-04","bank":"Itaú","description":"Transferência própria fictícia","amount":-80,"status":"scheduled","identity":{"own_identity_proven":true,"destination_confirmed":true,"represented_in_flow":true,"origin_bank":"Itaú","destination_bank":"Bradesco","projection_description":"Transferência entre contas · Itaú → Bradesco"},"included_in_realized":false,"included_in_flow_totals":true},{"source_id":"synthetic-own-c6","date":"2026-11-04","bank":"Itaú","description":"Transferência própria C6 fictícia","amount":-50,"status":"scheduled","identity":{"own_identity_proven":true,"destination_confirmed":true,"represented_in_flow":true,"origin_bank":"Itaú","destination_bank":"C6","projection_description":"Transferência entre contas · Itaú → C6"},"included_in_realized":false,"included_in_flow_totals":true},{"source_id":"synthetic-review","date":"2026-11-05","bank":"Itaú","description":"Transferência em conferência fictícia","amount":-60,"status":"scheduled","identity":{"own_identity_proven":true,"represented_in_flow":false},"included_in_realized":false,"included_in_flow_totals":false},{"source_id":"synthetic-overdue","date":"2025-10-17","bank":"Itaú","description":"Agendamento vencido fictício","amount":-30,"status":"overdue_unconfirmed","identity":{"own_identity_proven":true,"destination_confirmed":true,"represented_in_flow":false,"origin_bank":"Itaú","destination_bank":"Bradesco","projection_description":"Transferência entre contas · Itaú → Bradesco"},"included_in_realized":false,"included_in_flow_totals":false}],"card_future_received":2});
  if(/^lts_browser_invoice_flow_reconciliation_/.test(name))return send({rows:[{card_name:'Cartão fictício sem fatura',reference_month:'2026-10-01',due_date:'2026-10-05',documented_amount:90,flow_amount:90,difference:0,invoice_status:'projected',reconciliation_status:'reconciled'}],row_count:1,issue_count:0,reconciled_count:1});
  if(name==='lts_browser_card_category_options_v226')return send({categories,aliases:{Assinatura:'Assinaturas'},registry:'shared-v290'});
  if(name==='lts_browser_product_v1')return send({ok:true,mvp:shift(fixture.product())});
  if(/^lts_browser_expense_review_queue_/.test(name)&&expenseZero)return send({row_count:0,matched_count:0,offset:0,next_offset:null,category_options:categories,rows:[]});
  if(/^lts_browser_expense_review_queue_/.test(name))return send({row_count:1,matched_count:1,offset:0,next_offset:null,category_options:categories,pending_projections:[],beneficiary_options:[{value:'Lucas',label:'Minha / sem prefixo'},'Larissa','Benjamin','Rafiki'],rows:[{key:'synthetic-bank-review',source_table:'lts_open_finance_staging',source_ref:BANK,date:'2026-10-19',amount:100,description:'Pix fictício',account_source:'Itaú',category:bankCategory,question_kind:'classification',suggestion:{},beneficiary:null}]});
  if(/^lts_browser_card_cycles_/.test(name))return send({version:'card-cycles-v226',as_of:'2026-10-19',active_billing_accounts:1,cards:[{bank:'Itaú',family:'itau_mastercard',name:'Mastercard fictício',last4:'1234',status:'ACTIVE',cycles:[{month:'2026-10-01',due_date:'2026-10-12',amount:120,basis:'open_finance_invoice_v263',payment_status:'paid',settlement_confirmed:true,items:[]},{month:'2026-11-01',due_date:'2026-11-16',due_date_basis:'owner_confirmed_cycle_rule',amount:90,basis:'open_finance_composition',items:[]}]}]});
  if(/^lts_browser_card_detail_/.test(name))return send({basis:'open_finance_composition',complete:true,detail_total:90,items:[{source_id:CARD,purchase_date:'2026-10-13',description:'Compra fictícia',last4:'1234',amount:100,provider_status:'PENDING',category:cardCategory,category_basis:cardCategory==='A classificar'?'unresolved':'user_decision'},{source_id:'synthetic-credit',purchase_date:'2026-10-15',description:'Crédito fictício',last4:'1234',amount:-10,category:'Créditos / Estornos',category_basis:'user_decision'}]});
  const data=shift(fixture.response(name,args));
  if(/^lts_browser_wealth_detail_/.test(name)){
   fixture.contracts(data);
   data.rsu_summary={as_of:'2026-10-06',available_total_brl:300,vested_shares_brl:300,brokerage_cash_brl:0,future_regular_brl:695.26,future_cash_net_brl:243.34,future_considered_total_brl:938.60};
   data.morgan_statement={as_of:'2026-10-06',gross_total_brl:728.14,available_total_brl:300,available_components:{vested_shares_brl:300,brokerage_cash_brl:0},future_components:{regular_rsu_gross_brl:111,cash_rsu_gross_brl:317.14,cash_rsu_after_reserve_brl:222,future_after_reserve_brl:333},quantities:{future_regular_rsu:1,future_cash_rsu:2}};
   data.rsu.future_schedule=[{group_key:'synthetic-regular',asset_type:'RSU',eligibility_date:'2026-11-05',available_date:'2026-11-08',quantity:10,unit_price_usd:13.75,fx_rate:5.0564,gross_value_brl:695.26,net_value_brl:695.26},{group_key:'synthetic-cash',asset_type:'Cash RSU',eligibility_date:'2026-11-05',available_date:'2026-11-08',quantity:5,unit_price_usd:13.75,fx_rate:5.0564,gross_value_brl:347.63,net_value_brl:243.34}];
  }
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
  await page.goto(BASE+'/releases/v309/app.html',{waitUntil:'domcontentloaded'});
  let frame;for(let n=0;n<200;n++){frame=page.frames().find(f=>f.url().includes('/releases/v309/index.html'));if(frame)break;await page.waitForTimeout(50);}assert(frame);
  await frame.waitForFunction(()=>document.body.dataset.ltsBootState==='ready'&&window.__LTS_V290_SOURCES?.installed);
  await frame.locator('#ltsMarketQuotes').waitFor();
  await frame.locator('.v226-upcoming [data-v226-family="itau_mastercard"]').first().waitFor();assert.match(await frame.locator('.v226-upcoming').innerText(),/16\/11\/2026/);assert.doesNotMatch(await frame.locator('.v226-upcoming').innerText(),/12\/10\/2026/,'Verified paid cycle cannot remain the next bill');
  assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/13,75/);assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/5,0564/);
  await frame.locator('#ltsFutureBank > .lts-future-list > summary').filter({hasText:'Agendamentos · 5'}).waitFor();
  const compact=frame.locator('#ltsFutureBank');
  assert.match(await compact.innerText(),/3 agendamentos a conferir/,'Material omissions and overdue payments remain visible');
  assert.doesNotMatch(await compact.innerText(),/vínculo|confirmações pendentes|incluídas nas previsões|somado duas vezes|recebidas dos cartões|Nenhum foi tratado|sem realização comprovada|backend|provedor|RPC|source_ref/i);
  const scheduleHeight=await (await frame.waitForFunction(()=>{const el=document.querySelector('#ltsFutureBank');if(!el)return false;const r=el.getBoundingClientRect();return r.height>0?r.height:false;})).jsonValue();
  assert(scheduleHeight<175,'Collapsed schedules cannot occupy the screen: '+scheduleHeight);
  assert.equal(await compact.locator('.lts-future-list').getAttribute('open'),null);
  assert.equal(await compact.locator('.lts-schedule-update').getAttribute('open'),null);
  await compact.getByRole('button',{name:'Ver agendamentos',exact:true}).click();
  assert.equal(await compact.locator('.lts-future-list').getAttribute('open'),'');
  assert.match(await compact.innerText(),/17\/10\/2025.*Pagamento a confirmar/,'Old pending source is neither dropped nor called paid');
  assert.match(await compact.innerText(),/Ainda fora da previsão/,'A missing forecast remains identifiable');
  await compact.locator('.lts-future-list > summary').click();
  await compact.locator('.lts-schedule-update > summary').click();
  assert.match(await compact.innerText(),/Compras e parcelas futuras dos cartões: 2/);
  await compact.locator('.lts-schedule-update > summary').click();
  const quoteDetails=frame.locator('#ltsMarketQuotes details');assert.equal(await quoteDetails.getAttribute('open'),null);
  await quoteDetails.locator('summary').click();assert.match(await quoteDetails.innerText(),/Data da cotação/);assert.match(await quoteDetails.innerText(),/Recebida no Wealth/);
  await frame.locator('[data-market-mode]').click();await frame.waitForFunction(()=>window.__LTS_V290_SOURCES.state.quotes?.mode==='manual');assert.match(await frame.locator('#ltsMarketQuotes').innerText(),/Simulação manual ativa/);
  assert.equal(await frame.locator('#ltsMarketQuotes details').getAttribute('open'),'','The chosen update detail stays open after a mode change');
  await frame.locator('[data-market-mode]').click();await frame.waitForFunction(()=>window.__LTS_V290_SOURCES.state.quotes?.mode==='automatic');
  const navigate=async view=>{await frame.evaluate(view=>{V=view;renderNav();render();},view);await page.waitForTimeout(150);};
  await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS?.installed&&window.__LTS_V296_CLASSIFICATIONS.state.data);
  await navigate('Atualizações');await frame.locator('[data-v181-category]').waitFor();
  await frame.locator('#v296IncomeQueue [data-income-review]').first().waitFor();
  assert.match(await frame.locator('[data-v="Atualizações"]').first().getAttribute('aria-label'),/31 classificações/);
  const actionsNav=frame.locator(viewport.width<820?'[data-mobile-route="Atualizações"]':'[data-v="Atualizações"]').first();
  await actionsNav.locator('.lts-classification-badge').waitFor({state:'visible'});
  assert.equal(await actionsNav.locator('.lts-classification-badge').innerText(),'31');
  await frame.waitForFunction(selector=>{const button=document.querySelector(selector),el=button?.querySelector('.lts-classification-badge');if(!el||el.textContent!=='31')return false;const r=el.getBoundingClientRect(),b=button.getBoundingClientRect();return r.width>0&&r.height>0&&r.left>=b.left&&r.right<=b.right&&r.top>=b.top&&r.bottom<=b.bottom;},viewport.width<820?'[data-mobile-route="Atualizações"]':'[data-v="Atualizações"]');
  assert.equal(await frame.locator('#v296IncomeQueue .lts-income-row').count(),25);
  await frame.locator('[data-income-next]').click();await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS.state.data.offset===25);
  assert.equal(await frame.locator('#v296IncomeQueue .lts-income-row').count(),5);
  await frame.locator('[data-income-prev]').click();await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS.state.data.offset===0);
  await frame.locator('#v296IncomeQueue [data-income-review]').first().click();
  const incomeDialog=frame.locator('#v183-income-dialog');
  await incomeDialog.locator('select[data-lts-category]').waitFor();
  assert.equal(await incomeDialog.locator('select option').filter({hasText:/^Reembolso plano de saúde$/}).count(),1);
  const incomeCreate=incomeDialog.locator('.lts-new-category');await incomeCreate.locator('summary').click();
  await incomeCreate.locator('input').fill('Receita de teste compartilhada');
  const beforeIncomeCreate=writes.length;await incomeCreate.getByRole('button',{name:'Criar classificação',exact:true}).click();
  await frame.waitForFunction(()=>document.querySelector('#v183-income-category')?.value==='Receita de teste compartilhada');
  assert.deepEqual(writes.slice(beforeIncomeCreate).map(x=>x.name),['lts_browser_category_create_v1']);
  await incomeDialog.getByRole('button',{name:'Salvar somente esta categoria',exact:true}).click();
  await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS.state.data.row_count===29&&!window.__LTS_V296_CLASSIFICATIONS.state.loading);
  assert.equal(await frame.evaluate(()=>V),'Atualizações','Saving a receipt must preserve the Actions route');
  const incomeWrite=writes.findLast(x=>x.name==='lts_browser_income_category_v183');
  assert.equal(incomeWrite.args.p_amount,100);assert.equal(incomeWrite.args.p_category,'Receita de teste compartilhada');
  assert.equal(incomeWrite.args.p_expected,'synthetic-token');assert(!Object.hasOwn(incomeWrite.args,'p_beneficiary'));
  await incomeDialog.getByRole('button',{name:'Fechar',exact:true}).click();
  await frame.locator('#v237CoverageAudit [data-coverage-key]').first().waitFor();
  assert.equal(await frame.locator('#v237CoverageAudit [data-coverage-key]').count(),17);
  const geometry=await frame.locator('#v237CoverageAudit .v168-action').evaluateAll(rows=>rows.map(row=>{
   const text=row.children[0].getBoundingClientRect(),button=row.children[1].getBoundingClientRect(),r=row.getBoundingClientRect();
   return{width:text.width,overlap:Math.min(text.right,button.right)>Math.max(text.left,button.left)+1&&Math.min(text.bottom,button.bottom)>Math.max(text.top,button.top)+1,outside:text.right>r.right+1||button.right>r.right+1,monthOutside:[...row.querySelectorAll('.v268-period')].some(e=>e.getBoundingClientRect().right>r.right+1)};
  }));
  assert(geometry.every(x=>x.width>180&&!x.overlap&&!x.outside&&!x.monthOutside),'Coverage text, month buttons and action must not overlap: '+JSON.stringify(geometry));
  await frame.waitForFunction(()=>window.__LTS_V308_REVIEW_LAYOUT?.installed);
  const audit=frame.locator('#v237CoverageAudit'),auditRows=audit.locator('[data-coverage-key]'),firstAudit=auditRows.first();
  assert.equal(await audit.locator('.lts-coverage-months[open]').count(),0,'Months start collapsed');
  assert.match(await audit.locator('.lts-coverage-count').innerText(),/17 de 17 séries · 2026/);
  const collapsedHeight=(await firstAudit.boundingBox()).height;
  assert(collapsedHeight<350,'A collapsed row stays concise even with a long title: '+collapsedHeight);
  assert.match(await firstAudit.innerText(),/pagamento\(s\) a confirmar/,'Unconfirmed payments stay visible while collapsed');
  assert.match(await firstAudit.innerText(),/sem previsão/,'Missing forecasts stay visible while collapsed');
  assert.equal(await firstAudit.locator('.v268-period:visible').count(),0);
  await firstAudit.locator('.lts-coverage-months>summary').click();
  assert.equal(await firstAudit.locator('.v268-period:visible').count(),12);
  assert((await firstAudit.boundingBox()).height>collapsedHeight+50);
  await frame.evaluate(()=>render());
  assert.equal(await firstAudit.locator('.lts-coverage-months').getAttribute('open'),'','Background rendering preserves expanded periods');
  const auditFilter=audit.getByLabel('Filtrar séries de projeção');
  await auditFilter.selectOption('gap');
  assert.equal(await audit.locator('[data-coverage-key]:visible').count(),12);
  assert.match(await audit.locator('.lts-coverage-count').innerText(),/12 de 17 séries/);
  await auditFilter.selectOption('awaiting');
  assert.equal(await audit.locator('[data-coverage-key]:visible').count(),11);
  assert.match(await audit.locator('.lts-coverage-count').innerText(),/11 de 17 séries/);
  await auditFilter.blur();await frame.evaluate(()=>render());
  assert.equal(await auditFilter.inputValue(),'awaiting','Background rendering preserves the filter');
  const yearPicker=audit.getByLabel('Ano da auditoria');await yearPicker.selectOption('2027');await yearPicker.blur();await audit.locator('h2').click();
  await frame.waitForFunction(()=>document.querySelector('.lts-coverage-count')?.textContent==='17 de 17 séries · 2027');
  assert.equal(await audit.locator('.lts-coverage-months[open]').count(),0,'Each year has independent expansion state');
  await auditFilter.selectOption('awaiting');
  assert.match(await audit.locator('.lts-coverage-count').innerText(),/0 de 17 séries/);
  assert(await audit.locator('.lts-coverage-empty').isVisible(),'An empty filter cannot look like an empty backlog');
  await yearPicker.selectOption('2026');await yearPicker.blur();await audit.locator('h2').click();
  await frame.waitForFunction(()=>document.querySelector('.lts-coverage-count')?.textContent==='11 de 17 séries · 2026');
  assert.equal(await firstAudit.locator('.lts-coverage-months').getAttribute('open'),'');
  await auditFilter.selectOption('all');await auditFilter.blur();
  await firstAudit.locator('.lts-coverage-months>summary').click();
  const periodButton=firstAudit.locator(':scope>button[data-v237-coverage-from]'),periodFrom=await periodButton.getAttribute('data-v237-coverage-from'),periodTo=await periodButton.getAttribute('data-v237-coverage-to');
  await periodButton.click();
  await frame.waitForFunction(({from,to})=>V==='Fluxo Diário'&&FLOWFROM===from&&FLOWTO===to,{from:periodFrom,to:periodTo});
  const flowNav=frame.locator(viewport.width<820?'[data-mobile-route="Dashboard"]':'[data-v="Dashboard"]').first();
  await flowNav.click();await frame.locator('.v168-dashboard').waitFor();
  const backToActions=frame.locator(viewport.width<820?'[data-mobile-route="Atualizações"]':'[data-v="Atualizações"]').first();
  await backToActions.click();await audit.waitFor();
  await frame.locator('#v237CoverageAudit').evaluate(el=>el.scrollIntoView({block:'start',behavior:'instant'}));
  await page.screenshot({path:path.join(qa,label+'-Actions-coverage.png')});
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
  await frame.locator('[data-income-next]').click();await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS.state.data.offset===25);
  assert.equal(await frame.locator('#v296IncomeQueue .lts-income-row').count(),4,'A deferred render must not duplicate pagination handlers');
  await frame.locator('[data-income-prev]').click();await frame.waitForFunction(()=>window.__LTS_V296_CLASSIFICATIONS.state.data.offset===0);
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
  await frame.locator('#ltsFlowOverdueProjections').waitFor({state:'hidden'});
  assert.doesNotMatch(await frame.locator('body').innerText(),/Nenhuma previsão vencida nesta lista recebida/);
  for(const account of ['Consolidado','Itaú','Bradesco']){await frame.evaluate(account=>{ACC=account;render();},account);assert.doesNotMatch(await frame.locator('#d-2026-10-19').innerText(),/encerramento do fluxo/i);}
  for(const [account,total]of [['Itaú',5],['Bradesco',2],['C6',1]]){
   await frame.evaluate(account=>{ACC=account;render();},account);
   await frame.locator('#ltsFutureBank > .lts-future-list > summary').click();
   assert.equal(await frame.locator('#ltsFutureBank .lts-future-row').count(),total,'Include incoming schedules in destination '+account);
   const ownRow=frame.locator('#ltsFutureBank .lts-future-row').filter({has:frame.locator('[data-future-day="2026-11-04"]')}).first();
   assert.match(await ownRow.innerText(),/Previsto/);
   assert.doesNotMatch(await ownRow.innerText(),/realizado|pago/i,'A schedule cannot be described as paid');
   const amount=await ownRow.locator('strong').innerText();
   if(account==='Itaú')assert.match(amount,/-/);else assert.doesNotMatch(amount,/-/,'Incoming schedule cannot show an outgoing amount');
   if(account==='C6')assert.match(amount,/50,00/);
  }
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
   if(view==='Patrimônio'){
    await frame.locator('.v172-future').waitFor();assert.match(await frame.locator('.v172-future').innerText(),/938,60/);
    await frame.getByRole('tab',{name:'RSUs e awards',exact:true}).click();await frame.locator('.v172-morgan').waitFor();
    assert.match(await frame.locator('.v172-morgan .v168-kpi').filter({hasText:'A receber líquido projetado'}).innerText(),/938,60/);
    assert.match(await frame.locator('.v172-morgan .v168-kpi').filter({hasText:'Total bruto do extrato'}).innerText(),/728,14/);
    const archive=frame.locator('.v183-statement-remainders + details');await archive.locator('summary').click();assert.match(await archive.innerText(),/333,00/);
    await frame.getByRole('tab',{name:'Bens e dívidas',exact:true}).click();
    const mortgage=frame.locator('[data-v309-contract="cipo_396"]'),vehicle=frame.locator('[data-v309-contract="volvo"]');
    await mortgage.waitFor();
    assert.match(await mortgage.innerText(),/Saldo documental.*900,00/s);
    assert.match(await mortgage.innerText(),/Pagas comprovadas\s*6/);
    assert.match(await mortgage.innerText(),/Previstas\s*2/);
    assert.match(await mortgage.innerText(),/Próxima prevista: 20\/11\/2020/);
    assert.match(await vehicle.innerText(),/Pagas comprovadas\s*0/,'Two elapsed dates do not become two paid installments');
    assert.match(await vehicle.locator('[data-v309-unconfirmed]').innerText(),/2 parcela/);
    await mortgage.locator('[data-v168-loan]').click();
    const contractDialog=frame.locator('.v168-modal-bg');
    await frame.locator('[data-v309-payments]').waitFor();
    assert.equal(await frame.locator('[data-v309-payments] tbody tr').count(),2);
    assert.match(await frame.locator('[data-v309-payments] tbody tr').first().innerText(),/20\/09\/2020.*100,00.*21\/09\/2020.*101,00/);
    assert.match(await frame.locator('[data-v309-payments] tbody tr').nth(1).innerText(),/90,00.*20\/10\/2020.*92,00/);
    assert.equal(await frame.locator('[data-v309-schedule] tbody tr').count(),2);
    assert.match(await frame.locator('[data-v309-schedule]').innerText(),/Saldo previsto/i);
    assert.doesNotMatch(await frame.locator('[data-v309-schedule]').innerText(),/Paga/);
    assert.doesNotMatch(await contractDialog.innerText(),/Quitar pela posição atual/);
    await page.screenshot({path:path.join(qa,label+'-Contract-payments.png')});
    await contractDialog.getByRole('button',{name:'Fechar',exact:true}).click();
    await vehicle.locator('[data-v168-loan]').click();
    assert.equal(await frame.locator('[data-v309-payments]').count(),0);
    assert.equal(await frame.locator('[data-v309-schedule] tbody tr').filter({hasText:'Pagamento a confirmar'}).count(),2);
    assert.match(await contractDialog.innerText(),/Nenhum pagamento individual identificado/);
    const contractDimensions=await frame.locator('html').evaluate(e=>({client:e.clientWidth,scroll:e.scrollWidth}));
    assert(contractDimensions.scroll<=contractDimensions.client+2,'Contract modal must fit the viewport');
    await page.screenshot({path:path.join(qa,label+'-Contract-unconfirmed.png')});
    await contractDialog.getByRole('button',{name:'Fechar',exact:true}).click();
    assert.equal(await frame.evaluate(()=>V),'Patrimônio');
    await frame.getByRole('tab',{name:'Visão geral',exact:true}).click();
   }
   await page.waitForTimeout(150);
   assert.doesNotMatch(await frame.locator('body').innerText(),/\bbackend\b|\bRPC\b|source_ref|\bsnapshot\b|posição do provedor|encerramento do fluxo/i,view+' cannot expose implementation language');
   const dimensions=await frame.locator('html').evaluate(e=>({client:e.clientWidth,scroll:e.scrollWidth}));assert(dimensions.scroll<=dimensions.client+2,view+' has page overflow '+JSON.stringify(dimensions));
   const file=label+'-'+view.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replaceAll(' ','_')+'.png';await page.screenshot({path:path.join(qa,file)});screenshots.push(file);
  }
  await Promise.all(assetReads);assert.deepEqual(assetErrors,[]);assert.deepEqual(errors,[]);assert.deepEqual(blocked,[]);
  await navigate('Despesas');await frame.evaluate(()=>{window.__LTS_V168_STATE.expense.tab='monthly';render();});
  await frame.locator('.v175-monthly [data-lts-category-key="Reembolsos e restituições"]').waitFor();
  assert.match(await frame.locator('.v175-monthly [data-lts-category-key="Reembolsos e restituições"]').innerText(),/150,00/);
  assert.equal(await frame.locator('.lts-report-update').getAttribute('open'),null);
  assert.doesNotMatch(await frame.locator('.v175-monthly').innerText(),/workbook|leitura integral concluída|carregamento anual de contingência|backend|source_ref|RPC/i);
  await page.screenshot({path:path.join(qa,label+'-Monthly-report.png')});
  expenseZero=true;
  await frame.evaluate(()=>{const r=window.__LTS_V181_STATE.review;r.status='ready';r.data={row_count:0,rows:[]};return window.__LTS_V296_CLASSIFICATIONS.refresh();});
  assert.match(await frame.locator('[data-v="Atualizações"]').first().getAttribute('aria-label'),/29 classificações/,'Income-only pending is visible even when expense queue is zero');
  incomeFailure=true;await navigate('Atualizações');await frame.evaluate(()=>window.__LTS_V296_CLASSIFICATIONS.refresh());
  assert.match(await frame.locator('#v296IncomeQueue').innerText(),/lista anterior pode estar desatualizada/);
  assert.doesNotMatch(await frame.locator('#v296IncomeQueue').innerText(),/RPC|backend|source_ref/);
  assert.match(await frame.locator('[data-v="Atualizações"]').first().getAttribute('aria-label'),/pelo menos 29/,'A failed refresh must not report zero');
  incomeFailure=false;await frame.evaluate(()=>window.__LTS_V296_CLASSIFICATIONS.refresh());
  await navigate('Dashboard');await frame.waitForFunction(()=>[...document.querySelectorAll('.v168-dashboard .v168-kpi')].some(e=>e.textContent.includes('Total de posições futuras')&&e.textContent.includes('938,60')));
  const required=[...new Set([...fs.readFileSync(path.join(root,'app.html'),'utf8').matchAll(/<script\b[^>]*\bsrc="([^"]+)"/g)].map(x=>x[1].split('?')[0]))];for(const name of required)assert(assets.has(name),'Missing real script '+name);
  return{pass:true,viewport,label,real_assets_checked:assets.size,network_substitutions:'synthetic API only',screenshots,checks:['dated contract next installment','no inferred vehicle payments','actual payment date and value beside original schedule','unconfirmed past installments stay distinct','dated debt stock is not payoff','contract dialogs fit mobile','native collapsed months retain material warnings','filter count and explicit empty state','filter and expansion survive background renders','independent choices by year','exact period opens Flow and physical navigation returns to Dashboard','360px schedule density preserves touch targets','income pending list and pagination','one shared registry for receipts, Flow and Cards','create then exact category-only receipt save','receipt save preserves Actions','income-only pending badge','failed reads preserve uncertainty and hide raw errors','17 populated monthly coverage rows without overlap','source price/date/receipt separated','manual and automatic modes','one shared option','first native-picker interaction stable','create without implicit assignment','immediate reuse in Cards and Flow','no inferred beneficiary','clean cash rows across three views','all six screens fit viewport','confirmed own transfers visible in both accounts','incoming/outgoing signs correct','overdue pending source remains visible without payment','disjoint schedule counters']};
 }catch(error){console.error(JSON.stringify({label,writes,errors,blocked}));await page.screenshot({path:path.join(qa,label+'-failure.png')});throw error;}finally{await context.close();}
}
(async()=>{const browser=await chromium.launch({headless:true});try{const results=[];for(const [viewport,label]of [[{width:1440,height:1000},'desktop'],[{width:390,height:844},'mobile-390'],[{width:360,height:800},'mobile-360']])results.push(await run(browser,viewport,label));fs.writeFileSync(path.join(qa,'browser-results.json'),JSON.stringify({pass:true,results},null,2));console.log(JSON.stringify({pass:true,results}));}finally{await browser.close();}})().catch(error=>{console.error(error);process.exitCode=1;});
