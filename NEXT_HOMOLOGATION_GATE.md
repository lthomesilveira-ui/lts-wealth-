# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a new candidate. This file is operational and stays aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current public baseline
- WIP35-v136 remains the canonical public fallback at `index.html`.
- WIP35-v139 is served only as isolated candidate `wip35-v139-candidate.html`; it does not replace `index.html`.
- Latest v139 candidate UI commit: `d374eb152fff0cbb9644a674ae28527681a75f21`.
- GitHub Pages deployment for that exact commit succeeded on run 33273116737.
- Real authenticated visual E2E remains pending/unclaimed.

## Current data-recovery position — 2026-08-29
- Historical expense total: R$ 8,623,752.53 invariant.
- Certified historical category-allocation cycles: 34.
- Historical effective rows: 3,767.
- Rows with recovered category detail: 3,449.
- Remaining card aggregate fallback rows: 318, totaling R$ 2,714,803.16.
- Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- Mastercard Itaú 2025 candidate only: Jan, Feb, Jul, Oct.
- Mastercard Itaú 2025 blocked: Sep, Dec.
- Mastercard Itaú 2024 pending ledger identities: Jan/1829/R$53,652.87; Feb/1871/R$58,667.61; Apr/1966/R$47,802.70; Jun/2061/R$48,393.80; Jul/2104/R$51,947.18; Nov/2281/R$45,259.24.
- File Library retrieval is currently failing technically; no cycle may be promoted without complete documentary evidence.

## WIP35-v139 package
### Despesas
- Uses cache-backed `lts_browser_expense_executive_v4` in candidate path.
- Historical total remains invariant and expense cache QA closes 3,767/3,767 rows with zero mismatch.
- Category ranking/trends remain interactive and month drilldown delegates to certified month-detail logic.
- No merchant/purchase is fabricated when documentary detail does not exist.

### Fluxo
- Candidate future reads use authenticated-only `lts_browser_flow_v4`.
- Future cache slice v2 preserves 30/30 day and 13/13 event parity against Flow v12 in current QA.
- Current 33-day backend benchmark: ~13 ms cached versus ~4.59 s direct v12.
- Flow mutations invalidate the future cache.
- `lts_browser_flow_v4` is authenticated=true / anon=false.

### Atualizações / classificação / writes
- Main queue now presents only 10 actionable items; 2 informational/guardrail items are moved to collapsed `Contexto / monitoramento` without changing status.
- Lifecycle visual is compacted to one line: Recebido › Interpretado › Reconciliado › Decisão necessária › Resolvido.
- Classification confidence/history remains evidence-backed; 48/48 card review groups have category options, 9 have evidence-backed suggestions and 39 remain explicit no-suggestion states.
- Semantic matcher was optimized with 5,224/5,224 exact row parity; benchmark ~0.314 s versus ~2.65 s old path.
- Classification save uses scoped refresh: card-only ~0.66 s, semantic-only ~1.75 s.
- Permanent classification cache QA: 5/5 PASS; live/cache card groups 48=48 and semantic groups 0=0.
- Confirmation writes are economically invariant and now use targeted refresh (`card_operating` + `updates`), ~2.93 s versus ~18.83 s full refresh with exact affected-block parity.
- Manual invoice update uses a financial targeted refresh; affected 9 modules are exact-parity versus full refresh.
- No small browser write remains coupled to the global operational refresh.

### Document lifecycle / Inputs
- Document lifecycle read model is now `document-lifecycle-v2-change-summary`.
- `document-change-summary-v1` derives only from targets actually applied; lifecycle/reconciliation state by itself never creates a financial write.
- Multi-entry documents are summarized from `lts_input_entry_application`; legacy/simple applied documents use the actual `applied_target/applied_id` target as fallback.
- Documented card purchase is explicitly distinguished from bank cash effect before invoice reconciliation.
- Existing lifecycle v1 vs v2 parity: same summary and same inbox_id/phase state.
- Lifecycle QA: 17/17 PASS, including RLS/auth, applied→resolved mapping and presence of change summary for known applied targets.
- Current verified resolved document now has an auditable change summary based on its actual applied financial event.
- `lts_browser_product_v1` performs a one-time Updates-only schema self-heal when a same-day cache still lacks `document-change-summary-v1`; it does not trigger a global financial refresh for this migration.
- Operational health upgraded to v14: current cached lifecycle-v1 is accepted during transition; once v2 is present the gate requires `document-change-summary-v1`.
- Candidate v139 renders a compact `O que mudou` line for applied documents, with details collapsed; internal IDs are not shown in the main reading.

### Planejamento
- Planning executive is now live single-pass, without relying on the future Flow cache internally.
- JSON output is exactly equal to the prior implementation in the tested annual horizon.
- Benchmark ~3.96 s versus ~9.84 s before optimization.
- Planning QA: 23/23 PASS.
- First gap, worst gap, three episodes, FGTS D+30 and v131 counterfactual remain unchanged.

### Candidate / financial gates
- Expense v9: 19/19 PASS.
- Expense v10: 18/18 PASS.
- Core financial regression: 15/15 PASS after document lifecycle/health changes.
- Planning QA: 23/23 PASS.
- Classification cache consistency: 5/5 PASS.
- Document lifecycle QA: 17/17 PASS.
- Operational cache health v14: PASS.
- Expense read cache: 3,767/3,767, R$ 8,623,752.53 on both sides, zero missing/extra/mismatch.
- WIP35-v139 compact Updates layer before document-summary addition had Node parser + static smoke 7/7 PASS.
- Latest document-summary candidate change has repository-content smoke + Pages SUCCESS, but Node parser could not be rerun in this runtime because the container cannot resolve GitHub; do not mark the final parser gate complete yet.
- Immutable evidence: `backups/wip35-v139-performance-batch2-2026-08-29.json`, `backups/wip35-v139-performance-updates-batch3-2026-08-29.json`, and `backups/wip35-v139-document-lifecycle-batch4-2026-08-29.json`.

## Minimum package before next user look
1. Despesas critical timeout architecture fixed and financial gates green. **Status: technically green; real authenticated browser retest still pending.**
2. Cartões and Planejamento materially redesigned from rejected report-like layouts. **Status: implemented in v138/v139; visual approval pending.**
3. Atualizações lifecycle/actionability materially clearer, classification cache protected and post-document change summary visible. **Status: implemented; authenticated click-path validation pending.**
4. Fluxo candidate future latency materially reduced with exact financial parity. **Status: implemented; authenticated browser retest pending.**
5. Inputs/document lifecycle must tell the user what actually changed after an applied document. **Status: backend/read model implemented and candidate UI wired; next authenticated load performs Updates-only cache schema self-heal.**
6. Parser/static smoke for the effective isolated candidate must remain green after any candidate-file change. **Status: repository/static structure + Pages green; Node parser for the latest `d374eb15...` change remains pending because local GitHub resolution is unavailable.**
7. Public v136 fallback remains untouched. **Status: preserved.**
8. Do not claim authenticated visual E2E unless actually performed. **Status: pending/unclaimed.**

## Current readiness assessment
- Backend/data safety: GREEN.
- Expense/history gates: GREEN.
- Planning gates: GREEN.
- Flow cache parity/security: GREEN.
- Classification cache consistency: GREEN.
- Document lifecycle/change-summary backend: GREEN.
- Small-write performance architecture: materially improved.
- Latest candidate Pages deployment: GREEN.
- Final candidate Node parser after latest UI change: PENDING.
- Historical recovery: continues in parallel; current File Library failure is technical and does not authorize inference.
- Real authenticated visual E2E: PENDING.
- Visual homologation of Cartões/Planejamento/Atualizações/Despesas candidate: PENDING.
- Publish readiness for replacing `index.html`: NOT AUTHORIZED / NOT DONE.

## Trigger to ask user to look again
Do not ask the user to perform basic QA. The next look should happen only after the maximum available authenticated/browser checks are exhausted for the v139 isolated candidate, the final candidate parser/smoke gate is complete, and no data/financial gate regression exists.

Until then:
- continue backend/performance/recovery/UX work autonomously;
- keep v136 as fallback;
- preserve all blocked documentary gaps explicitly;
- never certify historical category/merchant/reversal data by inference;
- never claim authenticated visual E2E unless actually performed.