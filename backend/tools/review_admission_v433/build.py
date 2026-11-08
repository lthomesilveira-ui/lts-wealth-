"""Build a new immutable UI from V425; no database or financial mutations."""
from pathlib import Path
import hashlib
import json
import shutil
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SRC = ROOT / 'releases/v425'
TARGET = ROOT / 'releases/v433'

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def once(text, old, new):
    assert text.count(old) == 1, ('predecessor changed', old[:90])
    return text.replace(old, new)

manifest = json.loads((SRC / 'manifest.json').read_text())
for name, expected in manifest['files'].items():
    assert digest(SRC / name) == expected, ('published asset changed', name)

work = tempfile.TemporaryDirectory() if TARGET.exists() else None
dst = Path(work.name) / 'v433' if work else TARGET
shutil.copytree(SRC, dst)

old_review = (SRC / 'lts-v181-regression-closure.js').read_text()
review = once(old_review,
    "  async function rpc(name,args,timeoutMs=22000){\n   let timer;",
    """  async function rpc(name,args,timeoutMs=22000){
   // This read already has separate admission and execution bounds in the
   // authenticated transport. A wall timer here discarded valid queued reads.
   // Mutations retain their original timeout and submission path.
   if(name==='lts_browser_expense_review_queue_v229'&&window.__LTS_V227_TRANSPORT?.installed){
    const result=await S.rpc(name,args||{});
    if(result?.error||result?.data==null)throw Error(result?.error?.message||'Lista indisponível.');
    return result.data;
   }
   let timer;"""
)
start = review.index('  async function ensureReview(force=false){')
end = review.index('  async function ensureReconciliation(', start)
review = review[:start] + """  const reviewGeneration=()=>typeof BOOT==='object'?BOOT.generation:D;
  let reviewOwner=reviewGeneration();
  function syncReviewSession(){
   const owner=reviewGeneration();
   if(owner!==reviewOwner){
    reviewOwner=owner;
    const s=state.review;
    Object.assign(s,{status:'idle',data:null,error:null,key:'',offset:0,query:'',saving:null,notice:'',sequence:(s.sequence||0)+1});
    s.drafts.clear();
   }
   return owner;
  }
  async function ensureReview(force=false){
   const owner=syncReviewSession(),range={from:'2013-10-10',to:today()},s=state.review;
   const queryKey=()=>[range.from,today(),s.offset,s.query].join('|'),key=queryKey();
   if(s.status==='loading'||(!force&&s.status==='ready'&&s.key===key))return;
   const sequence=(s.sequence||0)+1;s.sequence=sequence;
   const offset=s.offset,query=s.query;
   const current=()=>state.review===s&&owner===reviewGeneration()&&sequence===s.sequence&&key===s.key&&key===queryKey();
   if(s.key&&s.key!==key)s.data=null;
   s.status='loading';s.error=null;s.key=key;render();
   try{
    const data=await rpc('lts_browser_expense_review_queue_v229',{p_from:range.from,p_to:range.to,p_offset:offset,p_limit:25,p_query:query||null});
    if(!current())return;
    if(!data||data.from!==range.from||data.to!==range.to||data.offset!==offset||!Array.isArray(data.rows)||data.rows.length>25||!Number.isInteger(data.row_count)||data.row_count<0||!Number.isInteger(data.matched_count)||data.matched_count<0||data.matched_count>data.row_count||data.rows.length>data.matched_count)throw Error('Lista indisponível.');
    s.data=data;s.status='ready';
   }catch(error){if(current()){s.status='error';s.error=String(error?.message||error)}}
   finally{if(current())render()}
  }
""" + review[end:]
review = once(review,
    "   return head+notice+breakdown+search+'<div class=\"v181-review-list\">'+body+'</div>'+paging+",
    "   const warning=s.status==='error'?'<p class=\"lts-review-alert\" role=\"status\">Não foi possível atualizar a lista. As informações anteriores podem estar desatualizadas.</p><button class=\"v168-btn\" data-v181-review-retry>Tentar novamente</button>':'';\n   return head+warning+notice+breakdown+search+'<div class=\"v181-review-list\">'+body+'</div>'+paging+"
)
review = once(review, '  function bind(){\n   decorateVersion();',
    '  function bind(){\n   syncReviewSession();\n   decorateVersion();')
# A new session must be cleared before its panel is composed, not after paint.
review = once(review, '  function reviewPanel(){\n   const s=state.review,',
    '  function reviewPanel(){\n   syncReviewSession();\n   const s=state.review,')
(dst / 'lts-v181-regression-closure.js').write_text(review)

old_transport = (SRC / 'lts-v227-read-transport.js').read_text()
transport = once(old_transport,
    "const readBudget=name=>name==='lts_browser_product_refresh_status_v415'?10000:",
    "const readBudget=name=>name==='lts_browser_expense_review_queue_v229'?22000:name==='lts_browser_product_refresh_status_v415'?10000:")
(dst / 'lts-v227-read-transport.js').write_text(transport)
bundle = (SRC / 'lts-v384-startup-1.js').read_text()
bundle = once(bundle, old_review.rstrip(), review.rstrip())
bundle = once(bundle, old_transport.rstrip(), transport.rstrip())
(dst / 'lts-v384-startup-1.js').write_text(bundle)

index = (SRC / 'index.html').read_text()
index = once(index, 'function flowInternalTransferTitle(e){\n',
    "function flowInternalTransferTitle(e){\n if(e.asset_movement===true&&[e.category,e.description].some(x=>/^resgate fgts$/i.test(String(x||'').trim())))return 'Resgate FGTS';\n")
(dst / 'index.html').write_text(index)
(dst / 'app.html').write_text((SRC / 'app.html').read_text().replace('V425', 'V433'))
(dst / 'provenance.json').write_text(json.dumps({
    'release':'v433', 'base_release':'v425',
    'scope':'admitted expense review lifecycle and confirmed FGTS caption',
    'financial_values_changed':False, 'new_financial_reads_or_writes':False,
    'query_arguments_changed':False, 'cache_or_auth_policy_changed':False,
    'active_review_budget_ms':22000, 'existing_admission_budget_ms':60000,
    'private_session_verified':False, 'physical_iphone_verified':False,
}, indent=2) + '\n')
manifest.update(release='v433', version='v433', base_release='v425',
    protected_manifest={'path':'releases/v425/manifest.json', 'sha256':digest(SRC/'manifest.json')})
manifest['files'] = {name:digest(dst/name) for name in sorted(manifest['files'])}
(dst / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n')
if work:
    assert {p.name:digest(p) for p in dst.iterdir()} == {p.name:digest(p) for p in TARGET.iterdir()}, 'not reproducible'
    work.cleanup()
print(json.dumps({'pass':True,'release':'v433','predecessor_unchanged':True,'assets':len(manifest['files'])}))
