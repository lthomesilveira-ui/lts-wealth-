import json
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone

import lts_smoke as smoke


def fresh_shell(k):
    stamp = urllib.parse.quote(datetime.now(timezone.utc).isoformat())
    url = (
        f"{smoke.SUPABASE_URL}/rest/v1/lts_public_ui_shell"
        f"?version=eq.{smoke.VERSION}&created_at=lte.{stamp}&select=html&limit=1"
    )
    req = urllib.request.Request(
        url,
        headers={
            "apikey": k,
            "Authorization": "Bearer " + k,
            "Cache-Control": "no-cache, no-store, max-age=0",
            "Pragma": "no-cache",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.load(r)
    if not data or not data[0].get("html"):
        raise RuntimeError("shell=missing")
    return data[0]["html"]


smoke.shell = fresh_shell

if __name__ == "__main__":
    sys.exit(smoke.main())
