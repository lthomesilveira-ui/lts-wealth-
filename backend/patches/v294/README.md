# V294: superseded default-person decisions and historical source checks

This is an administrator-operated data correction and reproducible QA, not a new frontend release. V293 and every published asset remain immutable.

An earlier historical import wrote review decisions assigning a default person to otherwise generic expenses. Later owner instructions require a known expense to remain classified without inventing its consumer. The guarded operation only supersedes the exact old automatic-policy decisions with no category override; specific purchase/person decisions stay unchanged. The full original decisions remain in the private audit trail.

The operation requires explicit owner and expected nonempty scope, locks matching decisions, compares the complete canonical expense multiset, preserves amounts/dates/categories/identities/review status, rejects unrelated changes and compares every financial-event/bank-source row before/after. A change in the existing read fingerprint is mandatory. An identical repeat must not create another audit or decision. The initial execution must be rolled back before applying it.

The OOXML helper reads cached original values without executing macros, recalculating or modifying either workbook. The historical comparison uses Decimal, distinguishes missing from zero, rejects duplicate dates and compares original-source arithmetic, companion cells and actual API positions separately. Corroborated workbook positions are not certified full bank statements. Synthetic tests include missing/error values, source/API differences, empty years, genuine zero and unexecuted formulas.

Old audit helpers that compare unnormalized legacy rows with older transformation versions are not valid certification of the current cash engine. A failed comparison is investigated at the same source/account/date grain; it is never resolved by changing balances to make an old diagnostic green. The remaining historical anchors/conflicts, total-only invoice limitations, fully cold performance and native/private-session/device checks remain separate until individually proven.
