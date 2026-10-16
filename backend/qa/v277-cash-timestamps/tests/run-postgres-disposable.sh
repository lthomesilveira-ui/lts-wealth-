#!/usr/bin/env bash
set -euo pipefail
# Never accepts a connection URL or any production connection parameters.
# Creates its own no-TCP cluster, roles and database, then destroys that cluster.
if [[ "${1:-}" != "--disposable-local" || $# != 1 ]]; then
  echo 'Usage: run-postgres-disposable.sh --disposable-local' >&2; exit 2
fi
if [[ $(id -u) == 0 ]]; then echo 'Run as an unprivileged user, never root.' >&2; exit 2; fi
ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
BINDIR=''
for candidate in "${PGBIN:-}" /usr/lib/postgresql/*/bin /opt/homebrew/opt/postgresql*/bin; do
  if [[ -n "$candidate" && -x "$candidate/initdb" && -x "$candidate/pg_ctl" && -x "$candidate/psql" ]]; then BINDIR="$candidate"; break; fi
done
if [[ -z "$BINDIR" ]] && command -v pg_config >/dev/null 2>&1; then BINDIR=$(pg_config --bindir); fi
for binary in initdb pg_ctl psql createdb; do
  [[ -n "$BINDIR" && -x "$BINDIR/$binary" ]] || { echo 'BLOCKED: PostgreSQL binaries unavailable; no database was contacted.' >&2; exit 3; }
done
TMP=$(mktemp -d /tmp/wealth-cash-synthetic.XXXXXX)
chmod 700 "$TMP"
started=0
cleanup() {
  if [[ "$started" == 1 ]]; then "$BINDIR/pg_ctl" -D "$TMP/data" -m immediate stop >/dev/null 2>&1 || true; fi
  rm -rf -- "$TMP"
}
trap cleanup EXIT INT TERM
trap 'tail -n 100 "$TMP/result.log" >&2 2>/dev/null || true' ERR
unset PGHOST PGHOSTADDR PGPORT PGDATABASE PGUSER PGPASSWORD PGSERVICE PGSERVICEFILE PGPASSFILE PGOPTIONS PGSSLMODE
export LC_ALL=C TZ=UTC PGPASSFILE=/dev/null PGSERVICEFILE=/dev/null
"$BINDIR/initdb" -D "$TMP/data" --auth-local=trust --auth-host=reject --encoding=UTF8 --locale=C >"$TMP/initdb.log" 2>&1
"$BINDIR/pg_ctl" -D "$TMP/data" -l "$TMP/postgres.log" -o "-k $TMP -c listen_addresses='' -c max_connections=10" -w start >"$TMP/start.log" 2>&1
started=1
export PGHOST="$TMP" PGPORT=5432 PGUSER="$(id -un)" PGDATABASE=wealth_cash_timestamp_synthetic
"$BINDIR/createdb" "$PGDATABASE"
python3 "$ROOT/tests/prepare-postgres-suite.py" "$TMP/suite.sql"
if ! "$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/suite.sql" >"$TMP/result.log" 2>&1; then
  tail -n 100 "$TMP/result.log" >&2; exit 1
fi
# Exercise the exact offline-produced installer, using the cluster's synthetic lease.
python3 - "$ROOT" "$TMP" <<'PY_BUILD'
from pathlib import Path
import sys
root,tmp=map(Path,sys.argv[1:])
sql=(root/'baseline/lts_browser_cash_today_v178.sql').read_text()
(tmp/'restore.sql').write_text(sql.rstrip()+';\n')
marker='BEGIN\n positions:='
assert sql.count(marker)==1
changed=sql.replace(marker,'BEGIN\n -- synthetic concurrent definition change\n positions:=')
(tmp/'divergent.sql').write_text(changed.rstrip()+';\n')
PY_BUILD
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/restore.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -At -v ON_ERROR_STOP=1 -c "
SELECT jsonb_agg(jsonb_build_object('signature',v.signature,'definition_md5',md5(pg_get_functiondef(p.oid)),
 'acl',p.proacl::text,'owner',pg_get_userbyid(p.proowner),'security_definer',p.prosecdef,'config',to_jsonb(p.proconfig)) ORDER BY v.signature)
FROM (VALUES ('lts_browser_cash_today_v178()'),('lts_browser_cash_today_v242()'),
 ('lts_open_finance_current_bank_position_v1(uuid)'),('lts_open_finance_checking_positions_v1(uuid)')) v(signature)
JOIN pg_proc p ON p.oid=to_regprocedure('public.'||v.signature);
" >"$TMP/synthetic-lease.json"
python3 "$ROOT/tests/prepare-apply-plan.py" --lease-file "$TMP/synthetic-lease.json" --private-output-dir "$TMP/installer" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/installer/apply.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT set_config('wealth_test.user_id','10000000-0000-0000-0000-000000000001',false); SELECT wealth_test.assert_true(public.lts_browser_cash_today_v242() ? 'bank_positions','exact installer apply propagated through cash242');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/installer/rollback.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT set_config('wealth_test.user_id','10000000-0000-0000-0000-000000000001',false); SELECT wealth_test.assert_true(NOT (public.lts_browser_cash_today_v242() ? 'bank_positions'),'exact installer rollback restored prior payload');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/divergent.sql" >>"$TMP/result.log" 2>&1
if "$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/installer/apply.sql" >"$TMP/expected-rejection.log" 2>&1; then
  echo 'FAIL: stale installer lease was unexpectedly accepted.' >&2; exit 1
fi
grep -q CASH_LEASE_MISMATCH "$TMP/expected-rejection.log" || { cat "$TMP/expected-rejection.log" >&2; exit 1; }
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT wealth_test.assert_true(position('synthetic concurrent definition change' in pg_get_functiondef('public.lts_browser_cash_today_v178()'::regprocedure))>0,'stale installer left concurrent definition intact');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/restore.sql" >>"$TMP/result.log" 2>&1
# New gate: a single atomic DO, both standalone and inside an outer transaction.
python3 "$ROOT/tests/single-do-postgres-cases.py" "$ROOT" "$TMP"
expect_failure() {
  local file="$1" code="$2"
  if "$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$file" >"$TMP/single-do-expected-error.log" 2>&1; then
    echo 'FAIL: negative single-DO test unexpectedly succeeded.' >&2; exit 1
  fi
  grep -q "$code" "$TMP/single-do-expected-error.log" || { cat "$TMP/single-do-expected-error.log" >&2; exit 1; }
}
assert_baseline() {
  "$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT wealth_test.assert_true(NOT EXISTS(SELECT 1 FROM wealth_test.function_metadata_before b LEFT JOIN pg_proc q ON q.oid=b.oid WHERE q.oid IS NULL OR pg_get_functiondef(q.oid) IS DISTINCT FROM b.definition OR q.proacl IS DISTINCT FROM b.proacl OR q.proowner IS DISTINCT FROM b.proowner OR q.prosecdef IS DISTINCT FROM b.prosecdef OR q.proconfig IS DISTINCT FROM b.proconfig),'$1');" >>"$TMP/result.log" 2>&1
}
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/installer/apply-single-do.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT set_config('wealth_test.user_id','10000000-0000-0000-0000-000000000001',false); SELECT wealth_test.assert_true(public.lts_browser_cash_today_v242() ? 'bank_positions','single DO standalone apply');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/installer/rollback-single-do.sql" >>"$TMP/result.log" 2>&1
assert_baseline 'single DO standalone recovery preserves full metadata'
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c 'CREATE TABLE wealth_test.synthetic_migration_journal(name text PRIMARY KEY)' >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/single-do-wrapped-apply.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/single-do-wrapped-rollback.sql" >>"$TMP/result.log" 2>&1
assert_baseline 'single DO works inside existing transaction'
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT wealth_test.assert_true((SELECT count(*) FROM wealth_test.synthetic_migration_journal)=2,'synthetic outer journal committed with successful statements');" >>"$TMP/result.log" 2>&1
expect_failure "$TMP/single-do-fail-after-ddl.sql" SYNTHETIC_POST_DDL_FAILURE
assert_baseline 'single DO error after DDL reverts definition and permissions'
expect_failure "$TMP/single-do-postcheck-mismatch.sql" CASH_POSTCHECK_MISMATCH
assert_baseline 'single DO real postcheck failure reverts definition and permissions'
expect_failure "$TMP/single-do-wrapped-failure.sql" SYNTHETIC_POST_DDL_FAILURE
assert_baseline 'single DO error reverts enclosing transaction DDL'
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT wealth_test.assert_true(NOT EXISTS(SELECT 1 FROM wealth_test.synthetic_migration_journal WHERE name='must_rollback'),'synthetic enclosing journal rolls back on failure');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/divergent.sql" >>"$TMP/result.log" 2>&1
expect_failure "$TMP/installer/apply-single-do.sql" CASH_LEASE_MISMATCH
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c "SELECT wealth_test.assert_true(position('synthetic concurrent definition change' in pg_get_functiondef('public.lts_browser_cash_today_v178()'::regprocedure))>0,'single DO stale lease preserves concurrent definition');" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/restore.sql" >>"$TMP/result.log" 2>&1
"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -f "$TMP/hold-advisory-lock.sql" >"$TMP/held-lock.log" 2>&1 &
holder=$!
for attempt in $(seq 1 50); do [[ -f "$TMP/lock-held" ]] && break; sleep 0.1; done
[[ -f "$TMP/lock-held" ]] || { echo 'FAIL: synthetic lock-holder did not become ready.' >&2; exit 1; }
expect_failure "$TMP/installer/apply-single-do.sql" CASH_DEPLOYMENT_BUSY
wait "$holder"
assert_baseline 'single DO rejects active concurrent publisher without writes'

"$BINDIR/psql" -X -v ON_ERROR_STOP=1 -c 'SELECT count(*) AS synthetic_assertions_passed FROM wealth_test.assertions' >>"$TMP/result.log" 2>&1
tail -n 6 "$TMP/result.log"
printf 'PASS: full cash178/cash242, source guards, NULL/ACL and exact apply/rollback/stale lease in discarded PostgreSQL cluster.\n'
