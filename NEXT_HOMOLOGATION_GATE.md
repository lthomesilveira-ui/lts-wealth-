# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and immutable checkpoints.

## Current deployed baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation URL: `homologacao.html`.
- Fixed homologation currently targets **v143**.
- v143 exposure main SHA: `a86b7cffe909098d65fcaad849800316c13dab3a`.
- Post-switch exact-SHA Pages run `33402028275`: SUCCESS.
- Post-switch exact-SHA candidate-smoke run `33402029074`: SUCCESS.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## Why v144 exists
User material homologation of v143 found a P0 regression specifically in Atualizações:
- the earlier assisted-classification model no longer visibly presented suggestion + public research/evidence + confidence percentage;
- the layout was visually loose, with excessive blank space and weak hierarchy.

This is corrective work, not a new financial rule.

## v144 corrective package evidence
Current branch: `v144-updates-classification-layout`.
Current green head: `f7cd162062406c2e1e37328883ca9586cc0374a8`.
Stable product-host commit: `01b15f5e382939851086c67515b5ecff38fbcef1`.

Architecture:
- v144 outer candidate preserves the inherited v142/v143 product chain.
- The deepest inherited product runtime remains v143 by design.
- `wip35-v144-lexical-bridge.js` exposes the base lexical `D/V` state only inside that same deepest realm; no financial rule or writer changes.
- `wip35-v144-updates-layout.js` is a post-render layout/classification layer and does not replace `w.atualizacoes`.
- Existing `cardClassificationUpdates` / `expenseClassificationUpdates` helpers and save handlers are preserved.

Branch run `33412827358`: SUCCESS.
- Static deep-runtime hosting/layout: PASS.
- Inherited button contract audit: PASS.
- Updates smoke desktop 1440×1000: PASS.
- Updates smoke mobile 390×844: PASS.
- Full ownership/navigation desktop: PASS.
- Full ownership/navigation mobile: PASS.
- Zero root overflow and zero console/page errors.

Updates-specific evidence proven:
- classification first;
- `Sugestão + pesquisa + % de confiança, item por item`;
- history/public research/confidence/manual-confirmation methodology;
- `Restaurantes` suggestion visible in synthetic Gula-like evidence;
- `83% sugestão`;
- `99% identificação`;
- ambiguous marketplace `91% identificação`;
- research/evidence visible;
- two preserved save controls;
- secondary sections collapsed;
- duplicated v143 evidence panel suppressed.

This is synthetic/unauthenticated browser composition evidence. No backend financial write is executed. It is **not authenticated visual E2E**.

## Audited Planning conclusion — immutable unless new evidence/decision
- first management point: **08/01/2027**;
- FGTS request-by: **09/12/2026**;
- documentary FGTS 18/08/2026: **R$17.509,05**;
- existing accrual model: **R$3.700/mês**;
- projected request-date FGTS: **R$32.309,05**;
- worst balance before contingency: **-R$21.046,80**;
- worst balance after planned contingency: **+R$11.262,25**;
- first uncovered gap through 28/02/2027: none.

Interpretation: January is a liquidity-management point covered by the already-modeled D+30 FGTS contingency if requested on time. It is not evidence of real patrimonial insufficiency.

## Final backend evidence
Fingerprint remains `85a1b60816a5b84dfe3b41341ed27948`.
- v14: 24 suites / 293 checks PASS.
- v15: 5 / 67 PASS.
- v16: 2 / 19 PASS.
- v17: 4 / 32 PASS.
- staged total: **35 suites / 411 checks PASS**.
- supplemental v143 read-model QA v2: **16/16 PASS**.
No v144 backend/financial writer change occurred, so these rules are inherited unchanged.

## Open invariants / blockers retained
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only.
- C6 Aug/2024 R$66,70 detail gap remains explicit.
- Mastercard/Visa documentary gaps remain open; no inferred purchase detail.
- CIPÓ consortium delta R$303,60, overlap/date ambiguity and condominium formula/cut remain unresolved; no post-2029 TR fabrication.
- Volvo exact trim/km remains required before valuation refinement.
- Classification ambiguity still requires user confirmation when evidence does not close.
- Guided document association UI remains open.
- Liquidity cancellation/reversal semantics remain append-only/auditable design work.
- Open Finance provider/pricing/SLA/bank coverage remains open; no consent/spend without explicit user decision.
- Real authenticated visual E2E remains pending/unclaimed.

## Gate from here to user access
1. Freeze v144 evidence + synchronize canonical backlog/gate/handoff.
2. Keep legacy candidate-smoke intact and extend the static button census to include v144; run both legacy and v144 workflows on the freeze branch.
3. Open a normal PR from `v144-updates-classification-layout` to `main`; no force.
4. Merge only with expected head SHA.
5. On the exact integrated `main` SHA require:
   - v144 Updates/full-browser smoke SUCCESS;
   - legacy candidate-smoke SUCCESS;
   - Pages SUCCESS;
   - protected `index.html` blob still exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
   - fixed homologation manifest still v143.
6. In a separate controlled exposure commit, switch `homologacao-current.json` to `wip35-v144-candidate.html` with `promotion_status: not_promoted`.
7. On that exact exposure SHA require v144 smoke + candidate-smoke + Pages SUCCESS and reconfirm the public index blob.
8. Only then tell the user **Pode acessar** and direct first inspection to Atualizações at the fixed `/homologacao.html` URL.
9. Public `index.html` remains untouched until explicit user approval.
