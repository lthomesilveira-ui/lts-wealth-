# Readable reconstruction of the frozen synthetic PG85 package

This representation transports nine unchanged UTF-8 source files and a small
reconstructor. It regenerates inputs.json, expected.json, case-catalog.json and
overlay_contract.sql with the two original builders. No compression, base64,
network request, installation, SQL execution or change to the 85-case gate.

The target is exactly thirteen files, 689067 bytes, including the original
PACKAGE_MANIFEST.json with SHA256:
b96a934778a7cbe8d38f71b0067c074a30d85918b94f4fb513165ca2bc8cc831.

OUTPUT_PINS.json pins every target filename, byte size and SHA256 independently
of the transport manifest. The generator has its SHA256 embedded. A changed
source and changed transport hash cannot redefine these output pins. The nine
source files are also target members, so they must match the target pins before
any builder executes.

Before use, independently verify the received generator hash and transport
manifest hash against the coordinator's reviewed values. The script cannot
protect against an operator replacing the script itself or choosing a different
trust anchor. Do not derive the trusted manifest hash from an untrusted download.

Run from this directory, replacing REVIEWED_PIN with the externally reviewed
TRANSPORT_MANIFEST.json SHA256:

```
PYTHONDONTWRITEBYTECODE=1 python reconstruct.py \
  --expected-transport-manifest-sha256 REVIEWED_PIN \
  --output /an/existing/local/parent/new-pg85-directory
```

Requires Python 3 on POSIX with directory-fd and O_NOFOLLOW support. Use a
trusted local parent directory with no concurrent writers. The new output is
created mode 0700; this is integrity validation, not a security sandbox against
other hostile processes running as the same OS user.

The output path must not exist, even if it is an empty directory or dangling
symlink. The parent must exist. Any unexpected member, symlink, duplicate JSON
key, bad source, output name, size or hash causes refusal. All thirteen final
files are validated in a private temporary workspace before creating the output
directory. Emission and cleanup use pinned directory descriptors, so a replaced output
directory cannot redirect file writes or cleanup through a symlink. Existing
output contents are never overwritten. A second post-write
validation precedes the success receipt. An interrupted process can leave an
incomplete new output directory; it has no success receipt and must not be used.

Builders run from captured verified bytes; later changes to source files are not
used. Every final file is emitted from validated captured output bytes. No files
outside the strict allowlist are imported or emitted by this reconstruction.
The source programs use only the Python standard library. Only build_cases.py
and build_sql.py execute: run_pg17.py and the generated SQL are never executed.

The result is the unchanged original package. It still requires its separate
reviewed execution gate, PostgreSQL 17 on a disposable local Unix socket, and the
original runner's external package-manifest pin. Reconstruction success is not a
PostgreSQL result and does not establish financial integration or real binding.

The privacy scan checks the same UUID, email, endpoint and token patterns as the
original packaging gate; it complements human synthetic-only review. It is not a
universal detector of personal data. No user receipt or current invoice is part
of these sources. Years, identities and fixtures are synthetic.
