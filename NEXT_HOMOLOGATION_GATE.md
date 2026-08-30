# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and the latest immutable checkpoint.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged and not user-approved; effective prior visual baseline remains v135.
- Public fallback protected blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed user homologation URL: `homologacao.html`.
- `homologacao-current.json` still intentionally points to validated v141 while v142 finishes its final coherent package.
- Current integrated main: `4eded532ad90a11ed73119edf997ee58246f2f46`.
- Round 3 final-polish branch: `v142-round3-final-polish`; current smoke head `21a797e47484c4caaafcd7e9a56c75d4ae5cdd5c`.
- Real authenticated visual E2E: PENDING / NOT CLAIMED.
- Promotion to `index.html`: NOT AUTHORIZED / NOT DONE.

## P0 financial conclusion closed
The Excel→current Planning discrepancy is no longer an unresolved blocker for January/2027.

Audited current semantics:
- first management point: **08/01/2027**;
- FGTS request-by under the user-confirmed ~D+30 access rule: **09/12/2026**;
- conservative FGTS amount existing on request date: **R$32.309,05**;
- worst balance before contingency: **R$-21.046,80**;
- worst balance after conservative planned FGTS: **R$+11.262,25**;
- first uncovered gap through 28/02/2027: **none**.

Therefore Dashboard/Planning must describe January as a **liquidity management point covered by a D+30 contingency if requested on time**, not as “real lack of money”. Planning bridge QA: **19/19 PASS**.

## v142 integrated package through Round 2
Main `4eded532ad90a11ed73119edf997ee58246f2f46` now contains:
- restored Claude-era executive Dashboard/cockpit;
- reconciled Planning renderer with the FGTS D+30 bridge;
- executive-first Patrimônio read model;
- compact Atualizações + obvious natural-language launch surface;
- reviewed resgate/aplicação UI v2 with explicit preview and approval;
- hardened value parser (`5 mil`, `R$ 5.000`, `5000`, `3k`, `R$ 1.250,50`);
- Flow v13 effective bank↔asset movement propagation;
- no change to public fallback or homologation manifest.

Main post-merge evidence:
- candidate-smoke run `33342589464`: **SUCCESS**;
- Pages run `33342589186`: build/deploy/report checks **SUCCESS** on the same SHA;
- desktop 1440×1000: PASS;
- mobile 390×844: PASS;
- zero new console/page errors;
- zero root overflow;
- fixed homologation entrypoint still targets v141.

Important limit: browser smoke is non-authenticated composition/runtime evidence. It is not authenticated visual E2E.

## Round 3 — final action hierarchy / density
Round 3 is intentionally a polish layer, not a financial-model rewrite.

Implemented on `v142-round3-final-polish`:
- `Resolver agora` summary immediately below the natural-language launch surface;
- separate counts/shortcuts for current maintenance, classification review and documents requiring a decision;
- action buttons scroll directly to the relevant queue instead of forcing the user to hunt lower in the page;
- distant coverage and healthy checks remain available for audit but do not dominate the primary view;
- tighter classification/document/maintenance density;
- mobile-specific compact rows and no deliberate horizontal expansion;
- Dashboard/Patrimônio micro-density cleanup without changing financial values or read models.

Round 3 smoke head: `21a797e47484c4caaafcd7e9a56c75d4ae5cdd5c`.
Current branch smoke run: `33342704158` — must be SUCCESS before integration.

## Financial / backend gates
Heavy and delta gates are deliberately staged to avoid timeout-prone nesting.

Heavy gate v14:
- **24 suites / 293 checks / PASS**.

Delta gate v15:
- liquidity writer v2: 10/10;
- transactional rollback: 15/15;
- liquidity read-path: 12/12;
- browser liquidity ACL: 17/17;
- Dashboard cockpit: 13/13;
- **5 suites / 67 checks / PASS**.

Delta gate v16:
- refresh-v2 contract: 11/11;
- real transactional application across Flow v13 / Planning / Dashboard / Patrimônio / future cache with full rollback: 8/8;
- **2 suites / 19 checks / PASS**.

Current staged evidence total: **31 suites / 379 checks PASS**.

This proves code/data contracts, ACL and transaction semantics; it does not prove authenticated visual E2E or user homologation.

## Liquidity movement status
Application/redemption is now a reviewed everyday path rather than a hidden backend primitive.

Proven:
- equal-and-opposite bank ↔ cash-investment asset legs;
- economic effect zero;
- excluded from income/expense;
- idempotent;
- explicit preview + explicit approval required;
- over-redemption rejected against effective asset balance;
- same-snapshot-day guard against documentary double count;
- Flow v13 / Planning / Dashboard / future cache / effective Wealth propagation;
- browser wrappers auth.uid scoped, anon blocked;
- real transactional QA is fully rolled back; no QA financial rows persist;
- browser parser self-tests cover common pt-BR amount formats.

Still open before calling this a mature repairable writer:
- authenticated save→refresh→visible-result inspection in a real session;
- explicit cancellation/repair UX semantics for a previously confirmed liquidity movement.

Those two items do not authorize inventing or silently modifying any financial movement.

## Existing guardrails that remain mandatory
- Historical expense economic invariant: **R$8.623.752,53**.
- Analytical historical cache: 3.860/3.860, zero mismatch.
- Historical effective parity: 2.030 days / 147 months exact through 2025.
- FIX86 transversal guardrails remain mandatory.
- 38 certified card cycles / 650 categorical rows / R$885.855,19.
- Aggregate historical fallback 314 rows / R$2.650.846,36 remains non-promoting.
- Mastercard/Visa/C6 documentary gaps remain explicit; never infer category composition.
- C6 Aug/2024 R$66,70 remains unresolved.
- CIPÓ Consórcio Itaú R$303,60 remains unresolved.
- CIPÓ Condomínio formula/cut remains unresolved; arithmetic proximity never authorizes rewrite.
- Volvo market estimate remains provisional pending exact trim/km evidence.
- Classification triage may order review only; it may not suggest unsafe categories.
- Document association requires explicit bank/card/competence or commitment/as-of context; no filename inference.
- Open Finance production consent/provider/spend requires explicit user decision.

## Minimum package before changing `homologacao-current.json` to v142
1. Public fallback unchanged — GREEN.
2. Planning Excel→current bridge — GREEN.
3. Dashboard cockpit read model/ACL — GREEN.
4. v142 parser/static layers — GREEN.
5. Chromium desktop/mobile Round 2 composition smoke — GREEN.
6. Pages on integrated Round 2 main SHA — GREEN.
7. Heavy v14 + delta v15 + delta v16 — GREEN (**31 suites / 379 checks** staged).
8. Reviewed natural-language resgate/aplicação UI — GREEN on integrated main.
9. Flow-v13-effective write→refresh consistency after liquidity movement — GREEN.
10. Round 3 action hierarchy/density — IN FINAL SMOKE.
11. Final v142 package checkpoint + master backlog synchronization — PENDING.
12. Real authenticated visual E2E — PENDING / NOT CLAIMED.
13. Only after 10–11 are complete may the fixed homologation manifest move from v141 to v142 for the user's material visual review.
14. `index.html` promotion only after explicit user approval.

Continue autonomously. Do not ask the user to perform basic QA.
