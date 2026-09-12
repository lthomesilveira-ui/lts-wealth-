"""Isolated consumer fixtures. No credentials or user financial data in CI."""
import asyncio, datetime as dt, functools, json, pathlib, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=pathlib.Path.cwd()
TODAY=dt.date(2026,9,12)
CARDS=[
 {'date':'2026-09-14','due':'2026-09-12','name':'Fatura Personnalite Black Pontos final 5546','account':'Itaú','open':False},
 {'date':'2026-09-25','due':'2026-09-25','name':'Fatura Visa Aeternum','account':'Bradesco','open':True},
 {'date':'2026-09-08','due':'2026-09-08','name':'Fatura C6 Carbon · grupo 7873/8304','account':'C6','open':False,'credit':True},
 {'date':'2026-09-18','due':'2026-09-18','name':'Fatura Visa Infinite Prime','account':'Bradesco','open':False},
 {'date':'2026-09-20','due':'2026-09-20','name':'Fatura Visa Infinite Itaú','account':'Itaú','open':False},
 {'date':'2026-09-21','due':None,'name':'Gastos Cartão de Crédito','account':'Bradesco','unknown':True},
]
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args): pass

def product(classified):
 return {'flow':{'days':[],'events':[]},'updates':{'items':[],'maintenance_checks':[],'freshness':{}},'semantic_review':{'pending_groups':0,'items':[]},'card_classification_review':{'pending_groups':0 if classified else 1,'pending_lines':0 if classified else 1,'pending_value':0 if classified else 100,'category_options':['Casa','Saúde'],'items':[] if classified else [{'description_key':'fixture pendente','example_description':'Fixture pendente','card_name':'Cartão de teste','due_date':'2026-09-14','total_value':100,'occurrences':1}]},'card_operating':{'open_cycles':[]},'card_history':{'units':[]},'wealth_executive':{'summary':{},'assets':{}},'expenses':{},'wealth':{},'planning':{},'duplicate_quality_gate':{}}

def flow(args):
 first=dt.date.fromisoformat(args['p_from']);last=dt.date.fromisoformat(args['p_to']);hist=[];future=[]
 for i in range((last-first).days+1):
  day=first+dt.timedelta(days=i);date=day.isoformat()
  item={'date':date,'historical':day<TODAY,'Itaú':{'balance':6000,'net':0},'Bradesco':{'balance':5000,'net':0},'C6':{'balance':1000,'net':0},'Consolidado':{'bank_balance':12000,'net':0,'economic_net':0},'fix86_columns':{'saldo_anterior':12000,'entradas':0,'saidas':0,'saldo_final':12000,'liq_d0_1_recurso':500,'saldo_apos_d0_1':12500,'rsus_vested':0,'saldo_apos_rsu':12500,'fgts':0,'saldo_apos_fgts':12500},'reconciliation_gaps':{'Bradesco':0.02} if date=='2026-09-11' else {}}
  (hist if day<TODAY else future).append(item)
 events=[{'event_date':c['date'],'original_date':c['due'] or c['date'],'account':c['account'],'description':c['name'],'signed_amount':-1000,'category':'Cartão de Crédito','source':'current_event' if c.get('unknown') else 'card_invoice','source_ref':'fixture-'+str(i),'confidence':'documented_expected'} for i,c in enumerate(CARDS) if first.isoformat()<=c['date']<=last.isoformat()]
 return {'from':first.isoformat(),'to':last.isoformat(),'historical':{'days':hist,'events':[e for e in events if e['event_date']<TODAY.isoformat()]},'current_future':{'days':future,'events':[e for e in events if e['event_date']>=TODAY.isoformat()]},'bank_evidence_as_of':[{'bank':b,'date':'2026-09-11','documentary_balance':v} for b,v in [('Itaú',6000),('Bradesco',5000),('C6',1000)]]}

def invoice(args,classified):
 matches=[c for c in CARDS if c['date']==args['p_event_date'] and c['name']==args['p_description'] and c['account']==args['p_account'] and args['p_amount']==1000]
 assert len(matches)==1,('Caller lost exact bank/date/name',args)
 c=matches[0]
 if c.get('unknown'):return {'matched':False,'reason':'no_exact_documented_cycle','purchases':[]}
 ps=[{'description':'Casa documentada','category':'Casa','amount':700,'purchase_date':None if c['open'] else '2026-08-20','date_printed':'20/08' if c['open'] else None,'card_final':'9222' if c['open'] else '5546','row_id':'1'},
     {'description':'Saúde documentada','category':'Saúde','amount':310 if c.get('credit') else 200,'purchase_date':None,'row_id':'2'},
     {'description':'Estorno de tarifa' if c.get('credit') else 'Fixture pendente','category':'Casa' if classified and not c.get('credit') else 'A classificar','amount':-10 if c.get('credit') else 100,'purchase_date':None,'row_id':'3'}]
 return {'matched':True,'card_name':c['name'].removeprefix('Fatura '),'open_cycle':c['open'],'statement_state':'open' if c['open'] else 'closed','invoice_total':1000,'invoice_credit':0,'detail_lines':3,'cash_detail_delta':0,'detail_complete':True,'cash_reconciled':True,'purchases':ps,'due_date':c['due'],'cash_event_date':c['date'],'evidence_as_of':'2026-09-11','payment_documented':bool(c.get('credit'))}

async def main():
 results=[]
 async with async_playwright() as p:
  for engine,label,viewport in [(p.chromium,'desktop',{'width':1440,'height':900}),(p.chromium,'mobile',{'width':390,'height':844}),(p.webkit,'webkit-mobile',{'width':390,'height':844})]:
   browser=await engine.launch(headless=True)
   context=await browser.new_context(viewport=viewport,timezone_id='America/Sao_Paulo')
   await context.add_init_script("const NativeDate=Date;const fixed=NativeDate.parse('2026-09-12T15:00:00Z');window.Date=class extends NativeDate{constructor(...a){super(...(a.length?a:[fixed]))}static now(){return fixed}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture-only',expires_at:4102444800,user:{id:'fixture-user'}}));")
   state={'classified':False,'semantic_calls':0,'financial_writes':0};requests=[];errors=[]
   async def rpc(route):
    request=route.request;name=request.url.split('/')[-1];args=request.post_data_json or {};requests.append({'name':name,'args':args})
    if name=='lts_browser_product_v1':body={'ok':True,'mvp':product(state['classified'])}
    elif name.startswith('lts_browser_flow_v'):body={'ok':True,'flow':flow(args)}
    elif name=='lts_browser_card_settlement_detail_v2':body=invoice(args,state['classified'])
    elif name=='lts_browser_semantic_feedback_v1':
     assert args['p_description_key']=='fixture pendente' and args['p_category']=='Casa'
     state['classified']=True;state['semantic_calls']+=1;body={'ok':True}
    elif 'mutate' in name or 'apply' in name:
     state['financial_writes']+=1;raise AssertionError('Unrequested financial writer '+name)
    else:body={'ok':True,'rows':[],'total':0}
    await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
   await context.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',rpc)
   page=await context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
   await page.goto('http://127.0.0.1:8779/wip35-v162-candidate.html',wait_until='domcontentloaded')
   await page.wait_for_function("document.getElementById('gate')?.hidden===true",timeout=25000)
   frame=next(f for f in page.frames if 'index.html?v162' in f.url)
   await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-07'&&FLOWTO==='2026-10-12'",timeout=25000)
   assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
   assert 'Saldos documentados' in await frame.locator('#ltsBankEvidence').inner_text()
   assert '0,02' in await frame.locator('#ltsReconciliationWarning').inner_text()
   verified=[]
   for index,c in enumerate(CARDS):
    row=frame.locator('#d-'+c['date']);await row.locator('[data-d="'+c['date']+'"]').click()
    detail=frame.locator('#d-'+c['date']+' + .fx89-details')
    event=detail.locator('.fx89-detail-row').filter(has_text=c['name']).first
    await event.locator('.carddetailbtn').click()
    panel=frame.locator('.lts-invoice-unified');await panel.wait_for(state='visible')
    await frame.wait_for_function('!CARDDETAILLOADING')
    assert await panel.get_attribute('data-invoice-contract')=='all-cards-aeternum-summary-source-v1'
    text=await panel.inner_text();assert 'Resumo da fatura' in text
    if c.get('unknown'):
     assert 'Sem fatura documental' in text and await panel.locator('#openCardFull').count()==0
    else:
     assert 'Por categoria' in text and 'Detalhe confere' in text
     values=await panel.locator('[data-category-total]').evaluate_all('(nodes)=>nodes.map(n=>Number(n.dataset.categoryTotal))')
     assert values==sorted(values,reverse=True)
     if 'Personnalite' in c['name']:assert '12/09/2026' in text and '14/09/2026' in text
     if c.get('credit'):
      assert 'crédito(s)/estorno(s)' in text and 'R$ 10,00' in text and 'Não é uma nova despesa' in text
     await panel.locator('#openCardFull').click()
     assert await panel.locator('.lts-source-line').count()==3
     if c['open']:
      assert 'ano não informado' in await panel.inner_text()
      assert 'final 9222' in await panel.inner_text()
     if c.get('credit'):assert 'Crédito / estorno' in await panel.inner_text()
     if index<3:await page.screenshot(path=f'integrated-{label}-card{index}.png',full_page=False)
     await panel.locator('#backCardSummary').click()
    await panel.locator('#closeCardDetail').click();assert await frame.locator('.lts-invoice-unified').count()==0
    verified.append(c['name'])
   await frame.locator('.nav [data-v="Atualizações"]').click()
   await frame.locator('.cardcat').select_option('Casa')
   await frame.locator('.cardclass-save').click()
   await frame.wait_for_function("D.card_classification_review.pending_groups===0")
   assert state['semantic_calls']==1
   await page.reload();await page.wait_for_function("document.getElementById('gate')?.hidden===true",timeout=25000)
   frame=next(f for f in page.frames if 'index.html?v162' in f.url)
   await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-07'&&FLOWTO==='2026-10-12'")
   await frame.locator('.nav [data-v="Atualizações"]').click()
   await page.wait_for_timeout(19000)
   assert await frame.evaluate("V==='Atualizações'&&D.card_classification_review.pending_groups===0")
   assert await frame.locator('.cardclass-save').count()==0
   await frame.locator('.nav [data-v="Fluxo Diário"]').click()
   await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-07'")
   await frame.locator('[data-p="Últimos 30 dias"]').click();await frame.wait_for_function("!FLOWLOADING&&FLOWPRESET==='Últimos 30 dias'")
   await frame.locator('[data-a="Itaú"]').click();assert await frame.locator('#flowFrom').input_value()=='2026-08-14'
   await frame.locator('#goToday').click();await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-07'")
   assert await frame.locator('[data-p="Hoje"]').count()==0
   assert await frame.locator('#goToday').count()==1
   overflow=await frame.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth')
   assert overflow<=2,(label,overflow)
   assert not errors,errors
   assert state['financial_writes']==0
   results.append({'profile':label,'pass':True,'cards':verified,'stateful_classification_save_reload':'PASS_FIXTURE_ONLY','source_dates_and_credit':'PASS','five_past_today_thirty_future':True,'no_late_route_reset':True,'page_errors':errors,'overflow':overflow,'user_session_e2e':False,'financial_writes':0})
   await browser.close()
 pathlib.Path('integrated-flow-result.json').write_text(json.dumps({'pass':True,'results':results},ensure_ascii=False,indent=2))
 print(json.dumps(results,ensure_ascii=False,indent=2))

if __name__=='__main__':
 server=ThreadingHTTPServer(('127.0.0.1',8779),functools.partial(Handler,directory=str(ROOT)))
 threading.Thread(target=server.serve_forever,daemon=True).start()
 try:asyncio.run(main())
 except Exception as exc:
  pathlib.Path('integrated-flow-result.json').write_text(json.dumps({'pass':False,'error':str(exc)},indent=2));raise
 finally:server.shutdown()
