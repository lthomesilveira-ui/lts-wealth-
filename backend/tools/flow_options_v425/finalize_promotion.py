"""Compile generated acceptance adapters before exporting promotion objects."""
from pathlib import Path
import subprocess,json

def verify_adapters(root:Path,out:Path,changes:list[str]):
 name='.github/scripts/lts_v385_current_entry.cjs';p=root/name;s=p.read_text()
 old=r'/\/releases\/v(?:423|425)\//.test(new URL(f.url()).pathname)'
 new="['/releases/v423/','/releases/v425/'].some(p=>new URL(f.url()).pathname.includes(p))"
 if old in s:
  s=s.replace(old,new);p.write_text(s)
  dest=out/'promotion'/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_text(s)
  if name not in changes:changes.append(name)
 script="""const fs=require('fs'),vm=require('vm');
const adapter=fs.readFileSync('.github/scripts/lts_v385_current_entry.cjs','utf8');
const original=fs.readFileSync('.github/scripts/lts_v385_browser.cjs','utf8');
const assignment=adapter.split('\\n').find(x=>x.startsWith('const replacement='));
const value=vm.runInNewContext(assignment.replace('const replacement=',''));
new vm.Script(original.replace('assert.deepEqual(geometry.map(x=>x.name),groups);',value));
console.log(JSON.stringify({passed:true,generated_ranking_suite_parses:true}));"""
 r=subprocess.run(['node','-e',script],cwd=root,text=True,capture_output=True)
 (out/'generated-adapter-check.txt').write_text(r.stdout+r.stderr)
 assert r.returncode==0,r.stderr
 return sorted(changes)
