# V162 — Linear invoice categories and bank-context acceptance

12/09/2026. Implementation/readiness detail: V162_INVOICE_READING_ORDER_CLASSIFICATION_READINESS_2026-09-12.md. All values in public browser tests are synthetic; private financial source/audit data stays in owner-scoped source_documents.

## Exact product and automatic evidence
- Product implementation: 37bddb251c86e3eed4e813f56cca7093645dc395.
- Final tested revision: d3300083bc1288cb0c5aff1772f98877ef17728e. Its only extra change is waiting for the matching asynchronous invoice response in the legacy recovery smoke.
- Recovery smoke 34726662187: SUCCESS.
- Default-window 34726456351: SUCCESS.
- Integrated Flow/invoices, bank-scope and linear reading-order run 34726456372: SUCCESS.
- Artifact 10307648871; SHA-256 72a83f44e63cb06878a95c80cf5bc18c06c887861d294a74740431e2290d340f.
- Downloaded receipts: integrated-flow-result.json PASS for three profiles; bank-scope-result.json PASS for three profiles; invoice-reading-order-result.json PASS for four profiles.
- Notebook and WebKit-mobile category-summary screenshots were visually inspected. They show one vertical ranked category list, aligned category/value, not alternating columns.

The new geometry test uses six deliberately shuffled categories and proves descending values, common horizontal alignment, strictly non-overlapping vertical rows, unchanged raw purchases and zero financial writes across five card-family shapes. It checks summary/full/back states at 1366x768, 1440x900 and 390x844 Chromium, plus 390x844 WebKit. Bank-scope tests include loaded/full invoices, switch away/back, same-bank preservation, late success/error, close-during-load, day-collapse, date preservation and unchanged financial payloads. These are not the physical user's signed-in session.

The initial recovery run 34726456352 failed because it tested visible invoice loading-shell content before the response; its full behavior/content assertions were retained and a matching-response wait added. The corrected full recovery run passed. No failing test was ignored or removed.

## Publication boundary
The metadata package selects the final tested revision for fixed homologacao.html. Confirm actual main Pages deployment and post-manifest checks before reporting it live. Protected index.html is unchanged; promotion_status remains not_promoted. The package includes the previously unexposed bank-switch code and the new category-list styling together.

## Classification audit boundary
Read-only real consumer inspection found inconsistent current-versus-legacy Aeternum classification sources and an empty bank-review queue despite pending Flow categories. The save path also does not confirm downstream cache-readback success. This package documents those defects; it does not falsely claim to fix or release bulk classification. Exact receipt and original user feedback image are privately archived under invoice_linear_classification_readiness_20260912_v1.

Next priority is review-source alignment, recovery of confirmed historical taxonomy/mappings, clear semantic scope and verified save-refresh-readback before asking the user to process the accumulated classification queue. The existing yield correction and all prior financial decisions remain unchanged. Preserve unrelated master-backlog/evidence gaps and actual-session/human approval gates.
