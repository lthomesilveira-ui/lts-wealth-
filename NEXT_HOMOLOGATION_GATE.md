# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a new candidate. This file is operational and stays aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current public baseline
- WIP35-v136 remains the canonical public fallback at `index.html`.
- WIP35-v139 is served only as isolated candidate `wip35-v139-candidate.html`; it does not replace `index.html`.
- GitHub Pages deployment for the isolated v139 file succeeded on run 33270135266 / commit `c233adf6...`.
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

### Atualizações / writes
- Document lifecycle is persisted and operational resolutions append lifecycle evidence.
- Central currently exposes 12 visible items / 10 actionable.
- Semantic matcher was optimized with 5,224/5,224 exact row parity; current matcher benchmark ~0.314 s versus ~2.65 s old path.
- Semantic queue base benchmark ~0.88 s versus ~2.45 s before optimization.
- Confirmation writes are economically invariant and now use targeted refresh (`card_operating` + `updates`), ~2.93 s versus ~18.83 s full refresh with exact affected-block parity.
- Manual invoice update uses a financial targeted refresh; affected 9 modules are exact-parity versus full refresh.
- No small browser write remains coupled to the global operational refresh.

### Planejamento
- Planning executive is now live single-pass, without relying on the future Flow cache internally.
- JSON output is exactly equal to the prior implementation in the tested annual horizon.
- Benchmark ~3.96 s versus ~9.84 s before optimization.
- Planning QA: 23/23 PASS.
- First gap, worst gap, three episodes, FGTS D+30 and v131 counterfactual remain unchanged.

### Financial/data gates after performance batch 2
- Expense v9: 19/19 PASS.
- Expense v10: 18/18 PASS.
- Core financial regression: 15/15 PASS.
- Planning QA: 23/23 PASS.
- Operational cache health: PASS.
- Expense historical total: R$ 8,623,752.53.
- Full operational refresh improved from ~24.66 s to ~18.77 s; still too slow for small actions, therefore small writes now use targeted paths.
- Immutable evidence: `backups/wip35-v139-performance-batch2-2026-08-29.json`.

## Minimum package before next user look
1. Despesas critical timeout architecture fixed and financial gates green. **Status: technically green; real authenticated browser retest still pending.**
2. Cartões and Planejamento materially redesigned from rejected report-like layouts. **Status: implemented in v138/v139; visual approval pending.**
3. Atualizações lifecycle/actionability materially clearer and small-write latency reduced. **Status: implemented; authenticated click-path validation pending.**
4. Fluxo candidate future latency materially reduced with exact financial parity. **Status: implemented; authenticated browser retest pending.**
5. Parser/static smoke for the effective isolated candidate must remain green after any candidate-file change. **Status: no new candidate-file change in performance batch 2; prior v139 file remains isolated.**
6. Public v136 fallback remains untouched. **Status: preserved.**
7. Do not claim authenticated visual E2E unless actually performed. **Status: pending/unclaimed.**

## Current readiness assessment
- Backend/data safety: GREEN.
- Expense/history gates: GREEN.
- Planning gates: GREEN.
- Flow cache parity/security: GREEN.
- Small-write performance architecture: materially improved.
- Historical recovery: continues in parallel; current File Library failure is technical and does not authorize inference.
- Real authenticated visual E2E: PENDING.
- Visual homologation of Cartões/Planejamento/Atualizações/Despesas candidate: PENDING.
- Publish readiness for replacing `index.html`: NOT AUTHORIZED / NOT DONE.

## Trigger to ask user to look again
Do not ask the user to perform basic QA. The next look should happen only after the maximum available authenticated/browser checks are exhausted for the v139 isolated candidate and no new parser/smoke/data gate regression exists.

Until then:
- continue backend/performance/recovery work autonomously;
- keep v136 as fallback;
- preserve all blocked documentary gaps explicitly;
- never certify historical category/merchant/reversal data by inference.
