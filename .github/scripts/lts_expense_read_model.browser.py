"""Offline browser contract test; not the signed-in LTS UI or real-data E2E.
Uses the repository module with synthetic data and denies every network request.
"""
import json
import os
from pathlib import Path
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
SCENARIO = r"""async () => {
  const M=window.LTSExpenseReadModel, checks=[];
  const check=(ok,name)=>{if(!ok)throw new Error(name);checks.push(name);};
  const payload=()=>({version:'expense-month-detail-v2-certified-category-allocation',month:'2026-08-01',through:'2026-08-31',is_partial:false,category_filter:null,
    total:100,rows:1,category_known_total:100,category_unallocated_total:0,category_allocated_history_total:0,categories:[{name:'<img src=x onerror=alert(1)>',total:100,rows:1}],
    items:[{event_date:'2026-08-03',transaction_date:'2026-06-20',amount:100,category:'<img src=x onerror=alert(1)>',center_cost:null,counterparty:'Fixture',origin_type:'cartão',origin_name:'Teste',source_table:'fixture',source_ref:'1',coverage_mode:'card_detail_structured',detail_level:'transaction'}]});
  const jobs=[], session=M.createReadSession({load:()=>new Promise((resolve,reject)=>jobs.push({resolve,reject}))});
  const status=document.getElementById('status'), output=document.getElementById('total'), cat=document.getElementById('category');
  session.subscribe(state=>{
    status.textContent=state.message||state.phase;
    output.textContent=state.model?String(M.presentation(state.model).totalCents):'—';
    cat.textContent=state.model?state.model.categories[0].name:'';
  });
  const old=session.select({month:'2026-08-01',through:'2026-08-31'});
  check(output.textContent==='—','loading_has_no_total');
  const next=session.select({month:'2026-08-01',through:'2026-08-14'});
  const p=payload();p.through='2026-08-14';p.is_partial=true;jobs[1].resolve(p);await next;
  jobs[0].resolve(payload());await old;
  check(session.getState().model.scope.through==='2026-08-14','late_response_ignored');
  check(M.presentation(session.getState().model).periodLabel==='Mês parcial','partial_label');
  check(document.querySelectorAll('img').length===0 && cat.textContent.includes('<img'),'category_text_is_not_html');
  check(!session.getState().model.definitiveReportReady,'no_false_source_certification');
  const fail=session.select({month:'2026-08-01',through:'2026-08-31'});
  jobs[2].reject(new Error('private SQL token'));await fail;
  check(output.textContent==='—'&&!status.textContent.includes('token'),'error_redacted_and_no_false_zero');
  const last=session.select({month:'2026-08-01',through:'2026-08-31'});session.dispose();jobs[3].resolve(payload());await last;
  check(session.getState().model===null,'disposed_session_forgets_data');
  check(document.documentElement.scrollWidth<=innerWidth,'fixture_no_horizontal_overflow');
  return checks;
}"""

def main():
    results=[]
    with sync_playwright() as p:
        launch={"headless":True}
        executable=os.environ.get('LTS_TEST_CHROMIUM')
        if not executable and Path('/usr/bin/chromium').exists():
            executable='/usr/bin/chromium'
        if executable:
            launch['executable_path']=executable
        browser=p.chromium.launch(**launch)
        for w,h in [(1366,900),(390,844)]:
            page=browser.new_page(viewport={"width":w,"height":h})
            attempts=[]
            page.route('**/*',lambda route:(attempts.append(route.request.url),route.abort()))
            page.set_content('<!doctype html><html lang="pt-BR"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{font:16px system-ui;margin:16px}section{max-width:600px;overflow-wrap:anywhere}</style><section aria-label="Fixture sintética"><h1>Teste do leitor de Despesas</h1><p id="status" role="status"></p><p id="total"></p><p id="category"></p></section></html>')
            page.add_script_tag(path=str(ROOT/'lts-expense-read-model.js'))
            checks=page.evaluate(SCENARIO)
            if attempts:
                raise AssertionError('Unexpected network request in offline fixture')
            results.append({"viewport":[w,h],"checks":checks,"network_requests":len(attempts)})
            page.close()
        browser.close()
    print(json.dumps({"status":"PASS","scope":"Chromium synthetic fixture only; not deployed UI or real user session","results":results},ensure_ascii=False,indent=2))

if __name__=='__main__':
    main()
