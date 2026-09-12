# V162 — Bradesco account yield confirmed and applied

Date: 12/09/2026. This receipt supersedes the prior unexplained-residual status for the exact 11/09 Bradesco position occurrence, not all small account differences.

## Recovered rule and user confirmation
The user identified the displayed positive residual as account yield and reminded us the economic treatment was already agreed. Database retrieval found prior July/August RENTAB.INVEST FACILCRED* entries classified as Rendimentos financeiros and the existing sys_rentab_facilcred prefix rule. Historical spreadsheet records use Rentabilidade Conta Corrente Bradesco. Those existing names were preserved. A user-confirmed exact alias for the spreadsheet label was restored; no new taxonomy or amount-only rule was invented.

## Applied correction and provenance
A guarded, idempotent transaction checked the observed account position and exact residual, rejected any already-present small credit in the scoped period, recorded the confirmation with before-images, and added the confirmed cumulative yield once. The event is recognized as of the documented position date. Its bank_posting_date remains null: neither an exact bank credit date nor separate daily accruals were invented. Existing bank anchor and future daily balances remain unchanged because the observed position already includes this yield.

Private source_documents audit key bradesco_yield_user_confirmed_position_20260911_v1 preserves confirmation, source screenshot, earlier rule, before/after, date semantics and verification. All detailed monetary data remains private. The screenshot is archived in private Drive and linked in that source record.

## Verification actually executed
Post-application V11 consumer read confirmed: one yield event, existing Rendimentos financeiros category, zero remaining gap for the specified occurrence, unchanged observed bank balance and byte-equivalent current/future day payloads. The transaction committed only after all assertions passed. No financial writer/schema change, synthetic rounding entry, blanket tolerance, retrospective guessing or bank payment was used. This is database consumer testing, not signed-in physical-iPhone E2E.

## Continuity and release boundary
The new data is read by the already-published V162; the frontend manifest is unchanged. This update does not publish the separately pending bank-switch UX candidate or close the Bradesco invoice-opening report. The old same-residual warning must not be reintroduced as an unanswered user question. All unrelated gaps and classification/UX priorities remain preserved in the latest execution state.
