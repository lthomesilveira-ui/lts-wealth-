# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation URL: `homologacao.html`.
- v144 integrated-main SHA: `b0d23e35be1d5d27400268a36bb3562395bb3513`.
- Integrated-main v144 smoke `33414249775`: SUCCESS.
- Integrated-main legacy candidate-smoke `33414249873`: SUCCESS.
- Integrated-main Pages `33414248379`: SUCCESS.
- Before the current exposure commit, fixed homologation still targeted v143.
- Current exposure package switches `homologacao-current.json` to **v144** with `promotion_status: not_promoted`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## Why v144 exists
User material homologation of v143 found a P0 regression specifically in Atualizações:
- the earlier assisted-classification model no longer visibly presented suggestion + public research/evidence + confidence percentage;
- the layout was visually loose, with excessive blank space and weak hierarchy.

This is corrective work, not a new financial rule.

## v144 package evidence
Architecture:
- v144 outer candidate preserves the inherited v142/v143 product chain;
- deepest inherited product runtime remains v143 by design;
- lexical-state bridge exposes existing `D/V` state only inside that same runtime;
- post-render Updates layer does not replace `w.atualizacoes`;
- existing `cardClassificationUpdates` / `expenseClassificationUpdates` helpers and save handlers remain in use;
- no direct backend financial writer was introduced.

Branch/freeze evidence:
- product host commit `01b15f5e382939851086c67515b5ecff38fbcef1`;
- branch run `33412827358`: SUCCESS;
- freeze head `b0d23e35be1d5d27400268a36bb3562395bb3513`;
- freeze run `33413763757`: SUCCESS.

Updates-specific evidence proven in desktop 1440×1000 and mobile 390×844:
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
- duplicated v143 evidence panel suppressed;
- zero root overflow and zero console/page errors.

Full inherited ownership/navigation smoke also passes desktop/mobile for Dashboard, Atualizações, Fluxo Diário, Despesas, Cartões, Patrimônio and Planejamento; `Liquidez detalhada` remains the visual planning label.

This remains synthetic/unauthenticated browser composition evidence. It is **not authenticated visual E2E**.

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

## Final backend evidence inherited unchanged
Fingerprint `85a1b60816a5b84dfe3b41341ed27948`.
- v14: 24 suites / 293 checks PASS.
- v15: 5 / 67 PASS.
- v16: 2 / 19 PASS.
- v17: 4 / 32 PASS.
- staged total: **35 suites / 411 checks PASS**.
- supplemental v143 read-model QA v2: **16/16 PASS**.
No v144 backend/financial writer change occurred.

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

## Remaining gate to user access
1. Complete the current exposure commit switching `homologacao-current.json` to `wip35-v144-candidate.html` with `promotion_status: not_promoted`.
2. On that exact exposure SHA require:
   - v144 Updates/full-browser smoke SUCCESS;
   - legacy candidate-smoke SUCCESS;
   - Pages SUCCESS;
   - protected `index.html` blob still exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
   - manifest resolves to v144.
3. Only then tell the user **Pode acessar agora** and direct first inspection to Atualizações at the fixed `/homologacao.html` URL.
4. Public `index.html` remains untouched until explicit user approval.
