# V289 — grouped expense evidence

Applied as the official migration `lts_expense_grouped_evidence_v289`
(version `20261019212135`). The public application remains V285.

The review queue exceeded its authenticated query budget because two correlated
existence/uniqueness checks repeatedly scanned materialized historical expense
rows. The first now derives unique source-table/source-reference/month keys
once. The second derives the exact workbook-covered month set once.

Both checks retain ordinary SQL equality, including its treatment of NULL,
duplicates, case, month boundaries and unrelated sources. They do not change
matching evidence, amounts, categories or eligibility rules. Existing function
identity, owner, configuration, invoker status and ACLs are asserted unchanged.

Private repeatable-read trials compared complete effective and canonical rows,
and the complete review-queue JSON response. All were equal, including duplicate
multiplicity. The combined queue trial measured 11.405 → 6.695 seconds; a
separate authenticated-role trial with the existing 8-second statement limit
measured 6.118 seconds. These are observed test timings, not a cold-load SLA.

Validation also passed 31 synthetic equality/NULL/multiplicity/month cases,
10 authentication/range negative cases, and a round-trip restoration comparing
canonical output and financial-event/review-decision fingerprints. Security
advisor counts were unchanged. The actual signed-in V285 queue loaded after
installation; its search reduced the displayed list as requested.

`apply_grouped_evidence.sql` is the bounded official change. The candidate and
restoration rehearsal files end in ROLLBACK. The restoration requires the exact
installed hashes and checks the original definitions and privileges. Do not
silently remove leases after a mismatch.

Original → installed definition hashes:

| Function | Original | Installed |
| --- | --- | --- |
| lts_expense_effective_rows_v176 | 13b18a77b393aa74e679b6b71094f698 | 21af2733b8d46a42325233fa8e37257b |
| lts_expense_effective_rows_pre_v268 | de945f60b8211ab7f0c723938098e897 | c8c716093de7f247be51f6ed6f34bd8f |

Private identities, transaction values, source files and raw trial receipts are
excluded from this repository package. V288 remains a separate uninstalled
prototype. This correction does not close the project's unrelated documentary,
physical-device, cross-owner HTTP or native-restoration acceptance items.
