"""Recheck current deployment gates without rewinding an older UI promotion."""
from pathlib import Path
import subprocess,textwrap,json
root=Path(__file__).resolve().parents[3]
text=(root/'.github/workflows/pages.yml').read_text()
marker='      - name: Verify release assets and protected history\n        run: |\n'
assert marker in text
commands=textwrap.dedent(text.split(marker,1)[1].split('      - name: Configure Pages',1)[0])
assert commands.count('node .github/scripts/')>=70
assert all(not x.strip() or x.lstrip().startswith(('node ', 'LTS_')) for x in commands.splitlines())
pointer=(root/'mobile/current.json').read_bytes()
subprocess.run(['bash','-euo','pipefail','-c',commands],cwd=root,check=True)
assert (root/'mobile/current.json').read_bytes()==pointer
print(json.dumps({'passed':True,'historical_ui':'v417','current_entry':json.loads(pointer),'routing_changed':False,'gates_preserved':True}))
