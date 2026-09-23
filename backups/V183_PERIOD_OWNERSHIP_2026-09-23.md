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

## Published authenticated recheck

- PR #69 head `fc2904c32f0eca9932998aab02b2072f8a20454c`; merge `1187e9d3af5958be8db5d5cf89253059ff483959`.
- Pages `35924579834`: completed/success.
- All ten PR workflows passed first attempt: V171 `35924156027`, V172 `35924156020`, V173 `35924156157`, V174 `35924156001`, V175 `35924156051`, V176 `35924156087`, V177 `35924156109`, V182 `35924156112`, V183 historical `35924156015`, V183 cards `35924156080`.
- Authenticated full reload opened Dashboard with the same current-day position.
- Rapid Since 2013 → 12 months showed the new three-semester reader, not the obsolete 27-semester request.
- Real 12-month report: October 2025–September 2026. Real full history: October 2013–September 2026, 156 months, complete by the 62-second observation. Both had zero differences when comparing every monthly summary column, every group-matrix subtotal, final result and all five period KPIs.
- Cards survived rapid full-history/12-month switches. The selected window contained four current-register document/Flow matches, three legacy documentary cycles and the separately disclosed documentary-only evidence. Exact-day custom reload immediately suppressed the previous window's rows.
- Dashboard loan detail: complete selected-year list, 13 rows, sum and components matched. Property detail: complete selected-year list, 34 rows, sum matched. Private values are only in the private continuity record.

These scoped checks do not certify invoice bank settlement, a historical bank-balance start, all historical card instruments, Morgan/award valuation, debt balances, user acceptance or physical-phone validation. Current-candidate mobile and source-led financial verification remain open. The older V177 intermittent load failure is not claimed fixed simply because this PR's regression matrix passed.

Receipt classification remains a separate implementation task: the current Flow badge routes to the generic expense review; the existing description-wide semantic writer stamps expense semantics and is not a safe source-keyed income editor. Inspection was read-only; no receipt or other real financial fact was changed.

## Additional isolated display correction

Authenticated inspection of the RSU page found statement totals whose displayed components omitted the existing residuals. The V183-only wealth wrapper now explicitly compares available and future totals against their respective displayed components in integer cents. Missing components stay unavailable; a negative residual is labelled as a divergence, not an asset. Residuals are already included in existing totals and do not create cash, infer taxes or change values. One additional deterministic test covers exact, zero, negative and missing cases (14 tests total). Published recheck of this addition remains required.
