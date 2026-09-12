"""Regression for user-observed cross-bank disclosure leakage. Fixtures only."""
import asyncio
import functools
import json
import pathlib
import runpy
import threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.async_api import async_playwright

ROOT=pathlib.Path.cwd()
F=runpy.run_path(str(ROOT/'.github/scripts/lts_integrated_flow_gate.py'))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args):pass

async def main():
    results=[]
    async with async_playwright() as p:
        for engine,label,viewport in [(p.chromium,'desktop',{'width':1366,'height':768}),(p.chromium,'mobile',{'width':390,'height':844}),(p.webkit,'webkit-mobile',{'width':390,'height':844})]:
            browser=await engine.launch(headless=True)
            context=await browser.new_context(viewport=viewport,timezone_id='America/Sao_Paulo')
            await context.add_init_script("const N=Date,t=N.parse('2026-09-12T15:00:00Z');window.Date=class extends N{constructor(...a){super(...(a.length?a:[t]))}static now(){return t}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture-only',expires_at:4102444800,user:{id:'fixture'}}));")
            queue=[];errors=[];writes=[];delayed=[]
            async def rpc(route):
                request=route.request;name=request.url.split('/')[-1];args=request.post_data_json or {}
                if name=='lts_browser_product_v1':body={'ok':True,'mvp':F['product'](False)}
                elif name.startswith('lts_browser_flow_v'):body={'ok':True,'flow':F['flow'](args)}
                elif name=='lts_browser_card_settlement_detail_v2':
                    body=F['invoice'](args,False)
                    held=queue.pop(0) if queue else None
                    if held:
                        held['started'].set();await held['release'].wait()
                        if held.get('error'):
                            await route.fulfill(status=503,content_type='application/json',body=json.dumps({'message':'fixture delayed error'}));held['done'].set();return
                    await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
                    if held:held['done'].set()
                    return
                elif 'mutate' in name or 'apply' in name or 'semantic_feedback' in name:
                    writes.append(name);raise AssertionError('No writer is allowed in bank-scope tests')
                else:body={'ok':True}
                await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
            await context.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',rpc)
            page=await context.new_page();page.on('pageerror',lambda error:errors.append(str(error)))
            await page.goto('http://127.0.0.1:8780/wip35-v162-candidate.html',wait_until='domcontentloaded')
            await page.wait_for_function("document.getElementById('gate')?.hidden===true",timeout=25000)
            frame=next(f for f in page.frames if 'index.html?v162' in f.url)
            await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-07'&&FLOWTO==='2026-10-12'")
            baseline=await frame.evaluate("JSON.stringify(FLOWQ)")
            async def switch(bank):
                await frame.locator('[data-a="'+bank+'"]').click()
                await frame.wait_for_function('(bank)=>ACC===bank',arg=bank)
            async def clean():
                assert await frame.evaluate('EXP.size===0&&CARDDETAIL===null&&!CARDDETAILFULL&&!CARDDETAILLOADING')
                assert await frame.locator('.fx89-details').count()==0
                assert await frame.locator('.lts-invoice-unified').count()==0
                assert await frame.evaluate("JSON.stringify(FLOWQ)")==baseline
            async def open_card(index,wait=True):
                card=F['CARDS'][index]
                if not await frame.evaluate('(day)=>EXP.has(day)',card['date']):
                    await frame.locator('[data-d="'+card['date']+'"]').click()
                detail=frame.locator('#d-'+card['date']+' + .fx89-details')
                await detail.locator('.fx89-detail-row').filter(has_text=card['name']).locator('.carddetailbtn').click()
                if wait:await frame.wait_for_function('!CARDDETAILLOADING&&CARDDETAIL?.matched===true')
            def hold(error=False):
                item={'started':asyncio.Event(),'release':asyncio.Event(),'done':asyncio.Event(),'error':error};queue.append(item);delayed.append(item);return item
            # Exact reported symptom: loaded Itaú invoice and expanded day leak to C6.
            await switch('Itaú');await open_card(0)
            await frame.locator('#openCardFull').click()
            assert await frame.locator('.lts-source-line').count()==3
            await switch('C6');await clean()
            await switch('Itaú');await clean()  # No saved disclosure restored on return.
            await open_card(0)
            await switch('Itaú')  # Clicking the already-active bank is not a change.
            assert await frame.locator('.lts-invoice-unified').count()==1
            await switch('C6');await clean();await open_card(2)
            assert 'C6' in await frame.locator('.lts-invoice-unified').inner_text()
            await switch('Bradesco');await clean();await open_card(1)
            assert 'Aeternum' in await frame.locator('.lts-invoice-unified').inner_text()
            assert await frame.locator('#ltsReconciliationWarning').count()==1
            await page.screenshot(path=f'bank-scope-{label}-aeternum.png')
            await switch('Consolidado');await clean()
            # A late success must neither resurrect Itaú nor replace a new C6 detail.
            await switch('Itaú');held=hold();await open_card(0,False)
            await asyncio.wait_for(held['started'].wait(),5)
            await switch('C6');await clean();await open_card(2)
            held['release'].set();await asyncio.wait_for(held['done'].wait(),5)
            await page.wait_for_timeout(150)
            assert await frame.evaluate("ACC==='C6'&&CARDDETAIL?.event?.account==='C6'&&!CARDDETAILLOADING")
            assert 'Personnalite' not in await frame.locator('.lts-invoice-unified').inner_text()
            # A late error is obsolete too, even after switching back to the original bank.
            await switch('Itaú');held=hold(True);await open_card(0,False)
            await asyncio.wait_for(held['started'].wait(),5)
            await switch('Bradesco');await switch('Itaú');await clean()
            held['release'].set();await asyncio.wait_for(held['done'].wait(),5)
            await page.wait_for_timeout(150);await clean()
            # Close while loading must remain closed after the response arrives.
            held=hold();await open_card(0,False);await asyncio.wait_for(held['started'].wait(),5)
            await frame.locator('#closeCardDetail').click();held['release'].set()
            await asyncio.wait_for(held['done'].wait(),5);await page.wait_for_timeout(150)
            assert await frame.evaluate('CARDDETAIL===null&&!CARDDETAILLOADING')
            assert await frame.locator('.lts-invoice-unified').count()==0
            # Collapsing the owning day closes its invoice, not other expanded days.
            await open_card(0);await frame.locator('[data-d="2026-09-09"]').click()
            await frame.locator('[data-d="2026-09-14"]').click()
            assert await frame.evaluate("CARDDETAIL===null&&!EXP.has('2026-09-14')&&EXP.has('2026-09-09')")
            await switch('Bradesco');await clean()
            # Preserve the user's manual date range across all banks and close all days.
            await frame.locator('#flowFrom').fill('2026-09-08');await frame.locator('#flowTo').fill('2026-09-25')
            await frame.locator('#flowApply').click()
            await frame.wait_for_function("!FLOWLOADING&&FLOWFROM==='2026-09-08'&&FLOWTO==='2026-09-25'")
            baseline=await frame.evaluate('JSON.stringify(FLOWQ)')
            for bank in ['Itaú','C6','Consolidado','Bradesco']:
                await frame.locator('[data-d="2026-09-09"]').click()
                await switch(bank);await clean()
                assert await frame.locator('#flowFrom').input_value()=='2026-09-08'
                assert await frame.locator('#flowTo').input_value()=='2026-09-25'
            assert not errors,errors
            assert not writes,writes
            results.append({'profile':label,'pass':True,'loaded_full_invoice_reset':True,'same_bank_preserved':True,'return_starts_closed':True,'delayed_success_error_ignored':True,'new_bank_invoice_not_replaced':True,'close_pending_not_reopened':True,'day_collapse_closes_invoice':True,'manual_period_preserved':True,'bradesco_warning_does_not_block_fixture_invoice':True,'financial_payload_unchanged':True,'page_errors':errors,'user_session_e2e':False})
            await browser.close()
    pathlib.Path('bank-scope-result.json').write_text(json.dumps({'pass':True,'profiles':results},ensure_ascii=False,indent=2))
    print(json.dumps(results,ensure_ascii=False,indent=2))

if __name__=='__main__':
    server=ThreadingHTTPServer(('127.0.0.1',8780),functools.partial(Handler,directory=str(ROOT)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:asyncio.run(main())
    except Exception as error:
        pathlib.Path('bank-scope-result.json').write_text(json.dumps({'pass':False,'error':str(error)},ensure_ascii=False));raise
    finally:server.shutdown()
