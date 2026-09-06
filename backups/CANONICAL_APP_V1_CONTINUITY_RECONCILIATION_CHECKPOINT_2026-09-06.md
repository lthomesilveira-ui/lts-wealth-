# LTS Wealth — Canonical App v1 continuity reconciliation checkpoint — 06/09/2026

## Purpose
Immutable checkpoint after reconciling the canonical app, planning/FGTS, RSU evidence, append-only mutation contract, CIPÓ evidence and continuity documents. This checkpoint supersedes `CANONICAL_APP_V1_FUNCTIONAL_HOMOLOGATION_CHECKPOINT_2026-09-06.md` as the latest operational continuity source while preserving that earlier evidence unchanged.

## Canonical product / homologation
- Canonical frontend: `canonical-app.html`, one frontend with no historical release iframe/wrapper chain.
- Functional app source: `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`.
- App size: 79,339 bytes; SHA-256 `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`.
- Deterministic canonical functional gate `34003647351`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Gate artifact `9980249754`, digest `sha256:10aaad7ea9b27920562d32ce69462249fdd3d03818caffe2fe3d985527b6b5e0`.
- Fixed homologation exposure commit on `main`: `e6f3ab7421d5b7cb1986df768835f9d826536d9d`.
- Exact Pages deployment `34003976631`: SUCCESS.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`, selecting `canonical-v1` / `canonical-app.html` / `promotion_status:not_promoted`.
- Public `index.html` protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; no public promotion authorized/done.
- Authenticated physical-iPhone E2E remains pending/unclaimed.

## Documentation reconciliation completed
- `NEXT_HOMOLOGATION_GATE.md` refreshed from stale v160 framing to canonical baseline in commit `24ae91a5e2e142bd4766864cac08f2894b138a9c`.
- `LTS_WEALTH_CONTINUITY_HANDOFF.md` refreshed to canonical app in commit `375921ec8ef852fd8a803c3e679aa013dd389379`.
- `PROJECT_MASTER_BACKLOG.md` reconciled to current canonical/backend evidence in commit `ba2982900943a6f6e0352d02a570b659a15a3857`.
- No open financial/documentary dependency was intentionally removed; unsupported stale claims were corrected rather than carried forward.

## Planning / FGTS current contract
Audited current evidence:
- bank cash R$15.794,43;
- D0 R$42.929,50;
- vested D+3 R$12.909,65;
- liquidity through D+3 R$71.633,58;
- FGTS R$22.432,31 at 21/08/2026, restricted / approximately D+30;
- no future FGTS accrual estimated;
- request FGTS by 30/11/2026;
- management/action point 30/12/2026;
- first uncovered gap 30/01/2027;
- worst before FGTS -R$25.782,39;
- worst after documentary FGTS -R$3.350,08.

`dashboard_planning_first_negative_alias` normalizes the frontend field alias only; it does not change financial arithmetic.

## RSU evidence corrected
Current documentary asset evidence at 03/09/2026:
- Organon Long Share Holdings: 184,483 shares;
- value R$12.909,65;
- liquidity D+3;
- available now true.

Historical prior snapshot at 18/08/2026:
- 459,483 shares;
- R$32.772,30.

Current metadata records a 275-share reduction after the prior snapshot and a user-confirmed sale. Exact trade settlement date/price/proceeds for that reduction remain pending documentary reconciliation and must not be invented.

Separate brokerage cash at 03/09/2026:
- R$2.862,67;
- liquidity class `available_unclassified`;
- excluded from D0/D3 until transfer latency is evidenced.

Any older backlog claim presenting 459,483 / R$32.772,30 as the current position or asserting an unsupported exact sale quantity/gross/fees/FX has been superseded.

## Append-only mutation contract closed
Current backend code and QA prove append-only edit/cancel/split semantics:
- current-event operations append to `lts_flow_event_operation`;
- legacy overrides append to `projecao_op`;
- mutation audit appends to `lts_flow_mutation_audit`;
- source `financial_events` / legacy facts are not destructively rewritten by this contract;
- effective readers apply latest active operations and suppress cancelled/split originals;
- `lts_fix86_legacy_guardrails_qa_v4` returns 10/10 PASS, including `flow_mutations_append_only_operational`.

Therefore the backlog requirement for append-only cancellation/edit/split semantics is closed. A separate user-facing undo/reversal action is not implemented/claimed and remains disabled until an explicit append-only reversal contract exists.

## CIPÓ evidence preserved
Actual consortium evidence includes:
- 12/02/2023 R$6.654,50 Bradesco;
- 15/03/2023 R$6.502,70 Bradesco;
- 17/04/2023 R$6.502,70 Itaú;
- 12/05/2023 R$6.654,50 Itaú;
- 15/05/2023 R$151,80 Itaú;
- 12/06/2023 R$6.502,70 Itaú.

R$6.654,50 on 12/05 and R$151,80 on 15/05 are separate entries, not same-date arithmetic evidence. R$303,60 consortium delta remains unresolved; R$303,60 ledger matches found under Visa Infinite are not consortium evidence.

Still open: condominium source/formula/cutoff; raw R$1.780.358 gap; dedup R$1.312.268 gap; duplicate excess R$3.531,70; no fabricated post-2029 TR; no automatic taxable/net-gain conclusion.

## Open Finance current state
- Provider-neutral architecture QA 14/14.
- `lts_browser_open_finance_status_v1` exposes provider-neutral connection/sync health.
- Provider records are staged and reconciled before canonical financial effect.
- LTS tables do not store bank credentials/provider API secrets/tokens under the current contract.
- No provider selection/activation, consent or commercial spend is claimed.
- Still required: written pricing/support/SLA, exact product×bank coverage for Itaú/Bradesco/C6, scope, history depth, refresh/webhooks, consent renewal, error handling and sandbox quality.

## Remaining material dependencies
- Authenticated physical-iPhone canonical financial/data E2E.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation→review.
- Real authenticated server-side transaction-search/CSV E2E.
- Natural-liquidity authenticated save→refresh→visible.
- User-facing undo/reversal beyond proven append-only cancel/edit/split semantics.
- Expense density/insights and evidence-only `A classificar` reduction.
- Mastercard/Visa documentary recovery.
- RSU trade settlement details where documentary evidence remains incomplete.
- CIPÓ unresolved items above.
- Volvo exact trim/version and km.
- Open Finance provider comparison and later user decision for provider/spend/consent.
- Historical dependency audit back to 07/07/2026.
- Public promotion only after explicit user authorization.

## User action now
NONE. Continue autonomous work until a genuine decision/document/credential/physical-device final gate is the blocker.
