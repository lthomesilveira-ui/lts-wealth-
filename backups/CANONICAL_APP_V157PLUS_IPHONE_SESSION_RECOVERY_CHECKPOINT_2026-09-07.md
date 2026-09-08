# LTS Wealth — Canonical V157+ iPhone Session Recovery Checkpoint

Date: 2026-09-07 (America/Sao_Paulo)

Immutable evidence for the P0 correction triggered by the real-iPhone error `JWT issued at future` and for the continuity audit initiated immediately afterward.

## Real-device symptom

- The supplied iPhone screenshot showed the fixed GitHub Pages homologation entry reaching the LTS Wealth fatal card `Não foi possível carregar` with raw detail `JWT issued at future`.
- Prior deterministic gates proved clean unauthenticated boot and fixture routes, but did not inject a persisted cached session whose JWT was temporarily ahead of the effective clock.
- This was a gate-coverage defect as well as a product-session defect.

## Product correction

- Exact product commit: `abe6180d37657cc47bf18036f524a95ff262df13` — `Recover future-issued JWT sessions on iPhone`.
- `canonical-app.html` now centralizes RPC execution and coalesced token refresh.
- On a future-issued JWT, the app waits briefly and retries the same token, refreshes once if necessary, and retries again.
- If the session is still invalid, the cached session is cleared and the user receives the safe login state `Sua sessão foi renovada por segurança. Entre novamente.`.
- The raw JWT error is not rendered to the user.
- `canonical-liquidity-core.js`, `canonical-flow-v157.js` and `canonical-product-v157.js` use the shared recovery-aware RPC path.
- The cache-safe entry asset is `canonical-liquidity.js?v=20260908-session6`.

## Deterministic green evidence

- Active V157+ recovery gate `34174520963`: SUCCESS.
- Active candidate smoke `34174520971`: SUCCESS.
- Permanent canonical gate `34174620205`: SUCCESS.
- Canonical candidate smoke `34174620102`: SUCCESS.
- Main candidate smoke `34174717328`: SUCCESS.
- Main Pages `34174716172`: SUCCESS.
- WebKit 390×844 explicitly injects a persisted future-token session, returns Supabase 401 `JWT issued at future`, and proves safe session removal, `jwt-clock` recovery status, visible login guidance and absence of the raw JWT message.

## Fixed-homologation exposure

- Exposure manifest commit: `0643f57e2b2b89b8cbf3ea6ba3c58296b4614ebd` — `Expose iPhone session recovery in homologation`.
- Post-exposure candidate smokes: active `34175144495`, canonical `34175143351`, main `34175143758`: SUCCESS.
- Post-exposure Pages `34175143251`: SUCCESS.
- Direct browser verification resolved `homologacao.html` to `canonical-app.html?homologacao=abe6180d37657cc47bf18036f524a95ff262df13`.
- Observed title: `LTS Wealth`.
- Observed asset: `canonical-liquidity.js?v=20260908-session6`.
- A clean session rendered the truthful login surface and no fixture financial content.

## Continuity audit

- `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` consolidates recovered briefing, Dashboard model lineage, V150/V151 decisions, current implementation proof and unresolved gates.
- Audit sources include current GitHub state, 760 Git commits, immutable checkpoints, historical LTS artifacts and targeted indexed conversation recovery.
- The conversation archive is not available as a complete sequential export by project title; any unresolvable absence is recorded rather than guessed.

## Claims deliberately not made

- No authenticated physical-iPhone post-fix retest is claimed.
- No authenticated financial-data E2E is claimed.
- No real financial mutation was performed by the deterministic session test.
- Dashboard pixel-perfect parity is not claimed.
- Public `index.html` remains protected and unchanged; `promotion_status:not_promoted`.

