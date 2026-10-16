#!/usr/bin/env python3
"""Disposable PostgreSQL 17 SQL reconciliation rehearsal, using invented data only.

No dependency installer, production connection, Supabase client, or network client
is included. Execution requires both ALLOW_DISPOSABLE_RECONCILIATION_TEST=1 and
PG_CONTAINER (an alphanumeric Docker container ID). --static-check-only never
starts Docker or psql. A successful static check is not a database test result.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
import hashlib
import os
from pathlib import Path
import queue
import re
import subprocess
import sys
import threading
import time
from typing import Any
import unittest

HERE = Path(__file__).resolve().parent
SCHEMA = "reconciliation_fixture"
DATABASE = "reconciliation_ci"
TARGET = "00000000-0000-4000-8000-000000000002"
OWNER = "00000000-0000-4000-8000-000000000001"
CREDIT = "00000000-0000-4000-8000-000000000003"
ACCOUNT = "00000000-0000-4000-8000-000000000004"
CONNECTION = "00000000-0000-4000-8000-000000000005"
FUTURE = "00000000-0000-4000-8000-000000000006"
OTHER_OWNER = "00000000-0000-4000-8000-000000000007"
UNRELATED = "00000000-0000-4000-8000-000000000008"
SQL_TIMEOUT = 25
WAIT_TIMEOUT = 8


def sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def identifier(value: str) -> str:
    return '"' + value.replace('"', '""') + '"'


def require(condition: Any, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def render_template(name: str, contract: dict[str, Any], *, commit: bool = True,
                    barrier: tuple[str, int] | None = None) -> str:
    sql = (HERE / name).read_text(encoding="utf-8")
    ending = re.search(r"\bROLLBACK(?=\s*;\s*(?:--[^\n]*)?\s*\Z)", sql, re.IGNORECASE)
    require(ending is not None, f"{name}: final ROLLBACK safety boundary missing")
    if commit:
        sql = sql[:ending.start()] + "COMMIT" + sql[ending.end():]
    if barrier is not None:
        hook, key = barrier
        require(sql.count(hook) == 1, f"{name}: expected exactly one barrier {hook}")
        # A nested block avoids changing the template's declarations. The longer
        # timeout applies only to the harness gate, then the template value returns.
        gate = f"""{hook}
        DECLARE harness_previous_lock_timeout text := current_setting('lock_timeout');
        BEGIN
          PERFORM set_config('lock_timeout', '10s', true);
          PERFORM pg_advisory_lock({int(key)});
          PERFORM pg_advisory_unlock({int(key)});
          PERFORM set_config('lock_timeout', harness_previous_lock_timeout, true);
        END;"""
        sql = sql.replace(hook, gate, 1)
    payload = json.dumps(contract, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return "SET reconciliation_test.contract = " + sql_string(payload) + ";\n" + sql


@dataclass
class Result:
    code: int
    stdout: str
    stderr: str

    def check(self) -> "Result":
        require(self.code == 0, f"psql failed ({self.code}): {self.stderr.strip()[-1800:]}")
        return self

    def outcome(self, expected: str) -> None:
        self.check()
        require(expected in self.stdout, f"missing SQL outcome {expected!r}")


class Session:
    """Persistent psql process with drained pipes, bounded waits, and cleanup."""
    def __init__(self, command: list[str], application_name: str):
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, text=True, bufsize=1)
        self.lines: queue.Queue[tuple[str, str]] = queue.Queue()
        self.output: dict[str, list[str]] = {"stdout": [], "stderr": []}
        self.threads: list[threading.Thread] = []
        for name in ("stdout", "stderr"):
            stream = getattr(self.process, name)
            def reader(stream=stream, name=name):
                for line in stream:
                    self.output[name].append(line)
                    self.lines.put((name, line))
            worker = threading.Thread(target=reader, daemon=True)
            worker.start()
            self.threads.append(worker)
        self.send("SET application_name = " + sql_string(application_name) + ";\n")

    def send(self, sql: str) -> None:
        require(self.process.stdin is not None and not self.process.stdin.closed,
                "persistent psql stdin is closed")
        self.process.stdin.write(sql + "\n")
        self.process.stdin.flush()

    def wait_line(self, expected: str, timeout: float = WAIT_TIMEOUT) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            try:
                _, line = self.lines.get(timeout=min(.1, max(.001, deadline - time.monotonic())))
            except queue.Empty:
                if self.process.poll() is not None:
                    break
                continue
            if line.strip() == expected:
                return
        raise AssertionError(f"psql did not reach marker {expected!r}; stderr="
                             + "".join(self.output["stderr"])[-1200:])

    def close_input(self) -> None:
        if self.process.stdin and not self.process.stdin.closed:
            self.process.stdin.close()

    def finish(self, timeout: float = SQL_TIMEOUT) -> Result:
        self.close_input()
        try:
            self.process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            self.stop()
            raise AssertionError("persistent psql exceeded bounded timeout") from None
        for thread in self.threads:
            thread.join(timeout=2)
        return Result(self.process.returncode, "".join(self.output["stdout"]),
                      "".join(self.output["stderr"]))

    def stop(self) -> None:
        self.close_input()
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=2)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=2)
        for stream in (self.process.stdout, self.process.stderr):
            if stream:
                stream.close()


class Database:
    def __init__(self) -> None:
        if os.environ.get("ALLOW_DISPOSABLE_RECONCILIATION_TEST") != "1":
            raise RuntimeError("Refusing SQL: ALLOW_DISPOSABLE_RECONCILIATION_TEST=1 is required")
        container = os.environ.get("PG_CONTAINER", "")
        if not re.fullmatch(r"[A-Za-z0-9]+", container):
            raise RuntimeError("Refusing SQL: PG_CONTAINER must be an alphanumeric container ID")
        for key in ("DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH", "DOCKER_CONFIG"):
            if os.environ.get(key):
                raise RuntimeError(f"Refusing remote Docker override: {key}")
        self.command = ["docker", "exec", "-i", container, "psql", "-X", "-q", "-At",
                        "-U", "postgres", "-d", "reconciliation_ci", "-v", "ON_ERROR_STOP=1"]
        self.sessions: list[Session] = []
        self.prefix = f"reconciliation_ci_{os.getpid()}_"

    def run(self, sql: str, *, ok: bool = True, timeout: float = SQL_TIMEOUT) -> Result:
        try:
            completed = subprocess.run(self.command, input=sql, text=True, capture_output=True,
                                       timeout=timeout, check=False)
        except subprocess.TimeoutExpired:
            raise AssertionError("psql exceeded bounded timeout") from None
        result = Result(completed.returncode, completed.stdout, completed.stderr)
        return result.check() if ok else result

    def scalar(self, sql: str) -> str:
        lines = [line for line in self.run(sql).stdout.splitlines() if line.strip()]
        require(len(lines) == 1, "scalar SQL did not return exactly one row")
        return lines[0]

    def json(self, sql: str) -> Any:
        return json.loads(self.scalar(sql))

    def session(self, name: str) -> Session:
        session = Session(self.command, self.prefix + name)
        self.sessions.append(session)
        return session

    def wait_for_lock(self, name: str, *, advisory: bool = False,
                      timeout: float = WAIT_TIMEOUT) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            sql = "SELECT count(*) FROM pg_stat_activity WHERE application_name = " + sql_string(self.prefix + name)
            sql += " AND wait_event_type = 'Lock'"
            if advisory:
                sql += " AND wait_event = 'advisory'"
            if int(self.scalar(sql + ";")) == 1:
                return
            time.sleep(.05)
        raise AssertionError(f"session {name!r} did not reach the expected lock wait")

    def cleanup(self) -> None:
        # Terminating an exec client alone does not guarantee server cancellation.
        # All harness sessions have a unique explicit prefix; cancel/terminate only
        # those sessions in this disposable database, never unrelated clients.
        try:
            self.run("SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
                     "WHERE datname = current_database() "
                     "AND starts_with(application_name, " + sql_string(self.prefix) + ") "
                     "AND pid <> pg_backend_pid();", ok=False, timeout=5)
        finally:
            for session in self.sessions:
                session.stop()
            self.sessions.clear()


@dataclass(frozen=True)
class Snapshot:
    tables: dict[str, list[dict[str, Any]]]
    sequences: dict[str, dict[str, Any]]


def snapshot(db: Database) -> Snapshot:
    names = db.json("SELECT coalesce(jsonb_agg(c.relname ORDER BY c.relname),'[]') "
                    "FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
                    "WHERE n.nspname='reconciliation_fixture' AND c.relkind IN ('r','p');")
    tables = {}
    for name in names:
        tables[name] = db.json("SELECT coalesce(jsonb_agg(to_jsonb(t) ORDER BY to_jsonb(t)::text),'[]') "
                               f"FROM {identifier(SCHEMA)}.{identifier(name)} t;")
    names = db.json("SELECT coalesce(jsonb_agg(c.relname ORDER BY c.relname),'[]') "
                    "FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace "
                    "WHERE n.nspname='reconciliation_fixture' AND c.relkind='S';")
    sequences = {name: db.json(f"SELECT to_jsonb(s) FROM {identifier(SCHEMA)}.{identifier(name)} s;")
                 for name in names}
    return Snapshot(tables, sequences)


def row(state: Snapshot, table: str, row_id: str) -> dict[str, Any]:
    matches = [r for r in state.tables[table] if str(r.get("id")) == row_id]
    require(len(matches) == 1, f"expected one fixture {table} row {row_id}")
    return matches[0]


def static_checks() -> bool:
    # compile() writes no cache and deliberately does not import external modules.
    for name in ("run_tests.py", "test_static.py"):
        compile((HERE / name).read_text(encoding="utf-8"), str(HERE / name), "exec")
    sys.dont_write_bytecode = True
    suite = unittest.defaultTestLoader.discover(str(HERE), pattern="test_static.py")
    return unittest.TextTestRunner(verbosity=2).run(suite).wasSuccessful()


class Rehearsal:
    def __init__(self, db: Database):
        self.db = db
        self.contract: dict[str, Any] = {}
        self.passed: list[str] = []
        self.cases: list[dict[str, Any]] = []

    def reset(self) -> Snapshot:
        self.db.cleanup()
        self.db.run((HERE / "setup.sql").read_text(encoding="utf-8"))
        self.contract = self.db.json((HERE / "contract.sql").read_text(encoding="utf-8"))
        return snapshot(self.db)

    def apply(self, *, commit: bool = True, ok: bool = True) -> Result:
        return self.db.run(render_template("apply.sql", self.contract, commit=commit), ok=ok)

    def undo(self, *, ok: bool = True) -> Result:
        return self.db.run(render_template("rollback.sql", self.contract), ok=ok)

    def record_receipt(self) -> None:
        self.contract["post_event_md5"] = self.db.scalar(
            f"SELECT md5(to_jsonb(e)::text) FROM {SCHEMA}.events e WHERE id='{TARGET}';")
        self.contract["post_link_md5"] = self.db.scalar(
            f"SELECT md5(to_jsonb(l)::text) FROM {SCHEMA}.links l WHERE target_event_id='{TARGET}';")

    def rejects_without_changes(self, result: Result, before: Snapshot,
                                *, expected_error: str | None = None) -> None:
        require(result.code != 0, "conflicting SQL unexpectedly succeeded")
        if expected_error:
            require(re.search(expected_error, result.stderr, re.IGNORECASE),
                    f"failure did not exercise expected guard: {expected_error}")
        after = snapshot(self.db)
        require(before.tables == after.tables, "failed transaction changed persisted fixture tables")

    def test(self, name: str, action) -> None:
        started = time.monotonic()
        status, reason = "passed", None
        try:
            try:
                action()
            finally:
                self.db.cleanup()
        except BaseException as exc:
            status = "failed"
            reason = type(exc).__name__ + "; see synthetic-only job log"
            print(f"FAIL {name}", flush=True)
            raise
        finally:
            self.cases.append({"name": name, "status": status,
                               "duration_seconds": round(time.monotonic() - started, 4),
                               "reason": reason})
        self.passed.append(name)
        print(f"PASS {name}", flush=True)

    # Business assertions and scenarios follow below; fixture IDs and amounts are
    # invented and deliberately unrelated to any production reconciliation.

    def applied_state(self, before: Snapshot, after: Snapshot) -> None:
        original, event = row(before, "events", TARGET), row(after, "events", TARGET)
        require(event["amount"] == 725, "expected amount must remain 725")
        require(event["status"] == "expected", "original expected status changed")
        require(event["event_date"] == "2030-01-10", "expected date changed")
        require(event["is_suppressed"] is True, "expected event was not suppressed")
        require(event["suppression_reason"] == "reconciled_to_posted:" + CREDIT,
                "unexpected suppression reason")
        immutable = set(original) - {"is_suppressed", "suppression_reason", "metadata"}
        require(all(original[k] == event[k] for k in immutable), "unapproved event field changed")
        audit = event["metadata"][self.contract["marker"]]
        require(audit["original_event"] == original, "audit did not preserve exact original row")
        require(audit["original_expected_amount"] == 725 and audit["received_amount"] == 600,
                "audit amounts are incorrect")
        require(audit["difference_received_minus_expected"] == -125,
                "audit difference must be -125")
        require(audit["residual_expected"] is False, "unexpected residual projection")
        links = after.tables["links"]
        require(len(links) == 1, "expected exactly one link")
        link = links[0]
        require(link["target_event_id"] == TARGET and link["candidate_amount"] == 600
                and link["candidate_event_date"] == "2030-01-09"
                and link["candidate_source_ref"] == CREDIT
                and link["candidate_source_table"] == "credits", "incorrect posted-credit link")
        require(audit["link_snapshot"] == link, "audit does not contain complete link snapshot")
        require(audit["applied_at"] == link["confirmed_at"], "audit timestamps differ")
        require(after.tables["credits"] == before.tables["credits"], "source bytes changed")
        for event_id in (FUTURE, UNRELATED, "00000000-0000-4000-8000-000000000009"):
            require(row(before, "events", event_id) == row(after, "events", event_id),
                    "non-target event bytes changed")
        require(len(after.tables["events"]) == len(before.tables["events"]),
                "apply inserted or removed event rows")
        for table in before.tables.keys() - {"events", "links", "epoch", "cache"}:
            require(before.tables[table] == after.tables[table], f"unrelated table {table} changed")
        require(after.tables["epoch"][0]["epoch"] == before.tables["epoch"][0]["epoch"] + 2,
                "apply must increment epoch twice")
        require(after.tables["cache"] == [r for r in before.tables["cache"] if r["user_id"] is None],
                "global invalidation must remove both owners' entries and retain NULL-owner cache")
        for function in ("current_rows", "cashflow_engine", "cashflow_rows"):
            ids = self.db.json(f"SELECT coalesce(jsonb_agg(id ORDER BY id),'[]') FROM "
                               f"{SCHEMA}.{function}('{OWNER}','2030-01-01','2030-12-31');")
            require(TARGET not in ids and FUTURE in ids, f"{function} projection still includes target")

    def compile_apply_idempotence(self) -> None:
        before = self.reset()
        self.apply().outcome("applied_in_transaction")
        after = snapshot(self.db)
        self.applied_state(before, after)
        self.apply().outcome("already_applied")
        require(snapshot(self.db) == after, "second apply changed row, cache, epoch, timestamp or sequence")

    def retry_after_poll(self) -> None:
        self.reset()
        self.apply().outcome("applied_in_transaction")
        self.db.run(f"UPDATE {SCHEMA}.credits SET last_seen_at=last_seen_at+interval '1 second', "
                    "updated_at=updated_at+interval '1 second', "
                    "sync_run_id='00000000-0000-4000-8000-000000000099' "
                    f"WHERE id='{CREDIT}';")
        after_poll = snapshot(self.db)
        self.apply().outcome("already_applied")
        require(snapshot(self.db) == after_poll,
                "poll-only source refresh must permit an exact no-op retry without any DML")

    def dry_run(self) -> None:
        before = self.reset()
        self.apply(commit=False).outcome("applied_in_transaction")
        after = snapshot(self.db)
        require(before.tables == after.tables, "ROLLBACK dry-run changed table/cache/epoch bytes")
        require(before.sequences != after.sequences, "dry-run did not exercise nontransactional sequence")
        require(after.sequences["links_id_seq"]["is_called"] is True,
                "dry-run did not allocate a link ID")
        self.apply().outcome("applied_in_transaction")
        require(snapshot(self.db).tables["links"][0]["id"] == 2,
                "next committed ID should expose rolled-back sequence consumption")

    def inverse(self) -> None:
        before = self.reset()
        self.apply().outcome("applied_in_transaction")
        committed = snapshot(self.db)
        self.rejects_without_changes(self.undo(ok=False), committed,
                                     expected_error="COMMITTED receipt hashes")
        self.record_receipt()
        correct_hash = self.contract["post_event_md5"]
        self.contract["post_event_md5"] = "0" * 32
        self.rejects_without_changes(self.undo(ok=False), committed,
                                     expected_error="changed since committed receipt")
        self.contract["post_event_md5"] = correct_hash
        correct_link_hash = self.contract["post_link_md5"]
        self.contract["post_link_md5"] = "0" * 32
        self.rejects_without_changes(self.undo(ok=False), committed,
                                     expected_error="changed since committed receipt")
        self.contract["post_link_md5"] = correct_link_hash
        self.undo().outcome("restored_in_transaction")
        restored = snapshot(self.db)
        for table in before.tables.keys() - {"epoch", "cache"}:
            require(restored.tables[table] == before.tables[table],
                    f"inverse did not restore exact original {table} rows")
        require(restored.tables["epoch"][0]["epoch"] == 4,
                "inverse must perform two additional automatic invalidations")
        require(restored.tables["cache"] == committed.tables["cache"],
                "inverse must not recreate stale caches")
        self.undo().outcome("already_original")
        require(snapshot(self.db) == restored, "second inverse was not a complete no-op")

    def link_insert(self, target: str = TARGET, *, amount: int = 600,
                    source: str = CREDIT) -> str:
        return (f"INSERT INTO {SCHEMA}.links(user_id,target_event_id,candidate_source_table,"
                "candidate_source_ref,candidate_event_date,candidate_amount,note) VALUES "
                f"('{OWNER}','{target}','credits','{source}','2030-01-09',{amount},'synthetic conflict');")

    def operation_insert(self) -> str:
        return (f"INSERT INTO {SCHEMA}.operations(user_id,target_event_id,operation,payload) "
                f"VALUES('{OWNER}','{TARGET}','synthetic-concurrent-operation','{{\"fixture\":true}}');")

    def conflict(self, mutation: str, expected_error: str | None = None) -> None:
        self.reset()
        self.db.run(mutation)
        before = snapshot(self.db)
        self.rejects_without_changes(self.apply(ok=False), before, expected_error=expected_error)

    def refresh_trigger_contract_only(self) -> None:
        renewed = self.db.json((HERE / "contract.sql").read_text(encoding="utf-8"))
        self.contract["triggers"] = renewed["triggers"]

    def trigger_failure(self, *, phase: str) -> None:
        before = self.reset()
        if phase == "zero_update":
            statement = f"""CREATE FUNCTION {SCHEMA}.harness_zero_update() RETURNS trigger
              LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$;
              CREATE TRIGGER harness_zero_update BEFORE UPDATE ON {SCHEMA}.events
              FOR EACH ROW EXECUTE FUNCTION {SCHEMA}.harness_zero_update();"""
            expected = "Expected exactly one updated event"
        elif phase == "zero_insert":
            statement = f"""CREATE FUNCTION {SCHEMA}.harness_zero_insert() RETURNS trigger
              LANGUAGE plpgsql AS $$ BEGIN RETURN NULL; END $$;
              CREATE TRIGGER harness_zero_insert BEFORE INSERT ON {SCHEMA}.links
              FOR EACH ROW EXECUTE FUNCTION {SCHEMA}.harness_zero_insert();"""
            # INTO STRICT may reject zero rows before GET DIAGNOSTICS, which is
            # equally safe and explicitly distinguished from the update guard.
            expected = "query returned no rows|Expected exactly one inserted link"
        else:
            statement = f"""CREATE FUNCTION {SCHEMA}.harness_after_insert_failure() RETURNS trigger
              LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic after-insert failure'; END $$;
              CREATE TRIGGER zzzz_harness_after_insert_failure AFTER INSERT ON {SCHEMA}.links
              FOR EACH STATEMENT EXECUTE FUNCTION {SCHEMA}.harness_after_insert_failure();"""
            expected = "synthetic after-insert failure"
        self.db.run(statement)
        # Without this targeted renewal the trigger-set lease would reject first.
        # We renew no row, function, constraint, or receipt fingerprints.
        self.refresh_trigger_contract_only()
        self.rejects_without_changes(self.apply(ok=False), before, expected_error=expected)
        require(snapshot(self.db).sequences != before.sequences,
                "failure path did not reach link ID allocation")

    def tampered_inverse(self, mutation: str) -> None:
        self.reset()
        self.apply()
        self.record_receipt()
        self.db.run(mutation)
        before = snapshot(self.db)
        self.rejects_without_changes(self.undo(ok=False), before,
                                     expected_error="exact applied state|changed since committed receipt")

    def missing_event(self) -> None:
        self.reset()
        # The fixture intentionally forbids event deletion. Disable only this
        # local safeguard to construct an impossible/missing target fixture, then
        # reenable it so the recorded trigger contract still matches.
        self.db.run(f"BEGIN; ALTER TABLE {SCHEMA}.events DISABLE TRIGGER events_block_delete; "
                    f"DELETE FROM {SCHEMA}.events WHERE id='{TARGET}'; "
                    f"ALTER TABLE {SCHEMA}.events ENABLE TRIGGER events_block_delete; COMMIT;")
        before = snapshot(self.db)
        self.rejects_without_changes(self.apply(ok=False), before,
                                     expected_error="query returned no rows")

    def gate(self, name: str, hook: str, key: int) -> tuple[Session, Session]:
        coordinator = self.db.session(name + "_gate")
        coordinator.send(f"SELECT pg_advisory_lock({key}); SELECT 'gate_ready';")
        coordinator.wait_line("gate_ready")
        applying = self.db.session(name)
        applying.send(render_template("apply.sql", self.contract, barrier=(hook, key)))
        applying.close_input()
        self.db.wait_for_lock(name, advisory=True)
        return coordinator, applying

    def release_gate(self, coordinator: Session, key: int) -> None:
        coordinator.send(f"SELECT pg_advisory_unlock({key}); SELECT 'gate_released';")
        coordinator.wait_line("gate_released")
        coordinator.finish().check()

    def assert_blocked_by(self, waiting: str, blocking: str) -> None:
        self.db.wait_for_lock(waiting)
        result = self.db.scalar(
            "SELECT count(*) FROM pg_stat_activity w JOIN pg_stat_activity b "
            "ON b.pid=ANY(pg_blocking_pids(w.pid)) WHERE w.application_name="
            + sql_string(self.db.prefix + waiting) + " AND b.application_name="
            + sql_string(self.db.prefix + blocking) + ";")
        require(result == "1", "actor did not block on the intended applying session")

    def operation_before_lock(self) -> None:
        self.reset()
        key = 17017001
        coordinator, applying = self.gate("before_event", "-- HARNESS_BARRIER_BEFORE_EVENT_LOCK", key)
        self.db.run(self.operation_insert())
        before = snapshot(self.db)
        self.release_gate(coordinator, key)
        self.rejects_without_changes(applying.finish(), before, expected_error="Unexpected event operation")

    def operation_after_lock(self) -> None:
        before = self.reset()
        key = 17017002
        coordinator, applying = self.gate("after_event", "-- HARNESS_BARRIER_AFTER_EVENT_LOCK", key)
        actor = self.db.session("operation_actor")
        actor.send("BEGIN; SET LOCAL statement_timeout='12s'; SET LOCAL lock_timeout='10s'; "
                   + self.operation_insert() + " SELECT 'operation_inserted'; ROLLBACK;")
        actor.close_input()
        self.assert_blocked_by("operation_actor", "after_event")
        require(not actor.output["stdout"], "operation unexpectedly completed before event unlock")
        self.release_gate(coordinator, key)
        applying.finish().outcome("applied_in_transaction")
        actor.finish().check()
        require("operation_inserted" in "".join(actor.output["stdout"]),
                "operation did not resume after apply committed")
        after = snapshot(self.db)
        self.applied_state(before, after)
        require(after.tables["operations"] == [], "rolled-back actor operation persisted")

    def two_applies(self) -> None:
        before = self.reset()
        key = 17017003
        coordinator, first = self.gate("first_apply", "-- HARNESS_BARRIER_AFTER_EVENT_LOCK", key)
        second = self.db.session("second_apply")
        second.send(render_template("apply.sql", self.contract))
        second.close_input()
        self.assert_blocked_by("second_apply", "first_apply")
        self.release_gate(coordinator, key)
        first.finish().outcome("applied_in_transaction")
        second.finish().outcome("already_applied")
        after = snapshot(self.db)
        self.applied_state(before, after)
        require(after.sequences["links_id_seq"]["last_value"] == 1,
                "serialized retry consumed another sequence ID")
        self.apply().outcome("already_applied")
        require(snapshot(self.db) == after, "serialized result is not idempotent")

    def source_after_lock(self) -> None:
        before = self.reset()
        key = 17017004
        coordinator, applying = self.gate("after_credit", "-- HARNESS_BARRIER_AFTER_CREDIT_LOCK", key)
        actor = self.db.session("source_actor")
        actor.send("BEGIN; SET LOCAL statement_timeout='12s'; SET LOCAL lock_timeout='10s'; "
                   f"UPDATE {SCHEMA}.credits SET last_seen_at=last_seen_at+interval '1 second' "
                   f"WHERE id='{CREDIT}'; SELECT 'source_updated'; ROLLBACK;")
        actor.close_input()
        self.assert_blocked_by("source_actor", "after_credit")
        self.release_gate(coordinator, key)
        applying.finish().outcome("applied_in_transaction")
        actor.finish().check()
        require("source_updated" in "".join(actor.output["stdout"]), "source writer did not resume")
        self.applied_state(before, snapshot(self.db))

    def run(self) -> None:
        self.test("actual SQL compile, apply invariants and exact idempotence", self.compile_apply_idempotence)
        self.test("poll-only source refresh permits no-op retry", self.retry_after_poll)
        self.test("default ROLLBACK atomicity and nontransactional sequence", self.dry_run)
        self.test("committed receipt inverse, missing/changed receipt and inverse idempotence", self.inverse)
        cases = [
            ("existing competing link", self.link_insert(amount=601), "exact applied state"),
            ("source linked to another target", self.link_insert(FUTURE), "different target"),
            ("partial applied event", f"UPDATE {SCHEMA}.events SET metadata=metadata||'{{\"partial\":true}}' WHERE id='{TARGET}';", "exact applied state"),
            ("already suppressed conflict", f"UPDATE {SCHEMA}.events SET is_suppressed=true WHERE id='{TARGET}';", "exact applied state"),
            ("changed target status", f"UPDATE {SCHEMA}.events SET status='pending' WHERE id='{TARGET}';", "exact applied state"),
            ("changed target amount", f"UPDATE {SCHEMA}.events SET amount=726 WHERE id='{TARGET}';", "exact applied state"),
            ("changed target date", f"UPDATE {SCHEMA}.events SET event_date='2030-01-11' WHERE id='{TARGET}';", "exact applied state"),
            ("changed target owner", f"UPDATE {SCHEMA}.events SET user_id='{OTHER_OWNER}' WHERE id='{TARGET}';", "Owner mismatch"),
            ("changed source owner", f"UPDATE {SCHEMA}.credits SET user_id='{OTHER_OWNER}' WHERE id='{CREDIT}';", "Owner mismatch"),
            ("pending source", f"UPDATE {SCHEMA}.credits SET raw_payload=jsonb_set(raw_payload,'{{status}}','\"PENDING\"'), normalized_payload=jsonb_set(normalized_payload,'{{status}}','\"PENDING\"') WHERE id='{CREDIT}';", "Posted credit lease changed"),
            ("changed source value", f"UPDATE {SCHEMA}.credits SET signed_amount=601 WHERE id='{CREDIT}';", "Posted credit lease changed"),
            ("changed source date", f"UPDATE {SCHEMA}.credits SET posting_date='2030-01-10' WHERE id='{CREDIT}';", "Posted credit lease changed"),
            ("full-poll lease expires", f"UPDATE {SCHEMA}.credits SET last_seen_at=last_seen_at+interval '1 second' WHERE id='{CREDIT}';", "full-row lease expired"),
            ("reader definition drift", f"ALTER FUNCTION {SCHEMA}.current_rows(uuid,date,date) SET work_mem='8MB';", "definition lease changed"),
            ("trigger schema drift", f"ALTER TABLE {SCHEMA}.events DISABLE TRIGGER events_cache_update;", "Trigger set changed"),
            ("constraint schema drift", f"ALTER TABLE {SCHEMA}.events ADD CONSTRAINT synthetic_drift CHECK (amount IS NOT NULL);", "Constraint lease changed"),
            ("operation FK schema drift", f"ALTER TABLE {SCHEMA}.operations DROP CONSTRAINT operations_target_event_id_fkey;", "FK lease changed"),
            ("deferrable operation FK rejects", f"ALTER TABLE {SCHEMA}.operations ALTER CONSTRAINT operations_target_event_id_fkey DEFERRABLE INITIALLY DEFERRED;", "FK lease changed"),
            ("unvalidated operation FK rejects", f"ALTER TABLE {SCHEMA}.operations DROP CONSTRAINT operations_target_event_id_fkey; ALTER TABLE {SCHEMA}.operations ADD CONSTRAINT operations_target_event_id_fkey FOREIGN KEY(target_event_id) REFERENCES {SCHEMA}.events(id) NOT VALID;", "FK lease changed"),
            ("existing target operation", self.operation_insert(), "Unexpected event operation"),
            ("missing source", f"DELETE FROM {SCHEMA}.credits WHERE id='{CREDIT}';", "query returned no rows"),
        ]
        for name, mutation, error in cases:
            self.test(name, lambda m=mutation, e=error: self.conflict(m, e))
        self.test("missing event aborts", self.missing_event)
        for phase in ("zero_update", "zero_insert", "after_insert"):
            self.test("atomic synthetic trigger failure: " + phase,
                      lambda p=phase: self.trigger_failure(phase=p))
        self.test("modified audit rejects inverse", lambda: self.tampered_inverse(
            f"UPDATE {SCHEMA}.events SET metadata=jsonb_set(metadata,"
            f"ARRAY['reconciliation_fixture_v1','user_message_id'],'\"tampered-fixture\"') WHERE id='{TARGET}';"))
        self.test("modified link note rejects inverse", lambda: self.tampered_inverse(
            f"UPDATE {SCHEMA}.links SET note='tampered-fixture' WHERE target_event_id='{TARGET}';"))
        self.test("concurrent operation committed before row lock is detected", self.operation_before_lock)
        self.test("immediate FK blocks new operation after event row lock", self.operation_after_lock)
        self.test("concurrent applies serialize to one link and no-op", self.two_applies)
        self.test("credit FOR SHARE blocks concurrent source mutation", self.source_after_lock)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--static-check-only", action="store_true",
                        help="compile Python and verify SQL files without Docker/database access")
    args = parser.parse_args(argv)
    static_ok = static_checks()
    if args.static_check_only:
        if static_ok:
            print("STATIC CHECKS PASS. PostgreSQL SQL was not executed or dynamically validated.")
        return 0 if static_ok else 1
    report: dict[str, Any] = {
        "runtime_executed": False, "status": "not_started", "cases": [],
        "template_sha256": {name: hashlib.sha256((HERE / name).read_bytes()).hexdigest()
                            for name in ("apply.sql", "rollback.sql")},
        "postgres_major": None,
    }
    db: Database | None = None
    rehearsal: Rehearsal | None = None
    exit_code = 1
    try:
        require(static_ok, "static package checks failed; no database work attempted")
        db = Database()
        identity = db.json("SELECT jsonb_build_object('database',current_database(),"
                           "'major',current_setting('server_version_num')::integer/10000);")
        report["runtime_executed"] = True
        report["postgres_major"] = identity.get("major")
        require(identity == {"database": DATABASE, "major": 17},
                "Refusing runtime: exact disposable database/PostgreSQL 17 required")
        rehearsal = Rehearsal(db)
        rehearsal.run()
        report["status"] = "passed"
        exit_code = 0
    except (AssertionError, RuntimeError, OSError, ValueError) as exc:
        report["status"] = "failed" if report["runtime_executed"] else "blocked"
        report["reason"] = type(exc).__name__ + "; see synthetic-only job log"
        print(f"FAIL: {exc}", file=sys.stderr)
    except KeyboardInterrupt:
        report["status"] = "interrupted"
        report["reason"] = "KeyboardInterrupt; interrupted before completion"
        exit_code = 130
    finally:
        if rehearsal is not None:
            report["cases"] = rehearsal.cases
        if db is not None:
            try:
                db.cleanup()
            except (AssertionError, RuntimeError, OSError, ValueError) as exc:
                report["status"] = "failed"
                report["reason"] = "Cleanup failed; see synthetic-only job log"
                exit_code = 1
                print(f"FAIL cleanup: {exc}", file=sys.stderr)
        # This artifact contains no source rows, SQL output, credentials, URLs,
        # or receipts. Runtime failures still produce machine-readable status.
        (HERE / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    if exit_code == 0 and rehearsal is not None:
        print(f"RUNTIME PASS: {len(rehearsal.passed)} PostgreSQL 17 scenarios, invented fixtures only.")
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
