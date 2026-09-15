"""Actual V162 source page with synthetic RPC payloads. No real account/session.
Every Supabase request is intercepted; financial writers are forbidden.
"""
import asyncio, datetime, functools, json, pathlib, threading
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
from playwright.async_api import async_playwright
ROOT = pathlib.Path.cwd()
TODAY = datetime.date(2026, 9, 14)
class Handler(SimpleHTTPRequestHandler):
    def log_message(self, *_): pass
server = ThreadingHTTPServer(('127.0.0.1', 8786), functools.partial(Handler, directory=str(ROOT)))
threading.Thread(target=server.serve_forever, daemon=True).start()

def rows():
    out = []
    for month, card, bank in [('07', 80, 13), ('08', 110, 17), ('09', 130, 19)]:
        out.append(dict(event_date=f'2026-{month}-01', competence_month=f'2026-{month}-01', transaction_date=None if month == '09' else f'2026-{month}-02', amount=card,
            description='Compra sintética '+month, description_raw='Compra sintética '+month, category='Restaurantes', center_cost='Não atribuído', counterparty='Loja de teste',
            is_card=True, is_credit=False, account='Cartão de teste', account_raw='Cartão de teste', card_name='Cartão de teste', source_table='card_invoice_current_items' if month=='09' else 'card_purchase_detail',
            source_ref='fixture-card-'+month, invoice_id='fixture-invoice-'+month, installments=None, installment_number=None, statement_state='open' if month=='09' else 'observed'))
        out.append(dict(event_date=f'2026-{month}-10' if month != '09' else '2026-09-03', competence_month=f'2026-{month}-01', transaction_date=f'2026-{month}-10' if month!='09' else '2026-09-03', amount=bank,
            description='Despesa sintética '+month, description_raw='Despesa sintética '+month, category='Mercado', center_cost='Não atribuído', counterparty='Mercado de teste',
            is_card=False, is_credit=False, account='Itaú', account_raw='Itaú', source_table='daily_flow_documentary_bridge',source_ref='fixture-bank-'+month))
    return out

def product():
    return dict(flow={'days':[],'events':[]},updates={'items':[],'maintenance_checks':[],'freshness':{}},semantic_review={'pending_groups':0,'items':[]},
      card_classification_review={'pending_groups':0,'pending_lines':0,'items':[],'category_options':[]},card_operating={'open_cycles':[]},card_history={'units':[]},
      wealth_executive={'summary':{},'assets':{}},expenses={},wealth={},planning={},duplicate_quality_gate={},
      expense_drilldown={'rows':rows(),'row_count':len(rows()),'row_limit':None},
      expense_views={'card_detail_coverage':{'first_competence':'2026-07-01','last_competence':'2026-09-01','open_invoice_count':1},'quality':{}},expense_insights={'quality':{}})

def flow(args):
    first=datetime.date.fromisoformat(args['p_from']);last=datetime.date.fromisoformat(args['p_to']);hist=[];future=[]
    for i in range((last-first).days+1):
        d=first+datetime.timedelta(days=i)
        item={'date':d.isoformat(),'historical':d<TODAY,'Itaú':{'balance':1000,'net':0},'Bradesco':{'balance':50,'net':0},'C6':{'balance':0,'net':0},
              'Consolidado':{'bank_balance':1050,'net':0,'economic_net':0},'fix86_columns':{'saldo_anterior':1050,'entradas':0,'saidas':0,'saldo_final':1050,'liq_d0_1_recurso':0,'saldo_apos_d0_1':1050,'rsus_vested':0,'saldo_apos_rsu':1050,'fgts':0,'saldo_apos_fgts':1050}}
        (hist if d<TODAY else future).append(item)
    return {'from':first.isoformat(),'to':last.isoformat(),'historical':{'days':hist,'events':[]},'current_future':{'days':future,'events':[]}}

def dual(args):
    a,b=args['p_from'],args['p_to']
    selected=[r for r in rows() if (a[:7]<=r['competence_month'][:7]<=b[:7] if r['is_card'] else a<=r['event_date']<=b)]
    bank=[r for r in selected if not r['is_card']]
    def grouped(rs, field):
        d={}
        for r in rs:
            k=r[field];v=d.setdefault(k, {'total':0,'rows':0});v['total']+=r['amount'];v['rows']+=1
        return d
    cats=grouped(selected,'category'); monthly=grouped(selected,'competence_month'); cash_monthly=grouped(bank,'competence_month')
    total=sum(r['amount'] for r in selected); bank_total=sum(r['amount'] for r in bank)
    opened=[r for r in selected if r.get('statement_state')=='open']
    return {'version':'expense-dual-lens-v2-recent-cash','from':a,'to':b,
      'cash':{'gross_outflows':bank_total,'own_transfers':0,'spend_outflows':bank_total,'pending_reconciliation':0,
        'buckets':([{'bucket':'Consumo','rows':len(bank),'total':bank_total,'excluded_from_spend':False}] if bank else []),
        'monthly':[{'month':k,'total':v['total']} for k,v in cash_monthly.items()],
        'recent':[{'date':r['event_date'],'description':r['description'],'account':'Itaú','amount':r['amount'],'category':r['category'],'bucket':'Consumo','source':'current_event','source_ref':r['source_ref'],'evidence_status':'documentado','excluded_from_spend':False} for r in bank]},
      'consumption':{'total':total,'rows':len(selected),'unclassified':0,'categories':[{'category':k,**v} for k,v in cats.items()],
        'monthly':[{'month':k,'total':v['total']} for k,v in monthly.items()], 'open_invoice_count':len(opened),'open_invoice_rows':len(opened),'open_invoice_total':sum(r['amount'] for r in opened)},
      'data_quality':{'bank_evidence_as_of':'2026-09-11','source_contract':'current-documentary-expense-sources-v1'}, 'guardrails':[]}

async def main():
    results=[]
    async with async_playwright() as pw:
        browser=await pw.chromium.launch(headless=True,args=['--no-sandbox'])
        for label,width,height in [('desktop',1366,900),('mobile',390,844)]:
            errors=[];calls=[];mode={'error':False,'mismatch':False}
            context=await browser.new_context(viewport={'width':width,'height':height},timezone_id='America/Sao_Paulo')
            await context.add_init_script("const NativeDate=Date;const frozen=NativeDate.parse('2026-09-14T15:00:00Z');window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[frozen]))}static now(){return frozen}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture'}}));")
            async def route_handler(route):
                name=urlparse(route.request.url).path.split('/')[-1];args=route.request.post_data_json or {};calls.append(name)
                if any(part in name for part in ('mutate','semantic_feedback','category_create','manual_update')): raise AssertionError('Writer attempted in read-only browser test')
                if name=='lts_browser_product_v1':body={'ok':True,'mvp':product()}
                elif name.startswith('lts_browser_flow_v'): body={'ok':True,'flow':flow(args)}
                elif name=='lts_browser_expense_dual_lens_v1':
                    if mode['error']:
                        mode['error']=False
                        await route.fulfill(status=500,content_type='application/json',body=json.dumps({'message':'PRIVATE_DATABASE_DETAIL'}));return
                    body=dual(args)
                    if mode['mismatch']:
                        mode['mismatch']=False;body['consumption']['total']+=1
                    await asyncio.sleep(0.4 if args['p_from']=='2026-08-01' else 0.02)
                else:body={'ok':True}
                await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
            await context.route('https://*.supabase.co/**',route_handler)
            page=await context.new_page();page.on('pageerror',lambda e:errors.append(str(e)))
            await page.goto('http://127.0.0.1:8786/wip35-v162-candidate.html')
            await page.wait_for_function("document.getElementById('gate').hidden===true",timeout=25000)
            frame=next(f for f in page.frames if '/index.html?' in f.url)
            await frame.wait_for_function("window.__LTS_EXPENSE_SCREEN_ALIGNMENT?.installed===true",timeout=10000)
            assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
            await frame.locator('.nav [data-v=\"Despesas\"]').click()
            await frame.wait_for_function("window.EXPDUAL?.phase==='ready'",timeout=20000)
            checks=['existing_page_boot_and_flow36','expense_navigation_and_current_reader']
            await frame.evaluate("DSPPER='custom';DSPFROM='2026-07-07';DSPTO='2026-09-14';render()")
            await frame.wait_for_function("window.EXPDUAL?.phase==='ready'&&window.EXPDUAL.key==='2026-07-07|2026-09-14'",timeout=15000)
            assert await frame.evaluate("exp110Rows().length") == 6
            assert await frame.evaluate("expenseRows().length") == 6
            assert await frame.evaluate("window.__LTS_EXPENSE_SCREEN_ALIGNMENT.lastDetailParity") is True
            assert await frame.locator('.lts-exp-source-notice').count()==1
            assert 'meio do mês' in await frame.locator('.lts-exp-source-notice').inner_text()
            checks.append('partial_start_uses_documented_card_competence_without_losing_july')
            assert 'Período com fatura aberta' in await frame.locator('body').inner_text()
            await frame.evaluate("DSP='Consumo';render()")
            assert 'Data original não informada' in await frame.locator('body').inner_text()
            assert 'Compra 01/09/2026' not in await frame.locator('body').inner_text()
            checks.append('open_cycle_visible_no_fabricated_original_date')
            await frame.evaluate("DD={type:'category',key:'Restaurantes'}")
            assert await frame.evaluate("expenseRows().filter(r=>r.category===DD.key).length")==3
            assert '320,00' in await frame.evaluate("expenseDrill()")
            checks.append('category_drilldown_explains_all_three_card_cycles')
            await frame.evaluate("DD=null;DSPFROM='2026-08-01';DSPTO='2026-08-31';render();DSPFROM='2026-09-01';DSPTO='2026-09-14';render()")
            await frame.wait_for_function("window.EXPDUAL?.phase==='ready'&&window.EXPDUAL.key==='2026-09-01|2026-09-14'",timeout=15000)
            await page.wait_for_timeout(600)
            assert await frame.evaluate("window.EXPDUAL.model.consumptionCents")==14900
            checks.append('late_august_cannot_replace_september')
            mode['error']=True
            await frame.evaluate("loadExpenseDual('2026-09-01','2026-09-14')")
            assert await frame.evaluate("window.EXPDUAL.phase")=='error'
            body=await frame.locator('body').inner_text();assert 'PRIVATE_DATABASE_DETAIL' not in body
            assert await frame.evaluate("window.EXPDUAL.data===null")
            checks.append('read_failure_clears_old_totals_redacts_server_detail')
            mode['mismatch']=True
            await frame.evaluate("loadExpenseDual('2026-09-01','2026-09-14')")
            assert await frame.evaluate("window.EXPDUAL.phase")=='error'
            checks.append('internally_inconsistent_payload_not_presented_as_report')
            await frame.evaluate("loadExpenseDual('2026-09-01','2026-09-14')")
            assert await frame.evaluate("window.EXPDUAL.phase")=='ready'
            await page.screenshot(path=f'expense-screen-{label}.png',full_page=True)
            await frame.locator('.nav [data-v=\"Fluxo Diário\"]').click()
            await frame.wait_for_function("!FLOWLOADING&&V==='Fluxo Diário'",timeout=20000)
            assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
            assert await frame.evaluate("window.EXPDUAL.data===null")
            await frame.locator('[data-a=\"Itaú\"]').click()
            assert await frame.locator('#flowFrom').input_value()=='2026-09-09'
            checks.append('return_to_flow_clears_expenses_preserves_default_and_bank_filter')
            assert not errors, errors
            results.append({'profile':label,'status':'PASS','checks':checks,'page_errors':errors,'real_financial_reads':0,'financial_writes':0,'test_scope':'real V162 source, synthetic intercepted RPCs, not user authenticated data'})
            await context.close()
        await browser.close()
    pathlib.Path('expense-screen-qa.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
    print(json.dumps(results,ensure_ascii=False,indent=2))
try: asyncio.run(main())
finally: server.shutdown()
