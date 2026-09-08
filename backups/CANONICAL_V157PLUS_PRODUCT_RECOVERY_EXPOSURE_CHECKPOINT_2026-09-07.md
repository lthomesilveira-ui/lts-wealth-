# LTS Wealth — Canonical V157+ Product Recovery Exposure Checkpoint

Date: 2026-09-07 (America/Sao_Paulo)

Immutable evidence checkpoint for the V157+ single-frontend product recovery, permanent-gate migration and fixed-homologation exposure. This checkpoint records deterministic and public unauthenticated evidence only. It does not claim authenticated physical-iPhone financial/data E2E.

## Scope completed
- Kept `canonical-app.html` as the only canonical frontend; no iframe/release-wrapper chain was reintroduced.
- Migrated permanent browser coverage to the split modules `canonical-liquidity-core.js`, `canonical-flow-v157.js`, `canonical-product-v157.js` and `canonical-presentation-v157.js`.
- Preserved prior classification, server search/CSV, document lifecycle and neutral bank↔cash-investment preview contracts.
- Covered the V157+ Flow, Despesas, Patrimônio, Cartões, Atualizações, Dashboard and truthful login surfaces on desktop Chromium 1312×1199 and mobile WebKit 390×844.
- Exposed the exact gated product through `homologacao-current.json` while keeping `promotion_status:not_promoted` and leaving `index.html` unchanged.
- Retired automatic `main` triggers from historical v144–v160 wrapper workflows while preserving their feature-branch and manual execution paths.

## Exact commits
- Product and permanent-gate migration: `76f888dc0e668fb0e768c8cc825f56778f043f50`.
- Green canonical baseline / exact homologation target: `c44d401497e14d842d433a302006ff5648b956a9`.
- Fixed-homologation manifest exposure: `3b3048fa4660868e161582fcd8704438a13e300c`.
- At exposure, `canonical-v157plus-product-recovery`, `canonical-app-v1` and `main` were aligned at `3b3048fa4660868e161582fcd8704438a13e300c` by normal no-force ref updates.

## Exact protected/product blobs
- `index.html`: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` — protected and unchanged.
- `canonical-app.html`: `08680a3fad789351d3bbd7c3b44aef0af7ea9757`.
- `canonical-dashboard-fidelity.css`: `8ca76632029a80b65ced58f0cf4a5704df2c0269`.
- `canonical-liquidity.js`: `1399b6af2046eec23f700295fdb5b7925611c83f`.
- `canonical-liquidity-core.js`: `eee099e254569d955a64216edce1322613882644`.
- `canonical-flow-v157.js`: `fefe99aa1062ad5287f0a39f7872a28d96ee0b1f`.
- `canonical-product-v157.js`: `2eb33b2f3b5405b2e95f4a2104f267a4c46ff47c`.
- `canonical-presentation-v157.js`: `9f50f69ca33ef5c134cd771f86a958fed2aa1d89`.

## Green deterministic evidence
- Active modular recovery gate `34170935882`: SUCCESS, Chromium desktop + WebKit mobile.
- Active candidate smoke `34170935887`: SUCCESS.
- Permanent canonical gate `34171231918`: SUCCESS, Chromium desktop + WebKit mobile.
- Canonical candidate smoke `34171231935`: SUCCESS.
- Main pre-manifest candidate smoke `34171338575`: SUCCESS.
- Main pre-manifest Pages deployment `34171338335`: SUCCESS.
- Post-manifest active candidate smoke `34171452083`: SUCCESS.
- Post-manifest canonical candidate smoke `34171452913`: SUCCESS.
- Post-manifest main candidate smoke `34171453488`: SUCCESS.
- Post-manifest Pages deployment `34171452759`: SUCCESS.

The browser gate validates fixture readiness, the five Dashboard KPIs, all six physical routes, four Flow account views, 10 presets, 14 desktop columns, expandable movements, Despesas periods/drilldown, RSU/FGTS/CIPÓ/Volvo wealth surfaces, card coverage, Atualizações classification/search/CSV/documents, neutral liquidity preview with fixture writer disabled, no iframe, no horizontal overflow, unclipped six-item mobile navigation and truthful unauthenticated login.

## Fixed homologation verification
- Entry point: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Observed target: `https://lthomesilveira-ui.github.io/lts-wealth-/canonical-app.html?homologacao=c44d401497e14d842d433a302006ff5648b956a9&ts=1788825305174`.
- Observed page title: `LTS Wealth`.
- Canonical script tag present.
- Unauthenticated rendering was the truthful `Entrar / Sua vida financeira, em uma tela.` login surface; no fixture financial Dashboard was exposed.

## Historical workflow disposition
The post-manifest historical battery produced 16 successful runs and two failures tied to superseded wrapper assumptions: v160 expected an obsolete iframe route and received `via:not-found`; v151 failed in its old wrapper/browser cockpit step after inherited/static checks passed. These are not canonical release gates. Historical v144–v160 workflows remain runnable manually and on their own feature branches but no longer auto-trigger on `main`.

## Explicitly not claimed
- Authenticated physical-iPhone financial/data E2E.
- Real authenticated liquidity save→refresh→visible.
- Real authenticated classification save→refresh→resolved disappearance/self-heal.
- Real authenticated PDF/image interpretation→review.
- Real authenticated server-side transaction-search/CSV E2E.
- Pixel-perfect Dashboard parity with the approved reference.
- Public-root promotion.

## Next P0
Continue Dashboard visual fidelity against the approved 1312×1199 reference and remaining report/updates product recovery, using real evidence only and preserving the canonical single-frontend architecture.
