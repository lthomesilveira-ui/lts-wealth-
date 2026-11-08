#!/usr/bin/env bash
set -euo pipefail
# Only after review, in a fresh locally reachable disposable PG17 instance.
[[ "${OPTION_A_SYNTHETIC_DISPOSABLE:-}" == "YES" ]] || { echo 'explicit disposable flag required' >&2; exit 2; }
[[ "${PGHOST:-}" == "127.0.0.1" || "${PGHOST:-}" == "localhost" ]] || { echo 'local disposable host required' >&2; exit 2; }
[[ "${PGDATABASE:-}" =~ ^fixture_option_a_[A-Za-z0-9_]+$ ]] || { echo 'dedicated fixture database name required' >&2; exit 2; }
[[ -z "${DATABASE_URL:-}" && -z "${SUPABASE_URL:-}" && -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]] || { echo 'production environment variables forbidden' >&2; exit 2; }
for var in PGHOSTADDR PGSERVICE PGSERVICEFILE PGSYSCONFDIR PGOPTIONS; do
 [[ -z "${!var:-}" ]] || { echo "external libpq override forbidden: $var" >&2; exit 2; }
done
[[ "${PGPORT:-}" =~ ^[0-9]{1,5}$ && "${PGPORT}" -ge 1 && "${PGPORT}" -le 65535 ]] || { echo 'explicit local port required' >&2; exit 2; }
export PGCLIENTENCODING=UTF8
base="$(cd "$(dirname "$0")" && pwd)"
out="${1:?output directory required}"
mkdir -p "$out"
python3 - "$base" <<'PY'
import hashlib,json,sys
from pathlib import Path
base=Path(sys.argv[1]); m=json.loads((base/'PUBLIC_MANIFEST.json').read_text())
for x in m['files']:
 p=base/x['file']; assert p.is_file() and p.name==x['file']
 b=p.read_bytes(); assert len(b)==x['bytes'] and hashlib.sha256(b).hexdigest()==x['sha256'],x['file']
PY
psql -X -qAt -v ON_ERROR_STOP=1 -f "$base/option_a_full_consumers.sql" >"$out/functional.log" 2>"$out/functional.stderr"
python3 "$base/verify_results.py" "$out/functional.log" --output "$out"
