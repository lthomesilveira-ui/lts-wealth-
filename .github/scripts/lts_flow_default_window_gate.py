import asyncio, json, threading, functools, datetime, pathlib
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from playwright.async_api import async_playwright
ROOT=pathlib.Path.cwd()
OUT=ROOT
class Handler(SimpleHTTPRequestHandler):
 def log_message(self,*args): pass
server=ThreadingHTTPServer(('127.0.0.1',8778),functools.partial(Handler,directory=str(ROOT)))
threading.Thread(target=server.serve_forever,daemon=True).start()
def product():
 return {'flow':{'days':[],'events':[]},'updates':{'items':[],'maintenance_checks':[],'freshness':{}},'semantic_review':{'pending_groups':0,'items':[]},'card_classification_review':{'pending_groups':0,'pending_lines':0,'items':[],'category_options':[]},'card_operating':{'open_cycles':[]},'card_history':{'units':[]},'wealth_executive':{'summary':{},'assets':{}},'expenses':{},'wealth':{},'planning':{},'duplicate_quality_gate':{}}
def flow(args,day):
 first=datetime.date.fromisoformat(args['p_from']);last=datetime.date.fromisoformat(args['p_to']);hist=[];future=[]
 for i in range((last-first).days+1):
  date=first+datetime.timedelta(days=i)
  item={'date':date.isoformat(),'historical':date<day,'Itaú':{'balance':1000,'net':0},'Bradesco':{'balance':50,'net':0},'C6':{'balance':0,'net':0},'Consolidado':{'bank_balance':1050,'net':0,'economic_net':0},'fix86_columns':{'saldo_anterior':1050,'entradas':0,'saidas':0,'saldo_final':1050,'liq_d0_1_recurso':500,'saldo_apos_d0_1':1550,'rsus_vested':0,'saldo_apos_rsu':1550,'fgts':0,'saldo_apos_fgts':1550}}
  (hist if date<day else future).append(item)
 return {'from':first.isoformat(),'to':last.isoformat(),'historical':{'days':hist,'events':[]},'current_future':{'days':future,'events':[]}}
async def main():
 receipts=[]
 async with async_playwright() as p:
  browser=await p.chromium.launch(headless=True,args=['--no-sandbox'])
  for label,viewport,date in [('desktop',{'width':1440,'height':900},'2026-09-11'),('mobile',{'width':390,'height':844},'2026-09-11'),('year-boundary',{'width':1440,'height':900},'2027-01-02')]:
   day=datetime.date.fromisoformat(date);start=(day-datetime.timedelta(days=5)).isoformat();end=(day+datetime.timedelta(days=30)).isoformat();requests=[];errors=[]
   context=await browser.new_context(viewport=viewport,timezone_id='America/Sao_Paulo')
   await context.add_init_script("const NativeDate=Date;const frozen=NativeDate.parse('%sT15:00:00Z');window.Date=class extends NativeDate{constructor(...args){super(...(args.length?args:[frozen]))}static now(){return frozen}};localStorage.setItem('lts_supabase_session_v1',JSON.stringify({access_token:'fixture-only',refresh_token:'fixture',expires_at:4102444800,user:{id:'fixture'}}));"%date)
   async def route(reqroute):
    req=reqroute.request;name=req.url.split('/')[-1];args=req.post_data_json or {};requests.append({'name':name,'args':args})
    if 'mutate' in name: raise AssertionError('A test attempted a writer')
    if name=='lts_browser_product_v1':
     await asyncio.sleep(0.10);body={'ok':True,'mvp':product()}
    elif name.startswith('lts_browser_flow_v'):
     await asyncio.sleep(0.45 if name=='lts_browser_flow_v3' else 0.04)
     body={'ok':True,'flow':flow(args,day)}
    else: body={'ok':True}
    await reqroute.fulfill(status=200,content_type='application/json',body=json.dumps(body))
   await context.route('https://tadhkamnwtsbdozwkyut.supabase.co/**',route)
   page=await context.new_page();page.on('pageerror',lambda e: errors.append(str(e)))
   await page.goto('http://127.0.0.1:8778/wip35-v162-candidate.html')
   frame=next(f for f in page.frames if f.url.endswith('index.html?v162-flow-recovery'))
   async def expect_default():
    await frame.wait_for_function("([a,b])=>!FLOWLOADING&&FLOWFROM===a&&FLOWTO===b&&FLOWQ?.from===a&&FLOWQ?.to===b",arg=[start,end],timeout=18000)
    assert await frame.locator('.fx87-row:not(.fx87-head)').count()==36
    assert await frame.locator('#goToday').count()==1
    assert await frame.locator('[data-p="Hoje"]').count()==0
   await expect_default()
   await page.wait_for_function("document.getElementById('gate').hidden===true")
   await frame.locator('[data-a="Itaú"]').click();await expect_default()
   await frame.locator('[data-p="Últimos 30 dias"]').click()
   await frame.wait_for_function("([a,b])=>!FLOWLOADING&&FLOWFROM===a&&FLOWTO===b",arg=[(day-datetime.timedelta(days=29)).isoformat(),date])
   await frame.locator('[data-a="Bradesco"]').click()
   assert await frame.locator('#flowFrom').input_value()==(day-datetime.timedelta(days=29)).isoformat()
   await frame.locator('.nav [data-v="Atualizações"]').click()
   await frame.locator('.nav [data-v="Fluxo Diário"]').click();await expect_default()
   await frame.locator('[data-p="Próximos 5 dias"]').click()
   await frame.wait_for_function("!FLOWLOADING&&FLOWPRESET==='Próximos 5 dias'")
   await frame.locator('#goToday').click();await expect_default()
   await frame.locator('#flowFrom').fill((day-datetime.timedelta(days=10)).isoformat())
   await frame.locator('#flowTo').fill((day+datetime.timedelta(days=2)).isoformat())
   await frame.locator('#flowApply').click()
   await frame.wait_for_function("([a,b])=>!FLOWLOADING&&FLOWFROM===a&&FLOWTO===b",arg=[(day-datetime.timedelta(days=10)).isoformat(),(day+datetime.timedelta(days=2)).isoformat()])
   await frame.locator('#flowDefaultRange').click();await expect_default()
   await page.reload();frame=next(f for f in page.frames if 'index.html?v162' in f.url);await expect_default()
   await frame.locator('[data-p="Próximos 5 dias"]').click()
   await frame.wait_for_function("!FLOWLOADING&&FLOWPRESET==='Próximos 5 dias'")
   await page.wait_for_timeout(2600)
   assert await frame.locator('#flowFrom').input_value()==date
   assert await frame.locator('#flowTo').input_value()==(day+datetime.timedelta(days=4)).isoformat()
   await frame.locator('#goToday').click();await expect_default()
   overflow=await frame.evaluate('document.documentElement.scrollWidth-document.documentElement.clientWidth')
   assert overflow<=2,(label,overflow)
   await page.screenshot(path=str(OUT/f'window-{label}.png'))
   assert not errors,errors
   receipts.append({'profile':label,'date':date,'from':start,'to':end,'calendar_rows':36,'initial_reload_reentry_today_manual_and_bank_tabs':'PASS','page_errors':errors,'horizontal_overflow':overflow,'fixture_only':True,'financial_writes':False,'requests':requests})
   await context.close()
  await browser.close()
 (OUT/'window-qa.json').write_text(json.dumps(receipts,indent=2))
 print(json.dumps([{k:v for k,v in r.items() if k!='requests'} for r in receipts],indent=2))
try: asyncio.run(main())
finally: server.shutdown()
