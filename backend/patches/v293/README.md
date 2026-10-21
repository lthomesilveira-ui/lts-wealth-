# V293: confirmed bank schedules and exact contract realization

V293 preserves every published release. The interface is copied from V291; only its release identity and the bank-schedule disclosure change. No new expense category is introduced.

## Confirmed scheduled transfers

- Use an existing source-specific owner confirmation, the current raw hash/date/amount, equal owner/payer/receiver CPF evidence and exactly one active checking account in each registered bank.
- Verify the receiver routing number against the confirmed destination. Do not invent a bank account number.
- Add two virtual projection legs only while the source is pending and the date is today or later.
- Exclude duplicates or partial overlaps with existing transfer legs. Ambiguous same-date/account/amount schedules are not projected.
- Keep the historical/realized transfer reader unchanged. A pending source does not become realized merely because its date passes.
- Preserve previously confirmed pending sources in the disclosure after their date passes. The UI reports no proof of realization and does not create a payment.
- Source-key and outer Flow-cache fingerprints include the current confirmation evidence, so source changes or a new confirmation cannot reuse an older forecast cache.
- Transfer legs are internal, projected and explicitly not realized. They alter the two account forecasts equally and oppositely, not consolidated cash or economic expenses.

The new V293 source endpoint is owner-asserted and exposes only dates, descriptions, amounts and safe provenance, not raw CPF/account evidence. Internal helpers are not executable by anonymous or authenticated API callers. Use V293 for the updated schedule disclosure; older release assets remain immutable.

## Exact contract debit operation

The separate administrator-operated SQL requires explicit owner, event reference, bank source, expected schedule/actual amounts and current source hash. It requires one unique bank debit and obligation for the same month, the exact mortgage contract reference, registered account/bank and bank-position coverage. Prior verified mapping establishes property/purpose; a person's identity is never copied from that mapping.

The transaction records the original full event and expected schedule, applies the actual posted debit, links source and event, and requires one realized expense, unchanged unrelated canonical expenses and removal from pending projections. Repeating the exact request creates no second link or audit. An unexplained variance is retained without attributing it to interest, fees or indexation.

## Verification

The projection migration compares the full canonical expense corpus and sixty days of historical Flow before/after; all existing future events and every consolidated/liquidity field must stay equal. Every bank net/balance change must exactly equal the scheduled legs through that date. Real application RPCs are checked separately from synthetic browser regression.

Twenty actual PostgreSQL evidence-validator cases cover source/owner/hash/amount/date/status/deletion, CPF, routing, inactive/wrong-currency/savings accounts, missing identities and confirmation scope. Browser regression covers six screens across three viewports, incoming and outgoing schedule signs, disjoint counters and overdue disclosure. Mobile emulation is not a physical-phone or fresh private-login certification.

The broader backlog, including fully cold review-queue performance, unrelated transfer identity disagreements, source availability and documentary gaps, is not declared complete by this release.
