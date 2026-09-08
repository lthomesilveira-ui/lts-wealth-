# LTS Wealth — Canonical v1.7 Route/Session + DoD Receipt Checkpoint

Date: 2026-09-08

## Purpose

This immutable checkpoint records the coherent package that closes deterministic route/session continuity and introduces one machine-readable definition-of-done receipt. It preserves Dashboard Fidelity Pass 6, canonical v1.6 capabilities, future-JWT recovery, financial invariants and the bounded Supabase security baseline.

It does **not** claim authenticated real-data/write completion, physical-iPhone homologation or public-root promotion.

## Exact lineage

- Repository: `lthomesilveira-ui/lts-wealth-`
- Active branch: `canonical-v157plus-product-recovery`
- Product target: `e618ef48e22872ce718c7932872e2316e5660f67`
- Homologation exposure: `33da29ab0818c9dd59dca45f68d3680ed153f6af`
- Branches aligned after exposure: `canonical-v157plus-product-recovery`, `canonical-app-v1`, `main`
- Public fallback: unchanged `index.html` blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`
- Promotion state: `not_promoted`

## Product contract added

### Canonical route/session continuity

- `canonical-route-session-continuity-v1` resolves the URL hash before the first RPC and first product render.
- Only allowlisted navigation intent is persisted in `sessionStorage` under `lts_canonical_route_v1`; no financial fact or value is stored there.
- Central navigation uses `history.pushState`; `popstate` and `pageshow` restore the URL-owned route.
- Refresh, signed-out login, future-JWT safe reset, direct deep links, browser back/forward and bfcache preserve or safely canonicalize route intent.
- Invalid route names resolve to Dashboard instead of trapping the application.
- Logout preserves route intent while removing the authenticated session.

### Central de Gestão pane continuity

- The eight valid management panes are allowlisted and stored in `lts_canonical_management_pane_v1`.
- A selected pane survives refresh/back without introducing a seventh mobile route.
- Invalid pane state cannot replace a valid product panel.

### Unified definition-of-done receipt

- The permanent browser gate generates `canonical-definition-of-done-receipt.json` at runtime under contract `lts-canonical-definition-of-done-receipt-v1`.
- The receipt maps Dashboard, Flow, Despesas, Cartões, Patrimônio, Atualizações, Recorrências, Compromissos, Simulações, Conciliação, Relatórios, backup controls, route/session, performance and UX.
- `gate_status: PASS` is deliberately distinct from `delivery_status: AUTOMATED_GATE_PASS_REAL_E2E_OPEN`.
- Claim boundaries remain explicit: authenticated real data `NOT_CLAIMED`, authenticated writes `NOT_CLAIMED`, physical iPhone `NOT_CLAIMED`, public root `NOT_PROMOTED`.

## Changed product/gate evidence

| File | Git blob | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `canonical-app.html` | `92507f55f4de291c17e49a5b430bedcb33018506` | 98,648 | `d46a076f9de89cf6c5d6b70781941fcd692dec87b0dfe62522682efd66bd33b9` |
| `canonical-liquidity.js` | `8a8caba73c0f6a08710328c19e38bec6c6aab7e9` | 3,139 | `31bf976d9e1a227a4569bb7d31fd44e3bf6928b8b44f4ee2d0f9ff091c17cf84` |
| `canonical-capabilities-v161.js` | `da479e1c5215b593b7bb43d2df5d64dc939e19e2` | 33,626 | `49611cc7fd43645238424480ecb75aafc6aefec0e70f8afca60717df573dfbe6` |
| `.github/scripts/lts_canonical_v157plus_browser_gate.js` | `f48fc1520f1e50d7071f21be6648a2293fc21e6f` | 28,514 | `c5dafc9cebbaf3713c1419b71bda0ae6ae16afa311350b210c15ebc8ac59c42e` |

Workflow blobs:

- recovery workflow: `9a558c4574eb6439b1eeca0f34400fec2012cdd5`
- canonical workflow: `f66d75676bbb8fd5637ee11700a21968562adcda`
- candidate smoke: `4368b34094b2c3c100f5cbe44c51541858f72d64`

## Deterministic gate evidence

| Stage | Run | Result |
| --- | ---: | --- |
| Active recovery gate | `34190659782` | SUCCESS |
| Active candidate smoke | `34190659780` | SUCCESS |
| Canonical permanent gate | `34191017877` | SUCCESS |
| Canonical candidate smoke | `34191017858` | SUCCESS |
| Main candidate smoke | `34191216218` | SUCCESS |
| Main Pages deployment | `34191215874` | SUCCESS |
| Post-exposure active smoke | `34191461669` | SUCCESS |
| Post-exposure canonical smoke | `34191462282` | SUCCESS |
| Post-exposure main smoke | `34191463017` | SUCCESS |
| Post-exposure Pages deployment | `34191462402` | SUCCESS |

Receipt artifact:

- artifact ID `10042106418`
- size `2,126,739` bytes
- digest `sha256:69ef7f8af36374e9c91ae5074690d13525676d8fe8ee326024c40e381e36ed47`
- source SHA `e618ef48e22872ce718c7932872e2316e5660f67`
- desktop Chromium 1312×1199: PASS, 8,120 ms
- mobile WebKit 390×844: PASS, 20,119 ms
- session recovery: PASS
- route refresh, management-pane restore, back/forward, Cards deep link, invalid-route Dashboard fallback and future-JWT preservation of the Patrimônio intent: PASS

## Fixed homologation verification

The fixed URL `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` was opened after the post-exposure Pages deployment and resolved to:

`canonical-app.html?homologacao=e618ef48e22872ce718c7932872e2316e5660f67#Dashboard`

Observed facts:

- title `LTS Wealth`;
- real signed-out login with e-mail and password fields;
- `canonical-liquidity.js?v=20260908-continuity7` loaded;
- zero unauthenticated financial KPI cards;
- zero iframes.

## Preserved invariants

- One canonical frontend owns authentication, Dashboard and all six primary routes.
- No financial value, classification, merchant, valuation, competence or recurrence was invented or changed.
- FGTS remains restricted/D+30 context and is never automatic current cash.
- Reconciliation tolerance remains `R$ 0,00`; transfers remain economically neutral in consolidation.
- Append-only/idempotent financial semantics and human approval remain binding.
- Supabase migration `20260908045049` and its RLS/SECURITY DEFINER postconditions remain the security baseline.
- Public `index.html` was not modified or promoted.

## Honest remaining gates

- Authenticated physical-iPhone post-fix financial/data E2E.
- Authenticated real liquidity save→refresh→visible.
- Authenticated classification save→refresh→resolved/self-heal.
- Authenticated server-side search/CSV.
- Authenticated PDF/image interpret→review.
- Authenticated backup export→checksum→stage→preview→apply and audit verification.
- Evidence-led Dashboard/Despesas/Atualizações refinement and documentary gaps already retained in the master backlog.
- Controlled Auth-setting review of leaked-password protection.
- Public-root promotion only after the complete receipt and explicit user authorization.

## Continuation order

1. Treat product target `e618ef48e22872ce718c7932872e2316e5660f67` as the protected v1.7 baseline.
2. Continue Dashboard/Despesas/Atualizações refinement against real evidence.
3. Close receipt rows that require a real authenticated identity/device when that access is available; never infer them from fixture PASS.
4. Keep the Supabase security postconditions regression-protected.
5. Preserve `promotion_status:not_promoted` until explicit authorization.
