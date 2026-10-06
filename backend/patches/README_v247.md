# V247 backend — applied after transactional validation

Date: 2026-10-05. Preserve the V245 frontend and every frozen release.

Prepared changes:
- Exact-owner/range/day/timezone memo of corrected cash rows; original private
  engine retained in the database. Dates, signs, source identity, cancellation,
  splitting, displacement, invoice and payroll precedence remain unchanged.
- Optional memo persistence handles only read-only SQLSTATE 25006. Financial
  calculation errors, source changes and permission errors still propagate.
- Source hash functions use VOLATILE because their child readers can memoize.
- Documentary supplement and historical source-sign relations gain the same
  transition invalidation as other source tables, including real changes.
- Missing forecast cache in a read-only transaction computes from the existing
  engine with the same horizon and source fingerprint. No dummy values.

Verification:
- Local V247 source gate, V245 static/immutability and flow contracts PASS.
- Exact live corrected-cash row parity passed for historical, current/future
  and calendar-2027 ranges. Documentary invalidation and helper ACL checks PASS.
- The transactional probe restores all original function definitions/ACLs and
  candidate DDL; all financial fixtures and temporary cache changes roll back.
  Only an operator-private, RLS-protected validation receipt persists.
- Complete 2026–2027 coverage, exact cached replay, and an exact 2027 slice PASS.
- After guarded production migration, warming covers both calendar years.
  Warm server reads are sub-second; a full cold rebuild still takes tens of
  seconds. These measurements are not browser/mobile end-to-end acceptance.
- A genuinely uncached future range also passed in a local READ ONLY test
  without overriding the platform's protection or modifying source data.
- Browser CI is a preserved V245 fixture suite, not real-owner acceptance.
- SQL patches are now applied; no financial fact, actual bank operation,
  frozen frontend or release file has been changed by them.

Infrastructure recovery:
Supported included capacity has been provisioned, writable service recovered,
and the existing bank-sync scheduler resumed. Never override read-only safety,
delete documentary observations, restart via pause/restore, or add spending as
a workaround. If service regresses, recheck the actual mode before writes.
Private measurements and bank/source details belong in the continuity record,
not the public repo.

Operator probe:
Run `node backend/qa/lts_v247_transactional_probe.mjs` from the repository root
to build its migration JSON. Apply only through the authorized DDL workflow.
The private validation table denies all API-role access. Inspect its report and
the restored function fingerprint before deciding on a production migration.
The full-flow probe reports unknown historical resource fields without
inventing zeros, backdating current positions, or changing economic balances.
