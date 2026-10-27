# V351 — C6 settlement and consistent card cash schedule

The card cash schedule used a legacy reader: an old Mastercard forecast could appear even though the main application flow already represented the posted bank debit. The final main flow already contained the C6, Mastercard and Prime bank movements once. This change reads that final flow for the card schedule, includes reviewed posted settlements by their source identity and keeps pending invoices visibly unconfirmed, outside realized cash.

C6 sometimes reports a settled invoice as `OTHER_PAYMENT`. That type remains unchanged. A narrowly reviewed policy requires one C6 cycle, one selected issuer payment in the cycle, an exact posted checking debit, the same amount and civil date, one billing account and complete consumption coverage. Prior invoice credits are excluded from consumption alongside explicit invoice payments; merchant refunds remain economic credits. Existing FULL_PAYMENT policies keep their previous rules.

The private activation creates only one C6 documentary link and its consumption contract. It inserts no bank cash fact, no expense, no projection replacement and performs no payment. Its transaction validates all three already observed bank payments, preserves existing Mastercard/Prime links and contracts, compares the final application's bank-day amounts and daily balances, all future events, source rows and realized expenses. The flow cache epoch advances so comparisons use the current readers.

Native PostgreSQL fixtures execute the production validators, overlay and patched schedule, reject ten invalid or ambiguous source cases, preserve merchant refunds, retain pending projections, reject duplicate activation and verify exact schema replay. The prior 21 cycle-window cases also run. Real-data activation requires the same guards in a rollback trial, then a committed run and an independent read of the actual application RPCs.

The Aeternum bank record remains pending. A checking balance difference alone is insufficient to mark it settled. Authenticated browser validation remains a separate acceptance step when an owner session is available; SQL checks do not certify that session.
