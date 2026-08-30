# LTS Wealth — Next Homologation Gate

Purpose: define the minimum evidence-backed package required before asking the user to inspect a candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`; unchanged and not user-approved.
- User effective visual baseline: v135.
- v139 real authenticated boot failed on the user's notebook, stuck on `Carregando seu LTS…`.
- Root cause: v136 core state is lexical (`let`/`const`), while candidate layers incorrectly treated it as `window.*`; former synthetic-readiness Chromium could therefore false-green the path.
- v140 introduced the real lexical bridge without changing public v136. User confirmed v140 opened in a real mobile session.
- Current material candidate: `wip35-v141-candidate.html`.
- Latest reinforced browser-smoke head: `e7a69758bc4f15b7456e7ab2af4b30d6f40c1f29`.
- Public fallback exact blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Real authenticated visual E2E remains PENDING / NOT CLAIMED.

## Browser / serving evidence
- Candidate smoke run **33282949795**: SUCCESS.
- Pages deployment on the same head: SUCCESS.
- Chromium chain: v141 → v140 → v139 → v138 → v137 → v136.
- No synthetic `window.D/window.S/render` readiness is used.
- Runtime smoke now requires both the v140 lexical bridge and `S.__lts_v140_flow_v4_bridge=true` before PASS.
- Parser/Node syntax, v137/v138/v139/v141 injections and root-width checks are green.
- This is a non-authenticated browser composition/runtime-routing smoke, not authenticated visual E2E.

## Readiness / data / security
- `lts_candidate_fast_readiness_qa_v7`: **51/51 PASS**.
- Underlying UI shape contract: **17/17 PASS** against the real cached payload.
- UI internal consistency: **7/7 PASS**:
  - open-card total equals cycle sum;
  - card history month count equals monthly-array length;
  - Planning episode count equals episode array;
  - first gap summary equals first episode start;
  - Updates actionable summary closes to maintenance checks;
  - pending/actionable relationships remain valid.
- Writer→refresh/safety catalog contract: **9/9 PASS**:
  - classification patches effective expense cache and uses classification-scoped refresh;
  - manual invoice uses invoice-scoped refresh;
  - overdue transfer requires a complete neutral pair and uses confirmation-scoped refresh;
  - overdue event and card payment use confirmation-scoped refresh;
  - reconciliation requires an eligible candidate and uses Updates-scoped refresh.
- Browser RPC ACL: 48 `lts_browser_*` functions; anon exposure = 0.
- Latest latency sample: Despesas ~115 ms; Flow 33d ~10 ms; classification queue ~1.47 s.

## Financial/data invariants
- Core financial regression: **15/15 PASS** after current v141/v140 changes.
- Expense v9: 19/19 PASS.
- Expense v10: 18/18 PASS.
- Planning: 23/23 PASS.
- Wealth: 18/18 PASS.
- Classification cache: 5/5 PASS.
- Document lifecycle/change summary: 17/17 PASS.
- Documentary expense counterparty/merchant: 4/4 PASS.
- Card-history coverage: 5/5 PASS.
- Historical expense invariant remains R$8,623,752.53; effective expense cache remains exact 3,767/3,767 rows.

## v141 package
### Atualizações
- 25 maintenance checks remain fully auditable.
- v141 presents 6 near/current operational checks first.
- 4 distant 2030/2031 coverage checks are collapsed once, not duplicated.
- 15 covered/monitoring checks are collapsed.
- The 48 classification groups are a separate workstream and are not mixed into the headline operational-action count.
- Header/footer identify v141; inherited old-candidate badges are hidden; public v136 remains stated as fallback.
- Remaining blocker: real authenticated click/save/refresh visual validation.

### Fluxo Diário
- Financial truth remains Flow v12.
- Browser path is authenticated-only Flow v4 with exact cache parity.
- v140 now installs v1/v2/v3→v4 routing as soon as lexical `S` exists, before `D` finishes, removing first-load escape to old slow v3.
- Runtime CI now proves this bridge is installed.
- Remaining blocker: real authenticated visual/browser inspection of current Flow data.

### Despesas
- Timeout path remains replaced by exact-parity cache-backed read.
- Month/year/rolling analysis and documentary merchant/counterparty lens are present.
- Merchant detail is shown only from structured purchase evidence; category-only/recovered/aggregate history never fabricates merchant detail.
- Remaining blocker: real authenticated visual inspection.

### Cartões
- Current real payload: 3 open cycles; 153 historical monthly points.
- Historical evidence: 34 certified cycles; 553 allocation rows / R$821,898.39; 318 aggregate fallback rows / R$2,714,803.16; recovered C6 kept separate.
- Visa Infinite Itaú 2025: 12/12 certified.
- Mastercard 2025 certified Mar/Apr/May/Jun/Aug/Nov; Jan/Feb/Jul/Oct candidate-only; Sep/Dec blocked.
- Mastercard 2024 certified Mar/May/Aug/Sep/Oct/Dec; Jan/Feb/Apr/Jun/Jul/Nov pending.
- Latest Feb/2025 File Library retry failed technically before returning content; no new certification or inference.

### Planejamento
- Current payload: 5 liquidity layers; 3 negative episodes.
- Certified semantics: first real gap 08/01/2027; worst balance R$-21,046.80; FGTS request-by 09/12/2026 for the first gap; FGTS remains ~D+30 contingency, not automatic cash.
- v131 12/01 counterfactual remains preserved/explained.
- Remaining blocker: visual homologation of the cockpit/rationale.

### Patrimônio
- UI contract confirms named `wealth_executive.assets` object with explicit CIPÓ and Volvo objects.
- Market estimates, current documentary debt and future schedules remain separated.
- Remaining blocker: visual homologation; Volvo range remains provisional until trim/km evidence exists.

## Classification
- Current review: 48 groups / 53 lines across August and future September cycles; 62 category choices.
- Safe suggestion groups = 0. No auto-classification authorized.
- The 26 economically effective August lines remain genuine human-review gaps unless evidence changes.
- Real authenticated save→cache→UI click remains pending and unclaimed.

## CIPÓ unresolved evidence
- Condomínio formula/cut remains unresolved; duplicate-looking raw rows cannot be suppressed without full closure.
- Consórcio Itaú R$303.60 remains unresolved; overlap math alone cannot choose an invalid row.
- Post-2029 tail is TR-dependent and must never be treated as zero or fabricated exact.

## Open Finance
- Provider-neutral staging/writer v2 exists; architecture QA 14/14 PASS; no browser policy/direct canonical write.
- Pluggy remains first sandbox candidate; sandbox publicly available and operational limits documented; production price/SLA still commercial.
- Belvo current public Launch price is R$6,000/month; sandbox free; explicit C6 product equivalence remains to confirm.
- Klavi documents operational limits but public comparable production price/institution-product matrix/SLA remain to confirm.
- No account/token/consent/paid commitment exists. Real provider connection or spend requires explicit user decision.

## Minimum package before next user look
1. Public fallback unchanged. **GREEN.**
2. Real-user boot regression fixed. **GREEN on real mobile v140.**
3. Candidate parser + Chromium without synthetic readiness. **GREEN.**
4. Runtime early Flow-v4 bridge. **GREEN.**
5. Pages deployed on verified smoke head. **GREEN.**
6. Readiness shape/consistency/writer contracts. **GREEN 51/51.**
7. Core financial regression. **GREEN 15/15.**
8. Despesas/Fluxo performance regressions technically fixed. **GREEN internally.**
9. Cartões/Planejamento/Atualizações material UX. **IMPLEMENTED in v141; user approval pending.**
10. Historical/classification/CIPÓ gaps remain explicit without inference. **GREEN as guardrail.**
11. Real authenticated visual E2E. **PENDING / NOT CLAIMED.**
12. Promotion to `index.html`. **NOT AUTHORIZED / NOT DONE.**

Continue autonomous checks while they can materially reduce risk. Ask the user only when the remaining blocker is genuinely visual/authenticated behavior or a real financial/classification/commercial decision.

Latest immutable evidence:
- `backups/wip35-v141-readiness-ui-contract-batch11-2026-08-29.json`
- `backups/wip35-v141-writer-refresh-openfinance-batch12-2026-08-29.json`
