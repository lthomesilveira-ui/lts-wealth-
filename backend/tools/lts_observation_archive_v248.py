"""Offline, lossless observation archive pilot. No network, SQL writes or deletion.

The JSONB payloads MUST arrive as PostgreSQL ::text strings. They are never
converted to binary floats or reserialized. Hashes detect corruption; exact
tuple equality (not a hash alone) chooses which content is stored once.
"""

import argparse
from collections import Counter
from datetime import datetime
from decimal import Decimal
import gzip
import hashlib
import hmac
import json
from pathlib import Path
import re
import uuid
import zlib

EXPORT_FORMAT = "lts-observation-export-v1"
ARCHIVE_FORMAT = "lts-observation-archive-v248"
FIELDS = ("id", "user_id", "connection_id", "sync_run_id", "resource_type",
          "provider_record_id", "raw_hash", "raw_payload", "normalized_payload",
          "reconciliation", "ingest_action", "observed_at")
VERSION_FIELDS = ("user_id", "connection_id", "resource_type", "provider_record_id",
                  "raw_hash", "raw_payload", "normalized_payload", "reconciliation")
REF_FIELDS = ("id", "sync_run_id", "ingest_action", "observed_at")
MAX_BYTES = 64 * 1024 * 1024
MAX_ROWS = 100000


def require(condition, message):
    if not condition:
        raise ValueError(message)


def no_duplicates(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, "duplicate JSON key")
        result[key] = value
    return result


def reject_constant(_):
    raise ValueError("non-finite JSON number")


def loads(text, decimal=False):
    return json.loads(text, object_pairs_hook=no_duplicates,
                      parse_constant=reject_constant,
                      **({"parse_int": Decimal, "parse_float": Decimal} if decimal else {}))


def canonical(value):
    # Financial JSONB is already an exact string; only transport metadata is encoded.
    return json.dumps(value, ensure_ascii=False, sort_keys=True,
                      separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_uuid(value):
    require(isinstance(value, str) and str(uuid.UUID(value)) == value, "invalid UUID")


def validate_row(row, owner):
    require(isinstance(row, dict) and set(row) == set(FIELDS), "observation schema drift")
    require(all(isinstance(row[f], str) for f in FIELDS), "observation fields must be text")
    for f in ("id", "user_id", "connection_id", "sync_run_id"):
        checked_uuid(row[f])
    require(row["user_id"] == owner, "owner mismatch")
    require(row["ingest_action"] in ("inserted", "updated", "unchanged", "stale"), "unknown action")
    timestamp = datetime.fromisoformat(row["observed_at"])
    require(timestamp.tzinfo is not None, "timestamp must include timezone")
    for f in ("raw_payload", "normalized_payload", "reconciliation"):
        loads(row[f], decimal=True)  # Validate only; preserve original text verbatim.


def validate_exports(exports, owner, project):
    checked_uuid(owner)
    require(isinstance(project, str) and re.fullmatch(r"[a-z0-9]{20}", project), "invalid project")
    require(isinstance(exports, list) and 0 < len(exports) <= 100, "invalid export batch")
    rows, runs, ids = [], {}, set()
    export_keys = {"format", "source_project", "owner_id", "exported_at",
                   "run_metadata", "row_count", "rows"}
    for export in exports:
        require(isinstance(export, dict) and set(export) == export_keys, "export schema drift")
        require(export["format"] == EXPORT_FORMAT, "unsupported export format")
        require(export["owner_id"] == owner and export["source_project"] == project, "export scope mismatch")
        require(isinstance(export["rows"], list) and type(export["row_count"]) is int
                and export["row_count"] == len(export["rows"]), "incomplete export")
        require(isinstance(export["run_metadata"], str), "run metadata must be exact text")
        run = loads(export["run_metadata"], decimal=True)
        checked_uuid(run["id"])
        require(run["id"] not in runs and run["user_id"] == owner, "duplicate or cross-owner run")
        require(run["status"] == "success" and run["finished_at"] is not None, "pilot requires completed success run")
        require(run["raw_count"] == len(export["rows"]), "source run count mismatch")
        for row in export["rows"]:
            validate_row(row, owner)
            require(row["sync_run_id"] == run["id"] and row["connection_id"] == run["connection_id"], "row/run scope mismatch")
            require(row["id"] not in ids, "duplicate observation UUID")
            ids.add(row["id"])
            rows.append(row)
        runs[run["id"]] = {"metadata": export["run_metadata"], "exported_at": export["exported_at"]}
    require(len(rows) <= MAX_ROWS, "batch too large")
    # Stable order does not discard duplicate content or distinct observation IDs.
    rows.sort(key=lambda row: row["id"])
    require(len(canonical(rows)) <= MAX_BYTES, "export exceeds safe batch size")
    return rows, runs


def pack(exports, owner, project):
    rows, runs = validate_exports(exports, owner, project)
    exact_versions, versions, references = {}, {}, []
    for row in rows:
        content = tuple(row[f] for f in VERSION_FIELDS)
        if content not in exact_versions:
            key = digest(canonical(content))
            # A hypothetical hash collision fails closed, never merges different data.
            require(key not in versions or versions[key] == list(content), "content hash collision")
            versions[key] = list(content)
            exact_versions[content] = key
        references.append([*(row[f] for f in REF_FIELDS), exact_versions[content]])
    envelope = {"format": ARCHIVE_FORMAT, "owner_id": owner, "source_project": project,
                "field_schema": list(FIELDS), "version_schema": list(VERSION_FIELDS),
                "reference_schema": list(REF_FIELDS) + ["version_sha256"],
                "runs": runs, "versions": versions, "references": references,
                "row_count": len(rows), "run_counts": dict(Counter(r["sync_run_id"] for r in rows)),
                "source_rows_sha256": digest(canonical(rows))}
    plain = canonical(envelope)
    require(len(plain) <= MAX_BYTES, "archive exceeds safe batch size")
    archive = gzip.compress(plain, compresslevel=9, mtime=0)
    report = {"format": ARCHIVE_FORMAT, "rows": len(rows), "runs": len(runs),
              "versions": len(versions), "repeated_content_rows": len(rows) - len(versions),
              "source_rows_bytes": len(canonical(rows)), "archive_plain_bytes": len(plain),
              "archive_gzip_bytes": len(archive),
              "source_rows_gzip_without_dictionary_bytes": len(gzip.compress(canonical(rows), compresslevel=9, mtime=0)),
              "archive_sha256": digest(archive),
              "source_rows_sha256": envelope["source_rows_sha256"],
              "production_database_modified": False, "originals_removed": False}
    return archive, report


def unpack(archive, expected_sha256, owner, project):
    require(isinstance(expected_sha256, str) and re.fullmatch(r"[0-9a-f]{64}", expected_sha256), "trusted checksum required")
    require(len(archive) <= MAX_BYTES and hmac.compare_digest(digest(archive), expected_sha256), "archive checksum mismatch")
    inflater = zlib.decompressobj(wbits=31)
    plain = inflater.decompress(archive, MAX_BYTES + 1)
    require(len(plain) <= MAX_BYTES and inflater.eof and not inflater.unused_data
            and not inflater.unconsumed_tail, "invalid or oversized gzip stream")
    env = loads(plain.decode("utf-8"))
    require(isinstance(env, dict) and set(env) == {"format", "owner_id", "source_project", "field_schema",
            "version_schema", "reference_schema", "runs", "versions", "references", "row_count",
            "run_counts", "source_rows_sha256"}, "archive schema drift")
    require(env["format"] == ARCHIVE_FORMAT and env["owner_id"] == owner
            and env["source_project"] == project, "archive scope mismatch")
    require(env["field_schema"] == list(FIELDS) and env["version_schema"] == list(VERSION_FIELDS)
            and env["reference_schema"] == list(REF_FIELDS) + ["version_sha256"], "field schema mismatch")
    require(isinstance(env["versions"], dict) and isinstance(env["runs"], dict)
            and isinstance(env["references"], list) and len(env["references"]) <= MAX_ROWS, "invalid archive collections")
    for key, value in env["versions"].items():
        require(isinstance(value, list) and len(value) == len(VERSION_FIELDS)
                and all(isinstance(v, str) for v in value) and digest(canonical(value)) == key, "invalid content version")
    rows, ids = [], set()
    for ref in env["references"]:
        require(isinstance(ref, list) and len(ref) == len(REF_FIELDS) + 1
                and all(isinstance(v, str) for v in ref), "invalid reference")
        require(ref[-1] in env["versions"], "missing version")
        row = dict(zip(VERSION_FIELDS, env["versions"][ref[-1]]))
        row.update(zip(REF_FIELDS, ref[:-1]))
        validate_row(row, owner)
        require(row["id"] not in ids, "duplicate restored UUID")
        ids.add(row["id"])
        rows.append(row)
    rows.sort(key=lambda row: row["id"])
    require(type(env["row_count"]) is int and len(rows) == env["row_count"], "restored count mismatch")
    require(dict(Counter(r["sync_run_id"] for r in rows)) == env["run_counts"], "run counts mismatch")
    require(digest(canonical(rows)) == env["source_rows_sha256"], "restored source checksum mismatch")
    exports = []
    for run_id, entry in env["runs"].items():
        checked_uuid(run_id)
        require(isinstance(entry, dict) and set(entry) == {"metadata", "exported_at"}, "run manifest schema drift")
        require(isinstance(entry["metadata"], str) and loads(entry["metadata"], decimal=True)["id"] == run_id, "run manifest identity mismatch")
        subset = [r for r in rows if r["sync_run_id"] == run_id]
        exports.append({"format": EXPORT_FORMAT, "source_project": project, "owner_id": owner,
                        "exported_at": entry["exported_at"], "run_metadata": entry["metadata"],
                        "row_count": len(subset), "rows": subset})
    checked, _ = validate_exports(exports, owner, project)
    require(checked == rows, "unmanifested run")
    return rows, env["runs"]


def verify(exports, archive, expected_sha256, owner, project):
    original, original_runs = validate_exports(exports, owner, project)
    restored, restored_runs = unpack(archive, expected_sha256, owner, project)
    # Independent source comparison: matching self-contained hashes is insufficient.
    require(restored == original and restored_runs == original_runs, "exact reconstruction failed")
    return {"exact_rows_verified": len(original), "exact_run_metadata_verified": len(original_runs),
            "all_12_fields_equal": True, "payload_text_preserved": True,
            "source_rows_sha256": digest(canonical(original)), "restore_test": "PASS",
            "database_restore_test": "NOT_RUN", "production_database_modified": False}


def read_limited(path):
    with open(path, "rb") as stream:
        data = stream.read(MAX_BYTES + 1)
    require(len(data) <= MAX_BYTES, "input too large")
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("pack", "verify"))
    parser.add_argument("--exports", nargs="+", required=True)
    parser.add_argument("--owner", required=True)
    parser.add_argument("--project", required=True)
    parser.add_argument("--archive", required=True)
    parser.add_argument("--sha256")
    args = parser.parse_args()
    exports = [loads(read_limited(p).decode("utf-8")) for p in args.exports]
    if args.command == "pack":
        archive, report = pack(exports, args.owner, args.project)
        report.update(verify(exports, archive, report["archive_sha256"], args.owner, args.project))
        # New file only; never overwrite an existing audit artifact.
        path = Path(args.archive)
        with path.open("xb") as stream:
            stream.write(archive)
        path.chmod(0o600)
    else:
        report = verify(exports, read_limited(args.archive), args.sha256, args.owner, args.project)
    print(json.dumps(report, sort_keys=True, ensure_ascii=False))


if __name__ == "__main__":
    main()
