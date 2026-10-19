"""Private, read-only-export historical archive. No database client or deletion.

Unlike the strict success-only pilot, historical runs are checked against an
independent SQL inventory and per-run SQL SHA256, not their legacy raw_count.
Failed/partial/cancelled status and counters are preserved, never repaired.
"""
import argparse
from collections import Counter
import gzip
import importlib.util
import json
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("codec_v248", Path(__file__).with_name("lts_observation_archive_v248.py"))
B = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(B)
FORMAT = "lts-observation-historical-v248"
EXPORT = "lts-observation-export-v2"
INVENTORY = "lts-observation-inventory-v248"
TRANSPORT = "lts-observation-transport-v248"


def expand_transport(transport, inventory, owner, project):
    """Expand SQL exact-string dictionary transport, independently source-hashed."""
    B.require(isinstance(transport, dict) and set(transport) == {"format", "owner_id",
              "source_project", "exported_at", "versions", "runs"}, "transport schema drift")
    B.require(transport["format"] == TRANSPORT and transport["owner_id"] == owner
              and transport["source_project"] == project, "transport scope mismatch")
    versions = transport["versions"]
    B.require(isinstance(versions, list) and len(versions) <= B.MAX_ROWS, "transport version limit")
    for value in versions:
        B.require(isinstance(value, list) and len(value) == len(B.VERSION_FIELDS)
                  and all(isinstance(v, str) for v in value), "transport version schema drift")
    B.require(len({tuple(v) for v in versions}) == len(versions), "duplicate transport content")
    B.require(isinstance(transport["runs"], list) and 0 < len(transport["runs"]) <= 100,
              "transport run limit")
    exports, used = [], set()
    for run in transport["runs"]:
        B.require(isinstance(run, dict) and set(run) == {"run_metadata", "row_count",
                  "source_vectors_sha256", "references"}, "transport run schema drift")
        B.require(isinstance(run["references"], list) and len(run["references"]) <= B.MAX_ROWS,
                  "transport reference limit")
        rows = []
        for ref in run["references"]:
            B.require(isinstance(ref, list) and len(ref) == len(B.REF_FIELDS) + 1
                      and all(isinstance(v, str) for v in ref[:-1]) and type(ref[-1]) is int
                      and 0 <= ref[-1] < len(versions), "invalid transport reference")
            used.add(ref[-1])
            row = dict(zip(B.VERSION_FIELDS, versions[ref[-1]]))
            row.update(zip(B.REF_FIELDS, ref[:-1]))
            rows.append(row)
        exports.append({"format": EXPORT, "owner_id": owner, "source_project": project,
                        "exported_at": transport["exported_at"], "run_metadata": run["run_metadata"],
                        "row_count": run["row_count"], "source_vectors_sha256": run["source_vectors_sha256"],
                        "rows": rows})
    B.require(used == set(range(len(versions))), "unreferenced transport content")
    validate(exports, inventory, owner, project)
    return exports


def inventory_index(inventory, owner, project):
    B.checked_uuid(owner)
    B.require(inventory["format"] == INVENTORY and inventory["owner_id"] == owner
              and inventory["source_project"] == project, "inventory scope mismatch")
    B.require(inventory["field_schema"] == list(B.FIELDS), "inventory schema mismatch")
    B.require([x["name"] for x in inventory["catalog"]] == list(B.FIELDS), "catalog schema drift")
    B.require(inventory["nonterminal_runs"] == 0 and inventory["rows"] == inventory["actual_rows"], "inventory coverage incomplete")
    indexed = {}
    total = 0
    for item in inventory["inventory"]:
        B.checked_uuid(item["run_id"])
        B.require(item["run_id"] not in indexed, "duplicate inventory run")
        B.require(type(item["observation_count"]) is int and item["observation_count"] >= 0, "invalid inventory count")
        meta = B.loads(item["metadata"], decimal=True)
        B.require(meta["id"] == item["run_id"] and meta["user_id"] == owner, "inventory metadata scope mismatch")
        B.require(meta["status"] == item["status"] and meta["status"] in ("success", "partial", "failed", "cancelled")
                  and meta["finished_at"] is not None, "inventory contains nonterminal run")
        indexed[item["run_id"]] = item
        total += item["observation_count"]
    B.require(len(indexed) == inventory["runs"] and total == inventory["rows"], "inventory totals mismatch")
    return indexed


def vector_digest(rows):
    # Matches PostgreSQL array_to_json(ARRAY[12 text fields]) with LF separator,
    # ordered by UUID, including SHA256('') for a run with no observations.
    return B.digest(b"\n".join(B.canonical([r[f] for f in B.FIELDS]) for r in sorted(rows, key=lambda r: r["id"])))


def validate(exports, inventory, owner, project):
    index = inventory_index(inventory, owner, project)
    B.require(isinstance(exports, list) and 0 < len(exports) <= 100, "invalid historical batch")
    rows, runs, ids = [], {}, set()
    for export in exports:
        B.require(isinstance(export, dict) and set(export) == {"format", "source_project", "owner_id",
                  "exported_at", "run_metadata", "row_count", "rows", "source_vectors_sha256"}, "historical export schema drift")
        B.require(export["format"] == EXPORT and export["source_project"] == project
                  and export["owner_id"] == owner, "historical export scope mismatch")
        meta = B.loads(export["run_metadata"], decimal=True)
        run_id = meta["id"]
        B.require(run_id in index and run_id not in runs, "unlisted or repeated run")
        B.require(export["run_metadata"] == index[run_id]["metadata"], "run metadata changed since inventory")
        B.require(isinstance(export["rows"], list) and type(export["row_count"]) is int
                  and export["row_count"] == len(export["rows"]) == index[run_id]["observation_count"], "source observation coverage mismatch")
        for row in export["rows"]:
            B.validate_row(row, owner)
            B.require(row["sync_run_id"] == run_id and row["connection_id"] == meta["connection_id"], "historical row scope mismatch")
            B.require(row["id"] not in ids, "duplicate observation UUID")
            ids.add(row["id"])
            rows.append(row)
        B.require(vector_digest(export["rows"]) == export["source_vectors_sha256"], "independent SQL source hash mismatch")
        runs[run_id] = {"metadata": export["run_metadata"], "exported_at": export["exported_at"],
                        "source_vectors_sha256": export["source_vectors_sha256"], "row_count": export["row_count"]}
    B.require(len(rows) <= B.MAX_ROWS, "historical batch too large")
    rows.sort(key=lambda r: r["id"])
    B.require(len(B.canonical(rows)) <= B.MAX_BYTES, "historical batch exceeds byte limit")
    return rows, runs


def pack(exports, inventory, owner, project):
    rows, runs = validate(exports, inventory, owner, project)
    exact, versions, refs = {}, {}, []
    for row in rows:
        value = tuple(row[f] for f in B.VERSION_FIELDS)
        if value not in exact:
            key = B.digest(B.canonical(value))
            B.require(key not in versions or versions[key] == list(value), "historical content collision")
            versions[key], exact[value] = list(value), key
        refs.append([*(row[f] for f in B.REF_FIELDS), exact[value]])
    env = {"format": FORMAT, "owner_id": owner, "source_project": project,
           "inventory_sha256": B.digest(B.canonical(inventory)), "runs": runs,
           "versions": versions, "references": refs, "rows": len(rows),
           "source_rows_sha256": B.digest(B.canonical(rows))}
    plain = B.canonical(env)
    B.require(len(plain) <= B.MAX_BYTES, "historical archive too large")
    blob = gzip.compress(plain, compresslevel=9, mtime=0)
    report = {"format": FORMAT, "run_ids": sorted(runs), "runs": len(runs), "rows": len(rows),
              "versions": len(versions), "archive_sha256": B.digest(blob),
              "archive_gzip_bytes": len(blob), "source_rows_bytes": len(B.canonical(rows)),
              "source_rows_sha256": env["source_rows_sha256"], "inventory_sha256": env["inventory_sha256"],
              "originals_removed": False, "database_restore_test": "NOT_RUN"}
    return blob, report


def unpack(blob, checksum, inventory, owner, project):
    # Reuse bounded gzip validation without pretending this is the original format.
    B.require(isinstance(checksum, str) and B.digest(blob) == checksum, "historical archive checksum mismatch")
    B.require(len(blob) <= B.MAX_BYTES, "historical compressed input too large")
    inflater = B.zlib.decompressobj(wbits=31)
    plain = inflater.decompress(blob, B.MAX_BYTES + 1)
    B.require(len(plain) <= B.MAX_BYTES and inflater.eof and not inflater.unused_data
              and not inflater.unconsumed_tail, "invalid historical gzip")
    env = B.loads(plain.decode("utf-8"))
    B.require(set(env) == {"format", "owner_id", "source_project", "inventory_sha256", "runs",
              "versions", "references", "rows", "source_rows_sha256"}, "historical archive schema drift")
    B.require(env["format"] == FORMAT and env["owner_id"] == owner and env["source_project"] == project,
              "historical archive scope mismatch")
    B.require(env["inventory_sha256"] == B.digest(B.canonical(inventory)), "external inventory hash mismatch")
    inventory_index(inventory, owner, project)
    B.require(isinstance(env["references"], list) and len(env["references"]) <= B.MAX_ROWS, "historical reference limit")
    for key, value in env["versions"].items():
        B.require(isinstance(value, list) and len(value) == len(B.VERSION_FIELDS)
                  and all(isinstance(v, str) for v in value) and B.digest(B.canonical(value)) == key, "historical version mismatch")
    rows = []
    for ref in env["references"]:
        B.require(isinstance(ref, list) and len(ref) == len(B.REF_FIELDS) + 1
                  and all(isinstance(v, str) for v in ref) and ref[-1] in env["versions"], "historical reference mismatch")
        row = dict(zip(B.VERSION_FIELDS, env["versions"][ref[-1]]))
        row.update(zip(B.REF_FIELDS, ref[:-1]))
        rows.append(row)
    rows.sort(key=lambda r: r["id"])
    B.require(type(env["rows"]) is int and len(rows) == env["rows"]
              and B.digest(B.canonical(rows)) == env["source_rows_sha256"], "historical restored rows mismatch")
    exports = []
    for run_id, entry in env["runs"].items():
        B.require(set(entry) == {"metadata", "exported_at", "source_vectors_sha256", "row_count"}
                  and B.loads(entry["metadata"], decimal=True)["id"] == run_id, "historical run manifest mismatch")
        exports.append({"format": EXPORT, "owner_id": owner, "source_project": project,
                        "run_metadata": entry["metadata"], "exported_at": entry["exported_at"],
                        "row_count": entry["row_count"], "rows": [r for r in rows if r["sync_run_id"] == run_id],
                        "source_vectors_sha256": entry["source_vectors_sha256"]})
    checked, runs = validate(exports, inventory, owner, project)
    B.require(checked == rows, "historical unmanifested rows")
    return rows, runs


def verify(exports, blob, checksum, inventory, owner, project):
    original, runs = validate(exports, inventory, owner, project)
    restored, restored_runs = unpack(blob, checksum, inventory, owner, project)
    B.require(original == restored and runs == restored_runs, "historical exact reconstruction failed")
    return {"restore_test": "PASS", "exact_rows_verified": len(original), "exact_runs_verified": len(runs),
            "all_12_fields_equal": True, "independent_sql_source_hashes_verified": True}


def write_new(path, data):
    with Path(path).open("xb") as stream:
        stream.write(data)
    Path(path).chmod(0o600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("pack", "verify-collection", "expand-transport"))
    parser.add_argument("--inventory", required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--exports", nargs="+")
    parser.add_argument("--archive")
    parser.add_argument("--ledger")
    parser.add_argument("--directory")
    parser.add_argument("--source-directory")
    parser.add_argument("--report")
    parser.add_argument("--transport")
    args = parser.parse_args()
    inv = B.loads(B.read_limited(args.inventory).decode("utf-8"))
    if args.command == "expand-transport":
        transport = B.loads(B.read_limited(args.transport).decode("utf-8"))
        exports = expand_transport(transport, inv, args.owner, args.project)
        existing, created, rows = 0, 0, 0
        # Validate all existing sources before creating any new file. Never overwrite.
        pending = []
        for export in exports:
            run_id = B.loads(export["run_metadata"], decimal=True)["id"]
            path = Path(args.source_directory) / ("export-" + run_id + ".json")
            if path.exists():
                old = B.loads(B.read_limited(path).decode("utf-8"))
                old_rows, old_runs = validate([old], inv, args.owner, args.project)
                new_rows, new_runs = validate([export], inv, args.owner, args.project)
                B.require(old_rows == new_rows and old["run_metadata"] == export["run_metadata"]
                          and old["source_vectors_sha256"] == export["source_vectors_sha256"],
                          "transport disagrees with retained independent export")
                existing += 1
            else:
                pending.append((path, export))
            rows += export["row_count"]
        for path, export in pending:
            write_new(path, B.canonical(export))
            created += 1
        report = {"transport_source_hashes_verified": True, "exact_existing_sources_verified": existing,
                  "created_exports": created, "rows": rows, "production_modified": False}
    elif args.command == "pack":
        exports = [B.loads(B.read_limited(p).decode("utf-8")) for p in args.exports]
        blob, report = pack(exports, inv, args.owner, args.project)
        report.update(verify(exports, blob, report["archive_sha256"], inv, args.owner, args.project))
        write_new(args.archive, blob)
    else:
        index = inventory_index(inv, args.owner, args.project)
        ledger = B.loads(B.read_limited(args.ledger).decode("utf-8"))
        B.require(ledger["inventory_sha256"] == B.digest(B.canonical(inv)), "collection inventory mismatch")
        all_ids, all_runs, archive_names, byte_count = set(), set(), set(), 0
        for item in ledger["archives"]:
            filename = item["file_name"]
            B.require(Path(filename).name == filename and filename not in archive_names, "unsafe or repeated archive name")
            archive_names.add(filename)
            blob = B.read_limited(Path(args.directory) / filename)
            restored, runs = unpack(blob, item["archive_sha256"], inv, args.owner, args.project)
            B.require(sorted(runs) == item["run_ids"] and len(restored) == item["rows"], "collection ledger mismatch")
            exports = [B.loads(B.read_limited(Path(args.source_directory) / ("export-" + run_id + ".json")).decode("utf-8")) for run_id in runs]
            verify(exports, blob, item["archive_sha256"], inv, args.owner, args.project)
            for row in restored:
                B.require(row["id"] not in all_ids, "duplicate UUID across archives")
                all_ids.add(row["id"])
            B.require(not all_runs.intersection(runs), "duplicate run across archives")
            all_runs.update(runs)
            byte_count += len(blob)
        B.require(all_runs == set(index) and len(all_ids) == inv["rows"], "full inventory coverage not achieved")
        report = {"format": FORMAT, "restore_test": "PASS", "exact_rows_verified": len(all_ids),
                  "exact_runs_verified": len(all_runs), "archive_parts": len(archive_names), "archive_bytes": byte_count,
                  "all_12_fields_equal": True, "independent_sql_source_hashes_verified": True,
                  "full_observation_inventory_covered": True, "database_restore_test": "NOT_RUN",
                  "atomic_database_backup": False, "originals_removed": False, "production_modified": False}
    if args.report:
        write_new(args.report, B.canonical(report))
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
