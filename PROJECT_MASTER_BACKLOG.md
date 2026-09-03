# LTS Wealth — Master Backlog

Status legend: [x] concluded, [~] in progress, [ ] open.

Canonical persistent project list. Detailed immutable evidence remains in `backups/`, `HISTORICAL_RECOVERY_LOG.md`, `HOMOLOGATION_V135_V137_INCIDENTS_2026-08-29.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md`, `NEXT_HOMOLOGATION_GATE.md` and release checkpoints. Never remove an open financial, documentary, classification or product dependency during compaction.

## P0 — v150 recomposição / homologação fixa — 03/09/2026
- [x] v150 product candidate completed on `v150-expenses-input-dashboard-recomposition`.
- [x] Exact green product/gate SHA `a67ba2d9c8fb770a463397349c67e654fe2e781f`.
- [x] Branch workflow `33784295793` SUCCESS; job `100745221087`; artifact `9904891998`; digest `sha256:3a2550ddc480b17182cedfff16ef49d8756387195509816f163bc5d56145c8ea`.
- [x] v150 branch is fully contained in `main`; fresh compare on 03/09/2026 showed `ahead_by=0`, branch `behind_by=3` before canonical-doc closure.
- [x] Integrated-main baseline `25e517a28f900e281966d00a44cba827e49efb85`; exact v150 workflow `33785378395` SUCCESS; Pages `33785376825` SUCCESS.
- [x] Controlled fixed-homologation exposure commit `97fff4d35cc0c3edd24a11b458a1bed7d885ddcb`.
- [x] `homologacao-current.json` points to `v150` / `wip35-v150-candidate.html` / product SHA `a67ba2d9...` with `promotion_status:not_promoted`.
- [x] Exact exposure v150 workflow `33796998363` SUCCESS; job `100786998249`; artifact `9909647698`; digest `sha256:735cc4082378302a8b04ad710898a485defe6cf7909f2f9af65e0e292e02d388`.
- [x] Exact exposure candidate-smoke `33796998174` SUCCESS; v148 lifecycle `33796998303` SUCCESS; exposure Pages `33796996669` SUCCESS.
- [x] All nine workflows triggered by the exposure commit reached terminal successful/acceptable conclusions; no in-progress/null/failure/cancellation remained at release closure.
- [x] v150 smoke verifies desktop/mobile Dashboard, Despesas context×nature, drill-down, Atualizações tools, reviewed input route to `Entradas`, read-only Fluxo lookup, version ownership and zero forbidden writer RPCs.
- [x] Reviewed input route is `target:Entradas`, `preview_only:true`, `writer_added:false`; phrase is prefilled into the existing `.phrase` field and approval remains explicit.
- [x] Post-exposure `main` changes before this docs closure were docs-only: immutable checkpoint + homologation gate alignment; no product file changed.
- [x] Current protected public `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [x] Immutable exposure checkpoint: `backups/WIP35_V150_HOMOLOGATION_EXPOSURE_CHECKPOINT_2026-09-03.md`.
- [~] Material user homologation of v150 is the current release gate.
- [ ] Public `index.html` promotion only after explicit user authorization; never infer promotion from homologation approval.
- [ ] Real authenticated visual E2E remains pending/unclaimed.

## 0. Release / homologation guardrails
- [x] Public root: `https://lthomesilveira-ui.github.io/lts-wealth-/`.
- [x] Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- [x] Fixed homologation serves v150 through `wip35-v150-candidate.html`.
- [x] Public fallback remains WIP35-v136 with protected `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- [ ] Never force branch history or overwrite parallel work.
- [ ] Before every repository write, re-fetch `main`, active branch, `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and latest immutable checkpoint.
- [ ] Never promote `index.html` without explicit user authorization.
- [ ] Never claim authenticated visual E2E unless actually performed.
- [ ] Keep fixed link, mobile/desktop usability, backup and traceability working through every release.

## 1. Dashboard / planejamento incorporado
- [x] Product framing: `Sua vida financeira, em uma tela.`.
- [x] Primary hero: `Disponível realizável até D+3`.
- [x] Bank cash, D0 liquidity and vested RSU D+3 remain separated.
- [x] FGTS is a separate D+30 contingency layer, never current cash.
- [x] Redundant top-level `Planejamento` navigation removed in v150; planning remains functionally available inside Dashboard/liquidity detail.
- [x] Management point **08/01/2027**.
- [x] FGTS request-by **09/12/2026**.
- [x] Documentary FGTS **R$17.509,05**.
- [x] Existing accrual model **R$3.700/mês**; do not change by assumption.
- [x] Projected request-date FGTS **R$32.309,05**.
- [x] Worst before contingency **-R$21.046,80**; worst after contingency **+R$11.262,25**.
- [x] No uncovered gap through **28/02/2027** under the existing modeled contingency.
- [x] Future RSUs remain excluded before vest/settlement.
- [ ] Any new money-changing assumption/scenario requires explicit user decision.

## 2. Despesas — natureza × contexto/pessoa
- [x] Economic invariant **R$8.623.752,53** preserved.
- [x] Analytical cache **3.860/3.860**, zero mismatch.
- [x] v150 separates nature of spend from context/person/cost center.
- [x] Supported analysis periods: current year, 12 months, since 2023, since 2013 where evidence exists.
- [x] Context/person examples remain `Benjamin`, `Lucas`, `Larissa`, `Rafiki`, `Casa`, `Não atribuído`.
- [x] Nature examples remain semantic spend categories such as Educação, Saúde, Moradia, Alimentação and Transporte.
- [x] Context→nature and nature→context drill-down are read-only and can reach contributing transactions where certified detail exists.
- [x] `Não atribuído` is separated into documentary detail not recovered, detail available/system investigation, and classification/context pending rather than one undifferentiated manual queue.
- [x] Mixed historical model preserved: certified detail where evidence exists, aggregate otherwise; never fabricate detail for aggregate-only periods.
- [~] Improve density, ranking and decision-useful insights after material v150 feedback.
- [~] Reduce `A classificar` only by evidence, never by pattern invention.
- [~] Continue system-side evidence investigation before asking the user for classification.

## 3. Classification evidence hierarchy
1. explicit user-confirmed rule;
2. exact/consistent LTS history;
3. public merchant research;
4. manual review if ambiguity remains.

- [x] Public research may identify merchant/context possibility but never invent purchase purpose.
- [x] `GULA GULA MORUMBI` may support a restaurant suggestion but remains manual taxonomy review until classification is proven.
- [x] Marketplaces/intermediaries remain manual where the actual purchase purpose is not demonstrable.
- [x] v148 existing writer `lts_browser_semantic_feedback_v1` executes only after explicit user save; reader remains `lts_browser_product_v1`.
- [x] Synthetic lifecycle proves save→refresh→resolved disappearance, read-only retry and `O que mudou`.
- [x] Writer-success/refresh-failure state remains `Decisão salva · verificação pendente`; retry is read-only and must not repeat the writer.
- [ ] Real authenticated classification save→refresh→resolved disappearance/self-heal/`O que mudou` remains pending.

## 4. Atualizações / Input / documents
- [x] Atualizações remains an action center/checklist; avoid large blank whitespace and actions hidden far below the fold.
- [x] v150 adds `Ferramentas rápidas`: `Lançamento por texto` and `Consultar o Fluxo`.
- [x] Text input routes to existing `Entradas` preview; no automatic financial posting occurs from the phrase alone.
- [x] Preview continues to require explicit review of date, value, nature, account/card, category, center of cost, counterparty and description.
- [x] Date, value and account/card remain mandatory for approval.
- [x] Liquidity/RSU movements are not to be conflated with revenue/expense.
- [x] Fluxo quick lookup is read-only by date interval + textual search.
- [x] v147 guided document association preserved: bank statement requires account/institution + competence; card statement requires card + competence; financing requires commitment + exact as-of; other docs remain manual review.
- [x] Filename never determines account, card, competence, date or value.
- [x] Upload alone never creates a financial posting.
- [x] v149 read-only PDF/image interpretation review preserved; `Vínculo informado por você` remains separate from `Leitura do arquivo · revisar`.
- [x] Structured extraction is evidence, not automatic financial fact; raw OCR/text/pages/rows are not promoted automatically.
- [x] Guardrails preserved: `financial_writer_changed=false`, `rpc_calls=0` for v149 review, `filename_inference=false`, `manual_review_required=true`, `permanent_polling=false`.
- [ ] Real authenticated PDF/image interpret→review remains pending/unclaimed.

## 5. Fluxo Diário / FIX86
- [x] Mandatory by Itaú, Bradesco, C6 and Consolidado.
- [x] Historical coverage preserved back to 2013 where evidence exists.
- [x] Visual hierarchy `Saldo anterior | Entradas | Saídas | Saldo final`.
- [x] Balance/total fields keep visual differentiation from ordinary movements.
- [x] Engine `daily-flow-fix86-v13-bank-asset-liquidity-parity`.
- [x] Facts beat projections; scenarios never become facts; stale anchors cannot reanchor.
- [x] Cards do not feed their own projection.
- [x] Bank↔liquidity-asset transfer has consolidated economic effect zero.
- [ ] Never infer a historical bank where evidence is absent.
- [ ] Real authenticated visual E2E remains open.

## 6. Natural liquidity input
- [x] Parser supports `5 mil`, `R$5.000`, `5000`, `3k`, `R$1.250,50`.
- [x] Never guess account or asset.
- [x] Preview shows both legs, before→after and economic effect **R$0**; explicit confirmation required before write.
- [x] Transactional QA writes roll back; no QA financial row persists.
- [ ] Authenticated save→refresh→visible result remains pending.
- [ ] Cancellation/reversal semantics must be append-only and auditable; do not invent semantics. Ask before implementing any money-changing reversal behavior.

## 7. Cartões / historical recovery
- [x] Certified allocation **38 cycles / 650 rows / R$885.855,19**.
- [x] Aggregate fallback **314 rows / R$2.650.846,36** remains aggregate-only.
- [x] C6 Aug/2024 category **R$4.087,42**; detail **R$4.020,72**; explicit Taxi/Uber gap **R$66,70**.
- [x] Mastercard 2022 certified: Apr R$11.910,91; Jun R$10.185,54; Jul R$13.486,29; Oct R$28.374,06.
- [~] Mastercard 2022 remaining months require documentary recovery.
- [~] Mastercard 2023: 12 ledger-only payments totaling **R$496.689,05**; independent category matrix absent.
- [x] Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; other months incomplete.
- [x] Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct partial; Sep/Dec blocked.
- [x] Visa 2017 **R$126.681,76 aggregate-only**.
- [x] Visa Infinite Itaú 2024 **R$112.253,01 aggregate-only**.
- [x] Visa Infinite Itaú 2025 12/12 certified.
- [~] Continue Mastercard/Visa recovery only from evidence; never pattern-backfill or fabricate purchases.

## 8. Patrimônio / RSU / FGTS / CIPÓ / Volvo
### RSU
- [x] Vested **459.483 units / R$32.772,30 / D+3**.
- [x] Future awards excluded until vest/settle.
- [x] Sale 283 units settled 05/08/2026; theoretical gross **R$19.673,72**; net **R$19.095,04**.
- [ ] Historical sale difference **R$578,68** remains unexplained/unitemized.
- [x] `Simular antecipação` is read-only.

### FGTS temporal distinction
- [x] Historical Excel position **R$25.585,03**.
- [x] 07/05/2026 realization evidence: `FGTS` +R$25.585,03 and `investimentos itaú` -R$25.000,00.
- [x] Current documentary position **R$17.509,05** is later and distinct; never treat the two as the same static balance.
- [x] FGTS may be used as an approximately D+30 contingency in planning, never immediate cash.

### CIPÓ 396
- [x] Drill-down exposes purchase, history, reforms, debt, market estimate, equity and schedule.
- [ ] Itaú consortium delta **R$303,60** unresolved.
- [ ] `R$6.654,50 = R$6.502,70 + R$151,80` is arithmetic evidence only; dates differ and rows must not be suppressed by assumption.
- [ ] Condominium formula/cutoff lacks source.
- [ ] Raw gap **R$1.780.358** unresolved.
- [ ] Dedup gap **R$1.312.268** unresolved.
- [ ] Duplicate excess through Jul/2026 **R$3.531,70** unresolved.
- [ ] Never fabricate post-2029 TR.
- [ ] Market value minus cost is not automatically taxable profit/net gain without validated rules.

### Volvo
- [x] Bradesco financing: **60 × R$2.886,43**, first 08/09/2026, last 08/08/2031.
- [x] Economic effect exactly once across Bradesco Flow + Patrimônio; no duplication.
- [ ] Exact trim/version and km required before valuation refinement.

## 9. Open Finance
- [x] Provider-neutral private architecture QA **14/14**.
- [x] No real consent, token, provider or contracting exists.
- [~] Need written pricing, support, SLA and explicit product×bank coverage for Itaú, Bradesco and C6.
- [ ] No provider consent, spend, credential or commercial commitment without explicit user decision.

## 10. Backend QA / stability / performance
- [x] Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`.
- [x] v14 **293/293** across 24 suites; v15 **67/67** across 5; v16 **19/19** across 2; v17 **32/32** across 4.
- [x] Staged total **411 checks / 35 suites PASS**; supplemental v143 **16/16 PASS**. Do not call this one monolithic gate.
- [x] v146 repeated navigation regression: **10 cycles × 7 destinations × desktop/mobile = 140 physical Playwright clicks**, including `Cartões` → `Patrimônio`.
- [x] v150 inherits and reruns v146 navigation, v147 document association, v148 classification lifecycle and v149 interpretation review in its gate.
- [~] Further performance work only after correctness/parity.

## 11. Historical continuity / backups / product quality
- [~] Continue audit of pendências and improvements back to project start 07/07/2026 so no item disappears across chats.
- [x] Preserve historical financial evidence from 2013 where supported.
- [x] Preserve fixed public link and fixed homologation link.
- [x] Preserve canonical export/safe restore and backup traceability.
- [~] Keep Dashboard/Despesas/Atualizações dense enough to avoid large dead whitespace while remaining mobile/desktop usable.
- [~] Preserve visual emphasis for balances/totals and the intuitive checklist structure in Atualizações.

## 12. Historical release facts retained by checkpoints
- [x] v146 navigation hang root cause isolated to inherited v142 wealth-loader stale completion/retry rendering; corrected without financial rule changes.
- [x] v147 guided document association integrated/exposed with explicit identity/competence/as-of guardrails.
- [x] v148 classification lifecycle integrated/exposed; visible-version ownership correction eliminated inherited v142 label takeover.
- [x] v149 read-only document interpretation review integrated and inherited by v150.
- [x] v150 recomposition integrates Dashboard, Despesas and quick tools while preserving v147/v148/v149 contracts.
- [x] Detailed immutable evidence for those releases remains in `backups/`; do not delete or rewrite historical checkpoints.

## 13. Current user-dependent decisions / blockers
- [~] Material homologation of fixed v150 release.
- [ ] Human classification only where evidence remains insufficient.
- [ ] Any new money-changing financial assumption/scenario.
- [ ] Append-only reversal semantics before financial cancellation/reversal UI.
- [ ] Volvo refinement when exact trim/km evidence is available.
- [ ] Open Finance provider/consent/spend decisions.
- [ ] Public promotion only after explicit user approval.

Until one of these is the genuine blocker, continue autonomous technical/documentary work and test before asking the user to inspect anything.