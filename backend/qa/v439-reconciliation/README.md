# Incremental reconciliation package

## Frozen code

- `guarded_delta.sql`, SHA256 `8a45c452053177a2f5de675d9e20290f8186ac9a95fd90e27d5579dba1a8ef19`.
- CLI-created migration: `20261112012739_v439_reconcile_verified_card_obligations.sql`.
- Original applied V439 migration SHA256 remains `acb0da74db564e17c724123fbc8643d92aeef0aea7b72faacf4a16b205832a64`.
- Existing owner-policy/calculator hashes were read live and match the incremental predecessor guard.
- No change to build V438, source financial records, default loader, or an existing UI release.

## Generic behavior

The optional private `preserved_legacy_obligations` list supplies reference, original date, cash date, amount, source JSON digest and documentary evidence reference. The policy reader verifies each record against its owner, source hash, account, series, amount, direction and current normalized due date. It discards any supplied verification markers and reconstructs them itself.

The calculator permits additive new spending only when the slot has exactly the verified legacy total and corresponding source references. Unknown or changed sources remain blocked. The known obligations stay in base flow; the new event contains only the new-spend provision. There are no replacement references and no financial source writes. Private reconciliation details are omitted from presentation metadata.

## Tests

- Generic PGlite suite: 65 checks including exact V438 build, 50-to-59 regression reproduction and correction, nine verified obligations, no old allowance duplication, no-policy and pre-cutover equivalence, migration replay/rollback, source/hash/account/date/owner failures, unknown extra references, and final UI parser.
- Separate private source-backed fixture: six checks using actual isolated base-flow rows and source hashes. The existing failure reproduces, all required provision months appear, known amounts are retained, source fixtures are unchanged, and pre-cutover events match.
- All database tests run locally with controlled source adapters. These are not a complete live rebuild or authenticated UI acceptance.
- Static independent review found no blocking defect. Low-priority limitation: replay guards the two existing functions, not later edits to the two newly added helpers.

## Coordinated application and verification

1. Keep the original and incremental migrations in repository history. Do not rewrite the original applied migration.
2. Apply the frozen incremental migration using the normal migration tool.
3. Separately apply the reviewed private seed. Keep snapshots, owner references, source identities, values, hashes and rollback outside the repository.
4. Recalculate once through the normal refresh worker. Do not run competing heavy builds.
5. Confirm expected full monthly coverage, no unresolved card periods, exactly one additive provision per month, preserved known obligations, no other cards' new-spend provisions after cutover, and unchanged pre-cutover output.
6. Publish only an independent immutable UI URL for authenticated browser QA. Do not promote the default loader until that QA passes.
7. If necessary, roll back private policy first. `rollback-delta.sql` restores the previously applied V439 calculator/reader, not the older pre-V439 code. The private policy rollback is separate.

The UI parser tests do not replace the outstanding authenticated Premissas and refresh-flow checks.
