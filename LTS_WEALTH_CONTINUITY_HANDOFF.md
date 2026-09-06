# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-06 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial, documentary, classification, reconciliation and product dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, recurrence, reconciliation, valuation, tax or economic-effect rules.
- Ask the user only when a real financial/classification/documentary/provider/consent decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual/data E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence; use normal fast-forward/merge only after fresh compare.
- Preserve historical evidence back to 2013 where supported.

## Fixed links / access
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Public fallback remains WIP35-v136; protected `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.

## Current primary product — canonical app v1
The primary product line is the single canonical frontend `canonical-app.html`. The v154→v160 wrapper lineage is historical evidence only and must not be reintroduced as the product architecture.

Current facts:
- single frontend; no release iframe/wrapper chain;
- direct Supabase authentication/RPC integration;
- same app owns Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações;
- functional app source commit `f0c7737aecefc3e1f64c501502a0cdee2abeb9ca`;
- app size 79,339 bytes; SHA-256 `2ce0e6e92575c8ca11bc8178f54bc13a6b6c8bf05b0b75bc9b05046c1c1638f8`;
- canonical functional gate `34003647351`: SUCCESS;
- gate artifact `9980249754`, digest `sha256:10aaad7ea9b27920562d32ce69462249fdd3d03818caffe2fe3d985527b6b5e0`;
- fixed homologation exposure commit `e6f3ab7421d5b7cb1986df768835f9d826536d9d`;
- exact Pages deployment `34003976631`: SUCCESS;
- fixed homologation selects `canonical-v1` / `canonical-app.html` / `promotion_status:not_promoted`;
- latest immutable checkpoint: `backups/CANONICAL_APP_V1_CONTINUITY_RECONCILIATION_CHECKPOINT_2026-09-06.md`;
- authenticated physical-iPhone financial/data E2E remains pending/not claimed.

## Deterministic canonical evidence
Run `34003647351` validates in Chromium desktop 1312×1199 and WebKit 390×844:
- five liquidity-first KPI cards under controlled fixture;
- six physical routes and return to Dashboard;
- Fluxo account switching;
- Despesas nature × context, drilldown and historical period selector;
- Patrimônio / FGTS;
- Cartões;
- Atualizações classification queue, incremental transaction search, result total, CSV enablement and document lifecycle surface;
- no iframe;
- no horizontal overflow;
- mobile six-item navigation not clipped;
- no page errors;
- unauthenticated no-fixture state exposes the real login.

This is deterministic fixture/unauthenticated evidence, not authenticated physical-device E2E.

## Official visual / Dashboard target
- Authoritative reference: original 1312×1199 image, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.
- Target remains dark desktop rail, light dense executive canvas, compact spacing and intentional mobile layout.
- Liquidity-first hierarchy: `Dinheiro em contas`, `Contas + curto prazo`, `RSUs vested`, `FGTS`, `Despesas (mês)`; pending actions secondary.
- Reference defines hierarchy/density/language, not financial values.

## Current financial/product invariants
### Dashboard / Planning / FGTS
- Bank cash R$15.794,43; D0 R$42.929,50; current vested D+3 R$12.909,65; liquidity through D+3 R$71.633,58.
- `Contas + curto prazo` remains evidence-only arithmetic.
- FGTS exact documentary balance R$22.432,31 at 21/08/2026; restricted / approximately D+30; never D+3.
- No future FGTS deposit/accrual projection.
- Current audited planning: request FGTS by 30/11/2026; management/action point 30/12/2026; first uncovered gap 30/01/2027; worst before FGTS -R$25.782,39; worst after current documentary FGTS -R$3.350,08.
- `dashboard_planning_first_negative_alias` normalizes the first-negative field without changing arithmetic.
- Historical R$3.700/month FGTS accrual and dependent R$32.309,05 outputs are historical only.
- Future RSUs remain excluded until vest/settlement.

### RSU / Organon
- Current documentary position 03/09/2026: 184,483 shares / R$12.909,65 / D+3.
- Previous 18/08/2026 snapshot: 459,483 shares / R$32.772,30; historical only.
- Current metadata records a 275-share reduction after the prior snapshot and a user-confirmed sale, but exact trade settlement date/price/proceeds for that reduction remain pending documentary reconciliation.
- Brokerage cash R$2.862,67 at 03/09/2026 is separately `available_unclassified` and excluded from D0/D3 until transfer latency is evidenced.
- Do not invent quantity/gross/fees/FX for historical proceeds where evidence is incomplete.

### Despesas
- Economic invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature and context/person/cost center distinct.
- Canonical route consumes `lts_browser_expense_context_lens_v1` and keeps read-only drilldowns/historical periods.
- Classification hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- Marketplace/intermediary alone never proves purchase purpose.
- Continue decision-useful density/ranking and evidence-only reduction of `A classificar`.

### Atualizações / search / documents / classification
- Compact prioritized action center; no large blank whitespace or buried actions.
- `Lançamento por texto` remains preview/review first; no automatic posting.
- Server-side incremental search uses `lts_browser_transactions_v1`, includes total and Excel-compatible CSV; deterministic UI gate passed.
- Mastercard backend evidence: 239 rows spanning 01/11/2013–12/04/2028.
- Classification writer `lts_browser_semantic_feedback_v1`; canonical lifecycle wiring performs save → product refresh/read verification.
- Document lifecycle reader `lts_browser_document_lifecycle_v1` is surfaced in canonical Atualizações.
- Real authenticated classification, transaction-search and PDF/image interpret→review E2E remain pending/unclaimed.

### Fluxo Diário / liquidity input / mutation semantics
- Mandatory Consolidado, Itaú, Bradesco, C6.
- Facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- Bank↔liquidity-asset transfer consolidated economic effect zero.
- Natural input never guesses account/asset and requires reviewed preview before write.
- Authenticated liquidity save → refresh → visible remains pending.
- Append-only edit/cancel/split semantics proven: current-event overlays append to `lts_flow_event_operation`; legacy overrides append to `projecao_op`; mutations append to `lts_flow_mutation_audit`; source facts are not destructively rewritten.
- `lts_fix86_legacy_guardrails_qa_v4` passes 10/10 including `flow_mutations_append_only_operational`.
- Separate user-facing undo/reversal is not claimed/enabled without an explicit append-only reversal contract.

### Cartões
- Certified allocation 38 cycles / 650 rows / R$885.855,19.
- Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 explicit R$66,70 gap remains.
- Mastercard/Visa incomplete historical months remain documentary recovery only; never pattern-fill purchases.

### CIPÓ 396
- Distinct consortium entries R$6.654,50 on 12/05/2023 and R$151,80 on 15/05/2023; never present as same-date arithmetic.
- R$303,60 consortium delta unresolved; Visa Infinite R$303,60 rows are not consortium evidence.
- Condominium source/formula/cutoff absent.
- Raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess R$3.531,70 unresolved.
- Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.

### Volvo
- Bradesco financing 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically.
- Exact trim/version and km remain required before valuation refinement.

### Open Finance
- Provider-neutral architecture QA 14/14.
- `lts_browser_open_finance_status_v1` exposes architecture/connections/sync health; provider records are staged/reconciled before canonical financial effect; no bank credentials/provider secrets are stored in LTS tables under the current contract.
- No provider selected/activated by project decision; no consent/token/commercial commitment claimed.
- Need written pricing/support/SLA, exact product×bank coverage for Itaú/Bradesco/C6, scope, history depth, refresh/webhooks, consent renewal, errors and sandbox quality.
- Provider/spend/consent remains a future user decision.

## Historical release lineage retained, not current
- v154 accepted visual direction; v155 false-zero/navigation correction; v156 liquidity-first but rejected real iPhone; v157 WebKit deterministic pass but real-device rejection; v158 truthful fallback/product regression; v159 presentation restored but KPI data unavailable on real iPhone; v160 material-data readiness/truthful fallback; canonical app supersedes all as primary architecture.

## Open backlog that must always remain visible
- Authenticated physical-iPhone canonical financial/data E2E.
- Real authenticated classification lifecycle.
- Real authenticated PDF/image interpretation→review.
- Real authenticated server-side search/CSV E2E.
- Natural-liquidity authenticated save→refresh→visible.
- User-facing undo/reversal only after explicit append-only reversal contract; cancel/edit/split already proven append-only.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary recovery.
- Current/historical RSU sale documentary detail where not evidenced.
- CIPÓ R$303,60 delta, condominium source, raw/dedup gaps, duplicate excess.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank comparison; no provider/consent/spend without explicit authorization.
- Audit all dependencies/improvements back to 07/07/2026.
- Public promotion only after explicit user approval.
- Preserve official-reference visual language, mobile/desktop usability, backup/restore and traceability.

## User action now
NONE. Continue autonomous technical/documentary/reconciliation work until a genuine user decision or authenticated physical-device final gate is the blocker.