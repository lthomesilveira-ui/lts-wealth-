# V183 — exact receipt classification

Scope: V182-F07, isolated candidate only. The protected root and fixed V181 entry remain unchanged.

The Flow receipt badge no longer routes to expense review. It opens a native, keyboard-accessible dialog for one exact receipt (source, reference, civil date, bank and signed amount). The user chooses a receipt category explicitly; no default family assignment and no description-wide semantic rule are created.

The new authenticated RPC exposes a SECURITY INVOKER wrapper and a non-exposed, narrowly granted private implementation. It derives the user from the existing allowlisted session, rejects absent/ambiguous origins, transfers, projections, suppressed/cancelled records, existing effective classifications and stale snapshots. It updates only `financial_events.category`, records the decision in the existing audit and verifies the effective reader sees the result in the same transaction. An inconsistent result raises an exception and rolls back.

Supported scope is unresolved, confirmed financial-event income, through today, with one matching effective cash row. Other origins produce an explicit explanation; they do not fall through to the expense editor. Already classified income is preserved. This does not certify old balances or classify any real receipt automatically.

Verification before publication:

- 18 database integration assertions under the authenticated role, using synthetic receipts and transaction rollback: successful save, Flow category, monthly family grouping, unchanged monthly totals and all non-category fields, same-description sibling isolation, invalid category, stale token, mismatched amount/date/bank, transfer/projection rejection and unauthenticated/anonymous rejection.
- Security advisor comparison: no new findings versus the pre-change baseline. Existing database advisories are not claimed resolved.
- Candidate unit/contract tests cover eligibility, collision-free identity, read-only preview payload, monthly cache invalidation and entry isolation.

No real receipt was reclassified by this implementation/test session. Final publication and live UI verification are recorded in the private continuity checkpoint.
