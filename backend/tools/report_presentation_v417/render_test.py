"""Render the changed components offline with invented data, not a private session."""
from pathlib import Path
import json, subprocess, os, html
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parents[3]; HERE=Path(__file__).resolve().parent
out=Path(os.environ.get('V417_EVIDENCE','v417-evidence'));out.mkdir(parents=True,exist_ok=True)
payload=json.loads(subprocess.check_output(['node','-e',f"console.log(JSON.stringify(require({json.dumps(str(HERE/'test.cjs'))}).payload()))"]))
fixture='''<!doctype html><html lang="pt-BR"><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font:15px Arial;background:#f5f7fa;margin:16px;color:#172f45}article{background:white;padding:16px;border-radius:12px;margin:12px 0}button{min-height:40px}header{font-size:24px;font-weight:bold}.v168-loadstatus{margin:10px 0;padding:8px;background:#fff9e9}.hidden{display:none}.v168-note{padding:10px;background:#fff9e9}</style></head><body><nav id="nav">Wealth · ambiente fictício</nav><main id="content"></main><script>
window.__LTS_V411_RSU={installed:true};window.__LTS_V168_STATE={dashboard:{},updates:{}};
window.D={};window.N=document.getElementById('nav');window.V='Fluxo Diário';window.BOOT={generation:1};window.FLOWFROM='2026-11-01';window.FLOWTO='2030-12-31';window.FLOWLOADING=false;window.FLOWQ={from:FLOWFROM,to:FLOWTO};window.retryCount=0;
window.payload=__PAYLOAD__;window.fail=false;
window.S={rpc:async function(name,args){if(name.includes('recurring_future_gap'))return {data:{horizon_checks:[]}};if(window.fail)return {error:{message:'synthetic private diagnostic never render'}};return {data:window.payload}}};
window.loadFlowRange=function(from,to){FLOWFROM=from;FLOWTO=to;return Promise.resolve()};
window.render=function(){document.getElementById('content').innerHTML='<header>'+V+'</header><section class="flow-sticky-controls"><button id="flowDefaultRange">Período</button></section><section class="v168-updates"></section><section class="v168-dashboard"><article id="money">Saldo fictício <strong>R$ 1.234,56</strong></article><p class="v168-note warn" role="status">Não foi possível atualizar todas as ações. <button data-v333-actions-refresh>Atualizar ações</button></p><div class="v168-loadstatus" role="status"><span><b>Resumo preservado.</b> 3 leitura(s) não atualizaram; nenhuma informação anterior foi apagada.</span> <button id="retry">Tentar novamente</button></div></section>';document.querySelector('[data-v333-actions-refresh]').onclick=()=>window.retryCount++;document.getElementById('retry').onclick=()=>window.retryCount++};render();
</script></body></html>'''.replace('__PAYLOAD__',json.dumps(payload,ensure_ascii=False))
outer='''<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><style>html,body,iframe{margin:0;border:0;width:100%;height:100%}</style></head><body><iframe id="shell" src="/fixture.html"></iframe><script src="/releases/v417/lts-v412-projection-policy.js"></script><script src="/releases/v417/lts-v417-clean-reports.js"></script></body></html>'''
checks=[]
with sync_playwright() as p:
 b=p.chromium.launch(executable_path=os.environ.get('CHROMIUM_PATH','/usr/bin/chromium' if Path('/usr/bin/chromium').exists() else p.chromium.executable_path),headless=True,args=['--no-sandbox'])
 for width,height in [(390,844),(1440,1000)]:
  page=b.new_page(viewport={'width':width,'height':height});errors=[]
  page.on('pageerror',lambda e: errors.append(str(e)))
  offline=outer.replace('src="/fixture.html"','srcdoc="'+html.escape(fixture,quote=True)+'"')
  for asset in ['lts-v412-projection-policy.js','lts-v417-clean-reports.js']:
   offline=offline.replace('<script src="/releases/v417/'+asset+'"></script>','<script>'+(ROOT/'releases/v417'/asset).read_text()+'</script>')
  page.set_content(offline);frame=page.frames[1]
  frame.wait_for_function("window.__LTS_V412_PROJECTION?.status==='ready' && !!window.__LTS_V417_CLEAN_REPORTS")
  page.wait_for_timeout(100)
  assert frame.locator('#money').inner_text()=='Saldo fictício R$ 1.234,56'
  assert frame.locator('.v412-origin').count()==1 and not frame.locator('.v412-origin').get_attribute('open')
  assert frame.locator('body').evaluate('(e)=>e.scrollWidth<=window.innerWidth'), 'horizontal overflow'
  assert frame.evaluate('FLOWTO')=='2031-12-31'
  assert ' '.join(frame.locator('.v168-note.warn').inner_text().split())=='Não foi possível atualizar as pendências. Tentar novamente'
  assert frame.locator('.v168-loadstatus span').inner_text()=='Alguns dados não atualizaram.'
  frame.locator('[data-v333-actions-refresh]').click();frame.locator('#retry').click();assert frame.evaluate('retryCount')==2
  box=frame.locator('[data-v412-policy]').bounding_box();assert box['height']<190
  page.screenshot(path=str(out/f'{width}-default.png'),full_page=True)
  frame.locator('.v412-origin summary').click();assert frame.locator('.v412-origin').get_attribute('open') is not None
  text=frame.locator('.v412-origin').inner_text();assert 'Média de 3 meses completos' in text and 'Média de 12 meses completos' in text
  for word in ['RPC','source_ref','SQLSTATE','payload','backend','cache']:assert word not in text
  page.screenshot(path=str(out/f'{width}-expanded.png'),full_page=True)
  frame.evaluate("V='Atualizações';render()");assert frame.locator('.v412-origin').get_attribute('open') is None
  frame.evaluate("payload.series[0].reference_stale=true;payload.series[0].coverage_months=2;payload.series[0].observed_months=2;payload.series[0].months_with_spend=2;payload.series[0].reference_window={from:'2026-07-01',to:'2026-09-30'};__LTS_V412_PROJECTION.load(true)")
  frame.wait_for_function("window.__LTS_V412_PROJECTION.status==='ready'")
  assert frame.locator('.v412-policy > .v412-warning').count()==1
  assert frame.locator('.v412-policy > .v412-warning').inner_text()=='Há estimativas a conferir nas premissas.'
  assert frame.locator('.v412-policy').bounding_box()['height']<230
  page.screenshot(path=str(out/f'{width}-partial.png'),full_page=True)
  frame.evaluate("fail=true;V='Dashboard';__LTS_V412_PROJECTION.load(true)")
  frame.wait_for_function("window.__LTS_V412_PROJECTION.status==='error'")
  assert 'Não foi possível conferir as projeções' in frame.locator('[data-v412-policy]').inner_text()
  assert 'synthetic private diagnostic' not in frame.locator('body').inner_text()
  assert 'R$ 1.234,56' in frame.locator('#money').inner_text()
  page.screenshot(path=str(out/f'{width}-error.png'),full_page=True)
  frame.evaluate("fail=false");frame.locator('[data-v412-refresh]').click();frame.wait_for_function("window.__LTS_V412_PROJECTION.status==='ready'")
  assert frame.locator('[data-v412-policy=dashboard-warning]').count()==0
  assert not errors,errors
  checks.append({'width':width,'passed':True,'default_panel_height':box['height'],'real_device':False,'authenticated_session':False,'scope':'rendered changed components; synthetic values'})
  page.close()
 b.close()
result={'passed':True,'render_checks':checks,'financial_source_writes':0}
(out/'render-result.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
