#!/usr/bin/env python3
"""Native PostgreSQL-only interleaving checks for the exact V415 migration.

Requires the disposable database created by test_sql.py --setup-only. This script
never accepts a production URL and refuses a database name outside its fixture
prefix. Heavy predecessors are synthetic; PostgreSQL transactions/locks are real.
"""
from __future__ import annotations

import argparse
import json
import os
import select
import subprocess
import sys
import time
from pathlib import Path

OWNER = "11111111-1111-4111-8111-111111111111"
GATE = 415001999
RESULTS: list[dict] = []
DATABASE = ""


def args() -> list[str]:
    return ["psql", "-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-d", DATABASE]


def sql(text: str, *, timeout: float = 12) -> str:
    completed = subprocess.run(args() + ["-c", text], text=True, capture_output=True, timeout=timeout)
    if completed.returncode:
        raise AssertionError(f"Synthetic SQL failed ({completed.returncode}): {completed.stderr.strip()}")
    return completed.stdout


def last_json(output: str):
    for line in reversed(output.splitlines()):
        try:
            return json.loads(line)
        except (ValueError, TypeError):
            continue
    raise AssertionError(f"Expected JSON result; got {output!r}")


def query(text: str):
    return last_json(sql(text))


def check(name: str, condition: bool, **details):
    if not condition:
        raise AssertionError(f"{name}: {details}")
    RESULTS.append({"name": name, "pass": True, **details})


class Gate:
    """Own a native advisory lock in a separate persistent psql connection."""

    def __init__(self):
        self.process = subprocess.Popen(args(), stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
        assert self.process.stdin and self.process.stdout
        self.process.stdin.write(f"SELECT pg_advisory_lock({GATE}::bigint); SELECT 'V415_GATE_READY';\n".encode())
        self.process.stdin.flush()
        buffer = b""
        deadline = time.monotonic() + 8
        while b"V415_GATE_READY" not in buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                self.close()
                raise AssertionError("Native barrier did not acquire its advisory lock")
            ready, _, _ = select.select([self.process.stdout], [], [], remaining)
            if ready:
                chunk = os.read(self.process.stdout.fileno(), 4096)
                if not chunk:
                    raise AssertionError("Barrier connection exited before readiness")
                buffer += chunk

    def close(self):
        if self.process.poll() is None:
            if self.process.stdin:
                self.process.stdin.close()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=5)


def setup():
    sql("SELECT qa_v415.reset(true); "
        "UPDATE qa_v415.config SET value='\"v5_locked\"' WHERE key='pause_stage'; "
        f"SELECT lts_product_refresh_private_v415.enqueue('{OWNER}','manual',false);")


def cache_state():
    return query("SELECT jsonb_build_object("
                 f"'product',(SELECT md5(to_jsonb(p)::text) FROM public.lts_product_read_cache p WHERE user_id='{OWNER}'),"
                 f"'memo',(SELECT md5(to_jsonb(p)::text) FROM public.lts_flow_future_read_cache_v2 p WHERE user_id='{OWNER}'),"
                 f"'card_memo',(SELECT md5(jsonb_agg(to_jsonb(p) ORDER BY kind,as_of,from_date,to_date)::text) FROM public.lts_v229_read_cache p WHERE user_id='{OWNER}'),"
                 f"'unknown',(SELECT payload->'unknown_future_branch' FROM public.lts_product_read_cache WHERE user_id='{OWNER}'),"
                 "'epoch',(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton));")


def queue_state():
    return query(f"SELECT to_jsonb(q) FROM lts_product_refresh_private_v415.queue q WHERE user_id='{OWNER}';")


def start_worker(case: str):
    appname = "v415-fixture-" + case
    env = dict(os.environ, PGAPPNAME=appname)
    statement = """
BEGIN;
SET LOCAL statement_timeout='8s';
SELECT lts_product_refresh_private_v415.prepare(false);
COMMIT;
BEGIN;
SET LOCAL statement_timeout='20s';
SELECT lts_product_refresh_private_v415.run_claimed();
COMMIT;
"""
    process = subprocess.Popen(args() + ["-c", statement], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            out, err = process.communicate()
            raise AssertionError(f"Worker exited before heavy barrier: {out} {err}")
        state = query("SELECT jsonb_build_object('waiting',EXISTS(SELECT 1 FROM pg_stat_activity a "
                      f"WHERE a.application_name='{appname}' AND a.wait_event_type='Lock' AND a.wait_event='advisory'),"
                      "'owns_marker',EXISTS(SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid "
                      f"WHERE a.application_name='{appname}' AND l.locktype='advisory' AND l.granted AND l.objid=415001997));")
        if state["waiting"] and state["owns_marker"]:
            return process, appname
        time.sleep(0.04)
    process.terminate()
    raise AssertionError("Worker did not enter the locked-product/locked-memo barrier")


def finish_worker(process, *, expect_termination: bool = False):
    output, error = process.communicate(timeout=10)
    if expect_termination:
        check("terminated connection reports failure", process.returncode != 0)
        return None
    if process.returncode:
        raise AssertionError(f"Worker failed unexpectedly: {output} {error}")
    return last_json(output)


def nonblocking(statement: str):
    start = time.monotonic()
    output = sql("SET statement_timeout='800ms'; SET lock_timeout='650ms'; " + statement, timeout=4)
    return output, round((time.monotonic() - start) * 1000, 1)


def invalidation_race():
    setup()
    before = cache_state()
    gate = Gate()
    worker = None
    try:
        worker, _ = start_worker("invalidate")
        claimed = queue_state()
        _, milliseconds = nonblocking(f"SELECT lts_projection_private_v412.invalidate_reads('{OWNER}');")
        changed = queue_state()
        during = cache_state()
        check("invalidation commits while worker owns product and lower memo locks",
              changed["request_version"] == claimed["request_version"] + 1
              and changed["state"] == "running" and changed["invalidate_caches"] is True
              and during["epoch"] == before["epoch"] + 1
              and during["product"] == before["product"] and during["memo"] == before["memo"]
              and during["card_memo"] == before["card_memo"],
              elapsed_ms=milliseconds, statement_budget_ms=800)
        gate.close()
        result = finish_worker(worker)
        after = cache_state()
        queued = queue_state()
        check("superseded worker rolls back full cache and memo and leaves new request pending",
              result.get("published") is False and result.get("error_code") == "refresh_superseded"
              and after["product"] == before["product"] and after["memo"] == before["memo"]
              and after["card_memo"] == before["card_memo"]
              and queued["state"] == "pending" and queued["attempts"] == 0
              and queued["request_version"] == changed["request_version"]
              and queued["completed_version"] == 0 and queued["claim_token"] is None)
        sql("UPDATE qa_v415.config SET value='null' WHERE key='pause_stage';")
        result = query("BEGIN; SELECT lts_product_refresh_private_v415.prepare(false); COMMIT; "
                       "BEGIN; SELECT lts_product_refresh_private_v415.run_claimed(); COMMIT;")
        check("next worker clears deferred memo and publishes new source epoch",
              result.get("published") is True and queue_state()["state"] == "ready"
              and cache_state()["unknown"] == before["unknown"])
    finally:
        gate.close()
        if worker is not None and worker.poll() is None:
            worker.terminate()
            worker.wait(timeout=5)


def coalescing_and_advisory_race():
    setup()
    gate = Gate()
    worker = None
    try:
        worker, _ = start_worker("coalesce")
        before = queue_state()
        count_before = query("SELECT to_jsonb(qa_v415.count_calls());")
        output, milliseconds = nonblocking(
            f"SET app.synthetic_uid='{OWNER}'; SET ROLE authenticated; "
            "SELECT public.lts_browser_product_refresh_request_v415(); "
            "SELECT public.lts_browser_product_refresh_status_v415();")
        status = last_json(output)["refresh"]
        after = queue_state()
        check("public request and status do not block or supersede an active claim",
              status["state"] == "running" and after["request_version"] == before["request_version"]
              and after["attempts"] == 1 and after["claim_token"] == before["claim_token"],
              elapsed_ms=milliseconds, statement_budget_ms=800)
        prepared = query("SELECT lts_product_refresh_private_v415.prepare(false);")
        check("second scheduler does not steal a live lease", prepared.get("claimed") is False
              and queue_state()["claim_token"] == before["claim_token"])
        # This is an already persisted synthetic private claim, never a JWT.
        result = query("SELECT set_config('lts.product_refresh_claim',"
                       "(SELECT jsonb_build_object('user_id',user_id,'token',claim_token,'version',claimed_version::text,"
                       "'epoch',claimed_epoch::text)::text FROM lts_product_refresh_private_v415.queue "
                       f"WHERE user_id='{OWNER}'),false); SELECT lts_product_refresh_private_v415.run_claimed();")
        check("owner advisory lock prevents duplicate heavy execution", result.get("skipped") == "busy"
              and query("SELECT to_jsonb(qa_v415.count_calls());") == count_before)
        gate.close()
        result = finish_worker(worker)
        check("coalesced original worker publishes once", result.get("published") is True
              and queue_state()["completed_version"] == before["request_version"])
    finally:
        gate.close()
        if worker is not None and worker.poll() is None:
            worker.terminate()
            worker.wait(timeout=5)


def epoch_race():
    setup()
    before = cache_state()
    gate = Gate()
    worker = None
    try:
        worker, _ = start_worker("epoch")
        nonblocking("UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;")
        gate.close()
        result = finish_worker(worker)
        after = cache_state()
        queued = queue_state()
        check("independent committed epoch change discards old calculation without publication",
              result.get("published") is False and result.get("error_code") == "refresh_superseded"
              and after["product"] == before["product"] and after["memo"] == before["memo"]
              and after["card_memo"] == before["card_memo"]
              and queued["state"] == "pending" and queued["attempts"] == 1
              and queued["completed_version"] == 0 and queued["request_version"] == 1)
    finally:
        gate.close()
        if worker is not None and worker.poll() is None:
            worker.terminate()
            worker.wait(timeout=5)


def receipt_only_race():
    setup()
    before = cache_state()
    gate = Gate()
    worker = None
    try:
        worker, _ = start_worker("receipt")
        nonblocking("UPDATE public.lts_open_finance_staging SET last_seen_at=last_seen_at+interval '1 minute' WHERE id='first-receipt';")
        check("receipt-only fixture change leaves global epoch unchanged", cache_state()["epoch"] == before["epoch"])
        gate.close()
        result = finish_worker(worker)
        after = cache_state()
        queued = queue_state()
        check("committed card receipt change rejects old calculation and all new memo writes",
              result.get("published") is False and result.get("error_code") == "refresh_superseded"
              and after["product"] == before["product"] and after["memo"] == before["memo"]
              and after["card_memo"] == before["card_memo"]
              and queued["state"] == "pending" and queued["completed_version"] == 0)
    finally:
        gate.close()
        if worker is not None and worker.poll() is None:
            worker.terminate()
            worker.wait(timeout=5)
        sql("UPDATE public.lts_open_finance_staging SET last_seen_at=updated_at WHERE id='first-receipt';")


def crash_durability():
    setup()
    before = cache_state()
    gate = Gate()
    worker = None
    try:
        worker, appname = start_worker("crash")
        # Termination is restricted to this disposable session name/database.
        killed = query("SELECT to_jsonb(pg_terminate_backend(pid)) FROM pg_stat_activity "
                       f"WHERE application_name='{appname}' AND datname=current_database();")
        check("synthetic heavy worker is terminated", killed is True)
        finish_worker(worker, expect_termination=True)
        queued = queue_state()
        after = cache_state()
        check("claim attempt survives connection loss while cache writes roll back",
              queued["state"] == "running" and queued["attempts"] == 1 and queued["claim_token"] is not None
              and after["product"] == before["product"] and after["memo"] == before["memo"])
        gate.close()
        for expected in (2, 3):
            sql(f"UPDATE lts_product_refresh_private_v415.queue SET lease_expires_at=clock_timestamp()-interval '1 second' WHERE user_id='{OWNER}'; "
                "BEGIN; SELECT lts_product_refresh_private_v415.prepare(false); COMMIT;")
            check(f"expired crash lease increments attempt to {expected}", queue_state()["attempts"] == expected)
        count_before = query("SELECT to_jsonb(qa_v415.count_calls());")
        sql(f"UPDATE lts_product_refresh_private_v415.queue SET lease_expires_at=clock_timestamp()-interval '1 second' WHERE user_id='{OWNER}'; "
            "SELECT lts_product_refresh_private_v415.prepare(false);")
        queued = queue_state()
        check("three crashed claims exhaust automatic retries", queued["state"] == "failed"
              and queued["attempts"] == 3 and queued["claim_token"] is None
              and query("SELECT to_jsonb(qa_v415.count_calls());") == count_before)
    finally:
        gate.close()
        if worker is not None and worker.poll() is None:
            worker.terminate()
            worker.wait(timeout=5)


def main():
    global DATABASE
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", default="v415_concurrency")
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    DATABASE = options.database
    if not DATABASE.startswith("v415_") or not DATABASE.replace("_", "").isalnum():
        raise SystemExit("Only an explicitly named v415_ disposable database is supported")
    report = {"pass": False, "scope": "Native PostgreSQL transactions, row/advisory locks and interleaved synthetic dependencies", "results": RESULTS}
    try:
        runtime = query("SELECT to_jsonb(version());")
        if "PostgreSQL 17." not in runtime:
            raise AssertionError("Native PostgreSQL17 is required")
        report["runtime"] = runtime
        sources = query("SELECT to_jsonb(qa_v415.source_hash());")
        invalidation_race()
        coalescing_and_advisory_race()
        epoch_race()
        receipt_only_race()
        crash_durability()
        check("all native interleavings leave financial sources unchanged", sources == query("SELECT to_jsonb(qa_v415.source_hash());"))
        report["pass"] = True
    except Exception as error:
        report["error"] = str(error)
    finally:
        report["checks"] = len(RESULTS)
        options.output.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
