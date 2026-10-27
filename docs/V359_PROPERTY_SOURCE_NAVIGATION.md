# Property totals and source composition

The Cipó property card opens the current expense composition across acquisition, works, housing and taxes. Each group and category reaches the existing complete V353 expense detail and V346 historical card composition. Pagination, search, provenance and the return to the property comparison use existing authenticated read paths. No expense, payment, classification or source file is written.

The source comparison uses the private V358 signed-source proof and two corroborating original workbooks. The model compares copies and counts the primary workbook once. Acquisition reconciles the original summary by adding later mortgage payments and removing cash consortium contributions outside consumption. Card consortium purchases already represented by canonical expense rows remain included once. Negative source cost adjustments and zero source rows are preserved without treating them as new bank movements.

Works shows the original summary, the repeated furniture formula, the unique source components, current classified records and the unresolved difference. The amount remains unresolved rather than being turned into an artificial expense or an automatic reclassification. Original subcent precision is kept under the closed source disclosure. The mortgage source cutoff is a proved payment cutoff, not the workbook position date or a current payoff quote.

The comparison is withheld if source copies disagree, source identities or amounts are missing, the loan prefix or acquisition perimeter changes, or the works summary fails to reconcile to its source components. Current canonical group navigation remains available when only source comparison is unqualified. An incomplete or inconsistent canonical list is rejected with a retry action. Late responses cannot reopen the modal after navigation, invalidation, a changed session/day or sign-out.

## Validation

The V359 workflow runs the actual V358 private writer and V4 reader against synthetic PostgreSQL source data, including twelve rejected manifests, raw/proof preservation and owner isolation. Its native source projection is consumed by the model and rendered browser checks. Additional model cases reject inconsistent identities, duplicate file rows, partial canonical lists, changed summary amounts and unproved cutoffs.

Browser checks cover the four groups, categories, forced pagination over 350 rows, show more, search, card composition, return context, signed/zero source rows, closed provenance, unresolved difference, retry, late response and sign-out at desktop, 390 and 360 widths. Inherited Dashboard/Flow, monthly rollover and transport checks run against the new immutable release. Served asset verification covers V359 and all previously published release bytes. Synthetic browser sessions do not establish real owner HTTP or physical-device acceptance.
