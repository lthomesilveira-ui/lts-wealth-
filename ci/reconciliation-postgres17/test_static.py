"""No-database checks for the synthetic reconciliation rehearsal package.

These tests inspect text and exercise the Python orchestration using mocks. They
cannot prove PostgreSQL syntax, lock behavior, or transactional correctness; the
separately gated runtime suite is required for that evidence.
"""
from __future__ import annotations

import ast
from pathlib import Path
import re
import unittest
from unittest import mock

import run_tests as runner

HERE = Path(__file__).resolve().parent


def read(name: str) -> str:
    return (HERE / name).read_text(encoding="utf-8")


def uncommented(text: str) -> str:
    return re.sub(r"--[^\n]*", "", text)


class PackageSafety(unittest.TestCase):
    def test_required_files_and_python_compile(self):
        for name in ("setup.sql", "contract.sql", "apply.sql", "rollback.sql",
                     "run_tests.py", "test_static.py"):
            self.assertTrue((HERE / name).is_file(), name)
            self.assertGreater((HERE / name).stat().st_size, 50)
        for name in ("run_tests.py", "test_static.py"):
            compile(read(name), str(HERE / name), "exec")

    def test_templates_default_to_rollback(self):
        for name in ("apply.sql", "rollback.sql"):
            sql = uncommented(read(name))
            self.assertRegex(sql, r"(?is)^\s*BEGIN\s+ISOLATION\s+LEVEL\s+READ\s+COMMITTED\s*;")
            self.assertRegex(sql, r"(?i)ROLLBACK\s*;\s*\Z")
            self.assertNotRegex(sql, r"(?im)^\s*COMMIT\s*;")
            self.assertNotIn("SERIALIZABLE", sql.upper())
            self.assertIn("SET LOCAL statement_timeout", sql)
            self.assertIn("SET LOCAL lock_timeout", sql)

    def test_only_fixture_business_write_targets(self):
        for name in ("apply.sql", "rollback.sql"):
            sql = uncommented(read(name))
            targets = re.findall(r"\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+"
                                 r"(reconciliation_fixture\.\w+)", sql, flags=re.I)
            self.assertTrue(targets)
            self.assertLessEqual(set(targets), {"reconciliation_fixture.events", "reconciliation_fixture.links"})
            self.assertNotRegex(sql, r"(?i)\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+(?:public|auth)\.")
            self.assertNotRegex(sql, r"(?i)\b(?:ALTER|DROP|TRUNCATE|CREATE)\s+(?:TABLE|SCHEMA|FUNCTION|DATABASE)\b")
            self.assertNotRegex(sql, r"(?i)\bDELETE\s+FROM\s+reconciliation_fixture\.events\b")
            self.assertIn("current_database() IS DISTINCT FROM 'reconciliation_ci'", sql)
            self.assertIn("server_version_num", sql)
            self.assertIn("/10000<>17", sql.replace(" ", ""))
            self.assertIn("v_contract->>'fixture_contract'", sql)

    def test_fixture_reset_is_guarded_and_scoped(self):
        sql = read("setup.sql")
        drop = sql.index("DROP SCHEMA IF EXISTS reconciliation_fixture CASCADE")
        self.assertLess(sql.index("current_database()"), drop)
        self.assertLess(sql.index("server_version_num"), drop)
        self.assertIn("<> 'reconciliation_ci'", sql[:drop])
        self.assertRegex(sql[:drop], r"/\s*10000\s*<>\s*17")
        self.assertEqual(re.findall(r"(?im)^\s*DROP\s+SCHEMA\b[^;]*", sql),
                         ["\nDROP SCHEMA IF EXISTS reconciliation_fixture CASCADE"])
        self.assertNotRegex(sql, r"(?i)\b(?:DROP|CREATE)\s+DATABASE\b")
        self.assertIn("NOT DEFERRABLE INITIALLY IMMEDIATE", sql)
        self.assertIn("REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows", sql)
        self.assertIn("WHERE user_id IS NOT NULL", sql)

    def test_contract_includes_full_provenance(self):
        sql = read("contract.sql")
        for key in ("original_event", "event_md5", "credit", "credit_md5", "credit_stable_md5",
                    "credit_raw_hash", "credit_updated_at", "note", "marker", "user_message_id",
                    "definitions", "triggers", "constraints", "operations_fk_definition", "fixture_contract"):
            self.assertIn("'" + key + "'", sql)
        self.assertIn("to_jsonb", sql)
        self.assertIn("pg_get_functiondef", sql)
        self.assertIn("pg_get_triggerdef", sql)
        self.assertNotRegex(sql, r"pg_get_triggerdef\([^)]*,\s*true\)")
        self.assertIn("pg_get_constraintdef", sql)

    def test_driver_is_stdlib_and_local_exec_only(self):
        tree = ast.parse(read("run_tests.py"))
        imported = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                imported.update(alias.name.split(".")[0] for alias in node.names)
            elif isinstance(node, ast.ImportFrom) and node.module:
                imported.add(node.module.split(".")[0])
        allowed = {"__future__", "argparse", "dataclasses", "json", "hashlib", "os", "pathlib", "queue",
                   "re", "subprocess", "sys", "threading", "time", "typing", "unittest"}
        self.assertLessEqual(imported, allowed)
        with mock.patch.dict(runner.os.environ, {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1",
                                                "PG_CONTAINER": "abc123"}, clear=True):
            db = runner.Database()
            self.assertEqual(db.command, ["docker", "exec", "-i", "abc123", "psql", "-X", "-q", "-At",
                                          "-U", "postgres", "-d", "reconciliation_ci", "-v", "ON_ERROR_STOP=1"])
        self.assertNotIn("shell=True", read("run_tests.py"))

    def test_runtime_requires_opt_in_and_validated_container(self):
        denied = [{}, {"PG_CONTAINER": "abc123"},
                  {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1"},
                  {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1", "PG_CONTAINER": "-evil"},
                  {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1", "PG_CONTAINER": "a;rm"},
                  {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1", "PG_CONTAINER": "abc 123"}]
        for environ in denied:
            with self.subTest(environ=environ), mock.patch.dict(runner.os.environ, environ, clear=True), \
                    mock.patch.object(runner.subprocess, "run") as process:
                with self.assertRaises(RuntimeError):
                    runner.Database()
                process.assert_not_called()
        for key in ("DOCKER_HOST", "DOCKER_CONTEXT", "DOCKER_TLS_VERIFY", "DOCKER_CERT_PATH", "DOCKER_CONFIG"):
            with mock.patch.dict(runner.os.environ, {"ALLOW_DISPOSABLE_RECONCILIATION_TEST": "1",
                                                    "PG_CONTAINER": "abc123", key: "blocked"}, clear=True):
                with self.assertRaises(RuntimeError):
                    runner.Database()

    def test_static_mode_never_connects(self):
        with mock.patch.object(runner, "static_checks", return_value=True), \
                mock.patch.object(runner, "Database") as database, \
                mock.patch.object(runner.subprocess, "run") as process, \
                mock.patch.object(runner.subprocess, "Popen") as popen, \
                mock.patch("builtins.print"):
            self.assertEqual(runner.main(["--static-check-only"]), 0)
            database.assert_not_called()
            process.assert_not_called()
            popen.assert_not_called()

    def test_renderer_changes_only_final_transaction_token(self):
        contract = {"fixture_contract": True, "note": "synthetic ' quote", "marker": "fixture"}
        for name in ("apply.sql", "rollback.sql"):
            rolled_back = runner.render_template(name, contract, commit=False)
            committed = runner.render_template(name, contract, commit=True)
            self.assertTrue(rolled_back.startswith("SET reconciliation_test.contract = '"))
            self.assertIn("synthetic '' quote", rolled_back)
            ending = re.search(r"\bROLLBACK(?=\s*;\s*(?:--[^\n]*)?\s*\Z)", rolled_back)
            self.assertIsNotNone(ending)
            self.assertEqual(committed, rolled_back[:ending.start()] + "COMMIT" + rolled_back[ending.end():])
            self.assertIn("BEGIN ISOLATION LEVEL READ COMMITTED", committed)

    def test_sequence_snapshot_uses_explicit_fields(self):
        db = mock.Mock()
        sequence = {"last_value": 7, "log_cnt": 32, "is_called": True}
        db.json.side_effect = [[], ["links_id_seq"], sequence]
        state = runner.snapshot(db)
        self.assertEqual(state, runner.Snapshot({}, {"links_id_seq": sequence}))
        query = db.json.call_args_list[-1].args[0]
        self.assertEqual(query,
                         "SELECT jsonb_build_object('last_value', s.last_value, "
                         "'log_cnt', s.log_cnt, 'is_called', s.is_called) "
                         'FROM "reconciliation_fixture"."links_id_seq" s;')
        self.assertNotIn("to_jsonb(s)", query)


class SQLGuardCoverage(unittest.TestCase):
    def test_lock_order_and_deterministic_barriers(self):
        sql = read("apply.sql")
        before, after, credit = ("-- HARNESS_BARRIER_BEFORE_EVENT_LOCK",
                                 "-- HARNESS_BARRIER_AFTER_EVENT_LOCK",
                                 "-- HARNESS_BARRIER_AFTER_CREDIT_LOCK")
        for hook in (before, after, credit):
            self.assertEqual(sql.count(hook), 1)
        self.assertLess(sql.index(before), sql.index("FOR UPDATE;"))
        self.assertLess(sql.index("FOR UPDATE;"), sql.index(after))
        self.assertLess(sql.index(after), sql.index("FOR SHARE;"))
        self.assertLess(sql.index("FOR SHARE;"), sql.index(credit))
        self.assertLess(sql.index(credit), sql.index("Unexpected event operation"))
        self.assertIn("LOCK TABLE reconciliation_fixture.links IN SHARE ROW EXCLUSIVE MODE", sql)
        gated = runner.render_template("apply.sql", {"fixture_contract": True}, barrier=(before, 17017000))
        self.assertIn("pg_advisory_lock(17017000)", gated)
        self.assertIn("harness_previous_lock_timeout", gated)
        self.assertIn("set_config('lock_timeout', '10s', true)", gated)
        self.assertIn("set_config('lock_timeout', harness_previous_lock_timeout, true)", gated)

    def test_both_directions_revalidate_all_leases(self):
        for name in ("apply.sql", "rollback.sql"):
            sql = read(name)
            for phrase in ("Reader/trigger definition lease changed", "Trigger set changed", "Constraint lease changed",
                           "Owner mismatch", "Posted credit lease changed", "Event-operation FK lease changed",
                           "NOT condeferrable AND convalidated", "Unexpected event operation",
                           "Credit already linked to a different target", "Unexpected epoch trigger",
                           "Not the exact applied state", "link_snapshot", "original_event_md5",
                           "original_expected_amount", "residual_expected", "credit_stable_md5"):
                self.assertIn(phrase, sql, (name, phrase))
            self.assertGreaterEqual(sql.count("GET DIAGNOSTICS v_n=ROW_COUNT"), 2)
            self.assertGreaterEqual(sql.count("IF v_n<>1 THEN RAISE EXCEPTION"), 2)
            self.assertIn("INTO STRICT v_event", sql)
            self.assertIn("INTO STRICT v_credit", sql)
            self.assertIn("v_epoch+2", sql)
            self.assertIn("to_jsonb(e)=", sql)

    def test_apply_first_write_uses_full_credit_lease(self):
        sql = read("apply.sql")
        self.assertIn("Credit full-row lease expired", sql)
        self.assertLess(sql.index("Credit full-row lease expired"),
                        sql.index("INSERT INTO reconciliation_fixture.links"))
        self.assertLess(sql.index("already_applied"), sql.index("Credit full-row lease expired"))
        self.assertIn("applied_in_transaction", sql)
        self.assertIn("SELECT current_setting('reconciliation_test.outcome',true)", sql)

    def test_inverse_requires_committed_row_and_link_hashes(self):
        sql = read("rollback.sql")
        for phrase in ("post_event_md5", "post_link_md5", "COMMITTED receipt hashes",
                       "changed since committed receipt", "already_original", "restored_in_transaction",
                       "Expected exactly one restored event", "Expected exactly one removed correction link"):
            self.assertIn(phrase, sql)
        self.assertLess(sql.index("COMMITTED receipt hashes"), sql.index("UPDATE reconciliation_fixture.events"))
        self.assertIn("to_jsonb(l)=v_link", sql)

    def test_runtime_suite_contains_required_scenarios(self):
        sql = read("run_tests.py")
        for name in ("compile_apply_idempotence", "retry_after_poll", "dry_run", "inverse", "trigger_failure",
                     "tampered_inverse", "missing_event", "operation_before_lock",
                     "operation_after_lock", "two_applies", "source_after_lock"):
            self.assertTrue(callable(getattr(runner.Rehearsal, name)))
        for phrase in ("full-poll lease expires", "pending source", "changed target owner",
                       "constraint schema drift", "missing source", "zero_update", "zero_insert",
                       "after_insert", "modified link note rejects inverse"):
            self.assertIn(phrase, sql)
        self.assertIn("pg_blocking_pids", sql)
        self.assertIn("wait_event = 'advisory'", sql)
        self.assertIn("time.monotonic() + timeout", sql)
        self.assertIn("pg_terminate_backend", sql)


if __name__ == "__main__":
    unittest.main(verbosity=2)
