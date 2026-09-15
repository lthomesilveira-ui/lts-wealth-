"""Real V162 page with synthetic executive/monthly RPCs. No real financial session."""
import asyncio,datetime,functools,json,pathlib,threading
from http.server import SimpleHTTPRequestHandler,ThreadingHTTPServer
from urllib.parse import urlparse
from playwright.async_api import async_playwright
ROOT=pathlib.Path.cwd();TODAY=datetime.date(2026,9,14)
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*_):pass
server=ThreadingHTTPServer(('127.0.0.1',8786),functools.partial(Handler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
def rows():
 out=[]
 for m,c,b in [('07',80,13),('08',110,17),('09',130,19)]:
  out.append(dict(event_date=f'2026-{m}-01',competence_month=f'2026-{m}-01',transaction_date=None if m=='09' else f'2026-{m}-02',amount=c,description='Compra sintética '+m,description_raw='Compra sintética '+m,category='Restaurantes',center_cost='Não atribuído',counterparty='Loja de teste',is_card=True,is_credit=False,account='Cartão de teste',account_raw='Cartão de teste',card_name='Cartão de teste',source_table='card_invoice_current_items' if m=='09' else 'card_purchase_detail',source_ref='fixture-card-'+m,invoice_id='fixture-invoice-'+m,installments=None,installment_number=None,statement_state='open' if m=='09' else 'observed'))
  day=f'2026-{m}-10' if m!='09' else '2026-09-03'
  out.append(dict(event_date=day,competence_month=f'2026-{m}-01',transaction_date=day,amount=b,description='Despesa sintética '+m,description_raw='Despesa sintética '+m,category='Mercado',center_cost='Não atribuído',counterparty='Mercado de teste',is_card=False,is_credit=False,account='Itaú',account_raw='Itaú',source_table='daily_flow_documentary_bridge',source_ref='fixture-bank-'+m))
 return out
def product():
 return dict(flow={'days':[],'events':[]},updates={'items':[],'maintenance_checks':[],'freshness':{}},semantic_review={'pending_groups':0,'items':[]},card_classification_review={'pending_groups':0,'pending_lines':0,'items':[],'category_options':[]},card_operating={'open_cycles':[]},card_history={'units':[]},wealth_executive={'summary':{},'assets':{}},expenses={},wealth={},planning={},duplicate_quality_gate={},expense_drilldown={'rows':rows(),'row_count':6,'row_limit':None},expense_views={'card_detail_coverage':{'first_competence':'2026-07-01','last_competence':'2026-09-01','open_invoice_count':1},'quality':{}},expense_insights={'quality':{}},expense_universe_qa={'bank_documented_through':'2026-09-11'})
def flow(args):
 first=datetime.date.fromisoformat(args['p_from']);last=datetime.date.fromisoformat(args['p_to']);hist=[];future=[]
 for i in range((last-first).days+1):
  d=first+datetime.timedelta(days=i);item={'date':d.isoformat(),'historical':d<TODAY,'Itaú':{'balance':1000,'net':0},'Bradesco':{'balance':50,'net':0},'C6':{'balance':0,'net':0},'Consolidado':{'bank_balance':1050,'net':0,'economic_net':0},'fix86_columns':{'saldo_anterior':1050,'entradas':0,'saidas':0,'saldo_final':1050,'liq_d0_1_recurso':0,'saldo_apos_d0_1':1050,'rsus_vested':0,'saldo_apos_rsu':1050,'fgts':0,'saldo_apos_fgts':1050}}
  (hist if d<TODAY else future).append(item)
 return {'from':first.isoformat(),'to':last.isoformat(),'historical':{'days':hist,'events':[]},'current_future':{'days':future,'events':[]}}
def month_payload(month,category=None):
 end=(datetime.date.fromisoformat(month).replace(day=28)+datetime.timedelta(days=4)).replace(day=1)-datetime.timedelta(days=1)
 through=min('2026-09-14',str(end));chosen=[r for r in rows() if r['competence_month']==month and (category is None or r['category']==category)];categories={}
 for r in chosen:
  v=categories.setdefault(r['category'],{'total':0,'rows':0});v['total']+=r['amount'];v['rows']+=1
 total=sum(r['amount'] for r in chosen)
 return {'version':'expense-month-detail-v2-certified-category-allocation','month':month,'through':through,'category_filter':category,'rows':len(chosen),'total':total,'is_partial':month=='2026-09-01','category_unallocated_total':0,'category_allocated_history_total':0,'category_known_total':total,'categories':[{'name':k,**v} for k,v in sorted(categories.items(),key=lambda kv:-kv[1]['total'])],'items':[dict(event_date=r['event_date'],transaction_date=r['transaction_date'],amount=r['amount'],category=r['category'],center_cost=r['center_cost'],counterparty=r['counterparty'],source_table=r['source_table'],source_ref=r['source_ref'],detail_level='transaction',coverage_mode='card_detail_structured' if r['is_card'] else 'documentary_recent_bridge',origin_name=r['account_raw'],origin_type='cartão' if r['is_card'] else 'conta') for r in chosen]}
def executive(args):
 a,b=args['p_from'],args['p_to'];chosen=[r for r in rows() if a<=r['event_date']<=b];total=sum(r['amount'] for r in chosen);card=sum(r['amount'] for r in chosen if r['is_card']);months=[]
 for month in sorted(set(r['competence_month'] for r in chosen)):
  m=month_payload(month);cr=[r for r in chosen if r['competence_month']==month];months.append({'month':month,'total':m['total'],'rows':m['rows'],'card_total':sum(r['amount'] for r in cr if r['is_card']),'account_total':sum(r['amount'] for r in cr if not r['is_card']),'top_categories':m['categories'],'is_partial':month=='2026-09-01','category_detail_pct':100,'transaction_detail_pct':100,'mom_comparison_pct':25,'yoy_comparison_pct':30})
 cats=[{'name':'Restaurantes','rows':3,'total':320},{'name':'Mercado','rows':3,'total':49}];w={'total':369,'monthly_average':123,'financing_total':0,'known_category_total':369,'category_known_total':369,'category_unallocated_total':0,'category_detail_pct':100,'transaction_detail_pct':100,'top_categories':cats}
 return {'version':'expense-executive-v12-cached-effective-contract','period':{'from':a,'to':b,'months_in_selection':len(months),'last_available':'2026-09-03'},'summary':{'selected_total':total,'monthly_average':total/max(1,len(months)),'account_total':total-card,'card_total':card,'history_total':369},'monthly_detail':months,'yearly_detail':[],'rolling_windows':{k:dict(w) for k in ['3m','6m','12m']},'category_trends_12m':[],'rankings':{'categories':cats},'data_quality':{'selected_category_unallocated_total':0,'selected_category_allocated_history_total':0,'selected_category_detail_pct':100,'selected_transaction_detail_pct':100}}
async def main():
 results=[]
 async with async_playwright() as pw:
  browser=await pw.chromium.launch(headless=True,args=['--no-sandbox'])
  for label,width,height in [('desktop',1366,900),('mobile',390,844)]:
   errors=[];calls=[];mode={'error':False,'mismatch':False};frame=None
   context=await browser.new_context(viewport={'width':width,'height':height},timezone_id='America/Sao_Paulo')
   await context.add_init_script("const NativeDate=Date;const frozen=NativeDate.parse('2026-09-14T15:00:00Z');window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[frozen]))}static now(){return frozen}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture'}}));")
   async def route_handler(route):
    name=urlparse(route.request.url).path.split('/')[-1];args=route.request.post_data_json or {};calls.append(name)
    if any(part in name for part in ('mutate','semantic_feedback','category_create','manual_update')):raise AssertionError('Writer attempted')
    if name=='lts_browser_product_v1':body={'ok':True,'mvp':product()}
    elif name.startswith('lts_browser_flow_v'):body={'ok':True,'flow':flow(args)}
    elif name=='lts_browser_expense_executive_v3':
     if mode['error']:
      mode['error']=False;await route.fulfill(status=500,content_type='application/json',body=json.dumps({'message':'PRIVATE_DATABASE_DETAIL'}));return
     body=executive(args);await asyncio.sleep(0.35 if args['p_from']=='2026-04-01' else 0.02)
    elif name=='lts_browser_expense_month_detail_v2':
     body=month_payload(args['p_month'],args.get('p_category'))
     if mode['mismatch']:mode['mismatch']=False;body['total']+=1
     await asyncio.sleep(0.4 if args['p_month']=='2026-08-01' else 0.02)
    else:body={'ok':True}
    await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
   await context.route('https://*.supabase.co/**',route_handler)
   page=await context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
   try:
    await page.goto('http://127.0.0.1:8786/wip35-v162-candidate.html');await page.wait_for_function("document.getElementById('gate').hidden===true",timeout=25000)
    frame=next(f for f in page.frames if '/index.html?' in f.url);await frame.wait_for_function("window.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed===true",timeout=10000)
    assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
    await frame.locator('.nav [data-v="Despesas"]').click();await frame.wait_for_function("window.EX135?.phase==='ready'",timeout=15000)
    checks=['existing_V162_boot_flow36','actual_executive_route_loaded'];assert await frame.evaluate("window.EX135.data.summary.selected_total")==369
    assert await frame.locator('.lts-exp-source-notice').count()==1;assert 'posição provisória' in await frame.locator('.lts-exp-source-notice').inner_text();checks.append('source_freshness_and_open_period_notice')
    await frame.evaluate("ex135OpenMonth('2026-09-01')");assert await frame.evaluate("window.EX135.monthPhase")=='ready';assert await frame.evaluate("window.EX135.monthModel.actualTotalCents")==14900
    assert 'Data original não informada' in await frame.locator('.ex135-detail').inner_text();assert await frame.evaluate("window.__LTS_EXPENSE_SCREEN_ALIGNMENT.lastDetailParity") is True;checks.append('monthly_current_source_detail_no_fake_original_date')
    await frame.locator('[data-exp-category]').filter(has_text='Restaurantes').click();await frame.wait_for_function("window.EX135.monthPhase==='ready'&&window.EX135.monthCategory==='Restaurantes'");assert await frame.evaluate("window.EX135.monthModel.actualTotalCents")==13000;checks.append('category_buttons_safe_binding_and_exact_total')
    await frame.evaluate("ex135OpenMonth('2026-08-01');ex135OpenMonth('2026-09-01')");await frame.wait_for_function("window.EX135.monthPhase==='ready'&&window.EX135.monthData.month==='2026-09-01'");await page.wait_for_timeout(550);assert await frame.evaluate("window.EX135.monthModel.actualTotalCents")==14900;checks.append('late_august_month_cannot_replace_september')
    mode['mismatch']=True;await frame.evaluate("ex135OpenMonth('2026-09-01')");assert await frame.evaluate("window.EX135.monthPhase")=='error';assert await frame.evaluate("window.EX135.monthData===null");checks.append('detail_total_mismatch_fails_closed')
    await frame.evaluate("ex135OpenMonth('2026-09-01')");await frame.locator('[data-exp-close]').click();assert await frame.evaluate("window.EX135.month===null")
    await frame.evaluate("ex135SetRange('6m');ex135SetRange('ytd')");await frame.wait_for_function("window.EX135.phase==='ready'&&window.EX135.rangeKey==='ytd'");await page.wait_for_timeout(500);assert await frame.evaluate("window.EX135.data.period.from")=='2026-01-01';checks.append('late_executive_range_ignored')
    mode['error']=True;await frame.evaluate("ex135Load('ytd')");assert await frame.evaluate("window.EX135.phase")=='error';assert await frame.evaluate("window.EX135.data===null");assert 'PRIVATE_DATABASE_DETAIL' not in await frame.locator('body').inner_text();checks.append('error_clears_totals_and_redacts_raw_server_detail')
    await frame.evaluate("ex135Load('ytd')");assert await frame.evaluate("window.EX135.phase")=='ready';await frame.evaluate("ex135OpenMonth('2026-09-01')")
    overflow=await frame.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth');assert overflow<=2,(label,overflow);await page.screenshot(path=f'expense-screen-{label}.png',full_page=True);checks.append('responsive_width_no_horizontal_overflow')
    await frame.locator('.nav [data-v="Fluxo Diário"]').click();await frame.wait_for_function("!FLOWLOADING&&V==='Fluxo Diário'",timeout=20000);assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
    assert await frame.evaluate("window.EX135.data===null&&window.EX135.month===null");await frame.locator('[data-a="Itaú"]').click();assert await frame.locator('#flowFrom').input_value()=='2026-09-09';checks.append('return_to_flow_clears_expenses_preserves_default_bank_filter');assert not errors,errors
    results.append({'profile':label,'status':'PASS','checks':checks,'page_errors':errors,'real_financial_reads':0,'financial_writes':0,'test_scope':'real V162 source, synthetic intercepted RPCs; no personal user session'})
   except Exception as error:
    diagnostic=await frame.evaluate("JSON.stringify({route:V,executive:window.EX135,status:window.__LTS_EXPENSE_SCREEN_ALIGNMENT})") if frame else None
    print(json.dumps({'profile':label,'failure':str(error),'diagnostic':diagnostic,'errors':errors,'calls':calls},ensure_ascii=False),flush=True);await page.screenshot(path=f'expense-screen-{label}-failed.png',full_page=True);raise
   finally:await context.close()
  await browser.close()
 pathlib.Path('expense-screen-qa.json').write_text(json.dumps(results,ensure_ascii=False,indent=2));print(json.dumps(results,ensure_ascii=False,indent=2))
try:asyncio.run(main())
finally:server.shutdown()
