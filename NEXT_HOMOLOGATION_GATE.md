# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a new candidate. This file is operational and stays aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current public baseline
- WIP35-v136 remains the canonical public fallback at `index.html`.
- WIP35-v139 is served only as isolated candidate `wip35-v139-candidate.html`; it does not replace `index.html`.
- Latest material v139 candidate commit: `71853adfcbb40f06509a539eb359a85f19b6b3f3`.
- Candidate-only read-only CI run 33275122675 succeeded on that exact SHA.
- GitHub Pages run 33275122077 succeeded on that exact SHA.
- Real authenticated visual E2E remains pending/unclaimed.

## Current data-recovery position — 2026-08-29
- Historical expense total: R$8,623,752.53 invariant.
- Certified historical category-allocation cycles: 34.
- Historical effective rows: 3,767.
- Rows with recovered category detail: 3,449.
- Remaining card aggregate fallback rows: 318, totaling R$2,714,803.16.
- Visa Infinite Itaú 2025: 12/12 certified.
- Mastercard Itaú 2025 certified: Mar, Apr, May, Jun, Aug, Nov.
- Mastercard Itaú 2025 candidate only: Jan, Feb, Jul, Oct.
- Mastercard Itaú 2025 blocked: Sep, Dec.
- Mastercard Itaú 2024 pending ledger identities: Jan/1829/R$53,652.87; Feb/1871/R$58,667.61; Apr/1966/R$47,802.70; Jun/2061/R$48,393.80; Jul/2104/R$51,947.18; Nov/2281/R$45,259.24.
- C6 Aug/2024 retains a R$66.70 individual-detail gap; category total remains certified.
- File Library retrieval remains technically unreliable; no cycle may be promoted without complete documentary evidence.

## WIP35-v139 package
### Despesas
- Uses cache-backed `lts_browser_expense_executive_v4` in candidate path.
- Historical total remains invariant and expense cache QA closes 3,767/3,767 rows with zero mismatch.
- Category ranking/trends remain interactive and month drilldown delegates to certified month-detail logic.
- Documentary range lens is now wired into the candidate. Card merchants appear only from structured individual card purchases; recovered category-only rows and aggregate invoices never become fabricated merchants.
- Cash counterparties are shown separately from card merchants so banks/financial counterparties are not presented as shops.
- Current documentary-lens QA: 4/4 PASS.
- Example 2023→29/08/2026: 289 structured card-merchant rows / R$66,200.29 (~2.6% card-merchant coverage), while R$821,898.39 category-only certified, R$58,727.98 recovered-category C6 and aggregate fallback remain distinct evidence levels.

### Cartões
- Candidate cockpit presents open exposure, next outflow, contracted installments, classification pending, bill agenda, 12M history and existing drilldown.
- New dynamic historical-coverage lens reads evidence directly from the DB rather than a hardcoded month list.
- Current summary: 34 certified cycles, 553 category-allocation rows totaling R$821,898.39; 318 aggregate-fallback rows totaling R$2,714,803.16.
- C6 recovered purchase detail is shown separately by year: 2024 = 8 months/151 rows/R$21,657.14; 2025 = 12/157/R$24,560.95; 2026 = 6/39/R$12,509.89.
- Card-history coverage QA: 5/5 PASS; browser RPC authenticated-only and internal helper not exposed to browser roles.
- Historical validation is still not 100% complete; pending/blocked Mastercard cycles remain explicitly open.

### Fluxo
- Candidate future reads use authenticated-only `lts_browser_flow_v4`.
- Future cache slice v2 preserves 30/30 day and 13/13 event parity against Flow v12 in current QA.
- Current 33-day backend benchmark: ~13 ms cached versus ~4.59 s direct v12.
- Flow mutations invalidate the future cache.
- `lts_browser_flow_v4` is authenticated=true / anon=false.

### Atualizações / classificação / writes
- Primary queue now contains 6 near actions. Four 2030/2031 coverage items are collapsed under future coverage; 2 informational/guardrail items are collapsed under context/monitoring without changing backend status.
- Lifecycle visual is compacted to one line: Recebido › Interpretado › Reconciliado › Decisão necessária › Resolvido.
- Classification confidence/history remains evidence-backed; 48/48 card review groups have category options, 9 have evidence-backed suggestions and 0 are safe for auto-application.
- The 26 economically effective unclassified August card lines were audited against exact normalized history and active rules; they are genuine review gaps, not a technical cache/rule miss.
- Semantic matcher was optimized with 5,224/5,224 exact row parity; benchmark ~0.314 s versus ~2.65 s old path.
- Classification save uses scoped refresh: card-only ~0.66 s, semantic-only ~1.75 s.
- Permanent classification cache QA: 5/5 PASS.
- Confirmation writes use targeted refresh, ~2.93 s versus ~18.83 s full refresh with exact affected-block parity.
- Manual invoice update uses a financial targeted refresh; affected 9 modules are exact-parity versus full refresh.
- No small browser write remains coupled to the global operational refresh.

### Document lifecycle / Inputs
- Document lifecycle read model is `document-lifecycle-v2-change-summary`.
- `document-change-summary-v1` derives only from targets actually applied; lifecycle/reconciliation state by itself never creates a financial write.
- Multi-entry documents are summarized from `lts_input_entry_application`; legacy/simple applied documents use the actual target as fallback.
- Documented card purchase is explicitly distinguished from bank cash effect before invoice reconciliation.
- Lifecycle QA: 17/17 PASS.
- Candidate renders compact `O que mudou` for applied documents with detail collapsed and no internal IDs in primary reading.
- `lts_browser_product_v1` has an Updates-only same-day schema self-heal; authenticated visual validation of this path remains pending.

### Planejamento
- Planning executive is live single-pass, without relying on the future Flow cache internally.
- JSON output is exactly equal to prior implementation in tested annual horizon.
- Benchmark ~3.96 s versus ~9.84 s before optimization.
- Planning QA: 23/23 PASS.
- First gap 08/01/2027, worst gap R$-21,046.80, three episodes, FGTS D+30 and v131 counterfactual remain unchanged.

### CIPÓ reconciliation status
- Reconciliation v4 currently reports 12 exact components, 32 pending, 1 divergent, 1 unresolved and 6 source-only; existing QA remains green.
- Consórcio Itaú source R$19,508.10 versus raw ledger R$19,811.70 remains unresolved. Raw composition exposes an overlap signal involving R$151.80 but does not prove which row is invalid; no suppression is authorized.
- Condomínio source `Pago` R$115,867.108 is not reproduced by any tested raw cutoff. Exact duplicate early ledger rows exist, but deduplicating them still leaves a closest tested gap of R$1,312.268; duplicates alone do not authorize correction.

### Candidate / financial gates
- Expense v9: 19/19 PASS.
- Expense v10: 18/18 PASS.
- Core financial regression: 15/15 PASS after latest documentary-lens/card-history work; expense total remains R$8,623,752.53.
- Planning QA: 23/23 PASS.
- Classification cache consistency: 5/5 PASS.
- Document lifecycle QA: 17/17 PASS.
- Operational cache health v14: PASS.
- Expense read cache: 3,767/3,767, R$8,623,752.53 on both sides, zero missing/extra/mismatch.
- Documentary expense merchant/counterparty QA: 4/4 PASS.
- Card-history coverage QA: 5/5 PASS.
- Candidate CI run 33275122675: SUCCESS on SHA `71853adf...`.
- Pages run 33275122077: SUCCESS on the same SHA.
- Latest immutable checkpoint: `backups/wip35-v139-documentary-lenses-batch7-2026-08-29.json`, commit `b58b2693...`.
- Public v136 fallback remains untouched.

## Minimum package before next user look
1. Despesas critical timeout architecture fixed and financial gates green. **Status: technically green; real authenticated browser retest still pending.**
2. Cartões and Planejamento materially redesigned from rejected report-like layouts. **Status: implemented; visual approval pending.**
3. Atualizações lifecycle/actionability materially clearer, classification cache protected and post-document change summary visible. **Status: implemented; authenticated click-path validation pending.**
4. Fluxo candidate future latency materially reduced with exact financial parity. **Status: implemented; authenticated browser retest pending.**
5. Inputs/document lifecycle tells what actually changed after an applied document. **Status: backend + candidate UI implemented; authenticated validation pending.**
6. Despesas range-level documentary merchant/counterparty lens and Cartões historical evidence coverage must not fabricate missing history. **Status: implemented; dedicated QAs 4/4 and 5/5 green.**
7. Parser/static smoke for the effective isolated candidate must remain green after any candidate change. **Status: GREEN via candidate-only read-only CI run 33275122675.**
8. Public v136 fallback remains untouched. **Status: preserved.**
9. Do not claim authenticated visual E2E unless actually performed. **Status: pending/unclaimed.**

## Current readiness assessment
- Backend/data safety: GREEN.
- Expense/history gates: GREEN.
- Planning gates: GREEN.
- Flow cache parity/security: GREEN.
- Classification cache consistency: GREEN.
- Document lifecycle/change-summary backend: GREEN.
- Documentary expense lens: GREEN by backend QA; visual authenticated check pending.
- Card-history coverage lens: GREEN by backend QA; visual authenticated check pending.
- Small-write performance architecture: materially improved.
- Latest candidate Pages deployment: GREEN on exact current candidate SHA.
- Final candidate parser/static smoke: GREEN via read-only CI on exact current candidate SHA.
- Historical card recovery: INCOMPLETE by design where source evidence is insufficient; no inference permitted.
- CIPÓ Condomínio/Consórcio documentary gaps: OPEN and explicitly preserved.
- Real authenticated visual E2E: PENDING.
- Visual homologation of Cartões/Planejamento/Atualizações/Despesas candidate: PENDING.
- Publish readiness for replacing `index.html`: NOT AUTHORIZED / NOT DONE.

## Trigger to ask user to look again
Do not ask the user to perform basic QA. The next look should happen only after the maximum available authenticated/browser checks are exhausted for the isolated candidate and no data/financial gate regression exists.

Until then:
- continue backend/performance/recovery/UX work autonomously;
- keep v136 as fallback;
- preserve all blocked documentary gaps explicitly;
- never certify historical category/merchant/reversal data by inference;
- never claim authenticated visual E2E unless actually performed.
