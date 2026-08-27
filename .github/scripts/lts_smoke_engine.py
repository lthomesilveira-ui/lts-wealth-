import json
import re
import shutil
import subprocess
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
INDEX = ROOT / "index.html"
RESULT = ROOT / "smoke-result.txt"
TMP = Path("/tmp/lts-shell.html")
MANIFEST = ROOT / ".github" / "lts_smoke_manifest.json"
SUPABASE_URL = "https://tadhkamnwtsbdozwkyut.supabase.co"


def publishable_key():
    m = re.search(r"sb_publishable_[A-Za-z0-9_-]+", INDEX.read_text(encoding="utf-8"))
    if not m:
        raise RuntimeError("publishable_key=missing")
    return m.group(0)


def fresh_shell(version, key):
    stamp = urllib.parse.quote(datetime.now(timezone.utc).isoformat())
    url = (
        f"{SUPABASE_URL}/rest/v1/lts_public_ui_shell"
        f"?version=eq.{version}&created_at=lte.{stamp}&select=html&limit=1"
    )
    req = urllib.request.Request(
        url,
        headers={
            "apikey": key,
            "Authorization": "Bearer " + key,
            "Cache-Control": "no-cache, no-store, max-age=0",
            "Pragma": "no-cache",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    if not data or not data[0].get("html"):
        raise RuntimeError("shell=missing")
    return data[0]["html"]


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    version = manifest["version"]
    lines = [f"version={version}"]
    fail = []
    try:
        h = fresh_shell(version, publishable_key())
        TMP.write_text(h, encoding="utf-8")
        lines.append(f"shell_bytes={len(h)}")

        scripts = re.findall(r"<script(?:\s[^>]*)?>(.*?)</script>", h, re.I | re.S)
        lines.append(f"inline_scripts={len(scripts)}")
        for i, script in enumerate(scripts):
            p = Path(f"/tmp/lts-script-{i}.js")
            p.write_text(script, encoding="utf-8")
            r = subprocess.run(["node", "--check", str(p)], capture_output=True, text=True)
            lines.append(f"node_check_{i}={r.returncode}")
            if r.returncode:
                fail.append(f"node_check_{i}")

        for name, marker in manifest.get("required", {}).items():
            ok = marker in h
            lines.append(f"{name}={'ok' if ok else 'missing'}")
            if not ok:
                fail.append(name)

        for name, marker in manifest.get("exact", {}).items():
            count = h.count(marker)
            lines.append(f"single_{name}={count}")
            if count != 1:
                fail.append(f"single_{name}")

        for marker in manifest.get("css_markers", []):
            count = h.count(marker)
            lines.append(f"css_{marker}={count}")
            if count != 1:
                fail.append(f"css_{marker}")

        for name, spec in manifest.get("counts", {}).items():
            marker = spec["marker"]
            expected = int(spec["expected"])
            count = h.count(marker)
            lines.append(f"{name}={count}")
            if count != expected:
                fail.append(name)

        for name, marker in manifest.get("forbidden", {}).items():
            present = marker in h
            lines.append(f"{name}={'present' if present else 'absent'}")
            if present:
                fail.append(name)

        if fail:
            lines += ["publish=blocked", "failures=" + ",".join(fail)]
            RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
            print(RESULT.read_text())
            return 1

        shutil.copyfile(TMP, INDEX)
        lines.append("publish=ready")
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text())
        return 0
    except Exception as e:
        lines += ["publish=blocked", f"exception={type(e).__name__}:{e}"]
        RESULT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(RESULT.read_text())
        return 1


if __name__ == "__main__":
    sys.exit(main())
