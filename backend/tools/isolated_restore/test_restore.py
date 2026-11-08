"""Invented data only. This suite does not certify production restoration."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).with_name("restore.py")
spec = importlib.util.spec_from_file_location("offline_restore", SCRIPT)
restore = importlib.util.module_from_spec(spec)
spec.loader.exec_module(restore)


def fixture(directory):
    directory.mkdir()
    contents = {
        "roles.sql": "CREATE ROLE fixture_owner; CREATE ROLE fixture_other;",
        "schema.sql": """
CREATE SCHEMA auth; CREATE SCHEMA storage; CREATE SCHEMA cron;
CREATE TABLE auth.users(id text PRIMARY KEY);
CREATE TABLE storage.objects(id int PRIMARY KEY, name text);
CREATE TABLE cron.job(id int PRIMARY KEY, active boolean);
CREATE TABLE public.ledger(id int PRIMARY KEY, owner_name text, amount numeric);
ALTER TABLE public.ledger ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA public TO fixture_owner, fixture_other;
GRANT SELECT ON public.ledger TO fixture_owner, fixture_other;
CREATE POLICY own_rows ON public.ledger USING(owner_name=current_user);
CREATE FUNCTION public.fixture_total() RETURNS numeric LANGUAGE sql SECURITY INVOKER
AS 'select sum(amount) from public.ledger';
CREATE FUNCTION public.fixture_unwanted_trigger() RETURNS trigger LANGUAGE plpgsql
AS $$BEGIN RAISE EXCEPTION 'insert side effect must not run'; END$$;
CREATE TRIGGER insert_side_effect BEFORE INSERT ON public.ledger
FOR EACH ROW EXECUTE FUNCTION public.fixture_unwanted_trigger();
""",
        "data.sql": """
COPY auth.users(id) FROM stdin;
fixture_owner
fixture_other
\\.
COPY storage.objects(id,name) FROM stdin;
1\tfixture-only.txt
\\.
COPY cron.job(id,active) FROM stdin;
1\tt
\\.
COPY public.ledger(id,owner_name,amount) FROM stdin;
1\tfixture_owner\t100
2\tfixture_other\t240
\\.
""",
        "acceptance.sql": """
CREATE TABLE public.lts_recovery_acceptance(
 component text PRIMARY KEY,
 passed boolean NOT NULL,
 evidence_sha256 text NOT NULL
);
DO $$BEGIN
 IF (SELECT count(*) FROM auth.users)<>2 THEN RAISE EXCEPTION 'auth count'; END IF;
 IF (SELECT count(*) FROM storage.objects)<>1 THEN RAISE EXCEPTION 'metadata'; END IF;
 IF (SELECT sum(amount) FROM public.ledger)<>340 THEN RAISE EXCEPTION 'history'; END IF;
 IF EXISTS(SELECT FROM cron.job WHERE active) THEN RAISE EXCEPTION 'active job'; END IF;
END$$;
SET ROLE fixture_owner;
DO $$BEGIN
 IF (SELECT count(*) FROM public.ledger)<>1 OR public.fixture_total()<>100
 THEN RAISE EXCEPTION 'own and cross read'; END IF;
END$$;
RESET ROLE;
SET ROLE fixture_other;
DO $$BEGIN
 IF (SELECT count(*) FROM public.ledger)<>1 OR public.fixture_total()<>240
 THEN RAISE EXCEPTION 'other role'; END IF;
END$$;
RESET ROLE;
INSERT INTO public.lts_recovery_acceptance(component,passed,evidence_sha256) VALUES
 ('database_history',true,repeat('1',64)),
 ('auth_records',true,repeat('2',64)),
 ('storage_metadata',true,repeat('3',64)),
 ('roles_grants_rls',true,repeat('4',64)),
 ('application_consumers',true,repeat('5',64));
""",
    }
    for name, content in contents.items():
        (directory / name).write_text(content)
    rehash(directory)


def rehash(directory):
    (directory / "manifest.json").write_text(json.dumps({
        "data_kind": "synthetic",
        "capture": {
            "id": "synthetic-fixture-1",
            "captured_at": "2026-01-01T00:00:00Z",
            "consistent_snapshot": True,
        },
        "recovery_scope": {
            "database_history": "covered_by_sql_acceptance",
            "auth_records": "covered_by_sql_acceptance",
            "storage_metadata": "covered_by_sql_acceptance",
            "storage_object_bytes": "separate_evidence_required",
            "roles_grants_rls": "covered_by_sql_acceptance",
            "application_consumers": "covered_by_sql_acceptance",
            "replay_and_cache": "not_captured",
        },
        "sha256": {name: restore.digest(directory / name) for name in restore.INPUTS}
    }))


class FixtureCase:
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.source = self.root / "source"
        fixture(self.source)

    def tearDown(self):
        self.temporary.cleanup()


class InputGuards(FixtureCase, unittest.TestCase):

    def test_freezes_bytes_and_permissions(self):
        frozen = self.root / "frozen"
        manifest = restore.freeze_inputs(self.source, frozen)
        (self.source / "data.sql").write_text("changed after copy")
        self.assertEqual(restore.digest(frozen / "data.sql"), manifest["sha256"]["data.sql"])
        self.assertEqual(frozen.stat().st_mode & 0o777, 0o700)
        self.assertEqual((frozen / "data.sql").stat().st_mode & 0o777, 0o600)

    def test_rejects_tampering(self):
        (self.source / "data.sql").write_text("changed before copy")
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_symlink(self):
        (self.source / "data.sql").unlink()
        (self.source / "data.sql").symlink_to(self.source / "schema.sql")
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_missing_acceptance(self):
        (self.source / "acceptance.sql").unlink()
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_mixed_or_undeclared_capture(self):
        manifest_path = self.source / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["capture"]["consistent_snapshot"] = False
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_invalid_or_timezone_free_capture_timestamp(self):
        for timestamp in ("not-a-timestamp", "2026-01-01T00:00:00"):
            with self.subTest(timestamp=timestamp):
                manifest_path = self.source / "manifest.json"
                manifest = json.loads(manifest_path.read_text())
                manifest["capture"]["captured_at"] = timestamp
                manifest_path.write_text(json.dumps(manifest))
                with self.assertRaises(restore.RehearsalError):
                    restore.freeze_inputs(self.source, self.root / f"frozen-{timestamp[:3]}")
                rehash(self.source)

    def test_recovery_scope_summary_distinguishes_missing_evidence(self):
        manifest = json.loads((self.source / "manifest.json").read_text())
        summary = restore.recovery_scope_summary(manifest["recovery_scope"])
        self.assertEqual(summary["components_not_captured"], ["replay_and_cache"])
        self.assertEqual(summary["components_with_separate_evidence_required"],
                         ["storage_object_bytes"])
        self.assertIn("database_history",
                      summary["components_covered_by_sql_acceptance"])
        self.assertEqual(summary["components_requiring_separate_evidence"],
                         ["replay_and_cache", "storage_object_bytes"])

    def test_sql_acceptance_evidence_must_match_declared_coverage(self):
        manifest = json.loads((self.source / "manifest.json").read_text())
        expected = [
            {"component": name, "passed": True, "evidence_sha256": str(i) * 64}
            for i, name in enumerate(sorted(
                key for key, state in manifest["recovery_scope"].items()
                if state == "covered_by_sql_acceptance"
            ), start=1)
        ]
        self.assertEqual(
            restore.validate_sql_acceptance_evidence(expected, manifest["recovery_scope"]),
            expected,
        )
        for bad in (
            expected[:-1],
            expected + [expected[0]],
            [{**row, "passed": False} if index == 0 else row
             for index, row in enumerate(expected)],
            [{**row, "evidence_sha256": "not-a-digest"} if index == 0 else row
             for index, row in enumerate(expected)],
        ):
            with self.subTest(rows=bad):
                with self.assertRaises(restore.RehearsalError):
                    restore.validate_sql_acceptance_evidence(
                        bad, manifest["recovery_scope"]
                    )

    def test_rejects_incomplete_recovery_scope(self):
        manifest_path = self.source / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        del manifest["recovery_scope"]["storage_object_bytes"]
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_unsupported_scope_state(self):
        manifest_path = self.source / "manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["recovery_scope"]["replay_and_cache"] = "verified"
        manifest_path.write_text(json.dumps(manifest))
        with self.assertRaises(restore.RehearsalError):
            restore.freeze_inputs(self.source, self.root / "frozen")

    def test_rejects_same_network_namespace(self):
        with self.assertRaises(restore.RehearsalError):
            restore.verify_isolation(os.readlink('/proc/self/ns/net'))

    def test_does_not_inherit_connection_credentials(self):
        original = os.environ.copy()
        try:
            os.environ.update(PGHOST="remote", PGPASSWORD="fixture", SUPABASE_DB_URL="fixture")
            clean = restore.child_environment()
            self.assertFalse({"PGHOST", "PGPASSWORD", "SUPABASE_DB_URL"} & clean.keys())
        finally:
            os.environ.clear()
            os.environ.update(original)


@unittest.skipUnless(os.environ.get("LTS_RESTORE_PG_BIN"), "native PostgreSQL 17 binaries not supplied")
class NativeRestore(FixtureCase, unittest.TestCase):
    def invoke(self, name):
        result = subprocess.run([
            sys.executable, str(SCRIPT), "--input", str(self.source), "--output", str(self.root/name),
            "--pg-bin", os.environ["LTS_RESTORE_PG_BIN"], "--timeout", "30"
        ], capture_output=True, text=True, timeout=60)
        receipt = self.root / name / "receipt.json"
        return result, json.loads(receipt.read_text()) if receipt.exists() else None

    def test_restores_in_offline_postgres_and_stops_it(self):
        result, receipt = self.invoke("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(receipt["database_rehearsal_passed"])
        self.assertTrue(receipt["cluster_stopped"])
        self.assertEqual(receipt["data_kind"], "synthetic")
        self.assertEqual(receipt["server_settings"]["listen_addresses"], "")
        self.assertFalse(receipt["production_connection_attempted"])
        self.assertFalse(receipt["full_application_recovery_certified"])
        self.assertFalse(receipt["real_authentication_verified"])
        self.assertFalse(receipt["storage_binary_api_restore_verified"])
        self.assertEqual(receipt["capture"]["id"], "synthetic-fixture-1")
        self.assertEqual(receipt["components_requiring_separate_evidence"],
                         ["replay_and_cache", "storage_object_bytes"])
        self.assertEqual(receipt["components_not_captured"], ["replay_and_cache"])
        self.assertEqual(receipt["components_with_separate_evidence_required"],
                         ["storage_object_bytes"])
        self.assertEqual(
            [row["component"] for row in receipt["sql_acceptance_evidence"]],
            ["application_consumers", "auth_records", "database_history",
             "roles_grants_rls", "storage_metadata"],
        )
        original = (self.root / "success" / "receipt.json").read_bytes()
        repeated, _ = self.invoke("success")
        self.assertNotEqual(repeated.returncode, 0)
        self.assertEqual((self.root / "success" / "receipt.json").read_bytes(), original)

    def test_failed_acceptance_is_not_a_restore_pass(self):
        (self.source / "acceptance.sql").write_text("DO $$BEGIN RAISE EXCEPTION 'fixture failure'; END$$;")
        rehash(self.source)
        result, receipt = self.invoke("rejected")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNotNone(receipt, result.stdout + result.stderr)
        self.assertFalse(receipt["database_rehearsal_passed"])
        self.assertIn("server_settings", receipt)
        self.assertTrue(receipt["cluster_stopped"])
        self.assertFalse(receipt["full_application_recovery_certified"])

    def test_missing_extension_aborts_without_stripping_schema(self):
        with (self.source / "schema.sql").open("a") as target:
            target.write("CREATE EXTENSION fixture_extension_that_does_not_exist;")
        rehash(self.source)
        result, receipt = self.invoke("missing-extension")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIsNotNone(receipt, result.stdout + result.stderr)
        self.assertFalse(receipt["database_rehearsal_passed"])
        self.assertIn("server_settings", receipt)
        self.assertTrue(receipt["cluster_stopped"])

    def test_missing_structured_acceptance_evidence_is_rejected(self):
        acceptance = self.source / "acceptance.sql"
        acceptance.write_text(
            acceptance.read_text().split(
                "CREATE TABLE public.lts_recovery_acceptance", 1
            )[0] + "SELECT 1;\n"
        )
        rehash(self.source)
        result, receipt = self.invoke("missing-evidence")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(receipt["database_rehearsal_passed"])
        self.assertTrue(receipt["cluster_stopped"])


if __name__ == "__main__":
    unittest.main()

