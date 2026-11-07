"""Prepare routing and deployment verification, retaining every previous gate."""
from pathlib import Path
import json, subprocess, textwrap
ROOT=Path(__file__).resolve().parents[3]
p=ROOT/'.github/workflows/pages.yml';s=p.read_text()
if 'LTS_MOBILE_RELEASE=v417' not in s:
 assert "paths: ['releases/v415/**'" in s
 s=s.replace("paths: ['releases/v415/**'","paths: ['releases/v417/**','releases/v415/**'")
 s=s.replace('LTS_MOBILE_RELEASE=v415','LTS_MOBILE_RELEASE=v417')
 s=s.replace('          node .github/scripts/lts_v415_release_contract.cjs','          LTS_MOBILE_RELEASE=v417 node .github/scripts/lts_v415_release_contract.cjs')
 s=s.replace('Verify published V415 and preserved releases','Verify published V417 and preserved releases')
 s=s.replace('.github/scripts/lts_v415_verify_published.cjs','.github/scripts/lts_v417_verify_published.cjs')
 s=s.replace('v415-published-verification','v417-published-verification')
 p.write_text(s)
base=ROOT/'.github/scripts/lts_v415_verify_published.cjs';v=base.read_text()
v=v.replace("['v415','v412'","['v417','v415','v412'")
v=v.replace("{release:'v415',entry:'../releases/v415/app.html'}","{release:'v417',entry:'../releases/v417/app.html'}")
v=v.replace('v415-published-verification','v417-published-verification').replace("ui:'v415'","ui:'v417'")
v=v.replace("previous_ui:['v412'","previous_ui:['v415','v412'")
(ROOT/'.github/scripts/lts_v417_verify_published.cjs').write_text(v)
(ROOT/'mobile/current.json').write_text(json.dumps({'release':'v417','entry':'../releases/v417/app.html'},indent=2)+'\n')
start=s.index('      - name: Verify release assets and protected history\n        run: |\n')
block=s[start:].split('        run: |\n',1)[1].split('      - name: Configure Pages',1)[0]
commands=textwrap.dedent(block)
assert commands.count('node .github/scripts/')>=70
subprocess.run(['bash','-euo','pipefail','-c',commands],cwd=ROOT,check=True)
print(json.dumps({'promoted_candidate':'v417','prior_release_gates_preserved':True,'deploy_not_run':True}))
