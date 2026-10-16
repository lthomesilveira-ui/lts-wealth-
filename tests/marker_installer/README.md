# Synthetic PostgreSQL17 marker-installer gate

Prepared locally, not executed locally. This package does not connect to production. Publish only the paths in PUBLIC_FILES.json after review, never this directory recursively: the private generation helper is deliberately excluded.

## What runs

The apply/rollback are exact parameterizations of the real marker installer. Only owner/operation/date literals, reviewed metadata arrays, baseline hashes and sanitized baseline definitions are substituted. Control flow, checks, locking, epoch/cache updates, audit, transaction isolation and SQL invariants are retained. A single synthetic source relation is additionally leased for post-DDL metadata-drift testing.

The published SQL templates still contain ready=false. They reject execution. The runtime first verifies a fresh dedicated loopback PostgreSQL17 database and role, zero preexisting public objects/functions and absence of fixture roles. Only after those checks does it enable an ephemeral in-memory copy. Neither the private installer nor published templates are modified. No production credentials or inherited PG connection environment are used.

The entire baseline function, not merely the final projection, is compiled with check_function_bodies=on and executed on invented rows. Seventy-one function signatures and 49 source relation column contracts are recreated; source views are represented by synthetic tables. Upstream function bodies are explicit stubs, while the final consumer wrapper executes the complete baseline. This validates parsing, type resolution and baseline behavior against those contracts. It is not production reader-chain integration, real-source validation or an execution of the P05 settlement behavior.

The baseline is sanitized by consistent replacements of canonical people, property identifiers/display, private descriptive matching strings and historical decision tags/dates. The private authoring helper proves exact reversal of these substitutions and that the only original/candidate difference remains the marker predicate. Public artifacts contain only synthetic actors and values. Private ACLs, OIDs, owners, raw leases and evidence are not exported; the runner measures metadata on its disposable objects.

## Coverage

- Complete sanitized baseline compiles and executes; exactly the two generic health/clothing rows change
- Education, known person, missing category, property review and unknown description remain invariant
- All other 19 output fields, row cardinality, object OIDs, owners, ACLs, configs and relation properties remain unchanged
- Required five-overlay audit missing or rolled back causes refusal
- Real apply, exact rollback, duplicate-operation refusal and preservation of audit history
- Pre-DDL ACL, owner, configuration, dependency and relation drift
- Post-DDL financial mutation, forbidden Education transition, ACL mutation and source-schema mutation; every rejected transaction restores exact prior state
- Rollback blocked by a later function change and atomic on a post-DDL failure
- One epoch advance and global nonnull-user cache deletion
- Audit explicitly invalidates all five global homologation stages

The prior projection-only suite remains separate. A passed receipt from this suite is still not permission to deploy; production metadata, exact unsanitized definition and authorization require independent review.

## Run

Use the proposed standalone job with a fresh postgres:17 service, database/role wealth_synthetic_marker_installer and the synthetic CI-only password. No secrets are needed.

    python tests/marker_installer/validate_static.py
    python tests/marker_installer/run_postgres17.py --allow-fresh-synthetic-postgres17

The proposed workflow assumes this package was copied to tests/marker_installer. It is not installed automatically. Static checks report no SQL execution. A runtime receipt is marked passed only when all checks complete; failures retain completed-case details. Destroy the entire disposable CI service after the job.
