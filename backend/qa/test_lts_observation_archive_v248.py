"""Synthetic-only tests. Never put owner bank exports in git/CI artifacts."""
import copy
import gzip
import importlib.util
import json
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("archive", Path(__file__).resolve().parents[1] / "tools/lts_observation_archive_v248.py")
A = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(A)
OWNER = "00000000-0000-4000-8000-000000000001"
CONN = "00000000-0000-4000-8000-000000000002"
PROJECT = "abcdefghijklmnopqrst"


def source():
    exports = []
    for run_n in (3, 4):
        run_id = f"00000000-0000-4000-8000-{run_n:012d}"
        rows = []
        for n in range(4):
            rows.append({"id": f"00000000-0000-4000-8000-{run_n * 10 + n:012d}",
                "user_id": OWNER, "connection_id": CONN, "sync_run_id": run_id,
                "resource_type": "balance", "provider_record_id": f"record-{n}", "raw_hash": "same",
                "raw_payload": '{"amount": 9007199254740993.12345678901234567890, "note": "ação \\n"}',
                "normalized_payload": '{"balance": -0.00000000000000000001, "unknown": null}',
                "reconciliation": '{"state": "unresolved"}', "ingest_action": "unchanged",
                "observed_at": "2026-10-05 13:15:01.123456+00"})
        run = {"id": run_id, "user_id": OWNER, "connection_id": CONN,
               "status": "success", "finished_at": "2026-10-05T13:16:00Z", "raw_count": 4}
        exports.append({"format": A.EXPORT_FORMAT, "source_project": PROJECT, "owner_id": OWNER,
                        "exported_at": "2026-10-05T19:00:00Z", "run_metadata": json.dumps(run),
                        "row_count": 4, "rows": rows})
    return exports


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.exports = source()
        self.archive, self.report = A.pack(self.exports, OWNER, PROJECT)

    def test_exact_roundtrip_and_content_dedup(self):
        self.assertEqual(self.report["rows"], 8)
        self.assertEqual(self.report["versions"], 4)
        result = A.verify(self.exports, self.archive, self.report["archive_sha256"], OWNER, PROJECT)
        self.assertEqual(result["exact_rows_verified"], 8)
        self.assertEqual(result["database_restore_test"], "NOT_RUN")

    def test_numeric_precision_nulls_and_unicode(self):
        rows, _ = A.unpack(self.archive, self.report["archive_sha256"], OWNER, PROJECT)
        self.assertEqual(rows[0]["raw_payload"], self.exports[0]["rows"][0]["raw_payload"])
        self.assertIn("9007199254740993.12345678901234567890", rows[0]["raw_payload"])
        self.assertIn('"unknown": null', rows[0]["normalized_payload"])

    def test_normalized_change_not_merged_by_raw_hash(self):
        self.exports[1]["rows"][0]["normalized_payload"] = '{"balance": 1}'
        _, report = A.pack(self.exports, OWNER, PROJECT)
        self.assertEqual(report["versions"], 5)

    def test_reconciliation_change_not_merged(self):
        self.exports[1]["rows"][0]["reconciliation"] = '{"state": "resolved"}'
        _, report = A.pack(self.exports, OWNER, PROJECT)
        self.assertEqual(report["versions"], 5)

    def test_deterministic_archive(self):
        self.assertEqual(A.pack(copy.deepcopy(self.exports), OWNER, PROJECT)[0], self.archive)

    def test_wrong_owner_and_project(self):
        for owner, project in ((CONN, PROJECT), (OWNER, "abcdefghijklmnopqrss")):
            with self.assertRaises(ValueError):
                A.unpack(self.archive, self.report["archive_sha256"], owner, project)

    def test_duplicate_ids(self):
        self.exports[1]["rows"][0]["id"] = self.exports[0]["rows"][0]["id"]
        with self.assertRaises(ValueError):
            A.pack(self.exports, OWNER, PROJECT)

    def test_incomplete_run(self):
        self.exports[0]["rows"].pop()
        self.exports[0]["row_count"] = 3
        with self.assertRaises(ValueError):
            A.pack(self.exports, OWNER, PROJECT)

    def test_schema_drift(self):
        self.exports[0]["rows"][0]["future_column"] = "unhandled"
        with self.assertRaises(ValueError):
            A.pack(self.exports, OWNER, PROJECT)

    def test_invalid_payload(self):
        for text in ('{"x": NaN}', '{"x":1,"x":2}', 'not json'):
            self.exports = source()
            self.exports[0]["rows"][0]["raw_payload"] = text
            with self.assertRaises(ValueError):
                A.pack(self.exports, OWNER, PROJECT)

    def test_corruption_and_truncation(self):
        for data in (self.archive[:-1], self.archive + b"trailing", self.archive[:25] + b"bad"):
            with self.assertRaises((ValueError, zlib_error())):
                A.unpack(data, self.report["archive_sha256"], OWNER, PROJECT)

    def test_missing_content_version(self):
        env = A.loads(gzip.decompress(self.archive).decode())
        env["versions"].pop(next(iter(env["versions"])))
        data = gzip.compress(A.canonical(env), mtime=0)
        with self.assertRaises(ValueError):
            A.unpack(data, A.digest(data), OWNER, PROJECT)

    def test_source_tampering_rejected_even_with_new_archive_hash(self):
        changed = copy.deepcopy(self.exports)
        changed[0]["rows"][0]["raw_payload"] = '{"amount": 0}'
        data, report = A.pack(changed, OWNER, PROJECT)
        with self.assertRaises(ValueError):
            A.verify(self.exports, data, report["archive_sha256"], OWNER, PROJECT)

    def test_gzip_bomb_guard(self):
        data = gzip.compress(b"x" * 4096, mtime=0)
        old_limit = A.MAX_BYTES
        try:
            A.MAX_BYTES = 1024
            with self.assertRaises(ValueError):
                A.unpack(data, A.digest(data), OWNER, PROJECT)
        finally:
            A.MAX_BYTES = old_limit

    def test_required_external_checksum(self):
        with self.assertRaises(ValueError):
            A.unpack(self.archive, None, OWNER, PROJECT)


def zlib_error():
    import zlib
    return zlib.error


if __name__ == "__main__":
    unittest.main()
