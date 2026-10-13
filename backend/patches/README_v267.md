# V267 — execution-only reader performance

The published interface remains V264. This package changes no interface, financial
source, classification, source identity, payment, cache contract or client grant.

Apply the two guarded patches only against their exact prior definition leases:

1. `text_key_inlining_v267.sql` lets PostgreSQL inline two immutable invoker text
   expressions. Their existing expressions and null behavior are unchanged.
   All calls are explicitly bound to `pg_catalog` or the existing `public` helper.
2. `paid_identity_prepared_plan_v267.sql` reuses a prepared statement for the exact
   existing paid-cycle reconciliation. Its entire source query is preserved;
   only the wrapper language and function-local planning mode change. This reuses
   a query plan, never a financial result. The caller's planning mode is restored.

## Actual private verification

The complete Flow and Expenses JSON responses matched their pre-patch digests.
Wealth also matched, excluding only `current_liquidity.computed_at`. Source events
and all expense-row identities matched, with no pending reader identities.
The 730 daily rows and 365 future-year rows passed arithmetic/current-cash checks.
The corpus of 2,414 distinct source/edge texts had zero normalization or merchant
key differences. The exact existing source expressions were verified unchanged.

Fifteen independent identity expression sites took 726.6 ms before and 91.4 ms
after. Result digests matched. Foreign/null owner, deleted invoice and unposted
debit tests passed; temporary source mutations were rolled back. The original
ACLs and owners are unchanged, with no anonymous/authenticated helper access.
All 147 tested authenticated browser routines denied calls with no identity claims.

One matched, source-invalidated server read measured Flow 11,498.0 -> 9,100.1 ms,
Expenses 8,801.8 -> 7,142.1 ms, and Wealth 2,485.8 -> 2,429.0 ms. These are scoped
database observations, not a latency guarantee or a physical-phone acceptance.
P13 remains open. No full-source or whole-product closure is implied.

## Static security observations

The advisor now emits two `function_search_path_mutable` observations because
the pure text helpers intentionally have no SET clause (required for inlining).
They are immutable invoker expressions, access no tables, qualify every function
reference, retain their server-only ACLs, and contain no unqualified operators.
This narrow exception must be re-reviewed if their bodies or grants ever change.
No SECURITY DEFINER data reader lost its fixed search_path.

[Advisor reference](https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable).
The pre-existing authenticated definer/API and server-only no-policy observations
are not blanket-cleared. Administrative Auth, signed-session/cross-owner HTTP,
physical-device, full recovery and all other unresolved backlog work remain open.

## QA

- `../qa/lts_v267_reader_probe_rollback.sql`: compare complete before/after receipts
  at the same source epoch/business day, including source and identity digests.
- `../qa/lts_v267_text_corpus.sql`: compare exact expression results and digests.
- `../qa/lts_v267_paid_identity_rollback.sql`: planning-mode, identity and live
  source invalidation proofs, all temporary changes rolled back.
- `../qa/lts_v267_source_gate.js`: public static contracts only. It is not a
  substitute for private database, signed-session or physical-device evidence.

Prior protected assets, resolved financial answers, V266 fixes, V248 isolation,
historical source limits and Continuity Watch OFF remain unchanged.
