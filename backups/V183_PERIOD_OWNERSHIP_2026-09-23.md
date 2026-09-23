# V183 — selected-period request ownership

## Scope and evidence

The authorized shared-browser login succeeded. Published bounded-history PR #68/main `4c651486bc13ac06cd870f7ca3add2cdc09c87d7` passed full reload, Dashboard/current Flow agreement and an early historical interval that preserved movements without exposing uncertified balances. Private values remain outside this public repository.

A rapid live Since 2013 → 12 months switch left the new filter waiting for the old 27-semester load. Inspection found loading-only locks, missing generation invalidation and card payloads that could retain old period ownership. Earlier errors also blocked a newly selected monthly period.

## Isolated correction

- Start the newly selected period without waiting for an older period.
- Require both period and generation to own every committed response; this also covers A → B → A races.
- Stop further superseded semester/quarter and invoice-chunk reads after the outstanding request returns.
- Show loading rather than old totals, zero placeholders or invoices beneath new dates.
- Recover on a different period; retry an unavailable same period only on the explicit retry action.
- Apply period ownership to the monthly overlay as well as its summary reader.
- Preserve every financial source row and authenticated API contract. No schema, classification, balance, cash or invoice writes.

## Verification before publication

`node --test test-v183-period-ownership.cjs`: 13 tests pass. The suite executes the shipped functions with deferred read-only fixtures, including complete 156-month coverage, missing-month fail-closed behavior, old/new completion permutations, error recovery and root/manifest isolation.

`node test-history-coverage.cjs`: 30 checks pass.

`python3 -B -m unittest test_reconcile_historical_scope.py`: 8 tests pass.

Published authenticated recheck is required after deployment. These scoped tests do not claim invoice settlement, a certified historical bank-balance start, all historical card instruments, Morgan/award valuation, debt reconciliation, user acceptance or physical-phone validation. All unrelated backlog items remain open.
