# LTS Wealth — Execution State

Latest update: 12/09/2026, user feedback after the integrated release. This override concerns bank-switch UX and the next classification phase, not new financial data. The complete prior state is preserved without modification at backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_BANK_SCOPE_2026-09-12.md and remains binding for all unaffected items.

## Current feedback, not full human approval
The user says the Itaú balance/invoices inspected appear correct. They report Bradesco did not open, expanded days survive bank switching, an Itaú invoice stays visible after selecting C6, and pending classifications have reappeared. The screenshots prove the cross-bank UI leak. The Bradesco screenshot shows an existing historical-reconciliation notice and an expanded no-movement day, not a captured invoice error. Do not equate those observations or dismiss the reported failure.

## UX candidate
- The existing recovery owner now clears expanded days and invoice summary/full/loading state when the selected bank changes, including Consolidado. Returning to a bank starts closed; clicking the same active bank leaves its current disclosure intact.
- The selected date range is preserved. Default D-5 through D+30 remains unchanged.
- Obsolete invoice requests are invalidated so late success/error cannot reopen a dismissed invoice or overwrite the new bank's invoice.
- Closing the invoice or collapsing its owning day also invalidates its pending request. Leaving the route closes the invoice.
- No new wrapper, permanent observer or polling. Protected index.html, financial writer, source amounts, dates, classifications, bank anchors and the existing reconciliation warning are unchanged.
- The extended integrated CI covers the reported sequence plus delayed success/error, close-during-load, return-to-bank and manual-range cases in desktop/mobile Chromium and mobile WebKit. CI and fixed-link publication remain to be verified for this candidate.

## Bradesco investigation boundary
Read-only controlled-authenticated database tests still return the current open Aeternum with all 96 source rows and exact total. The current generic small Bradesco card debit remains unmatched for lack of a safe current documentary identity. The historical reconciliation notice is returned separately. This does not prove which action failed in the user's session. Need only identify the date/card they attempted; do not ask for the already-received source again.

## Confirmed sequence and next priority
First close Flow functionality and UX gaps; then recover the accumulated classifications comprehensively. Scope includes both bank/Flow transactions and card-purchase classifications, plus the ability to review/reclassify from the Flow. It is not a card-only cleanup.

For the classification package: compare current labels against the original spreadsheet and validated LTS rules/history; user-confirmed decisions take precedence. Recover already-known mappings, distinguish genuinely unresolved transactions from missing links/presentation regressions, and preserve raw descriptions and financial facts. Do not invent marketplace/intermediary purposes, create new taxonomy to hide the gap, classify an invoice payment as new consumption, or simply remove pending labels. Ask only about irreducible semantic ambiguity after the evidence search. Taxonomy remains Categoria/Grupo/Macrogrupo and the existing validated cost-center scheme. No automatic classifications were written in this UX package.

Bulk manual classification stays unreleased pending the actual-session persistence gate and restored semantic experience. Prior fixture save/reload PASS is not actual user-session proof.

## Retained operational references
Repo lthomesilveira-ui/lts-wealth-; main and active recovery-v152-flow-20260910 must be refreshed before every write, together with master backlog/delta, NEXT_HOMOLOGATION_GATE.md, LTS_WEALTH_CONTINUITY_HANDOFF.md, CANONICAL_DELIVERY_MASTER_PLAN.md, decision ledger and latest checkpoint. No force updates or parallel-work overwrite.

Fixed homologacao.html -> wip35-v162-candidate.html; Flow V150/V151 contract; V162 reader lts_browser_flow_v11; guarded writer lts_browser_flow_mutate_v2; exact invoice reader via V2/V3. Integrated publication receipt backups/V162_INTEGRATED_PUBLICATION_2026-09-12.md remains valid for the preceding release.

Current checkpoint: backups/V162_BANK_SWITCH_FEEDBACK_2026-09-12.md. Complete open list remains PROJECT_MASTER_BACKLOG.md + PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md + this latest feedback. Historical Bradesco residual, other-Visa documentary gaps, classification lifecycle, all unrelated backlog and human approval remain open. Preserve all prior confirmed financial data and source evidence. Dashboard is out of scope and public-root promotion unauthorized.
