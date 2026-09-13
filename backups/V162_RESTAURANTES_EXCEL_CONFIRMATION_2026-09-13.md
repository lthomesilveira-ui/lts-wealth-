# V162 — Restaurantes: historical Excel category confirmed and applied

Date: 13/09/2026. User chooses Restaurantes, the label they confirm was used in the Excel history since 2013, to preserve consolidation while recovering the two pending migration months. A nomenclature revision is deferred to a separate later proposal. This closes the question previously asked about the identified restaurant purchases, not all unresolved transaction meanings.

## Applied scope
Four identified charges at the three previously discussed restaurant descriptors in the current September Aeternum source snapshot now carry Restaurantes. The existing per-source category_lts field and user-confirmed decision provenance were added only to those four lines. No global semantic rule, cross-category alias, processor-based inference or category merge was created. The older August invoice and all unrelated categories remain unchanged.

Private audit key restaurantes_excel_user_confirmed_20260913_v1 in owner-scoped source_documents preserves the exact confirmation, source PDF reference/page, before-invoice/detail, source-line attribution, prior-cycle before-image, after-detail and refreshed queue. The source invoice corresponds to the already-received open Bradesco PDF, whose first page contains these four charges. The source supports the charges; the user confirmation supplies the chosen LTS category.

## Verification
One guarded transaction applied the changes and refreshed the current card review cache. It asserted four target lines only, identical invoice total/count, identical source description/date/amount and identity fields, unchanged unrelated classifications, unchanged prior-cycle detail, and exact agreement between the refreshed review queue and invoice detail. The four confirmed charges no longer appear as pending. The transaction committed after all assertions passed.

A second read through the authenticated consumer signatures after commit returned Restaurantes for each target and the matching reduced pending count/value in both invoice and queue. This is controlled authenticated-role database consumer testing, not the user's physical device/session E2E. Exact amounts and counts beyond the four-line scope remain in the private audit, not this public record.

## Product and remaining work
No frontend, manifest, schema, permission or financial-writer changes. The same published V162 reads the updated classification after reload. No new link/build or repeat file upload is required. The prior recovery batch remains intact and all other open dependencies are preserved.

For the remaining bank and card classifications, use the existing Excel/LTS labels and apply supported historical decisions before asking about genuine ambiguity. Do not substitute a naming redesign for completing the two-month backlog. Do not globally recode historical Restaurantes e Lazer records because the mixed label may include actual leisure. A future approved mapping may improve reporting while preserving original labels.

Resume with LTS_WEALTH_EXECUTION_STATE.md, LTS_WEALTH_DECISION_LEDGER.md, this checkpoint, NEXT_HOMOLOGATION_GATE.md and the complete unchanged master backlog plus delta. The restaurant-label choice is resolved; other documentary, contextual, manual-UI/session and human-approval gates remain separate.
