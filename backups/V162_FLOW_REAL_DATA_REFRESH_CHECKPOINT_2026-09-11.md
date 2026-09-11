# V162 Daily Flow — real-data refresh checkpoint

Date: 2026-09-11

## Scope
Continue homologation of the user-validated V150/V151 Daily Flow through the isolated V162 candidate. V152 remains audited comparison evidence. Dashboard and the remaining product modules are not approved by this checkpoint. Public `index.html` remains protected and unpromoted.

## Evidence handling
A new user evidence package was received on 11/09/2026 containing bank screenshots/statements, a closed card statement, brokerage-position evidence and a protected card-export archive. Exact originals were preserved outside chat in a private evidence bundle. The private retrieval pointer is retained in Supabase metadata rather than this public repository. No password was guessed or recorded for the protected archive.

## Applied refresh
- Refreshed documentary bank-account anchors supported by the newly supplied bank evidence.
- Preserved the user's append-only manual edit of the September Bradesco real-estate financing event; the effective Flow still resolves to the user-edited amount.
- Replaced the stale September Itaú Mastercard open aggregate with the closed documentary statement, imported its full line detail and reconciled detail to statement total at delta zero.
- Preserved the contractual card due date while moving the projected bank-cash effect to the separately evidenced scheduled automatic-debit date. Migration `card_invoice_cash_effect_date_overlay_2026_09_11` adds this cash-date overlay without rewriting the contractual due date.
- Marked the already-observed C6 September card payment as documented from the supplied bank statement, without duplicating the existing card obligation.
- Added one newly evidenced scheduled Itaú subscription debit that was absent from the Flow.
- Added one Bradesco scheduled card debit as a generic card-cash event only; the supplied screen does not evidence which Bradesco card generated it, so no card identity was invented.
- Refreshed the current Morgan Stanley documentary position while keeping unavailable future awards outside operational cash and retaining brokerage cash transfer/conversion latency as unresolved.
- Invalidated future Flow caches after the data refresh.

## Card-detail parity
The closed Itaú statement is now represented through the same documentary-detail model used by the validated Visa Aeternum experience: reconciled statement total, line-level purchases, existing confirmed semantic rules first, unresolved descriptions left as `A classificar`, category aggregation by value and access to full detail. No category was inferred merely from the issuer PDF's merchant-category label.

## Post-write verification
The V18/V11 future read was re-run after refresh. It proves:
- the refreshed bank anchors are used on the current day;
- the closed Itaú card cash event occurs on its evidenced scheduled debit date rather than the contractual due date;
- the new scheduled subscription debit is present;
- the user's financing edit remains effective;
- the generic Bradesco card debit is present on its evidenced date;
- the current vested-share layer is not double counted after the brokerage refresh.

## Open evidence / decisions — do not infer
1. A scheduled transfer to Larissa conflicts by amount with an existing health-related projection on the same date. Confirm whether it replaces that projection or is a separate payment before changing either.
2. A later scheduled transfer to Larissa has the same date/value as an existing Volvo-insurance projection. Confirm whether they are the same economic item or separate.
3. The Itaú screenshot shows only a total invested amount, not enough evidence to assert that the entire amount is the already-modeled D0 Cofrinho. Do not overwrite that asset without detail/confirmation.
4. A presented Mercado Pago boleto is visible in DDA, but presentation alone does not prove that it is an accepted obligation to be paid. Keep it out of Flow until the user confirms commitment.
5. The supplied card-export ZIP contains an encrypted CSV and remains preserved but unread. Use a decrypted/exported CSV if the user wants that source ingested; do not request or store a banking password.
6. The small scheduled Bradesco card debit has no evidenced card identity in the supplied screen. Full Aeternum-style invoice drilldown requires the actual card statement/detail or explicit identity evidence.

## Classification gate
Do not ask the user to classify the accumulated backlog in bulk yet. First perform one real authenticated classification save -> refresh -> readback/self-heal test in the recovered Flow/Updates surface. Only after that lifecycle is proven should the user be told to resume large-scale classification.

## Next gate
User reviews the refreshed signed-in Daily Flow in practice. Material Flow approval remains human and separate from deterministic/browser/backend tests. Any discrepancy found during this review is appended here or in a successor checkpoint; it must not be reconstructed from chat memory.