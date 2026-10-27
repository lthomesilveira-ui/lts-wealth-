# Read-time eligibility for a documented income adjustment

The documentary rule for a negative salary adjustment was already present, but activation depended on physically removing its effective expense-cache row. Retain that cache as source material and apply the validated rule at the canonical expense reader instead.

Only `receipt_adjustment` evidence accepted by the existing V348/V343 source view is eligible. The reader additionally requires exactly one canonical occurrence for that owner and source, direct-cash coverage, the documented date and amount. A changed raw import, conflicting or revoked proof, later explicit review, changed cached identity or ambiguous occurrence stops the exclusion. Classification mapping and all reader attributes are preserved by an exact source lease. With no active proof, output is identical.

The private activation binds the two-workbook proof to its intended owner, validates membership, inserts it once and verifies the effective result. It compares every other canonical row, the full physical expense cache, the raw import and existing proofs. It writes no financial event and removes no physical expense row. Existing evidence triggers invalidate derived report caches. Replays require inspection.

Native PostgreSQL tests execute the actual reader and documentary source guard, invalid proofs, later changes, ambiguity, replay and owner/privilege isolation. Live validation must run a rollback trial first, then prove that only the documented adjustment leaves spending and that the actual report, monthly/detail consumers and cash values agree. The published frontend remains V353; code or a synthetic test alone is not delivery.
