# LTS Wealth — V181 user-feedback register

Date: 22/09/2026. This public record is sanitized; private amounts, source rows, screenshots and person/provider associations remain in Supabase and the user's Library.

Status legend: **completed** means implemented and evidenced at the stated layer; **in progress** means not yet eligible for user acceptance; **open source dependency** means the product must disclose the gap rather than invent detail.

| ID | Requirement | Status before publication | V181 treatment / evidence required |
|---|---|---|---|
| V181-01 | Persist every feedback, dependency, implementation and validation outside chat | In progress | This register, the prepublication record, continuity state, publication receipt and private Library record form one traceable chain. |
| V181-02 | Make the effective homologation version unequivocal and preserve V176–V180 behavior | In progress | Dedicated V181 candidate and visible release stamp; fixed entry remains on V180 until the successor passes its own gate. |
| V181-03 | Turn unidentified expenses into an actionable, evidence-led workflow | Implemented; browser validation pending | Authenticated queue with date, description, origin, amount and one explicit question. No option is preselected; a decision writes one source-keyed row and must remove that item from the queue. |
| V181-04 | Audit group/subgroup/import/card-payment double counting | Backend audit completed; publication pending | Current-period source keys are unique, mutually exclusive coverage modes reconcile to the selected total, and card invoice payments are not added to purchase consumption. Named subgroups remain alternative partitions, not extra totals. |
| V181-05 | Clarify apartment period, current-period expenses and full investment history | Implemented; browser validation pending | Drawer labels the selected period, separates current-period components from the full documented investment archive and retains drill-down totals. |
| V181-06 | Remove the non-actionable card inventory block | Implemented; browser validation pending | The inventory card is removed from the operating view without deleting source history. |
| V181-07 | Reconcile documented invoice, card screen and Daily Flow by card and due date | Backend completed; UI/browser validation pending | Authenticated reconciliation returns documented value, Flow value, difference, event count and legacy-projection conflicts. A documentary cycle must have one matching cash obligation and zero legacy conflict. |
| V181-08 | Keep monthly KPIs, remove repetition and show monthly inputs, expenses and result | Implemented; browser validation pending | Removes the repeated annual table, adds a selected-year monthly summary and total, and states that monthly result is not accumulated bank balance. Existing category matrices remain. |
| V181-09 | Offer useful expense views by person/context and by nature without double counting | Implemented; browser validation pending | Two alternative views reuse the same source-keyed groups; each item opens the original detail. The property recurring-cost label is preserved where applicable. |
| V181-10 | Revalidate extraordinary receipts and keep RSU vesting separate from cash | Audited; source dependency remains | Effective receipts, transfers and asset availability remain distinct. The already-recorded missing original source for one historical share-sale month remains open and no amount is fabricated for it. |
| V181-11 | Make long detail drawers scroll to the final row on notebook and mobile | Implemented; browser validation pending | The drawer keeps a bounded flex layout with explicit vertical scrolling, touch panning, overscroll containment and mobile full-height behavior. |
| V181-12 | Let consolidated totals reach source rows and disclose missing purchase detail | Partly implemented; source dependency remains | Available rows remain expandable. Monthly aggregates without purchase-level evidence are visibly marked and request the statement for that competence; no invented purchases or categories are created. |

## Financial incident that blocks release

The user-reported duplicate card obligations were reproduced as a systematic precedence defect: a documentary invoice and an older projection could coexist for the same card family and reference month. V181 applies central card/cycle precedence in the derived cash-flow reader, preserves raw sources, excludes installment floors from cash obligations and retains projections only when no documentary cycle exists.

The successor must not be exposed from the fixed homologation entry until all documentary cycles in the bounded validation range reconcile to exactly one Flow event, zero amount difference and zero legacy conflict, followed by authenticated browser validation after full reload and Dashboard → Flow → Dashboard navigation.

## Still open after this implementation

- User acceptance; agent and automated checks are not the user's own review.
- Physical-device validation if no physical phone is available; responsive browser validation must not be mislabeled.
- Genuine source ambiguities in the identification queue.
- Historical invoice aggregates for which purchase-level statements have not been supplied.
- The previously recorded missing original source for one historical extraordinary receipt.
- Every earlier backlog item that lacks its own closure evidence.

Production/root promotion remains unauthorized.
