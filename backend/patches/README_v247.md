# V247 candidate — NOT applied to production

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
- Live database mutation, old/new row parity and complete cold tests are still
  pending. The rollback-only QA script must pass before applying a release.
- Browser CI is a preserved V245 fixture suite, not real-owner acceptance.
- No production migration, financial change, bank operation or release has
  been applied by this candidate.

Infrastructure blocker discovered:
The project reports ACTIVE_HEALTHY, but default_transaction_read_only is on
from configuration. Its pg_cron launcher repeatedly exits with read-only UPDATE
errors. Do not override this safeguard, delete documentary observations,
restart via pause/restore, or alter spending/billing settings as a workaround.
Restoring writable service is required for sync, warming and production DDL.
Private measurements and bank/source details belong in the continuity record,
not the public repo.
