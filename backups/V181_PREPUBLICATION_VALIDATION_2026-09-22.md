# LTS Wealth — V181 prepublication validation

Date: 22/09/2026. Candidate publication status: **not yet exposed at the fixed homologation entry**.

This record distinguishes database verification, static/automated gates, direct-candidate browser checks, fixed-entry authenticated checks and user acceptance. A pass in one layer never stands in for another.

## Preserved baseline

- Base main before the V181 product branch: `cf15307eac17b0d000002d4001ce309354c131f1`.
- Previous fixed homologation: V180.
- Protected `index.html` SHA-256: `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`.
- V177–V180 candidates and all earlier continuity/backlog records remain available.
- No public-root/production promotion is authorized.

## Database and financial validation completed

- The card/cycle collision was reproduced across every affected documented card family, not patched as a one-day exception.
- Derived-reader precedence now yields one documentary cash obligation per eligible card/cycle, zero surviving legacy projection for that cycle and zero difference between documented invoice and Flow value.
- All eligible documentary cycles in the bounded future range passed the central QA reader.
- Raw invoice and legacy source rows were preserved. Derived installment floors remain planning evidence, not cash obligations.
- Current-period expense rows have no duplicate source key. Structured card purchases, direct cash rows, monthly reconciled allocations and aggregate-only coverage are mutually exclusive presentation modes whose totals reconcile exactly to the selected expense total.
- The two questioned named expense groups were audited as mutually exclusive source-row assignments, not a parent-plus-child sum.
- Extraordinary receipts retain the existing missing-source issue; no unsupported historical amount was added.
- The review writer was exercised inside an authenticated transaction and rolled back. It resolved one source-keyed test item, returned the owner-without-prefix display contract and left the real queue unchanged after rollback.

## Candidate contracts implemented

- V179 current-day cash priority/recovery and V180 documentary/brokerage behavior remain loaded before V181.
- Cards view removes the non-actionable inventory panel and adds documentary value, Flow value, difference, status and direct Flow navigation.
- Atualizações begins with an authenticated classification queue. No option is preselected and one explicit save affects one source key.
- Pending-identification buttons route to that queue; documentary coverage remains a separate action.
- Categories can be read by person/context or by nature as alternative partitions of the same total.
- Monthly balance keeps the KPI cards and matrices, removes the repeated annual block and adds monthly inputs, expenses, result and year total.
- Apartment detail states the active period and distinguishes the complete documented investment archive.
- Aggregate-only rows disclose the missing purchase-level evidence and request the statement for the relevant competence.
- Detail scrolling uses a full-height flex drawer, real overflow, touch panning and mobile-safe sizing.
- Visible candidate/version labels are V181; the protected root remains unchanged.

## Direct-candidate defect found before exposure

The first authenticated V181 candidate opened with complete cash and its seven documentary cycles reconciled, but a long-detail click exposed a client-thread stall. The drawer observer reapplied identical header text on every mutation, which could retrigger itself. The fixed homologation remained on V180. The runtime was corrected to mutate drawer text only when the value actually changes, and the permanent gate now asserts the idempotent-decoration contract.

The corrected candidate then opened the apartment component, returned 17 of 17 rows and allowed scrolling to the final row. That same pass showed that the two explicit invoice-coverage rows opened correctly but lacked the aggregate-only warning because their account labels were card names rather than the generic historical-aggregate label. V181 now treats the entire reconciled-total coverage group as aggregate-only as well as detecting generic historical aggregate rows. The asset revision was advanced again so no browser can reuse the pre-fix runtime. A fresh direct-candidate pass remains required before exposure.

## Still required before fixed-entry exposure

- Product pull-request gate and exact protected-root hash.
- Direct published V181 candidate in the authorized authenticated session.
- Full reload into Dashboard with complete current-day cash.
- Documentary reconciliation screen with zero issues.
- Daily Flow verification of each eligible card cycle, including the user-reported due date.
- Return Flow → Dashboard without stale/partial cash.
- Classification queue read with no default selection and without saving a real decision.
- Categories alternate-view total identity and apartment/aggregate drill-down.
- Notebook and responsive mobile viewport scroll to the final detail row.
- Fixed-entry exposure in a separate change, served-byte/signed-out gate, Pages completion, then the same authenticated reload and Dashboard → Flow → Dashboard path.

Until those checks pass, V181 is **in progress**, not ready for user testing, and no completion claim is allowed.

## Post-publication outcome

The pending list above documents the pre-exposure checkpoint. PR #36 merged its final aggregate disclosure and v181c asset. PR #37 exposed V181 at the fixed entry after nine green pull-request workflows. The served manifest returned V181 after the Pages update; an earlier browser visit had still received V180 while publication lagged. The authorized authenticated browser then opened the fixed entry, fully reloaded into a complete dated Dashboard, compared today's total with Flow, observed one documentary invoice on the reported date, and returned Flow → Dashboard with the cash position intact. Card reconciliation, classification no-default behavior, alternative expense views, long-detail scrolling and aggregate-only disclosure had passed on the directly published candidate. See the immutable V181 publication receipt for evidence boundaries and open dependencies. User acceptance and physical-phone validation are still open.
