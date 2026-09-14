# LTS Wealth — Execution State

Latest implementation update: 14/09/2026. Continued Despesas with actual-reader adapters, an exact-source bridge to the existing integrity checker, safe asynchronous request state and repeatable synthetic CI. The code is tested but NOT activated in the user's V162 screen. The complete previous state is preserved unchanged at backups/LTS_WEALTH_EXECUTION_STATE_BEFORE_EXPENSE_ADAPTERS_2026-09-14.md; all unaffected decisions, blocked-operation boundaries and pending items remain binding.

## Work actually implemented
Added lts-expense-read-model.js for the existing dual cash/consumption payload and monthly-detail payload, plus same-scope executive/month comparison. Exact cents and original taxonomy are preserved. It detects missing/duplicate/out-of-scope rows and internal total/category/count inconsistencies, distinguishes transaction/category-only/total-only evidence, and never turns an absent value into zero or a matching total into documentary certification.

Added selection-scoped request lifecycle: stale replies cannot replace a new period/category, loading and failed requests do not display old totals under new filters, authentication errors are separate and raw server detail is not shown. Invalidation/disposal clears in-memory results. No background polling, automatic retry or persistent browser storage.

Added .github/scripts/lts_expense_reader_adapter.cjs, which integrates monthly payloads with the unchanged original offline integrity checker. Explicit preverified source-identity bindings, date basis and economic treatment are mandatory. The module neither fetches these proofs nor infers them from merchants/amounts. This closes the previous missing CODE adapter, not the missing live-source proof or actual-screen integration.

New .github/workflows/expense-read-contract.yml runs offline Node and browser contracts on relevant code changes. Test artifacts contain synthetic examples only. The workflow is configured, not retrospectively claimed as having run before publication; consult its actual run status.

## Actual interface path clarified
The freshly read protected index.html shows that despesas() uses expenseDualState/loadExpenseDual -> lts_browser_expense_dual_lens_v1. It also reads D.expense_drilldown in some existing sections. Executive v3/v4 over cached v12 and monthly-detail v2 over total_rows_v5 are additional paths, not replacements for that active dual lens. The new adapters support these distinct contracts without equating cash, consumption and total-expense semantics.

The only Supabase reads this turn were function-definition metadata for the dual wrapper/core. No actual expense-value comparison, previous denied query, classification write, cache refresh, migration or financial mutation was attempted. All synthetic tests are offline and do not reconstruct/execute the denied request through another channel.

## Verification
Local Node: 86 PASS (20 unchanged original integrity tests + 52 monthly/executive/adapter/lifecycle tests + 14 dual-lens tests). Original lts_expense_integrity.cjs was fetched, reconstructed locally and checked at the exact existing Git blob d2870a4b16c07aa9397eb74b98f387dab365dbe8; it is unchanged in this package.

Local Chromium: eight synthetic checks each at 1366x900 and 390x844, sixteen PASS, zero network attempts. The fixture verifies loading, late-response isolation, partial-month labels, safe text rendering, no false source certification, redacted errors/no zero, disposal and fixture bounds. This is not real-LTS UI layout verification, WebKit/iPhone E2E or the user's authenticated session. No actual expense totals were certified.

Detailed implementation contract: LTS_WEALTH_DESPESAS_READ_MODEL_CONTRACT.md, read alongside the preserved execution plan. Latest checkpoint: backups/V162_DESPESAS_ADAPTERS_AND_LIFECYCLE_TESTED_2026-09-14.md.

## Delivery boundary and next work
No active HTML, V162 runtime, manifest, index.html or financial/backend function was changed. The new module is not loaded by the live app. There is no new Despesas screen or homologation link to test yet. The implemented adapter/controller must next be integrated into the existing component after an allowed live-source verification path is available; do not insert another wrapper chain or use its injected loader to bypass denied operations.

Continue Despesas as the user-selected module. Required next steps remain source/reading parity, the known historical duplicate lineage and vehicle-advance consumption repair, summary synchronization and transaction drill-down bound to the same verified basis. Finance/asset layers and cash-versus-competence remain unchanged. Category/date coverage, month openness and historical granularity must be explicit. Complete code tests are not full financial delivery.

## Preserve the completed question set and pending execution
The H01–H13 question set is answered. The last verified baseline remains seven source-pending card lines and two bank groups, all previously answered; stored summaries forty/eleven. These counts were NOT newly queried this turn. Seven H06/H08 decisions are in private Drive record 1V0jeNYASEUEkERRFuqrA0E-lzfor6Laj and the screenshot checkpoint. The two outgoing health-plan reimbursements and the Benjamin - Presentes rename remain unapplied. Correct rename scope remains seven H11 plus H12b/d, excluding the baby-changing equipment and household electrical kit. Do not re-ask or count answers as completed writes.

The last successful five-source batch remains H09b Mercado Livre intentional fallback; H10a Vestuário; H10b/c and H13b Casa - Utensílios e equipamentos. Their private before/after evidence remains final_five_h09b_h10_h13b_categories_20260914_v1. H12a remains child structure/equipment; H12b/d toy identity is confirmed with the old label; H12c is household equipment; H13a is Carro with car-bin use. All other employer, restaurant/Ifood, child, gift, health, fuel, household, maintenance, travel and vehicle-source decisions remain authoritative.

## Unclosed gates / protected history
Known initiated/posting-date duplicate representations, vehicle-advance extra consumption, two payment/control markers, historical bank attribution, beneficiary display, cached summaries, transaction-scoped manual UI and actual-session save/refresh/reopen remain OPEN. No source field or cash record was removed to make reports pass. Full review remains inclusive from 07/07/2026 with relevant older installments; history since 2013 and unknown purchase years are preserved. Other-card documents, data freshness, manual bulk release and whole-product human approval remain separate.

Patrimônio requires independent holdings/debts/valuation/date-base evidence. A new Dashboard still needs an explicitly approved complete visual proposal. Current cash anchors, confirmed Bradesco yield, separate dated Cofrinho, vested-only awards, invoice due/cash distinction, C6 prior-payment exclusion, financing/insurance/family/vehicle and rejected-DDA choices remain untouched. The nomenclature-equivalence map stays deferred.

RETOMAR_LTS_WEALTH.md remains the permanent restart entry. Preserve the current V162 bank-switch closure, selected dates, single descending invoice list, D-5/today/D+30 and protected public root. Before repository writes refresh main/active branch, latest state/checkpoint, full backlog/delta/coverage, next gate, decisions, handoff and canonical plan. Never force refs or overwrite concurrent work. All previous complete states/checkpoints are immutable. Updates use Concluído / Em execução / Próximos passos; no unattended execution was scheduled.
