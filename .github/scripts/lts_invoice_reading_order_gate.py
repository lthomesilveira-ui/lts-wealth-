"""All-card category reading order: geometry and values, not source markers only."""
import asyncio, functools, json, pathlib, runpy, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=pathlib.Path.cwd()
F=runpy.run_path(str(ROOT/'.github/scripts/lts_integrated_flow_gate.py'))
class Handler(SimpleHTTPRequestHandler):
    def log_message(self,*args): pass

async def assert_linear(panel):
    rows=await panel.locator('[data-category-total]').evaluate_all('''nodes=>nodes.map(node=>{
      const b=node.getBoundingClientRect();return {value:Number(node.dataset.categoryTotal),
      x:b.x,y:b.y,width:b.width,height:b.height,text:node.textContent.trim()};})''')
    assert len(rows)>=3,rows
    assert [r['value'] for r in rows]==sorted([r['value'] for r in rows],reverse=True),rows
    assert max(r['x'] for r in rows)-min(r['x'] for r in rows)<2,rows
    for first,second in zip(rows,rows[1:]):
        assert second['y']>=first['y']+first['height']-1,rows
    return rows

async def main():
    receipts=[]
    async with async_playwright() as p:
        profiles=[(p.chromium,'notebook',1366,768),(p.chromium,'desktop',1440,900),
                  (p.chromium,'mobile',390,844),(p.webkit,'webkit-mobile',390,844)]
        for engine,label,width,height in profiles:
            browser=await engine.launch(headless=True)
            context=await browser.new_context(viewport={'width':width,'height':height},timezone_id='America/Sao_Paulo')
            await context.add_init_script("const N=Date,t=N.parse('2026-09-12T15:00:00Z');window.Date=class extends N{constructor(...a){super(...(a.length?a:[t]))}static now(){return t}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture-only',expires_at:4102444800,user:{id:'fixture'}}));")
            writes=[];errors=[];expected={}
            async def rpc(route):
                req=route.request;name=req.url.split('/')[-1];args=req.post_data_json or {}
                if name=='lts_browser_product_v1':body={'ok':True,'mvp':F['product'](False)}
                elif name.startswith('lts_browser_flow_v'):body={'ok':True,'flow':F['flow'](args)}
                elif name=='lts_browser_card_settlement_detail_v2':
                    body=F['invoice'](args,False)
                    # Six deliberately shuffled categories with a single known total.
                    body['purchases']=[{'row_id':str(k),'description':'Item sintético '+str(k),
                      'category':category,'amount':amount,'purchase_date':None}
                      for k,(category,amount) in enumerate([('Categoria D',120),('A classificar',350),
                         ('Categoria F',40),('Categoria B',240),('Categoria E',70),('Categoria C',180)])]
                    body['invoice_total']=1000;body['detail_lines']=6
                    expected[args['p_description']]=body['purchases']
                elif 'mutate' in name or 'apply' in name or 'semantic_feedback' in name:
                    writes.append(name);raise AssertionError('Layout must not write financial data')
                else:body={'ok':True}
                await route.fulfill(status=200,content_type='application/json',body=json.dumps(body))
            await context.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',rpc)
            page=await context.new_page();page.on('pageerror',lambda err:errors.append(str(err)))
            await page.goto('http://127.0.0.1:8782/wip35-v162-candidate.html',wait_until='domcontentloaded')
            await page.wait_for_function("document.getElementById('gate')?.hidden===true",timeout=25000)
            frame=next(f for f in page.frames if 'index.html?v162' in f.url)
            await frame.wait_for_function('!FLOWLOADING&&!!FLOWQ')
            verified=[]
            for k,card in enumerate(F['CARDS'][:5]):
                await frame.locator('[data-a="'+card['account']+'"]').click()
                await frame.locator('[data-d="'+card['date']+'"]').click()
                detail=frame.locator('#d-'+card['date']+' + .fx89-details')
                await detail.locator('.fx89-detail-row').filter(has_text=card['name']).locator('.carddetailbtn').click()
                await frame.wait_for_function('!CARDDETAILLOADING&&CARDDETAIL?.matched===true')
                panel=frame.locator('.lts-invoice-unified')
                summary=await assert_linear(panel)
                assert [r['value'] for r in summary]==[350,240,180,120,70,40]
                assert await frame.evaluate('CARDDETAIL.purchases')==expected[card['name']]
                if k==0:
                    await panel.screenshot(path=f'invoice-order-{label}.png')
                await panel.locator('#openCardFull').click()
                full=await assert_linear(panel)
                assert [r['value'] for r in full]==[350,240,180,120,70,40]
                assert await panel.locator('.lts-source-line').count()==6
                assert await frame.evaluate('CARDDETAIL.purchases')==expected[card['name']]
                await panel.locator('#backCardSummary').click();await assert_linear(panel)
                await panel.locator('#closeCardDetail').click()
                verified.append(card['name'])
            overflow=await frame.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth')
            assert overflow<=2,(label,overflow)
            assert not errors,errors
            assert not writes,writes
            receipts.append({'profile':label,'pass':True,'cards':verified,'summary_and_full_single_column':True,
              'values_descending':True,'raw_purchases_unchanged':True,'page_errors':errors,'overflow':overflow,
              'financial_writes':0,'user_session_e2e':False})
            await browser.close()
    pathlib.Path('invoice-reading-order-result.json').write_text(json.dumps({'pass':True,'profiles':receipts},ensure_ascii=False,indent=2))
    print(json.dumps(receipts,ensure_ascii=False,indent=2))

if __name__=='__main__':
    server=ThreadingHTTPServer(('127.0.0.1',8782),functools.partial(Handler,directory=str(ROOT)))
    threading.Thread(target=server.serve_forever,daemon=True).start()
    try:asyncio.run(main())
    except Exception as error:
        pathlib.Path('invoice-reading-order-result.json').write_text(json.dumps({'pass':False,'error':str(error)}));raise
    finally:server.shutdown()
