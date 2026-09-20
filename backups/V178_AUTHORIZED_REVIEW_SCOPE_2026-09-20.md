# V178 — Authorized integrated review — 20/09/2026

Status: IMPLEMENTATION AUTHORIZED; NOT RELEASED.
Baseline main: `24dae85acb42993d395f7a20fe2160414ff2aa33`.
V177 and production remain unchanged until validation and homologation-only exposure.

The user ended feedback collection and explicitly authorized the complete package. The detailed private record is `/LTS Wealth/Feedbacks/LTS_WEALTH_V177_REVISAO_USUARIO_2026-09-20.md` in their Library. Read it before continuing; keep financial values, source photos and private provider/person decisions out of this public repository.

## Binding work
1. #23: restore current bank cash independently of expensive projections; never label an incomplete liquidity subtotal as a complete total; distinguish loading, error, stale and recovered states.
2. #24: make every detail panel fully scrollable to its last item; count and sum all source items, preserve dates versus monthly competence, handle search and asynchronous race/cancellation correctly.
3. Preserve category AND beneficiary from original sources; apply only the user's explicit scoped classification decisions in private data. Unknown person is not automatically the default user. Same model for Dashboard, categories, monthly balance and detail.
4. Property drilldown: purchase (identifiable financing, acquisition instalments, brokerage, consortium), works/reform, recurring occupancy costs, property taxes. Avoid attributing unrelated historical housing to one property. Unknowns remain explicit private review items.
5. Replace the generic family-outflow label for demonstrably identified personal outflows as instructed, without flipping signs or relabeling unrelated past data.
6. Preserve reviewed loans, historical cards, expense-window boundaries and raw financial facts. Tests are not permission to delete pending documentary issues.
7. Final feedback: RSU/award vesting never enters bank cash Entradas/Saídas. Non-cash event is visible only on expanding the day. Dedicated vested column changes on evidenced vesting date; distinguish later availability/settlement, avoid double counting, preserve cash-only hide-zero filtering.
8. Professional product UI: no reconciliation/programming explanations. Missing information must remain honestly disclosed in concise product language.

## Release gates
- Read current main, working branch, handoff, execution state, master backlog, next gate and latest checkpoint before writes.
- Additive candidate and readers only; preserve production index hash.
- Source tests: amount/sign/count identities; beneficiary preservation; all supported accounts/cards exactly once; no cross-period leakage; detail and group totals reconcile.
- Browser tests: two failed dashboard reads then recovery, day rollover, null vs zero vs negative, month/window navigation, hundreds of detail rows with last-row access on desktop/mobile, cross-group races, RSU-only and cash+RSU days with unchanged cash.
- Do not claim authenticated user-session tests unless actually executed. Fixture tests and live database checks are distinct evidence.
- Persist completed vs unresolved status and private ambiguity list. Publish only validated homologation; keep earlier fallback intact.
