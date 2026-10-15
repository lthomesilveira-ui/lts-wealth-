# Combined atomicity review gate

This supplement uses the reviewed joint guard while keeping the existing financial SQL, documentary SQL and fixtures byte-identical. It is covered by its own disposable PostgreSQL CI job; no live application is authorized by this package.

## Guard contract

`combined_state_guard.guard_sql(mode, planned_ids, rule_id)` emits the exact pre-DDL DO block. The two `combined-*-guard.sql` files are generated using the existing synthetic fixture identities. The private assembly can use the same generator with its private identities, while retaining that result and its linkage privately.

Only these pairs are eligible:

- Apply: original reader + zero owned planned IDs; or candidate reader + all 24 owned planned IDs with suppression false
- Recovery: candidate reader + all 24 owned planned IDs with suppression false; or original reader + all 24 owned planned IDs with suppression true

Every other pair aborts before DDL. Counts refer only to the resolved owner's exact planned UUIDs. The guard leases the owner helper and locks the rule before the planned existing rows. Null suppression flags do not count as either true or false. These coarse state checks never replace the complete economic guards; exact rows, backups, identities, rule/evidence, schema and triggers are still checked by the unchanged economic DO.

Execution order in one SERIALIZABLE transaction is joint guard, reviewed destination reader DDL, exact destination reader hash check, unchanged economic DO, then caller-selected COMMIT or ROLLBACK. The draft harness itself commits only in its newly generated disposable local test database. Review SQL must continue to default to ROLLBACK.

Repeated final states may execute the same CREATE OR REPLACE definition, but the economic DO must be a no-op: no cache epoch change or cache-row removal. Mixed states such as an original reader with already-applied economic rows must not silently repair themselves.

## Eight focused PostgreSQL cases

1. Apply installs the candidate reader and exact 24 events/rule; both real cache invalidations observe the candidate definition.
2. Recovery restores the exact original function definition and identity, original rule, and suppresses only the 24 planned rows; both invalidations observe the original definition.
3. Errors immediately after apply DDL and after all apply writes restore the entire initial snapshot.
4. Errors immediately after recovery DDL and after all recovery writes restore the entire applied snapshot.
5. Repeated apply and recovery preserve warm cache entries and epoch.
6. Eight crossed/partial/unknown-source state combinations abort before DDL.
7. Rule, new-row and old-backup mutations still fail the complete economic guards after coarse eligibility.
8. Foreign-owner planned UUIDs do not enter the owner-bound count; the complete economic block rejects their global identity collision atomically.

The snapshot includes financial events, rule, legacy rows, accounts, caches, epoch, both documentary tables, function definition/OID/owner/ACL/configuration, and the observations. The fixture revokes default public execution so the preservation assertions exercise an explicit, non-default ACL. An extra AFTER UPDATE trigger is attached only to the synthetic cache-epoch fixture. It records the installed reader definition and transaction ID during each real invalidation. No observer is added to the guarded financial tables, and no existing helper is rewritten.

Offline: `python combined_atomicity_gate.py`

Disposable PostgreSQL 16 only: `P07_QA_ALLOW_DISPOSABLE=1 python combined_atomicity_gate.py --postgres`

Five offline checks validate frozen inputs, generic function hashes, exact generated guards, invalid inputs and reuse of the documentary schema. Offline success does not demonstrate transactional atomicity; the eight database cases still require reviewed CI execution.
