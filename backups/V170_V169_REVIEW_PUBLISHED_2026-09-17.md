# V170 — V169 review closure published

Date: 17/09/2026
Status: PUBLISHED IN FIXED HOMOLOGATION; PUBLIC ROOT UNCHANGED; HUMAN ACCEPTANCE PENDING

## Authorization and lineage

The user authorized autonomous completion and publication only in homologation in `lthomesilveira-ui/lts-wealth-`.

- Previous remote `main`: `4707f2d143c9b2fbe5094cadae53372eaaed34e7`.
- V170 product head: `139ac69564820cd54439d202a875b244839b2602`.
- Manifest exposure commit: `0b49a8a999dfd51c30fbb4b80aefed5bf71f4192`.
- Branch: `work/v170-v169-user-review-20260917`.
- Candidate: `wip35-v170-candidate.html`.

No force update was used. `index.html` stayed byte-for-byte unchanged with SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`. `promotion_status` remains `not_promoted`.

## Delivered scope

- Dashboard pension total follows its components; principal expense view is Top 15 and Education is split by person.
- Expense composition uses current effective sources and separates financing, loans/Coopharma, and O Parque/CIPÓ 396 with traceable subgroups and original-source disclosure.
- Patrimônio clarifies today, future, restricted assets and passives without double-counting future installments as current payoff balances.
- Morgan Stanley shows statement gross, available and unavailable totals separately from the planning total after the projected Cash RSU reserve.
- Available Morgan cash is R$ 15.913,44 and is carried into Flow, including vested shares and brokerage cash.
- A confirmed bulk action applies one price and FX rate to every active RSU/Cash RSU vesting; individual price/date controls remain available.
- Flow opens by default from five prior days through 31 December of the following year.
- Historical consolidated Flow has nonblank opening and closing balances for every civil day from 09/10/2013 through 16/09/2026.
- Paired internal transfers net to zero. An internal move across the tracked-bank perimeter adjusts tracked cash and is explicitly labelled as neither revenue nor expense.
- V169 atomic edit/delete controls for both legs of a user-created transfer remain protected.

## Data and audit evidence

The tracked cash perimeter is Itaú, Bradesco and C6. The historical audit covers 4,726 civil days, with 4,726 balanced days, zero mismatches and maximum absolute arithmetic gap R$ 0.00.

The Morgan statement snapshot reconciles to:

- gross total: R$ 1.745.784,67;
- available: R$ 15.913,44;
- unavailable: R$ 1.729.871,23;
- future regular RSU gross: R$ 1.142.654,04;
- future Cash RSU gross: R$ 587.217,19;
- vested shares: R$ 13.012,45;
- brokerage cash: R$ 2.900,98.

The bulk vesting RPC was executed inside an explicit database transaction and rolled back. No audit artifact or changed award assumption remained. New internal readers have no anon/authenticated execution privilege; browser writes retain authenticated user assertion and audit behavior.

## Exact automated evidence

- Branch V170: `35222746676` — SUCCESS.
- Main V170: `35223164124` — SUCCESS.
- V169 compatibility: `35223164154` — SUCCESS.
- Integrated Flow and invoices: `35223164142` — SUCCESS.
- Flow default window: `35223164131` — SUCCESS.
- Candidate smoke: `35223164083` — SUCCESS.
- V163 compatibility: `35223164146` — SUCCESS.
- V164 compatibility: `35223164201` — SUCCESS.
- V165 compatibility: `35223164184` — SUCCESS.
- GitHub Pages manifest deployment: `35223163491` — SUCCESS.

The V170 gate covers desktop and 390 px mobile layouts, exact bulk-award mutation parameters with controlled fixtures, internal-transfer cash arithmetic, no horizontal overflow, and V170-only visible release branding. The protected regressions include Chromium and WebKit. Controlled fixtures are test evidence, not the user's private financial data.

## Published verification

After Pages completed, the fixed homologation bootstrap returned HTTP 200. The live manifest selected `wip35-v170-candidate.html` at product head `139ac69564820cd54439d202a875b244839b2602`. The live candidate contained the V170 title, V170 runtime and `noindex,nofollow`. A fresh live download of the public `index.html` matched the protected SHA-256 exactly.

This proves deployment, routing and protected-root integrity. It does not substitute for the user's human authenticated notebook/phone review.

## Next gate

The user should inspect V170 through the fixed homologation link, especially historical Flow years, the Morgan gross/net/available reading, bulk vesting update, management expense groups and transfer controls. Public-root promotion remains a separate explicit decision.
