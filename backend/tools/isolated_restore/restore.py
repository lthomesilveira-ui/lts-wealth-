#!/usr/bin/env python3
"""Rehearse an official logical export in a fresh, offline PostgreSQL cluster.

This command never connects to a remote database or exports production data.
Its receipt certifies only this database rehearsal, not whole-app recovery.
"""
from __future__ import annotations

import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time


INPUTS = ("roles.sql", "schema.sql", "data.sql", "acceptance.sql")
RECOVERY_COMPONENTS = (
    "database_history",
    "auth_records",
    "storage_metadata",
    "storage_object_bytes",
    "roles_grants_rls",
    "application_consumers",
    "replay_and_cache",
)
SCOPE_STATES = {
    "covered_by_sql_acceptance",
    "separate_evidence_required",
    "not_captured",
}
ACCEPTANCE_EVIDENCE_TABLE = "public.lts_recovery_acceptance"
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class RehearsalError(Exception):
    pass


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def validate_manifest(manifest: dict) -> None:
    if manifest.get("data_kind") not in ("synthetic", "production"):
        raise RehearsalError("The manifest must identify the data kind")
    capture = manifest.get("capture")
    if not isinstance(capture, dict):
        raise RehearsalError("The manifest must declare one capture")
    if not isinstance(capture.get("id"), str) or not capture["id"].strip():
        raise RehearsalError("The capture must have a non-empty identifier")
    if not isinstance(capture.get("captured_at"), str) or not capture["captured_at"].strip():
        raise RehearsalError("The capture must have a timestamp")
    timestamp = capture["captured_at"].strip()
    try:
        parsed_timestamp = datetime.fromisoformat(
            timestamp[:-1] + "+00:00" if timestamp.endswith("Z") else timestamp
        )
    except ValueError as exc:
        raise RehearsalError("The capture timestamp must be valid ISO 8601") from exc
    if parsed_timestamp.tzinfo is None or parsed_timestamp.utcoffset() is None:
        raise RehearsalError("The capture timestamp must include a timezone")
    if capture.get("consistent_snapshot") is not True:
        raise RehearsalError("The SQL inputs must belong to one consistent snapshot")
    scope = manifest.get("recovery_scope")
    if not isinstance(scope, dict) or set(scope) != set(RECOVERY_COMPONENTS):
        raise RehearsalError("The manifest must declare every recovery component")
    invalid = {name: state for name, state in scope.items() if state not in SCOPE_STATES}
    if invalid:
        raise RehearsalError("The manifest contains an unsupported recovery scope state")
    if scope["database_history"] != "covered_by_sql_acceptance":
        raise RehearsalError("Database history must be covered by SQL acceptance")
    covered = {
        name for name, state in scope.items()
        if state == "covered_by_sql_acceptance"
    }
    expected_evidence = manifest.get("sql_acceptance_evidence_sha256")
    if not isinstance(expected_evidence, dict) or set(expected_evidence) != covered:
        raise RehearsalError(
            "The manifest must bind one expected SQL evidence digest per covered component"
        )
    if any(
        not isinstance(value, str) or not SHA256_PATTERN.fullmatch(value)
        for value in expected_evidence.values()
    ):
        raise RehearsalError(
            "Expected SQL evidence digests must be lowercase SHA-256 values"
        )


def recovery_scope_summary(scope: dict) -> dict:
    """Separate declared SQL coverage from missing and external evidence."""
    return {
        "components_covered_by_sql_acceptance": sorted(
            name for name, state in scope.items()
            if state == "covered_by_sql_acceptance"
        ),
        "components_with_separate_evidence_required": sorted(
            name for name, state in scope.items()
            if state == "separate_evidence_required"
        ),
        "components_not_captured": sorted(
            name for name, state in scope.items()
            if state == "not_captured"
        ),
        # Compatibility field retained for existing receipt consumers.
        "components_requiring_separate_evidence": sorted(
            name for name, state in scope.items()
            if state != "covered_by_sql_acceptance"
        ),
    }


def validate_sql_acceptance_evidence(
    rows: list[dict], scope: dict, expected_digests: dict
) -> list[dict]:
    """Require SQL evidence to match independently declared expected digests."""
    expected = {
        name for name, state in scope.items()
        if state == "covered_by_sql_acceptance"
    }
    if not isinstance(rows, list):
        raise RehearsalError("SQL acceptance evidence must be a list")
    components = [row.get("component") for row in rows if isinstance(row, dict)]
    if len(components) != len(rows) or len(set(components)) != len(components):
        raise RehearsalError("SQL acceptance evidence has invalid or duplicate components")
    if set(components) != expected:
        raise RehearsalError("SQL acceptance evidence does not match declared coverage")
    normalized = []
    for row in rows:
        if row.get("passed") is not True:
            raise RehearsalError("A SQL-covered recovery component did not pass")
        evidence_sha256 = row.get("evidence_sha256")
        if not isinstance(evidence_sha256, str) or not SHA256_PATTERN.fullmatch(evidence_sha256):
            raise RehearsalError("SQL acceptance evidence requires a lowercase SHA-256 digest")
        if evidence_sha256 != expected_digests.get(row["component"]):
            raise RehearsalError(
                "SQL acceptance evidence does not match the manifest expectation"
            )
        normalized.append({
            "component": row["component"],
            "passed": True,
            "evidence_sha256": evidence_sha256,
        })
    return sorted(normalized, key=lambda row: row["component"])


def verify_isolation(outer_namespace: str) -> dict:
    current_namespace = os.readlink("/proc/self/ns/net")
    if not outer_namespace or current_namespace == outer_namespace:
        raise RehearsalError("A separate network namespace is required")
    # Test the actual routing result, without sending application data. A new
    # namespace must have no route even to this reserved documentation address.
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe:
        probe.settimeout(1)
        result = probe.connect_ex(("192.0.2.1", 9))
    import errno
    if result != errno.ENETUNREACH:
        raise RehearsalError("Outbound routing is not demonstrably disabled")
    with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as probe:
        probe.settimeout(1)
        result6 = probe.connect_ex(("2001:db8::1", 9))
    # A brand-new namespace can have no IPv6 source address at all.
    if result6 not in (errno.ENETUNREACH, errno.EADDRNOTAVAIL):
        raise RehearsalError("IPv6 outbound routing is not demonstrably disabled")
    return {"namespace_changed": True, "ipv4_unreachable": True,
            "ipv6_unreachable": True}


def freeze_inputs(source: Path, destination: Path) -> dict:
    manifest_path = source / "manifest.json"
    if not manifest_path.is_file() or manifest_path.is_symlink():
        raise RehearsalError("A regular manifest.json file is required")
    manifest = json.loads(manifest_path.read_text())
    validate_manifest(manifest)
    expected = manifest.get("sha256", {})
    if set(expected) != set(INPUTS):
        raise RehearsalError("The manifest must hash every required input")
    destination.mkdir(mode=0o700)
    for name in INPUTS:
        original = source / name
        if not original.is_file() or original.is_symlink():
            raise RehearsalError("Every input must be a regular file")
        frozen = destination / name
        shutil.copyfile(original, frozen)
        frozen.chmod(0o600)
        if digest(frozen) != expected[name]:
            raise RehearsalError("An input hash did not match its manifest")
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2))
    (destination / "manifest.json").chmod(0o600)
    return manifest


def child_environment() -> dict:
    # Do not inherit connection URLs, startup settings, passwords or cloud keys.
    # LD_LIBRARY_PATH supports a separately installed, vendor PostgreSQL runtime.
    return {k: v for k, v in os.environ.items()
            if k in ("PATH", "LANG", "LC_ALL", "LD_LIBRARY_PATH", "TZ")}


def rehearse(args) -> int:
    output = args.output.resolve()
    receipt = {"database_rehearsal_passed": False,
               "full_application_recovery_certified": False,
               "production_connection_attempted": False,
               "storage_binary_api_restore_verified": False,
               "real_authentication_verified": False,
               "cluster_stopped": False}
    process = None
    output_created = False
    env = child_environment()
    socket_directory = None
    try:
        receipt["network"] = verify_isolation(args.outer_namespace)
        output.mkdir(mode=0o700, parents=False, exist_ok=False)
        output_created = True
        frozen = output / "input"
        manifest = freeze_inputs(args.input.resolve(), frozen)
        receipt["data_kind"] = manifest["data_kind"]
        receipt["capture"] = manifest["capture"]
        receipt["recovery_scope"] = manifest["recovery_scope"]
        receipt.update(recovery_scope_summary(manifest["recovery_scope"]))
        receipt["input_sha256"] = manifest["sha256"]
        pg_bin = args.pg_bin.resolve()
        version = subprocess.check_output([str(pg_bin / "postgres"), "--version"],
                                          env=env, text=True).strip()
        if " 17." not in version:
            raise RehearsalError("This rehearsal requires PostgreSQL 17")
        receipt["postgres_version"] = version
        data = output / "cluster"
        # A private short Unix-socket path avoids pathname limits and TCP ports.
        socket_directory = Path(tempfile.mkdtemp(prefix="socket-", dir=output))
        log_path = output / "private.log"
        with log_path.open("wb") as log:
            log_path.chmod(0o600)
            def run(argv, *, capture=False, timeout=120):
                result = subprocess.run(argv, env=env, stdout=subprocess.PIPE if capture else log,
                                        stderr=log, timeout=timeout, check=False)
                if result.returncode:
                    raise RehearsalError("A database command failed; inspect the private log")
                return result.stdout.decode() if capture else None
            run([str(pg_bin / "initdb"), "-D", str(data), "-U", "postgres",
                 "--auth-local=trust", "--auth-host=reject", "--no-locale", "-E", "UTF8"])
            process = subprocess.Popen([
                str(pg_bin / "postgres"), "-D", str(data), "-k", str(socket_directory),
                "-c", "listen_addresses=", "-c", "shared_preload_libraries=",
                "-c", "max_worker_processes=0", "-c", "max_parallel_workers=0",
                "-c", "cron.launch_active_jobs=off", "-c", "max_connections=10",
                "-c", "shared_buffers=32MB", "-c", "dynamic_shared_memory_type=mmap"
            ], env=env, stdout=log, stderr=log)
            psql = [str(pg_bin / "psql"), "-X", "-w", "-h", str(socket_directory),
                    "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1"]
            for _ in range(100):
                if process.poll() is not None:
                    raise RehearsalError("The offline server did not start")
                ready = subprocess.run([str(pg_bin / "pg_isready"), "-h", str(socket_directory),
                                        "-U", "postgres"], env=env, stdout=log, stderr=log)
                if ready.returncode == 0:
                    break
                time.sleep(0.1)
            else:
                raise RehearsalError("The offline server was not ready within ten seconds")
            settings_sql = ("select json_build_object('listen_addresses',current_setting('listen_addresses'),"
                            "'shared_preload_libraries',current_setting('shared_preload_libraries'),"
                            "'max_worker_processes',current_setting('max_worker_processes'),"
                            "'cron_enabled',current_setting('cron.launch_active_jobs'));")
            settings = json.loads(run(psql + ["-At", "-c", settings_sql], capture=True))
            if settings != {"listen_addresses": "", "shared_preload_libraries": "",
                            "max_worker_processes": "0", "cron_enabled": "off"}:
                raise RehearsalError("The offline server settings were not preserved")
            receipt["server_settings"] = settings
            run(psql + ["--single-transaction", "-f", str(frozen / "roles.sql"),
                        "-f", str(frozen / "schema.sql"),
                        "-c", "SET session_replication_role=replica",
                        "-f", str(frozen / "data.sql")], timeout=args.timeout)
            # Only the isolated copy is touched. These are never remote commands.
            disable_jobs = ("DO $offline$ BEGIN IF to_regclass('cron.job') IS NOT NULL THEN "
                            "EXECUTE 'UPDATE cron.job SET active=false'; END IF; END $offline$;")
            run(psql + ["-c", disable_jobs])
            run(psql + ["-f", str(frozen / "acceptance.sql")], timeout=args.timeout)
            evidence_sql = (
                "select coalesce(json_agg(json_build_object("
                "'component',component,'passed',passed,'evidence_sha256',evidence_sha256) "
                "order by component),'[]'::json)::text from "
                f"{ACCEPTANCE_EVIDENCE_TABLE};"
            )
            evidence_rows = json.loads(run(psql + ["-At", "-c", evidence_sql], capture=True))
            receipt["sql_acceptance_evidence"] = validate_sql_acceptance_evidence(
                evidence_rows,
                manifest["recovery_scope"],
                manifest["sql_acceptance_evidence_sha256"],
            )
            settings_after = json.loads(run(psql + ["-At", "-c", settings_sql], capture=True))
            if settings_after != settings:
                raise RehearsalError("Restore altered an isolation setting")
            receipt["database_rehearsal_passed"] = True
    except (RehearsalError, OSError, ValueError, subprocess.SubprocessError) as exc:
        receipt["error_type"] = type(exc).__name__
        if isinstance(exc, RehearsalError):
            receipt["error"] = str(exc)
        # Keep raw command output and possible source data out of the receipt.
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
                receipt["database_rehearsal_passed"] = False
                receipt["shutdown_forced"] = True
            receipt["cluster_stopped"] = process.poll() is not None
        if socket_directory is not None:
            shutil.rmtree(socket_directory)
        if output_created:
            receipt_path = output / "receipt.json"
            receipt_path.write_text(json.dumps(receipt, indent=2) + "\n")
            receipt_path.chmod(0o600)
    print(json.dumps(receipt, sort_keys=True))
    return 0 if receipt["database_rehearsal_passed"] and receipt["cluster_stopped"] else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True,
                        help="A new private directory; existing paths are rejected")
    parser.add_argument("--pg-bin", type=Path, required=True)
    parser.add_argument("--timeout", type=int, default=1800)
    parser.add_argument("--outer-namespace", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.timeout < 1:
        parser.error("timeout must be positive")
    if args.outer_namespace:
        return rehearse(args)
    if args.output.exists() or args.output.is_symlink():
        parser.error("output already exists")
    namespace = os.readlink("/proc/self/ns/net")
    # No fallback is allowed if the host cannot create a network namespace.
    result = subprocess.run([
        "unshare", "--user", "--map-current-user", "--net", "--fork", "--kill-child", "--",
        sys.executable, str(Path(__file__).resolve()), *sys.argv[1:],
        "--outer-namespace", namespace
    ], env=child_environment(), check=False)
    return result.returncode


if __name__ == "__main__":
    raise SystemExit(main())

