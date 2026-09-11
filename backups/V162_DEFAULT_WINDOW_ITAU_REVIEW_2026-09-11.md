# V162 — Default Flow window and Itaú reconciliation review

Date: 2026-09-11. Scope: the user's latest request to show the previous five days, today and the next thirty days whenever entering Flow, and investigate the mismatching Itaú balance.

## Window contract
- Keep the protected V150/V151 Flow component and unchanged public index.html; no Dashboard or cumulative historical-wrapper runtime.
- On initial signed-in load, reload, navigation into Flow, clicking Flow again, the default-range chip or Hoje, request D-5 through D+30 inclusive: 36 calendar rows, including days without movements. The date reference remains America/Sao_Paulo.
- Existing manual presets and date inputs remain available. Switching bank filters or expanding details must not reset the manual period.
- A latest-request-wins loader prevents an older response from overwriting a newer period. The initial inherited read is allowed to finish before a recovery default read.
- Only one Hoje control remains. The default range is explicitly labelled.
- Backend V11 was tested with the user's real data under PostgreSQL role authenticated and controlled database claims, under an eight-second statement limit: five historical days plus thirty-one current/future days returned in approximately 890 ms. This is not signed-in browser E2E.
- New deterministic browser coverage lives in .github/scripts/lts_flow_default_window_gate.py and .github/workflows/flow-default-window.yml. It covers desktop, mobile, cross-year dates, reload, navigation, bank filters, Hoje, manual selection and late boot callbacks. CI must pass before exposure; local browser navigation was blocked by the runtime administrator and is not claimed.

## Itaú — open, not reconciled
The currently calculated balance still uses an early-September documentary anchor and subtracts two legacy scheduled projections. It must not be represented as a bank-confirmed current-day balance.

A later account statement previously uploaded to File Library was recovered. It contains a more recent headline balance and an additional same-day transfer. Another transfer has distinct posting/description/balance dates; no effective date has been invented. The later document was absent from the operational document index before this audit.

The recovered statement does not cover the current day. The new screenshots of Itaú investments, future transactions and Mastercard billing do not establish the current checking-account balance. Do not substitute the investment position or invoice total for bank cash. Do not silently cancel condominium/utility obligations or manufacture an adjustment to make cash match.

Private source_documents audit_key itau-current-balance-20260911 preserves the recovered file pointer, original name, documentary amounts and dates, exact current formula, before-image, temporal ambiguity and the missing current statement. This package does not change financial amounts, dates, classifications, account anchors or financial facts. The correct current Itaú balance remains blocked pending its documentary basis.

## Retained scope
The five user confirmations, imported closed Itaú/C6 detail, financing edit, separate invoice due/cash date and Cofrinho history remain preserved. Bulk classification and all-card parity gates remain open. Public-root promotion remains unauthorized. Preserve every other master-backlog item.

## Next gate
Record browser CI evidence and publication separately. Ask only for the current Itaú checking-account statement covering the gap from the recovered statement through the current day; do not re-ask the five resolved questions or claim the balance has been fixed.
