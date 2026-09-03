# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-03 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial, documentary, classification, reconciliation and product dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, recurrence, reconciliation, valuation, tax or economic-effect rules.
- Ask the user only when a real financial/classification/documentary decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence. Integration is normal fast-forward/merge only after a fresh compare.
- Preserve historical evidence back to 2013 where supported.

## Fixed links / access
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Canonical user UUID: `c1b23404-210f-4095-b3c7-7b8664e64f4c`.
- Public fallback remains WIP35-v136; protected `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.
- Authenticated visual E2E remains pending/not claimed.

## Current release — v150 fixed homologation
- Source branch: `v150-expenses-input-dashboard-recomposition`.
- Exact green product/gate SHA: `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- Candidate path: `wip35-v150-candidate.html`.
- Marker: `expense-input-dashboard-recomposition-v1`.
- Branch workflow `33784295793`: SUCCESS; job `100745221087`; artifact `9904891998`; digest `sha256:3a2550ddc480b17182cedfff16ef49d8756387195509816f163bc5d56145c8ea`.
- Integrated-main baseline: `25e517a28f900e281966d00a44cba827e49efb85`; v150 workflow `33785378395` SUCCESS; Pages `33785376825` SUCCESS.
- Controlled exposure commit: `97fff4d35cc0c3edd24a11b458a1bed7d885ddcb`.
- `homologacao-current.json` points to `v150` / `wip35-v150-candidate.html` / product SHA `a67ba2d9...`.
- `promotion_status` remains `not_promoted`.
- Exact exposure v150 workflow `33796998363`: SUCCESS; job `100786998249`; artifact `9909647698`; digest `sha256:735cc4082378302a8b04ad710898a485defe6cf7909f2f9af65e0e292e02d388`.
- Exact exposure candidate-smoke `33796998174`: SUCCESS; v148 lifecycle `33796998303`: SUCCESS; Pages `33796996669`: SUCCESS.
- All nine workflows triggered by the exposure commit reached terminal state with no in-progress/null/failure/cancellation at release closure.
- Post-exposure main changes before the canonical-doc closure were docs-only; product and manifest state remained unchanged.
- Immutable exposure evidence: `backups/WIP35_V150_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-09-03.md`.
- Current release gate: material user homologation of v150.

## v150 product contract
### Dashboard
- `Sua vida financeira, em uma tela.`
- Primary hero `Disponível realizável até D+3`.
- Bank cash, D0 and vested RSU D+3 stay separated.
- FGTS is a separate restricted D+30 contingency, never current cash.
- Top-level `Planejamento` navigation is removed as redundant; detailed liquidity remains inside Dashboard.
- Planning invariants remain: management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; accrual R$3.700/month; request-date FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027 under the existing model.
- Future RSUs remain excluded until vest/settlement.

### Despesas
- Invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Nature of spend and context/person/cost center are distinct analytical dimensions.
- Periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- Context→nature and nature→context drill-down are read-only and only show item detail where evidence exists.
- `Não atribuído` is split into documentary detail not recovered, detail available/system review, and classification/context pending.
- Never fabricate detail for aggregate-only history.
- Evidence hierarchy: explicit user rule → exact/consistent LTS history → public merchant research → manual review.
- GULA GULA MORUMBI remains manual taxonomy review despite restaurant evidence; marketplaces/intermediaries remain manual where purpose is unproven.

### Atualizações / Entradas / Fluxo lookup
- Atualizações is a compact action center/checklist; avoid large blank whitespace and buried actions.
- `Lançamento por texto` routes to the existing `Entradas` preview, prefills `.phrase`, uses `preview_only:true`, adds no writer and requires explicit approval before any existing writer can execute.
- Date, amount and account/card remain mandatory for approval.
- Do not conflate liquidity/RSU movements with revenue/expense.
- `Consultar o Fluxo` is read-only by date interval + text search.
- v150 desktop/mobile smoke explicitly validates `Atualizações → texto → Entradas → phrase prefilled`, read-only Fluxo query and no forbidden writer RPC.

## Preserved v146–v149 contracts
### v146 navigation stability
- Real hang reproduced around `Cartões` → `Patrimônio`; root cause was inherited v142 wealth-loader stale completion/retry rendering.
- Stable navigation preserved without reintroducing competing ownership timers/observers.
- Regression gate: 10 cycles × 7 destinations × desktop/mobile = 140 physical Playwright clicks.

### v147 guided document association
- Bank statement: explicit account/institution + competence.
- Card statement: explicit card + competence.
- Financing: explicit commitment + exact as-of.
- Other financial document: manual review.
- Filename never infers account/card/competence/date/amount.
- Upload/registration itself creates no financial posting.

### v148 classification lifecycle
- Existing writer `lts_browser_semantic_feedback_v1` executes once only on explicit user save; reader `lts_browser_product_v1` reloads product.
- Synthetic lifecycle proves save→refresh→resolved disappearance, `O que mudou`, and read-only retry after refresh failure.
- Writer success + refresh failure state remains `Decisão salva · verificação pendente`; retry never repeats the writer.
- Real authenticated lifecycle remains pending/unclaimed.

### v149 document interpretation review
- Read-only interpretation review for PDF/image output remains layered on v147 explicit association.
- `Vínculo informado por você` stays separate from `Leitura do arquivo · revisar`.
- Structured extraction is evidence only; raw OCR/text/content/pages/rows/lines never auto-promote to financial facts.
- Guardrails: `financial_writer_changed=false`, `rpc_calls=0`, `filename_inference=false`, `manual_review_required=true`, `permanent_polling=false`.
- Real authenticated PDF/image interpret→review remains pending/unclaimed.

## Canonical financial/product invariants
### Fluxo Diário
- Mandatory by Itaú, Bradesco, C6 and Consolidado; preserve supported history back to 2013.
- Hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances remain visually differentiated.
- Engine `daily-flow-fix86-v13-bank-asset-liquidity-parity`.
- Facts > projections; scenarios never facts; stale anchors cannot reanchor; cards do not feed their own forecast.
- Bank↔liquidity-asset movement has consolidated economic effect zero.

### Natural liquidity input
- Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- Never guess account/asset.
- Preview both legs/before-after/economic effect R$0; explicit confirmation before write.
- Authenticated save→refresh→visible remains open.
- Cancellation/reversal must be append-only/auditable; do not invent semantics.

### Cards
- Certified allocation 38 cycles / 650 rows / R$885.855,19.
- Aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 category R$4.087,42 vs detail R$4.020,72; explicit Taxi/Uber gap R$66,70.
- Visa 2017 R$126.681,76 aggregate-only; Visa Infinite Itaú 2024 R$112.253,01 aggregate-only; Visa Infinite Itaú 2025 12/12 certified.
- Mastercard 2022 certified Apr R$11.910,91; Jun R$10.185,54; Jul R$13.486,29; Oct R$28.374,06.
- Mastercard 2023: 12 ledger-only payments totaling R$496.689,05; independent category matrix absent.
- Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; others incomplete.
- Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- Never pattern-fill or fabricate aggregate-only purchases.

### RSU / FGTS
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded.
- 283-unit sale settled 05/08/2026: theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unexplained/unitemized.
- Historical Excel FGTS R$25.585,03 and 07/05/2026 realization are a different temporal position from current R$17.509,05.
- FGTS is approximately D+30 contingency when needed, never immediate cash.

### CIPÓ 396
- Preserve drill-down purchase/history/reforms/debt/market estimate/equity/schedule.
- Open: consortium delta R$303,60; R$6.654,50 = R$6.502,70 + R$151,80 is arithmetic evidence only with different dates; condominium formula/cutoff source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70.
- Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.

### Volvo
- Financing: 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically across Bradesco Flow + Patrimônio.
- Exact trim/km remains open before refined valuation.

### Open Finance / backend QA
- Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- Need written pricing/support/SLA/product×bank for Itaú/Bradesco/C6 before any provider decision.
- No consent/spend/credential/commercial commitment without explicit user decision.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`.
- v14 293/293 in 24 suites; v15 67/67 in 5; v16 19/19 in 2; v17 32/32 in 4; staged total 411 checks / 35 suites PASS; supplemental v143 16/16 PASS. Never call this one monolithic gate.

## Open backlog that must always remain visible
- Material user homologation of current v150 fixed release.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.
- Real authenticated PDF/image interpretation→review.
- Real authenticated classification save→refresh→resolved disappearance/self-heal/`O que mudou`.
- Natural liquidity authenticated save→refresh→visible.
- Append-only cancellation/reversal semantics.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa historical documentary recovery.
- All CIPÓ blockers listed above.
- Volvo exact trim/km.
- Open Finance pricing/SLA/product×bank.
- Further performance only after correctness/parity.
- Audit of any project dependency/improvement since 07/07/2026 so no item disappears across chats.
- Preserve visual balance emphasis, compact Atualizações checklist, no large whitespace regressions, mobile/desktop usability, fixed links, backup and traceability.
