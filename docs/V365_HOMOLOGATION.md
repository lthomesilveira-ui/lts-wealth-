# V365: classification, Flow and wealth presentation

Card suggestions can be confirmed in place or changed in an editable dialog. Both paths use the existing source UUID and expected raw hash, and refresh the canonical pending queue after a confirmed save. The dialog keeps its confirmation action in a visible footer.

Flow leaves scheduling and overdue reviews in Updates. A balance discontinuity displays an explicit bridge from the reconstructed balance to the observed available position. An overdue invoice is visible on its due date as a payment awaiting evidence, outside realized cash entries/exits. The bridge never creates a transaction or assumes an invoice settled. Phase indicators use accessible dots instead of labels beside every date.

The recurrence audit requests a rolling five calendar years. Covered series are separate from the default pending filter. Recurrence actions show affected periods and last observed dates. This release does not infer future values or extend contracts without a confirmed policy.

Wealth separates current gross assets, documented liabilities, incomplete net worth and future awards. Morgan reference and dated statement retain separate bases; detailed provenance is closed. Pension structure is preserved and quotes appear with awards. Financing cards retain installment progress and display documented interest and CET when available. Monthly expense summaries emphasize consolidation and negative values without changing totals or drilldown.

No historical financial rows, raw sources, categories or settlement decisions are changed by this release. It copies immutable V359 into a new release. Browser fixtures exercise notebook 1366×768 and mobile 390/360; their synthetic session and persistence are distinct from a real owner's private HTTP acceptance and a physical device test.

The separate V366 database change adds explicit fixed or variable recurrence policies and an owner-scoped daily worker. Public RPCs are invokers; authenticated writes remain in a non-exposed schema and require the existing owner guard. The worker creates no financial occurrence without a confirmed fixed policy, respects existing occurrences and cancellations, and never backfills the past. V367 can attach source-hash-bound receipt facts as suggestions; it never decides a category or a beneficiary.
