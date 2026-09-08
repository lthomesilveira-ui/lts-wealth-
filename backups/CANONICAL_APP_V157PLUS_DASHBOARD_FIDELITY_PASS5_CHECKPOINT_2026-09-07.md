# LTS Wealth — Canonical V157+ Dashboard Fidelity Pass 5 Checkpoint

Date: 2026-09-07 (America/Sao_Paulo)

Immutable evidence for the package that restores the dense canonical Dashboard as the sole owner of the Dashboard route while retaining V157+ domain-route recovery.

## Product change
- Root cause: `canonical-product-v157.js` mounted after the canonical app and replaced the richer Dashboard with a simplified product surface.
- Correction: the canonical app now owns Dashboard; the V157+ product module enriches Despesas, Patrimônio and Cartões and reports Dashboard readiness without replacing its DOM.
- The five liquidity-first KPIs remain: Dinheiro em contas, Contas + curto prazo, RSUs vested, FGTS and Despesas (mês).
- The dense section hierarchy remains: Evolução da Liquidez, Distribuição do Patrimônio, Posição por Banco, Fluxo de Caixa, Principais Despesas, Próximos Compromissos, Planejamento – Visão de Caixa, FGTS and Atualizações Pendentes.
- No financial amount, classification, recurrence, valuation or documentary fact was added by the presentation change.

## Exact commits
- Product implementation: `6eca5c3785cd5dca69a2aa8f610312eefbb2a669`.
- Cache-safe/static gate correction: `4bda698a559518dd9242d3eafb56053ef266e810`.
- Final gated canonical target: `eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d`.
- Fixed-homologation exposure: `a808d855aa6687a893a51598db8f5fad4faf1cbb`.

## Green evidence
- Active recovery gate `34173223977`: SUCCESS, Chromium desktop 1312×1199 + WebKit mobile 390×844.
- Final active candidate smoke `34173481335`: SUCCESS.
- Permanent canonical gate `34173482173`: SUCCESS, Chromium desktop + WebKit mobile.
- Canonical candidate smoke `34173482194`: SUCCESS.
- Main candidate smoke `34173586238`: SUCCESS.
- Main Pages deployment `34173586282`: SUCCESS.
- Post-exposure active/canonical/main candidate smokes `34173674961` / `34173674230` / `34173673390`: SUCCESS.
- Post-exposure Pages deployment `34173673353`: SUCCESS.

Two intermediate red runs are superseded and explained: candidate smoke `34173223985` retained an exact old cache-buster string; canonical gate `34173386311` retained the prior Dashboard chart title in its static list. Both gate contracts were made cache-safe/aligned, then rerun green before integration or exposure.

## Fixed homologation verification
- Entry: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Observed target: `https://lthomesilveira-ui.github.io/lts-wealth-/canonical-app.html?homologacao=eff928cb88e01ba3c5c88b8a8a8c4e8fa5d89f5d&ts=1788827690312`.
- Page title: `LTS Wealth`.
- Pass 5 `canonical-liquidity.js?v=20260908-dashboard5` asset present.
- Truthful unauthenticated login present; Dashboard/fixture financial content absent.

## Guardrails retained
- `index.html` protected and unchanged.
- `promotion_status:not_promoted`.
- No iframe/wrapper primary architecture.
- No authenticated physical-iPhone financial/data E2E claim.
- No real authenticated financial write claim.
- Pixel-perfect parity remains open; this package removes the architectural visual regression and restores the approved-reference hierarchy.
