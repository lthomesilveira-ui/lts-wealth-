# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect a candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md` and `HISTORICAL_RECOVERY_LOG.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged and not user-approved; effective user visual baseline remains v135.
- v139 real authenticated boot failed on user evidence; synthetic-readiness smoke was retired.
- v140 introduced lexical bridge/early Flow-v4 routing; user confirmed v140 opened in a real mobile session.
- Current material candidate: `wip35-v141-candidate.html`.
- Latest candidate code/smoke head: `5d67b2e2d719c309d9159e078d3c2e681e6ab361`.
- Public fallback exact blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Real authenticated visual E2E: PENDING / NOT CLAIMED.

## Browser / serving evidence
- Candidate smoke run `33311276232`: SUCCESS.
- Candidate job `99256663902`: SUCCESS.
- Same-head GitHub Pages build/deploy: SUCCESS; deploy check `99256687084`, Pages workflow run `33311275717`.
- Chromium chain: v141 → v140 → v139 → v138 → v137 → v136.
- No synthetic `window.D/window.S/render` readiness.
- Runtime requires lexical bridge v140, real lexical Supabase client, early Flow-v4 bridge, top candidate v141, visible v141 brand label, current `wip35-v141-updates-cipo-backup-shared-flow` stamp, zero new browser errors and no root overflow.
- Parser requires current CIPÓ documentary and backup-status markers while preserving fallback blob lock.
- Evidence is non-authenticated browser composition/runtime smoke, not authenticated visual E2E.

## Backend readiness / gates
- `lts_candidate_fast_readiness_qa_v7`: 51/51 PASS.
- Core financial regression: 15/15 PASS.
- UI shape: 17/17 PASS.
- UI consistency: 7/7 PASS.
- Writer→refresh/safety: 9/9 PASS.
- Browser ACL: 48 `lts_browser_*`; anon exposure 0; 39 authenticated exposures.
- Expense v9 19/19; Expense v10 18/18; Planning 23/23; Wealth 18/18; classification cache 5/5; document lifecycle 17/17; documentary expense lens 4/4; card-history coverage 5/5.
- Candidate UI extension QA: 6/6 PASS.
- Shared-Flow exact parity: 6/6 PASS.
- Backup scheduled snapshot QA: 13/13 PASS.
- CIPÓ documentary coverage QA: 6/6 PASS.
- Historical validation registry QA: 7/7 PASS.
- Extended heavy pre-homologation gate v3: **213/213 PASS across 15 suites**.

## Performance / refresh
- Despesas cache read ~0.1s; Flow cached 33d ~10ms; classification queue ~1.5s within permanent guards.
- Operational refresh v3 computes one annual Flow v12 and reuses it for short Flow, Planning, Dashboard and cashflow scenarios.
- Each shared-Flow output is JSON + MD5 exact versus its previous motor.
- Warm daily operational refresh reduced from ~20.2s to ~11.8s.
- Simulated day rollover with stale Despesas cache ~14.06s including ~2.82s expense-cache rebuild; transaction rolled back after benchmark.
- Day rollover now refreshes Despesas cache when stale, preventing product/Flow and Despesas from being on different dates.
- Browser product v9 / api 39 uses operational refresh v3.

## v141 material package
### Atualizações
- 25 checks remain auditable: 6 near/current actions shown first, 4 distant coverage checks collapsed, 15 covered/monitoring checks collapsed.
- 48 classification groups remain separate from operational action count.
- Remaining blocker: real authenticated save/refresh visual behavior.

### Fluxo
- Flow v12 financial truth; browser Flow v4 cache-backed/authenticated-only.
- Early v4 routing is proven at runtime.
- Remaining blocker: real authenticated visual inspection and real-session latency.

### Despesas
- Historical invariant R$8,623,752.53 / 3,767 effective rows remains exact.
- Executive comparisons and documentary merchant/counterparty lens remain present without merchant fabrication.
- Remaining blocker: visual inspection.

### Cartões / historical evidence
- 3 open cycles; 153 historical monthly points.
- 34 certified historical allocation cycles / 553 rows / R$821,898.39.
- Visa Infinite Itaú 2025 = 12/12 certified.
- Mastercard Itaú 2025 certified Mar/Apr/May/Jun/Aug/Nov.
- Mastercard Itaú 2025 Jan/Feb/Jul/Oct remain candidate-partial; full signed tails missing.
- Mastercard Itaú 2025 Sep/Dec remain documentary-blocked.
- Mastercard Itaú 2024 certified Mar/May/Aug/Sep/Oct/Dec; Jan/Feb/Apr/Jun/Jul/Nov have exact payment identity but missing category composition.
- Internal validation registry persists all 12 open months and prevents accidental promotion; QA 7/7 PASS.
- Latest File Library targeted retrieval failed technically before content; no inference or certification resulted.

### Planejamento
- 5 liquidity layers / 3 negative episodes.
- First real gap 08/01/2027; worst balance R$-21,046.80; FGTS request-by 09/12/2026; FGTS remains D+30 contingency.
- v131 12/01 counterfactual preserved.
- Remaining blocker: visual homologation of rationale/cockpit.

### Patrimônio / CIPÓ
- Market estimate, documentary debt and equity remain separate.
- New CIPÓ documentary coverage is evidence-only: source card aggregates R$1,465,713.29; conservative capped documented floor R$569,196.83; no status promotion.
- 32 CIPÓ card aggregates remain pending; Consórcio Itaú R$303.60 and Condomínio formula/cut remain unresolved.
- Candidate displays documentary progress separately from reconciliation closure.
- Volvo remains provisional pending trim/km evidence.

### Configurações / backup
- Private daily automatic snapshot is active through internal `pg_cron` at 06:15 UTC / 03:15 BRT.
- Snapshot is idempotent by user/date, hashed and private; browser roles cannot read payload.
- UI reads metadata only through authenticated `lts_browser_backup_status_v1`.
- Restore behavior remains unchanged.

## Classification
- Current review 48 groups / 53 lines; 62 category options; safe suggestion groups 0.
- 26 economically effective August lines remain human-review gaps.
- No auto-classification from merchant appearance.
- Real authenticated save→cache→UI click remains pending/unclaimed.

## Open Finance
- Provider-neutral staging/writer v2 exists; architecture QA 14/14 PASS, no browser policy/direct canonical write.
- Pluggy first sandbox candidate; Belvo benchmark; Klavi alternative.
- No account/token/consent/commercial commitment exists. Provider/consent/spend needs explicit user decision.

## Minimum package before next user look
1. Public fallback unchanged — GREEN.
2. Real-user boot regression fixed — GREEN on real mobile v140.
3. Candidate parser + Chromium without synthetic readiness — GREEN.
4. Visible v141 ownership + current extension stamp — GREEN.
5. Pages same verified candidate head — GREEN.
6. Readiness/core/financial/ACL gates — GREEN.
7. Heavy gate including shared Flow, backup, CIPÓ evidence and historical registry — GREEN 213/213.
8. Material v141 UX package — IMPLEMENTED; user approval pending.
9. Historical/classification/CIPÓ unresolved items explicit and non-promoted — GREEN as guardrail.
10. Real authenticated visual E2E — PENDING / NOT CLAIMED.
11. Promotion to `index.html` — NOT AUTHORIZED / NOT DONE.

Continue autonomous technical and historical evidence work while it can materially reduce risk. Ask the user only when the remaining blocker is genuinely visual/authenticated behavior or a real financial/classification/commercial decision.
