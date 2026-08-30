# LTS Wealth — Next Homologation Gate

Purpose: minimum evidence-backed package before asking the user to inspect the next material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `PLANNING_EXCEL_TO_CURRENT_AUDIT_2026-08-30.md` and `DASHBOARD_COCKPIT_V142_CHECKPOINT_2026-08-30.md`.

## Current baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged and not user-approved; effective prior visual baseline remains v135.
- Public fallback protected blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed user homologation URL: `homologacao.html`.
- `homologacao-current.json` still intentionally points to validated v141 while v142 finishes its coherent package.
- Current material work candidate: `wip35-v142-candidate.html`.
- Current Dashboard/Planning/UX smoke head: `8f9fb976891a7f5d7cafddcd68f22dca4d12742b`.
- Real authenticated visual E2E: PENDING / NOT CLAIMED.
- Promotion to `index.html`: NOT AUTHORIZED / NOT DONE.

## P0 financial conclusion now closed
The Excel→current Planning discrepancy is no longer an unresolved blocker for January/2027.

Audited current semantics:
- first management point: **08/01/2027**;
- FGTS request-by under the user-confirmed ~D+30 access rule: **09/12/2026**;
- conservative FGTS amount existing on request date: **R$32.309,05**;
- worst balance before contingency: **R$-21.046,80**;
- worst balance after conservative planned FGTS: **R$+11.262,25**;
- first uncovered gap through 28/02/2027: **none**.

Therefore Dashboard/Planning must describe January as a **liquidity management point covered by a D+30 contingency if requested on time**, not as “real lack of money”.

Planning bridge QA: **19/19 PASS**.

## v142 Dashboard package
The user asked to restore the strong Claude-era cockpit rather than invent a new Dashboard. The exact repository reference is the existing `dashboard-planning-v114-cockpit` / `d114-*` information architecture.

Required hierarchy:
1. `Sua vida financeira, em uma tela.`
2. Hero `Disponível realizável até D+3`.
3. Caixa bancário / D0 Cofrinho / RSU vested / FGTS restricted D+30.
4. Snapshot operational: card confirmation, open bills, pending work, next card action.
5. 30d / 90d / year-end trajectory.
6. Audited decision bridge: management point → planned D+30 coverage.
7. A few current actions, not distant 2030/31 noise.
8. Future-liquidity agenda.
9. Fast drill-down to Flow, Expenses, Cards and Wealth.

New cached read model:
- `lts_refresh_dashboard_cockpit_v1(uuid)` internal;
- `lts_browser_dashboard_cockpit_v1()` auth.uid scoped;
- `lts_dashboard_cockpit_qa_v1(uuid)`;
- dedicated cache invalidated whenever product-cache `refreshed_at` changes.

Current cockpit values:
- bank R$4.766,99;
- D0 R$42.842,59;
- vested RSU R$32.772,30;
- through-D3 R$80.381,88;
- FGTS R$17.509,05 restricted/D+30;
- open cards R$28.516,67;
- next card due C6 R$960,16 on 08/09/2026;
- central net-worth estimate R$3.572.800,64, with existing valuation guardrails;
- current-month Expenses R$50.686,38 versus Jul R$62.472,85, explicitly marked descriptive because card-detail coverage is not homogeneous.

Dashboard cockpit QA: **13/13 PASS**.
Auth-role SQL simulation of browser cockpit RPC: PASS.

## Browser / serving evidence
Current smoke head: `8f9fb976891a7f5d7cafddcd68f22dca4d12742b`.

- Candidate-smoke run `33337978951`: **SUCCESS**.
- Same-head Pages run `33337978699`: **SUCCESS**.
- v142→v141→v140→v139→v138→v137→index chain: PASS.
- Desktop 1440×1000: PASS.
- Mobile 390×844: PASS.
- v142 visible ownership: PASS.
- Planning reconciled renderer: PASS.
- restored Dashboard renderer/nav: PASS.
- Dashboard primary nav visible: PASS.
- Dashboard static cockpit copy: PASS.
- CSS layers: PASS.
- zero new console/page errors.
- zero root overflow desktop/mobile.

Important limit: this is non-authenticated browser composition/runtime evidence. It is not authenticated visual E2E.

## Financial / backend gates
Heavy gate v14 was re-run after current cache-health contracts were synchronized:
- **24 suites / 293 checks / PASS**.

Because the full gate already takes ~105s, new liquidity/Dashboard checks are a staged delta rather than nesting another timeout-prone mega-function.

Delta gate v15:
- liquidity writer v2: 10/10;
- transactional rollback: 15/15;
- liquidity read-path: 12/12;
- browser liquidity ACL: 17/17;
- Dashboard cockpit: 13/13;
- **5 suites / 67 checks / PASS**.

Current staged evidence total: **29 suites / 360 checks PASS**.

This proves code/data contracts, not authenticated visual E2E or user homologation.

## Liquidity movement status
Application/redemption foundation is now proven but should not be exposed carelessly.

Proven:
- equal-and-opposite bank ↔ cash-investment asset legs;
- economic effect zero;
- excluded from income/expense;
- idempotent;
- explicit approval required;
- over-redemption rejected against effective asset balance;
- same-snapshot-day guard against documentary double count;
- Flow v13 / future cache / product cache / effective Wealth propagation exact;
- browser wrappers auth.uid scoped, anon blocked;
- QA writes rolled back; no QA financial rows persist.

Still required before visible writer promotion:
- coherent reviewed UI preview + confirmation;
- all relevant rollover/read paths must stay v13-effective after a liquidity movement;
- authenticated save→refresh→visible result check;
- cancellation/repair semantics before treating this as a mature everyday writer.

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
4. v142 parser/static layer — GREEN.
5. Chromium desktop/mobile composition smoke — GREEN.
6. Pages on same tested head — GREEN.
7. Heavy v14 + delta v15 — GREEN (29 suites / 360 checks staged).
8. Dashboard current-action prioritization / density — IN PROGRESS.
9. v13-effective rollover/write-read consistency after liquidity movements — IN PROGRESS.
10. Final v142 package checkpoint + master backlog synchronization — PENDING.
11. Real authenticated visual E2E — PENDING / NOT CLAIMED.
12. Only after 8–10 are complete should the fixed homologation manifest move from v141 to v142 for the user's material visual review.
13. `index.html` promotion only after explicit user approval.

Continue autonomously. Do not ask the user to perform basic QA.
