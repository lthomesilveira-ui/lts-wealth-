"""Build the immutable Updates recovery release from the published V433."""

import hashlib
import json
import shutil
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PREDECESSOR = ROOT / "releases/v433"
RELEASE = ROOT / "releases/v436"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def replace_once(text, old, new):
    assert text.count(old) == 1, f"Unexpected predecessor: {old[:80]}"
    return text.replace(old, new)


def update_card_review(source):
    # An unsuccessful background attempt should not block the first visible
    # attempt. Subsequent errors on the visible screen keep the manual retry.
    source = replace_once(source,
        "reload:false,deferredRender:false,error:false,data:null,readAt:0,offset:0,query:''",
        "reload:false,deferredRender:false,error:false,data:null,readAt:0,startedInUpdates:false,offset:0,query:''")
    source = replace_once(source,
        "state.reload=false;state.deferredRender=false;state.error=false;state.data=null;state.readAt=0;state.offset=0;",
        "state.reload=false;state.deferredRender=false;state.error=false;state.data=null;state.readAt=0;"
        "state.startedInUpdates=false;state.offset=0;")
    return replace_once(source,
        """   if(!force&&Date.now()-state.readAt<300000)return;
   const generation=state.generation,sequence=++state.sequence,query=state.query,offset=state.offset;state.loading=true;
   if(V==='Atualizações')render();""",
        """   const inUpdates=V==='Atualizações';
   const retryOnEntry=inUpdates&&state.error&&!state.startedInUpdates;
   if(!force&&!retryOnEntry&&Date.now()-state.readAt<300000)return;
   const generation=state.generation,sequence=++state.sequence,query=state.query,offset=state.offset;state.loading=true;
   state.startedInUpdates=inUpdates;
   if(inUpdates)render();""")


def update_actions(source):
    source = replace_once(source,
        "updates:{loading:false,recurring:null,openFinance:null,error:null}",
        "updates:{loading:false,recurring:null,openFinance:null,error:null,startedInUpdates:false}")
    source = replace_once(source,
        """      if(s.loading||(!force&&(s.error||(s.recurring&&s.openFinance))))return;
      const token=(s.token||0)+1,owner=expenseDraftGeneration();s.token=token;s.loading=true;s.error=null;
      const current=()=>s.token===token&&owner===expenseDraftGeneration()&&!!D;
      s.partErrors={};s.pending=2;""",
        """      const inUpdates=V==='Atualizações';
      const retryOnEntry=!force&&inUpdates&&s.error&&!s.startedInUpdates;
      if(s.loading||(!force&&!retryOnEntry&&(s.error||(s.recurring&&s.openFinance))))return;
      const token=(s.token||0)+1,owner=expenseDraftGeneration();s.token=token;s.loading=true;
      s.startedInUpdates=inUpdates;
      if(!retryOnEntry){s.error=null;s.partErrors={};}
      const current=()=>s.token===token&&owner===expenseDraftGeneration()&&!!D;
      s.pending=2;""")
    return replace_once(source,
        """          const value=s[key]&&!force?s[key]:await rpcRead(name,args,1,current);
          if(!current())return;s[key]=value;""",
        """          const value=s[key]&&!force&&!s.partErrors[key]?s[key]:await rpcRead(name,args,1,current);
          if(!current())return;
          s[key]=value;delete s.partErrors[key];""")


def build(output):
    manifest_path = PREDECESSOR / "manifest.json"
    manifest = json.loads(manifest_path.read_text())
    assert manifest["release"] == "v433"
    assert set(manifest["files"]) | {"manifest.json"} == {p.name for p in PREDECESSOR.iterdir()}
    for name, expected in manifest["files"].items():
        assert digest(PREDECESSOR / name) == expected, name
    shutil.copytree(PREDECESSOR, output)

    readers = {
        "lts-v312-card-review.js": update_card_review,
        "lts-v183-v168-feedback-safe.js": update_actions,
        "lts-v384-startup-1.js": update_actions,
        "lts-v384-startup-2.js": update_card_review,
    }
    for name, update in readers.items():
        (output / name).write_text(update((PREDECESSOR / name).read_text()))

    (output / "app.html").write_text((PREDECESSOR / "app.html").read_text().replace("V433", "V436"))
    provenance = {
        "release": "v436",
        "base_release": "v433",
        "scope": "foreground recovery from a failed background Updates read",
        "financial_values_changed": False,
        "mutation_paths_changed": False,
        "query_arguments_changed": False,
        "cache_or_auth_policy_changed": False,
    }
    (output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    manifest.update(release="v436", version="v436", base_release="v433",
                    protected_manifest={"path": "releases/v433/manifest.json", "sha256": digest(manifest_path)})
    manifest["files"] = {name: digest(output / name) for name in sorted(manifest["files"])}
    changed = {name for name, value in manifest["files"].items()
               if value != digest(PREDECESSOR / name)}
    assert changed == set(readers) | {"app.html", "provenance.json"}, changed
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    return len(manifest["files"])


with tempfile.TemporaryDirectory(dir=RELEASE.parent) as work:
    candidate = Path(work) / RELEASE.name
    count = build(candidate)
    if RELEASE.exists():
        assert {p.name: digest(p) for p in candidate.iterdir()} == {p.name: digest(p) for p in RELEASE.iterdir()}
    else:
        candidate.rename(RELEASE)
print(json.dumps({"pass": True, "release": "v436", "assets": count, "predecessor_unchanged": True}))
