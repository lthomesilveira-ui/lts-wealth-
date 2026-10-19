"""Synthetic historical-status/source-proof tests; no real source data."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest
from test_lts_observation_archive_v248 import OWNER, PROJECT, source

SPEC = importlib.util.spec_from_file_location("snapshot", Path(__file__).resolve().parents[1] / "tools/lts_observation_snapshot_v248.py")
S = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(S)


def historical():
    exports = source()
    inventory = []
    for i, export in enumerate(exports):
        run = json.loads(export["run_metadata"])
        run["status"] = ("failed", "partial")[i]
        run["raw_count"] = 0  # Preserve historical counter mismatch; don't lose 4 rows.
        export["run_metadata"] = json.dumps(run)
        export["format"] = S.EXPORT
        export["source_vectors_sha256"] = S.vector_digest(export["rows"])
        inventory.append({"run_id": run["id"], "status": run["status"], "metadata": export["run_metadata"], "observation_count": 4})
    inv = {"format": S.INVENTORY, "owner_id": OWNER, "source_project": PROJECT,
           "field_schema": list(S.B.FIELDS), "catalog": [{"name": n} for n in S.B.FIELDS],
           "nonterminal_runs": 0, "runs": 2, "rows": 8, "actual_rows": 8, "inventory": inventory}
    return exports, inv


def transport_from(exports):
    values, lookup, runs = [], {}, []
    for export in exports:
        refs = []
        for row in export["rows"]:
            value = tuple(row[f] for f in S.B.VERSION_FIELDS)
            if value not in lookup:
                lookup[value] = len(values)
                values.append(list(value))
            refs.append([*(row[f] for f in S.B.REF_FIELDS), lookup[value]])
        runs.append({"run_metadata": export["run_metadata"], "row_count": export["row_count"],
                     "source_vectors_sha256": export["source_vectors_sha256"], "references": refs})
    return {"format": S.TRANSPORT, "owner_id": OWNER, "source_project": PROJECT,
            "exported_at": exports[0]["exported_at"], "versions": values, "runs": runs}


class HistoricalTests(unittest.TestCase):
    def test_failed_partial_and_counter_mismatch_preserved(self):
        exports, inv = historical()
        blob, report = S.pack(exports, inv, OWNER, PROJECT)
        result = S.verify(exports, blob, report["archive_sha256"], inv, OWNER, PROJECT)
        self.assertEqual(result["exact_rows_verified"], 8)
        _, runs = S.unpack(blob, report["archive_sha256"], inv, OWNER, PROJECT)
        self.assertEqual(json.loads(next(iter(runs.values()))["metadata"])["raw_count"], 0)

    def test_empty_failed_run_preserved(self):
        exports, inv = historical()
        exports[0]["rows"], exports[0]["row_count"] = [], 0
        exports[0]["source_vectors_sha256"] = S.vector_digest([])
        inv["inventory"][0]["observation_count"] = 0
        inv["rows"] = inv["actual_rows"] = 4
        blob, report = S.pack(exports, inv, OWNER, PROJECT)
        self.assertEqual(report["runs"], 2)
        self.assertEqual(S.verify(exports, blob, report["archive_sha256"], inv, OWNER, PROJECT)["exact_runs_verified"], 2)

    def test_source_hash_tampering(self):
        exports, inv = historical()
        exports[0]["rows"][0]["raw_payload"] = '{"amount": 0}'
        with self.assertRaises(ValueError):
            S.pack(exports, inv, OWNER, PROJECT)

    def test_metadata_repair_rejected(self):
        exports, inv = historical()
        run = json.loads(exports[0]["run_metadata"])
        run["raw_count"] = 4
        exports[0]["run_metadata"] = json.dumps(run)
        with self.assertRaises(ValueError):
            S.pack(exports, inv, OWNER, PROJECT)

    def test_inventory_wrong_count_and_nonterminal(self):
        for key, value in (("nonterminal_runs", 1), ("actual_rows", 9), ("runs", 1)):
            exports, inv = historical()
            inv[key] = value
            with self.assertRaises(ValueError):
                S.pack(exports, inv, OWNER, PROJECT)

    def test_unlisted_run(self):
        exports, inv = historical()
        inv["inventory"].pop()
        inv["runs"], inv["rows"], inv["actual_rows"] = 1, 4, 4
        with self.assertRaises(ValueError):
            S.pack(exports, inv, OWNER, PROJECT)

    def test_inventory_changed_after_archive(self):
        exports, inv = historical()
        blob, report = S.pack(exports, inv, OWNER, PROJECT)
        changed = copy.deepcopy(inv)
        changed["extra"] = "different"
        with self.assertRaises(ValueError):
            S.unpack(blob, report["archive_sha256"], changed, OWNER, PROJECT)

    def test_transport_exact_text_roundtrip(self):
        exports, inv = historical()
        transport = transport_from(exports)
        decoded = S.expand_transport(json.loads(json.dumps(transport)), inv, OWNER, PROJECT)
        self.assertEqual(decoded, exports)

    def test_transport_bad_slot(self):
        for slot in (-1, True, 999999):
            exports, inv = historical()
            transport = transport_from(exports)
            transport["runs"][0]["references"][0][-1] = slot
            with self.assertRaises(ValueError):
                S.expand_transport(transport, inv, OWNER, PROJECT)

    def test_transport_unreferenced_content(self):
        exports, inv = historical()
        transport = transport_from(exports)
        extra = list(transport["versions"][0])
        extra[-1] = '{"unused": true}'
        transport["versions"].append(extra)
        with self.assertRaises(ValueError):
            S.expand_transport(transport, inv, OWNER, PROJECT)

    def test_transport_duplicate_content(self):
        exports, inv = historical()
        transport = transport_from(exports)
        transport["versions"].append(list(transport["versions"][0]))
        with self.assertRaises(ValueError):
            S.expand_transport(transport, inv, OWNER, PROJECT)

    def test_transport_missing_reference_and_repeated_run(self):
        for repeated in (False, True):
            exports, inv = historical()
            transport = transport_from(exports)
            if repeated:
                transport["runs"].append(copy.deepcopy(transport["runs"][0]))
            else:
                transport["runs"][0]["references"].pop()
            with self.assertRaises(ValueError):
                S.expand_transport(transport, inv, OWNER, PROJECT)

    def test_transport_scope_and_source_proof(self):
        for field in ("scope", "proof"):
            exports, inv = historical()
            transport = transport_from(exports)
            if field == "scope":
                transport["source_project"] = "x" * 20
            else:
                transport["runs"][0]["source_vectors_sha256"] = "0" * 64
            with self.assertRaises(ValueError):
                S.expand_transport(transport, inv, OWNER, PROJECT)


if __name__ == "__main__":
    unittest.main()
