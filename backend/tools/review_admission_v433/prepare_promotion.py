"""Prepare routing and reviewed historical adapters; never deploy or update refs."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path(__file__).resolve().parents[3]

def put(name, text):
    p=ROOT/name
    if p.exists() and p.read_text()==text:
        return
    p.parent.mkdir(parents=True,exist_ok=True)
    p.write_text(text)

def replace(name, old, new):
    p=ROOT/name;s=p.read_text()
    assert old in s or new in s, (name,old[:100])
    put(name,s.replace(old,new))

def blob(text):
    b=text.encode()
    return hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()

for p in (ROOT/'.github/workflows').glob('*.yml'):
    s=p.read_text().replace('LTS_MOBILE_RELEASE: v425','LTS_MOBILE_RELEASE: v433').replace('LTS_MOBILE_RELEASE=v425','LTS_MOBILE_RELEASE=v433')
    if p.name=='pages.yml':
        s=s.replace("paths: ['releases/v425/**'", "paths: ['releases/v433/**','releases/v425/**'")
        s=s.replace('lts_v425_verify_published.cjs','lts_v433_verify_published.cjs').replace('v425-published-verification','v433-published-verification').replace('Verify published V425','Verify published V433')
        s=s.replace('          node .github/scripts/lts_v425_release_contract.cjs','          LTS_MOBILE_RELEASE=v433 node .github/scripts/lts_v425_release_contract.cjs')
        anchor='      - name: Configure Pages'
        if 'node .github/scripts/lts_v433_release_contract.cjs' not in s:
            assert anchor in s
            s=s.replace(anchor,'          node .github/scripts/lts_v433_release_contract.cjs\n'+anchor)
    if p.name=='v425-flow-options.yml':
        old='''      - name: Store tested release objects without commits or branch changes
        env:
          GITHUB_TOKEN: ${{ github.token }}
          REVIEWED_HEAD: ${{ github.event.pull_request.head.sha }}
        run: python3 backend/tools/flow_options_v425/stage.py'''
        new='''      - name: Verify current gates without rewinding historical routing
        run: python3 backend/tools/report_presentation_v417/read_only_gates.py > qa/v425/current-static-gates.txt'''
        assert old in s or new in s
        s=s.replace(old,new).replace('    permissions:\n      contents: write\n','')
    put(str(p.relative_to(ROOT)),s)

replace('.github/scripts/lts_v425_release_contract.cjs',
 "assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:'v425',entry:'../releases/v425/app.html'});",
 "const entry=process.env.LTS_MOBILE_RELEASE||'v425';assert.match(entry,/^v[0-9]+$/);assert.deepEqual(JSON.parse(fs.readFileSync('mobile/current.json')),{release:entry,entry:'../releases/'+entry+'/app.html'});")

# Extend only current-release selection. Monetary, source, warning, identity and
# failure assertions in the reviewed historical suites remain in place.
for suite,adapter in [('lts_v385_browser.cjs','lts_v385_current_entry.cjs'),('lts_v412_projection_browser.cjs','lts_v425_projection_current_entry.cjs')]:
    p=ROOT/'.github/scripts'/suite;s=p.read_text();prior=blob(s)
    t=s.replace('v(?:421|423|425)','v(?:421|423|425|433)').replace('v(?:417|421|423|425)','v(?:417|421|423|425|433)')
    if suite=='lts_v412_projection_browser.cjs':
        t=t.replace("new URL(f.url()).pathname.includes('/releases/v425/')", "['/releases/v425/','/releases/v433/'].some(p=>new URL(f.url()).pathname.includes(p))")
    put(str(p.relative_to(ROOT)),t)
    a=ROOT/'.github/scripts'/adapter;text=a.read_text()
    assert prior in text or blob(t) in text
    put(str(a.relative_to(ROOT)),text.replace(prior,blob(t)))

replace('.github/scripts/lts_v385_current_entry.cjs',
 "['/releases/v423/','/releases/v425/']", "['/releases/v423/','/releases/v425/','/releases/v433/']")
replace('.github/scripts/lts_v415_refresh_current_entry.cjs',
 "['v421','v423','v425']", "['v421','v423','v425','v433']")
replace('.github/scripts/lts_v415_refresh_current_entry.cjs',
 "if(release==='v425'){", "if(['v425','v433'].includes(release)){")

previous=(ROOT/'.github/scripts/lts_v425_verify_published.cjs').read_text()
published=previous.replace("['v425','v423'", "['v433','v425','v423'").replace("{release:'v425',entry:'../releases/v425/app.html'}", "{release:'v433',entry:'../releases/v433/app.html'}").replace('v425-published-verification','v433-published-verification').replace("ui:'v425'", "ui:'v433'").replace("previous_ui:['v423'", "previous_ui:['v425','v423'")
put('.github/scripts/lts_v433_verify_published.cjs',published)
put('mobile/current.json',json.dumps({'release':'v433','entry':'../releases/v433/app.html'},indent=2)+'\n')

subprocess.run(['node','.github/scripts/lts_v433_release_contract.cjs'],cwd=ROOT,check=True)
subprocess.run(['python3','backend/tools/report_presentation_v417/read_only_gates.py'],cwd=ROOT,check=True)
print(json.dumps({'pass':True,'release':'v433','prepared_only':True,'refs_changed':False,'published':False}))
