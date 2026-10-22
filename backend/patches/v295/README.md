# V295 — financial interface and explicit transfer confirmation

The main Flow must show financial information, not a narrative about backend processing. The rule is now permanent in the repository's `AGENTS.md`.

## Interface

- Scheduled movements use a compact, initially closed financial list. Dates, bank routes, amounts and forecast/payment states remain available.
- Source dates, the consultation date, availability limitations and refresh controls sit under the initially closed `Atualização` disclosure.
- Missing forecasts and overdue unconfirmed payments still cause a short human-language warning. Opening the list identifies the affected movement. These states are not erased or called paid.
- No healthy/empty overdue diagnostic banner is rendered. Unavailable, stale, malformed and partial data still receive a concise actionable warning.
- The two changed presentation modules do not change request ranges, import coverage, financial values, card calculations, transaction dates or overdue eligibility.
- All V293 and earlier release bytes remain immutable. V295 inherits the same base application and ordered script stack.

## Source-specific accounting operation

`backend/operations/confirm_exact_posted_own_transfer_v295.sql` accepts private transaction-local settings. It records an explicit owner confirmation in the existing private reference/evidence registries. It uses the already deployed V263 pair validator: both sources must be POSTED in owned checking accounts, with exact preserved hashes, opposing amounts, the same date, and reciprocal bank routing.

The confirmation supplements strict automatic matching for this exact source pair only. Raw provider discrepancies stay in private audit evidence. No broad merchant, name or amount rule is added. It does not execute a bank transfer or create financial events.

The operation validates idempotence, the absence of the pair from canonical expenses, exact preservation of every unrelated expense with multiplicity, unchanged source/event fingerprints, and source-key invalidation through the existing evidence registry. Run with ROLLBACK first, then apply and independently check the authenticated application APIs. Do not publish operator settings, financial records or private snapshots.

## Verification and limits

Unit contracts cover empty/healthy versus unavailable/partial states and retain real overdue financial rows. Browser QA uses the actual immutable candidate assets with synthetic API data at desktop, 390px and 360px widths. It checks six screens, a compact collapsed state, absence of processing narratives, accessible provenance, correct incoming/outgoing signs, retained aged overdue items, and existing shared category editors.

Browser fixtures do not certify a physical phone or a newly authenticated private browser session. A zero current classification queue does not certify cold-cache performance or completion of unrelated documentary and restoration work.
