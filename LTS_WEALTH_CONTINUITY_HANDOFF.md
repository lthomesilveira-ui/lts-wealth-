# LTS Wealth — Continuity Handoff

Last materially refreshed: 2026-09-02 (America/Sao_Paulo)

This file exists so project continuity never depends on chat context. Always re-fetch `main`, the active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, this file and the latest immutable checkpoint before every repository write.

## Conduct
- Preserve every open financial/documentary/classification dependency; never compact it away.
- Project updates use exactly `Concluído / Em execução / Próximos passos`.
- No microbuilds; package coherent changes.
- Never invent financial amounts, classifications, merchants, competence, valuation, recurrence or reconciliation.
- Ask the user only when a real financial/classification/documentary decision is required; otherwise advance autonomously.
- Test before user homologation; do not delegate basic QA.
- Never claim authenticated visual E2E unless actually executed.
- Public `index.html` remains protected; no promotion without explicit user approval.
- Never force branch divergence. Integration is normal fast-forward/merge only after a fresh compare.

## Fixed links and protected baseline
- Public: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Supabase project: `tadhkamnwtsbdozwkyut`.
- Canonical user UUID: `c1b23404-210f-4095-b3c7-7b8664e64f4c`.
- Public fallback remains WIP35-v136; protected `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion remains unauthorized/not done.
- Authenticated visual E2E remains pending/not claimed.

## Current fixed homologation — v148
- Fixed homologation currently serves v148 / `wip35-v148-candidate.html` / `not_promoted`.
- User/mobile previously saw v142 labels despite the v148 wrapper. This was reproduced publicly and was not diagnosed as cache.
- Cause: inherited v142 60 ms version-label ownership loop plus MutationObserver survived beneath later candidates.
- Corrected v148 product SHA `333bb3c4eb06c8e68d9de0c637da37c09db43989` owns badge/brand/footer across the same-origin frame chain and retires the inherited v142 brand owner.
- Exact v148 exposure SHA `966db03a64fdfadb4d27656044f220624f8debaf`; exact exposure Pages, candidate-smoke and v144–v148 workflows all SUCCESS.
- Live public unauthenticated verification remained visibly v148 beyond delayed inherited timers; no visible v142.
- Immutable evidence: `backups/WIP35_V148_VISIBLE_VERSION_CORRECTION_EXPOSURE_CHECKPOINT_2026-09-02.md`.
- Keep v148 fixed and untouched while the user tests today's resolved items and v149 integration is gated.

## Retained v146/v147/v148 product facts
### v146 navigation
- Real repeated-navigation hang reproduced around `Cartões` → `Patrimônio`.
- Cause was inherited v142 wealth-loader stale completion/retry rendering after retirement, not a financial rule.
- v146 owns stable seven-node navigation, coalesces navigation work outside the physical click path, redirects wealth ownership to v143 and suppresses stale legacy completion rendering.
- Repeated-navigation smoke: 10 cycles × 7 destinations × desktop/mobile = **140 physical Playwright clicks**.

### v147 guided document association
- Bank statement: explicit account/institution + competence.
- Card statement: explicit card + competence.
- Financing: explicit commitment + exact as-of date.
- Other financial document: manual review; no invented identity.
- Filename does not infer identity, competence, date or amount.
- Association stored under `task_context.document_association`; upload/registration itself creates no financial posting.

### v148 classification lifecycle
- Existing writer `lts_browser_semantic_feedback_v1` executes only on explicit user save; reader `lts_browser_product_v1` reloads product.
- Synthetic desktop/mobile gate proves save→refresh→resolved disappearance, one writer call, read-only retry after refresh failure and `O que mudou`.
- If writer succeeds and refresh fails, safe state is `Decisão salva · verificação pendente`; retry is read-only and must not repeat writer.
- Real authenticated save→refresh remains pending/unclaimed.

## Active branch — v149 document interpretation review
- Branch: `v149-document-interpretation-review`.
- Scope: read-only interpretation review for PDF/image output layered on v147 explicit association.
- Marker: `document-interpretation-review-v1`.
- Structured extracted fields are shown as evidence, separate from the user-provided association.
- Raw OCR/text/content/pages/rows/lines are not promoted automatically to financial facts.
- Missing required association remains visible/manual; filename never infers account/card/competence/date/amount.
- No financial posting, reconciliation, category inference, balance effect or new financial writer.
- Guardrails: `financial_writer_changed=false`, `rpc_calls=0`, `filename_inference=false`, `manual_review_required=true`, `permanent_polling=false`.
- v149 inherits v147 directly, loads the v148 lifecycle into the deepest app and uses one combined mutation owner to preserve v148 Atualizações + v149 Entradas behavior without competing version observers.
- First v149 gate caught a self-triggering version-label MutationObserver loop; fixed by idempotent version stamping before release evidence.
- Exact green product/gate SHA `050ca36dd14d4ffdbaa27dbfdfc579ddbfe54331`.
- Workflow `33692647025` SUCCESS; job `100454598090` SUCCESS.
- Artifact `9870669700`; digest `sha256:e470c3d9c46feb622b42371606cb11d0712ba057c6a4668ce2419e1b533d26ff`.
- Same run passed static architecture, button contracts, parser, v146 140-click regression, v147 association, v148 lifecycle and v149 desktop/mobile smoke.
- Desktop/mobile evidence includes explicit CIPÓ association/structured fields and an unassociated image field, with manual-review warnings, stable v149 visible labels and zero relevant browser errors.
- Immutable checkpoint: `backups/WIP35_V149_PREINTEGRATION_CHECKPOINT_2026-09-02.md`.
- Documentation commits after the exact product run are docs-only; integration must still be followed by exact integrated-main gates.
- v149 is NOT exposed in fixed homologation yet.
- Real authenticated PDF/image interpret→review remains pending/unclaimed.

## Immediate execution sequence
1. Freshly compare `main` vs `v149-document-interpretation-review`.
2. Require no divergence: main must be ancestor / branch `behind_by=0`.
3. Re-fetch the six mandatory resources immediately before integration.
4. Fast-forward `main` to the v149 branch head with `force=false`; do not alter `homologacao-current.json` in the integration step.
5. Run/verify v149 integrated-main workflow and Pages on the exact integrated SHA; protected `index.html` must remain exact.
6. Keep fixed homologation v148 while the user is testing; v149 exposure is separate after integrated gates.
7. If later exposed, use `promotion_status:not_promoted`, run exact exposure gates and verify served fixed URL before telling the user to test v149.
8. Never promote public `index.html` without explicit user approval.

## Canonical financial/product invariants — preserve
### Dashboard / liquidity
- Hero `Disponível realizável até D+3`.
- FGTS separate restricted D+30, never cash today.
- First liquidity management point 08/01/2027; FGTS request by 09/12/2026.
- Documentary FGTS 18/08/2026 R$17.509,05; existing accrual R$3.700/month; projected request-date R$32.309,05.
- Worst before contingency -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027 under current model.
- Future RSUs only when vested/settled.

### Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.
- GULA GULA MORUMBI may suggest Restaurantes but remains manual taxonomy review.
- Marketplaces/intermediaries remain manual where purchase purpose is unproven.

### Daily Flow
- Mandatory by bank + consolidated; historical evidence back to 2013 where supported.
- Hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`; balances visually differentiated.
- Facts > projections; scenarios never facts; stale anchors cannot reanchor.
- Cards do not feed their own forecast.
- Bank↔liquidity asset transfer economic effect zero.
- Engine `daily-flow-fix86-v13-bank-asset-liquidity-parity`.

### Natural liquidity input
- Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- Never guess account/asset.
- Preview both legs/before-after/economic effect 0; explicit confirmation before write.
- Authenticated save→refresh→visible remains open.
- Cancellation/reversal must be append-only/auditable; do not invent semantics.

### Expenses / cards
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Category/Group/Macrogroup/Cost Center/context primary; merchant secondary.
- Certified cards 38 cycles / 650 lines / R$885.855,19; aggregate fallback 314 lines / R$2.650.846,36.
- C6 Aug/2024 category R$4.087,42 vs detail R$4.020,72; explicit Taxi/Uber gap R$66,70.
- Aggregate-only history never receives fabricated purchase detail.
- Continue Mastercard/Visa recovery only from evidence, never pattern-backfill.

### RSU / FGTS
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded.
- 283-unit sale settled 05/08/2026: theoretical gross R$19.673,72; net R$19.095,04; R$578,68 difference unexplained/unitemized.
- Historical Excel FGTS R$25.585,03 and 07/05/2026 realization are a different temporal position from current R$17.509,05.

### CIPÓ / Volvo
- CIPÓ open: R$303,60 consortium delta; R$6.654,50 = R$6.502,70 + R$151,80 arithmetic evidence only with different dates; condominium formula/cutoff source absent; raw gap R$1.780.358; dedup gap R$1.312.268; duplicate excess through Jul/2026 R$3.531,70.
- Never fabricate post-2029 TR; market-minus-cost is not automatically taxable/net gain.
- Volvo financing: 60 × R$2.886,43, first 08/09/2026, last 08/08/2031, exactly once economically; exact trim/km open before refined valuation.

### Open Finance / backend QA
- Provider-neutral private architecture QA 14/14; no real consent/token/provider.
- Need written pricing/support/SLA/product×bank Itaú/Bradesco/C6 before any provider decision.
- No consent/spend/credential/commercial commitment without explicit user decision.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`.
- v14 293/293 in 24 suites; v15 67/67 in 5; v16 19/19 in 2; v17 32/32 in 4; staged total 411 checks / 35 suites PASS; supplemental v143 16/16 PASS. Never call this one monolithic gate.

## Open backlog that must always remain visible
- Material user homologation of current v148 fixed release.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.
- v149 safe integration, integrated-main gates and later controlled exposure.
- Real authenticated PDF/image interpretation→review.
- Real authenticated classification save→refresh→resolved disappearance/self-heal/`O que mudou`.
- Natural liquidity authenticated save→refresh→visible.
- Append-only cancellation/reversal.
- Expense refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa historical documentary recovery.
- All CIPÓ blockers listed above.
- Volvo trim/km.
- Open Finance pricing/SLA/product×bank.
- Performance only after correctness/parity.
