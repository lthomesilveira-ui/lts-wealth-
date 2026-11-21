# Synthetic full-consumer gate, prepared for review

This package has not been run. It contains no deployment envelope. Run only after independent review in a fresh disposable PostgreSQL 17 database. The shell runner additionally requires a local host, a dedicated `fixture_option_a_*` database and `OPTION_A_SYNTHETIC_DISPOSABLE=YES`.

## What this gate executes

Both original and candidate complete bodies of the expense reader and card-detail reader are compiled and invoked. Sixteen direct dependencies are listed in `DEPENDENCY_STUBS.json`: the original browser authorization guard is retained; fifteen ancestors use declared synthetic stubs with their original signatures, return types, volatility, security mode and configuration. Stub implementation language can differ, as explicitly recorded. Stub ancestor ACLs use disposable defaults; no assertion claims to reproduce access through the complete production dependency chain. The complete consumers keep their original language, signatures, attributes, wrappers and configuration.

Every scenario installs original then candidate on the same mutated inputs. An inactive resolution must return the entire original JSON and expense multiset, including diagnostics, the read-finish marker and November. An active resolution must equal an independently constructed exact expected delta, preserving all other fields and rows.

Synthetic baseline:
- Card detail: 114 items / 136.68 becomes 113 / 124.34; all 112 non-target items remain identical. The nominal contribution is 12.34.
- Core October stays 106 items / 117.34. This is an independent stubbed ancestor output, not a reproduction of the core implementation.
- Core November keeps seven detailed items summing 33.34, with its separate header of 99.99. The projected installment retains its source and installment 3/3.
- Legacy November detail remains empty. The complete expense consumer is also explicitly invoked on a November row to prove it is not suppressed.

Cases cover strict JSON types, malformed competitors, required keys, source identity changes, all-occurrence cardinality before matching, immutable external pin fields, canonical numeric spellings, settlement and administrative changes, mutable classification/presentation, source absence, payment/projected controls, another owner, document and alternative branches, original authorization errors and existing role entrypoints.

## Sanitization and canonical hash

The four standalone SQL body files are reversible sanitizations of their reviewed sources. Personal labels, property labels, employer labels (including regex/derived categories) and the operational UUID are replaced consistently. There are no case-specific date or amount literals in those four source bodies. The private reverse map and original sources are not in the allowlist. `ALLOWED_TRANSFORMATIONS.json` describes only public targets and transformation classes.

The candidate bodies retain an unbound pin in their standalone files. The fixture computes its SHA-256 from the synthetic immutable projection using PostgreSQL JSONB text and built-ins, stores it in fixture data, then binds exactly two declared tokens in each candidate. No Python JSON hash is treated as a PostgreSQL pin.

The verifier requires every expected unique result, rollback cleanup, all six compiled forms (four bound/original and two genuinely UNBOUND candidate forms) byte-equal to their sanitized sources with only the pin binding, and unchanged consumer contracts. It saves the PostgreSQL-deparsed definitions, MD5s and canonical scalar observations. A successful run is not claimed until that verifier succeeds.

## Limits and later gates

This is integration of two complete consumer bodies under synthetic ancestor contracts. It does not execute the full live dependency graph or prove live UI authentication, hot/cold cache behavior, financial before/after images, or deployment safety. The session identity provider is synthetic and exists only in the disposable database; the original authorization guard remains unchanged.

All fixture objects, roles and grants are transaction-local and rolled back. The exact ACL assertions reproduce only the two consumer entrypoints and evidence relation, including evidence RLS/default-deny and its existing privileged access; additional SELECT on synthetic ancestor tables and INSERT on the assertion log are isolated test plumbing. Exact evidence ACL-edge checks and actual anon/authenticated evidence-denial probes do not gain access from that plumbing. Service-role execution proves the full body under these declared synthetic dependencies, not every production ancestor grant. Other relation defaults, constraints, policies and triggers are not replicated. Source/evidence tables deliberately omit PKs so malformed duplicates can exercise conservative runtime guards.

A later, separately reviewed transactional gate must prove two existing invalidation events, cache behavior, CAS/rollback and competing evidence insertion with another ID during the critical section. The existing logical-pair uniqueness gap is not solved by this test and no new index or grant is proposed here.

Only files listed in `PUBLIC_MANIFEST.json`, plus that manifest itself, may be exported. Do not export the private generator, maps, original snapshots or local review records.
