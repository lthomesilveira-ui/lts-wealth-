# V162 — Read-only diagnosis: historical duplication and vehicle consumption

Business date 13/09/2026 (America/Sao_Paulo); database reads occurred after midnight UTC on 14/09. The user asked whether work had stopped. The previous response only checked status. This turn completed new technical/source analysis but did not perform any denied or substitute write.

## Historical representation defect reproduced
The three evidence records already listed in the private full-period audit match three actual statement facts. Matching uses the same owner and bank, exact original description, exact signed amount and the evidence's explicit posting_date. All matches are unique on both sides. The supplied Itaú statement, page 2, shows the posting-date payments once, between the two printed daily closes.

The current lts_historical_effective_cash_v4 output contains both the initiated-date evidence and posting-date facts. A read-only SELECT compared its interval net against the net obtained by counting each uniquely matched fact once. The latter exactly equals the difference between the printed closing balances; the former differs by the sum of the older evidence representations. No source row, reader or balance was changed by this diagnostic.

Code inspection identified the mechanism: lts_historical_effective_cash_v2.documented_evidence checks for an existing corrected/user/transfer row only on e.evidence_date, even when metadata carries a distinct posting_date that matches a newer source fact. This is a source-identity/date reconciliation defect. It is not evidence of a second bank debit, not a new user expense and not permission for blanket amount/date deduplication.

## Vehicle consumption defect reproduced
The actual lts_expense_total_rows_v4 consumer for the investigated period returns the confirmed card installment correctly but also returns the old bank advance/reimbursement evidence as an ordinary family expense. The old representation comes from lts_expense_total_rows_v2.documentary_bridge, which reads lts_daily_flow_fix86_v12 and filters using its classifications/exclusion flags. The confirmed metadata relation and newer Flow category overlay do not automatically reach this path.

The remaining task is therefore concrete: preserve bank cash, consume the explicit user-confirmed relationship in expense aggregation, and prevent the advance/reimbursement from being counted as another purchase. Do not guess a missing initial cash debit or adjust current balances. No report correction was applied in this turn.

## Other evidence search
Two focused Gmail searches for unresolved household/platform descriptors found no matching financial receipt; only unrelated promotional/news messages appeared in the broader search. Those messages were not used as purchase evidence and no category was inferred from them.

## State that did NOT change
No new source categories, catalog entries, cache, schema, financial values, frontend or manifest were written. The two user-confirmed reimbursement categories remain unapplied; their decision is preserved in the existing private receipt and must not be asked again. The stored card queue remains 43 and the stored bank queue remains the prior version. No blocked operation was retried through another channel. GitHub changes are documentation only, not a runnable migration or a workaround to apply denied actions.

## Handoff
Resume from the current execution state, this receipt, the private full-period audit and its source references, the blocked-two-transfer checkpoint and the complete backlog. The history-duplication and vehicle-consumption issues are now reproduced with identified code paths; their implementations and regression gates remain open. No physical-device/session E2E, completed two-month recovery, new app release or unattended work is claimed.
