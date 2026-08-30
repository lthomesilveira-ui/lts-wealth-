# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect a candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md` and `HISTORICAL_RECOVERY_LOG.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged and not user-approved; effective visual baseline remains v135.
- v139 real authenticated boot failed; synthetic-readiness smoke retired.
- v140 introduced lexical bridge/early Flow-v4 routing; user confirmed real mobile boot.
- Current material candidate: `wip35-v141-candidate.html`.
- Current document-outcome candidate code/smoke head: `3afecdccfc480b8719bc11fd7170671f8d30b3c1`.
- Fixed homologation URL: `homologacao.html`; it resolves the current validated candidate through `homologacao-current.json` with `no-store` + timestamp cache busting.
- Fixed-entrypoint gate head: `ff3107947cdf8dc34ea7dcddc284c07ec6daad86`.
- Public fallback exact blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Real authenticated visual E2E: PENDING / NOT CLAIMED.

## Browser / serving evidence
- Candidate smoke run `33323180487`: SUCCESS on the document-outcome head; parser, Chromium desktop/mobile and evidence upload green.
- Same-head GitHub Pages run `33323179920`: SUCCESS.
- Fixed homologation entrypoint candidate-smoke run `33325382391`: SUCCESS; entrypoint validation, parser and Chromium desktop/mobile all green.
- Fixed homologation entrypoint same-head Pages run `33325382173`: SUCCESS.
- Chromium chain v141→v140→v139→v138→v137→v136.
- Runtime requires lexical bridge, early Flow-v4, visible v141 ownership, current CIPÓ/backup/shared-flow/document-outcome extension stamp, Flow UX marker, document-outcome marker, zero new errors and no root overflow; no synthetic D/S/render readiness.
- `homologacao.html` is the user-facing homologation entrypoint; future candidate version changes update the manifest rather than requiring a new user URL.
- v141 Flow UX removes the duplicate internal `Hoje` button while retaining the period chip and restores subtle balance-cell emphasis on desktop/mobile.
- v141 Atualizações adds evidence-derived document outcomes without replacing `O que mudou`.
- Evidence is non-authenticated browser composition/runtime smoke, not authenticated visual E2E.

## Backend readiness / gates
- Readiness v7: **51/51 PASS**.
- Core financial regression: **15/15 PASS**.
- UI shape 17/17; UI consistency 7/7; writer→refresh 9/9.
- Browser ACL: anon exposure 0.
- Expense v9 19/19; Expense v10 18/18; Planning 23/23; Wealth 18/18; classification cache 5/5; document lifecycle 17/17; documentary expense lens 4/4.
- Candidate UI extension QA 6/6; shared-Flow exact parity 6/6; backup snapshot 13/13; CIPÓ documentary coverage 6/6.
- Dynamic card-history coverage QA v2: **8/8 PASS**.
- Historical validation registry QA v4: **16/16 PASS**, **68 open Mastercard cycles 2019–2025** tracked internally.
- Global historical fallback inventory QA v1: **5/5 PASS**; 31 instrument×year blocks, 314 fallback rows / R$2,650,846.36; 24 aggregate-only documentary gaps remain explicit.
- Document outcome semantics QA: **4/4 PASS**; browser ACL QA: **4/4 PASS**.
- Document association QA: **5/5 PASS**; classification triage QA: **9/9 PASS**; CIPÓ open-blocker QA: **6/6 PASS**.
- Effective-history QA v2: **PASS — 2,030 days / 147 months exact**.
- FIX86 legacy/transversal guardrails QA v4: **10/10 PASS**.
- Extended heavy pre-homologation gate **v12 = 268/268 PASS across 22 suites**.

## Performance / refresh
- Despesas cache read ~0.1s; Flow cached 33d ~10ms; classification queue within guard.
- Operational refresh v3 computes one annual Flow v12 reused by short Flow, Planning, Dashboard and scenarios; outputs proved JSON+MD5 exact against prior motors.
- Warm daily refresh ~20.2s → ~11.8s.
- Simulated stale-expense rollover ~14.06s including expense-cache rebuild; transaction rolled back after benchmark.
- Day rollover refreshes stale Despesas cache; browser product v9/api39 uses operational v3.

## v141 material package
### Atualizações / documents
- 25 checks auditable: 6 near/current first, 4 distant collapsed, 15 covered/monitoring collapsed; classification workstream separate.
- Document approval path explicitly gated: Inbox/manual review creates no financial write before approval; reviewed application is the write path.
- New outcome states: **Alterou / Sem alteração / Precisa decisão / Processando / Erro**. They are read-only presentation derived from lifecycle/change-summary evidence; `Sem alteração` never creates a launch and `Precisa decisão` remains pending until explicit review.
- Browser reads outcomes only through `auth.uid()` scoped RPC; anon blocked and arbitrary-user internal contracts private.
- Explicit file association contract forbids filename/similarity inference; card/bank association requires explicit identity + competence, financing requires explicit commitment + as-of date.
- Parser/Chromium/Pages are green for the new outcome marker.
- Remaining blocker: real authenticated save/refresh/self-heal/`O que mudou`/outcome visual behavior.

### Fluxo / FIX86
- Flow v12 financial truth; browser Flow v4 authenticated/cache-backed; early routing proven.
- Historical parity exact through 2025; baseline frozen; stale/superado anchor excluded; scenarios read-only; Flow edits/cancel/split append overlays/audit rather than destructively rewriting source facts.
- v141 Flow UX single-`Hoje`/balance-emphasis package is parser/Chromium/Pages green.
- Remaining blocker: real authenticated visual inspection and real-session latency.

### Despesas
- Historical economic invariant remains **R$8,623,752.53**.
- After 2022 historical recovery analytical cache has **3,860/3,860 rows** with zero mismatch; increased category detail changed row cardinality but not economic total.
- Executive comparisons and documentary merchant/counterparty lens remain present without merchant fabrication.
- Remaining blocker: visual inspection.

### Cartões / historical evidence
- 3 open cycles; 153 historical monthly points.
- Certified historical allocation: **38 cycles / 650 rows / R$885,855.19**.
- Aggregate fallback: **314 rows / R$2,650,846.36**.
- Global inventory: **31 instrument×year fallback blocks**; 7 registry-tracked, 24 aggregate-only. Two non-Mastercard P1 blocks are explicit: Visa 2017 R$126,681.76 and Visa Infinite Itaú 2024 R$112,253.01.
- Latest File Library pass confirms the 12 Visa 2017 settlement totals and Visa Infinite Itaú 2024 monthly settlement totals, but not category composition; no promotion.
- Visa Infinite Itaú 2025 = 12/12 certified.
- Mastercard 2025: Mar/Apr/May/Jun/Aug/Nov certified; Jan/Feb/Jul/Oct candidate-partial; Sep/Dec documentary-blocked.
- Mastercard 2024: Mar/May/Aug/Sep/Oct/Dec certified; Jan/Feb/Apr/Jun/Jul/Nov settlement proven but composition missing.
- Mastercard 2023: 12 ledger-only cycles totaling R$496,689.05; independent matrix missing.
- Mastercard 2022 certified exact: Apr R$11,910.91; Jun R$10,185.54; Jul R$13,486.29; Oct R$28,374.06. Eight months remain explicitly tracked; Jan–Mar fragmented settlements are not assumed to be one invoice. Dec/2022 source rows were re-found, but the complete signed tail is still truncated, so no certification.
- Mastercard 2021: 12 ledger-only months / R$116,458.47; all 12 fragmented.
- Mastercard 2020: 12 ledger-only months / R$99,107.08; 10 fragmented.
- Mastercard 2019: 12 ledger-only months / R$164,402.94; 5 fragmented.
- Internal registry tracks **68 open Mastercard cycles 2019–2025** and prevents accidental promotion.
- C6 Aug/2024 individual-detail gap R$66.70 remains explicit.

### Planejamento
- 5 layers / 3 negative episodes; first real gap 08/01/2027; worst R$-21,046.80; FGTS request-by 09/12/2026; FGTS remains D+30 contingency; v131 12/01 counterfactual preserved.
- Remaining blocker: visual homologation of rationale/cockpit.

### Patrimônio / CIPÓ
- Market estimate, documentary debt and equity separate.
- CIPÓ evidence-only coverage: source aggregates R$1,465,713.29; conservative capped documented floor R$569,196.83; no promotion.
- 32 CIPÓ card aggregates remain pending; Consórcio Itaú R$303.60 and Condomínio formula/cut unresolved.
- Volvo provisional pending trim/km evidence.

### Configurações / backup
- Private daily automatic snapshot active via `pg_cron` at 06:15 UTC / 03:15 BRT.
- Idempotent by user/date, hashed/private; browser receives metadata only; restore unchanged.

## Classification
- 48 groups / 53 lines; 62 category options; safe suggestions 0; 26 effective August lines remain genuine human-review gaps.
- Objective triage may order human review by value/share/repetition but proposes no category.
- No auto-classification from merchant appearance.
- Real authenticated save→cache→UI click pending/unclaimed.

## Open Finance
- Provider-neutral staging/writer v2; architecture QA 14/14; no browser direct canonical write.
- Pluggy first sandbox candidate; Belvo benchmark; Klavi alternative.
- No account/token/consent/commercial commitment exists; provider/consent/spend requires explicit user decision.

## Minimum package before next user look
1. Public fallback unchanged — GREEN.
2. Real-user boot regression fixed — GREEN on real mobile v140.
3. Candidate parser + Chromium without synthetic readiness — GREEN.
4. Visible v141 ownership/current extension + Flow UX + document-outcome markers — GREEN.
5. Fixed homologation URL + manifest cache-busting + target existence gate — GREEN.
6. Pages same verified fixed-entrypoint head — GREEN.
7. Readiness/core/ACL/current financial gates — GREEN.
8. Historical/FIX86/global fallback/document-outcome/document-association/classification-triage/CIPÓ-open-blocker contracts — GREEN; heavy v12 268/268.
9. Material v141 UX package — IMPLEMENTED; user approval pending.
10. Historical/classification/CIPÓ unresolved items explicit/non-promoted — GREEN as guardrail.
11. Real authenticated visual E2E — PENDING / NOT CLAIMED.
12. Promotion to `index.html` — NOT AUTHORIZED / NOT DONE.

Continue autonomous technical and historical evidence work while it can materially reduce risk. Ask the user only when the remaining blocker is genuinely visual/authenticated behavior or a real financial/classification/commercial decision.
