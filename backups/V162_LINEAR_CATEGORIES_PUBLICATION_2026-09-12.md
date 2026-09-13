# V162 — Linear categories and bank-context publication

Business date 12/09/2026, America/Sao_Paulo. This receipt closes the publication condition in V162_LINEAR_CATEGORIES_ACCEPTANCE_2026-09-12.md and the current execution state, not the classification-readiness or human-approval gates.

## Published package
- Product d3300083bc1288cb0c5aff1772f98877ef17728e, with unchanged product code from 37bddb251c86e3eed4e813f56cca7093645dc395 and a corrected asynchronous wait in the old smoke test.
- Main exposure e098b5472d6432a035fb436828fcf16fac353f9c.
- Main GitHub Pages run 34726875190: build, deploy and report SUCCESS.
- Main recovery smoke 34726875750: SUCCESS.
- Main default-window test 34726875762: SUCCESS.
- Main integrated invoices, bank-scope and category-reading-order run 34726875787: SUCCESS.
- Fixed homologacao.html points to the V162 candidate with integrated=20260912-v4-linear-categories.
- Protected public index.html is unchanged; promotion_status remains not_promoted. This is a fixed-homologation update, not public-root promotion or whole-app acceptance.

Every supported invoice family now has a single vertical category/value list ordered by descending net value in summary and full view. The same release closes expanded days and invoice context when the bank changes, preserves selected dates and rejects obsolete invoice responses. Prior balances, source transactions, classifications and financial rules are unchanged. The earlier confirmed Bradesco yield remains applied.

Notebook/desktop/mobile Chromium and mobile WebKit fixture tests cover geometry, values, full/back/close, bank switching and delayed responses. Representative notebook/mobile screenshots were inspected. These tests do not operate the user's actual session or physical iPhone.

## Classification is the next priority, not yet released in bulk
The real readiness audit found different source snapshots in current Aeternum detail versus the classification queue, and an empty bank-review queue despite pending Flow categories. The existing save handler also does not verify the deferred-refresh/readback result before showing full success. These defects are documented, not claimed fixed by the layout change.

Next package: align current sources/queues, recover the original spreadsheet and confirmed LTS mappings for both bank movements and card purchases, preserve exact-description versus transaction context, and prove save-persist-refresh-readback before explicitly releasing accumulated user-dependent classification. Do not ask the user to repeat previously known classifications. No new taxonomy or merchant purpose was invented in this UI package.

Operational restart: LTS_WEALTH_EXECUTION_STATE.md, NEXT_HOMOLOGATION_GATE.md, V162_INVOICE_READING_ORDER_CLASSIFICATION_READINESS_2026-09-12.md and the complete master backlog/delta. Private source_documents audit_key invoice_linear_classification_readiness_20260912_v1 contains exact counts/values, before-images and the archived original screenshot pointer. All other documentary gaps and human gates remain preserved.
