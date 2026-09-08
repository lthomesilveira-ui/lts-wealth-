# LTS Wealth — Canonical v1.17 Product Language Checkpoint

Immutable checkpoint date: 2026-09-08 16:21 BRT

## Scope

Canonical v1.17 removes internal release/build language from the product surface while preserving every validated financial, interaction, data, route, session and security contract from v1.16 through v1.9.

Contract: `user-facing-product-language-v1`.

## Exact lineage

- Local product commit: `e987ddd94375d9624d2fae85a01b92f289920c56`.
- Remote product commit: `e4cea67563ac379d5bf47d02d20846699194a002`.
- Product tree: `9037c73840167b1cfe1d36e2b8cc2b6f90d101f7`.
- Local exposure commit: `22eefcc2e4b4cd2c811b7cee67511d1ef3587ac0`.
- Remote fixed-manifest exposure: `06fdcbba8f1cbcae6af2ebf153a2291915195f96`.
- Exposure tree: `4d3a917076380bfc81d8a0a74842d97eb1fe38f9`.
- `canonical-v157plus-product-recovery`, `canonical-app-v1` and `main` all point to the exposure commit through normal no-force fast-forward.
- Internal build remains `LTS v1.17`; asset tag is `20260908-ux17`.
- Protected public `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Product behavior closed

- Removed fixed build badges from Fluxo Diário and the canonical product panels.
- Removed header release labels from Patrimônio and Cartões; the visible metadata is now only user-relevant data recency.
- Replaced Central de Gestão release wording with `Dados carregados` / `Carregando dados`.
- Kept internal version identifiers available to diagnostics and gates, not to the normal user interface.
- Added a permanent gate that fails if any canonical route exposes an `LTS`, `CANONICAL` or `WIP35` release label/build badge.
- No financial value, calculation, classification, projection, documentary rule, writer contract or route ownership changed.

## Automated evidence

- Local permanent Chromium gate: PASS at 1312×1199 and 390×844 across all routes, Flow, invoices, splits, reviewed input, documents, management panes, route continuity and JWT recovery.
- Recovery gate/smoke: `34267339089` / `34267339099`: SUCCESS.
- Canonical gate/smoke: `34267537086` / `34267537120`: SUCCESS.
- Main candidate smoke/Pages: `34267717067` / `34267715832`: SUCCESS.
- Post-exposure active/canonical/main smokes: `34267927974` / `34267929858` / `34267932211`: SUCCESS.
- Post-exposure Pages: `34267929912`: SUCCESS.
- Recovery artifact `10072405055`, digest `sha256:200786a5aee8034f91f7b625234a10900cb7e444ca754c1a5f4354177e0537a4`.
- Canonical artifact `10072479667`, digest `sha256:b135f99fbc2b64a029d5c462865d8e4461f93667bc0fdf1b73e0ca29c6dff4a7`.
- Product Pages artifact `10072497570`, digest `sha256:76738dc52c4522e405866f203e4711269b6adf1fd97538c28563f64ec7580048`.
- Exposure Pages artifact `10072584498`, digest `sha256:89d724b71905784ff47dac2fc36fda196c4f9b2e159533e49340da7a654ec478`.

## Live fixed-link evidence

- `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` resolved to `canonical-app.html?homologacao=e4cea67563ac379d5bf47d02d20846699194a002#Dashboard`.
- The live page loaded the `20260908-ux17` assets.
- Signed-out state was truthful: blank login, zero KPIs, zero fixtures, zero iframes, zero technical badges, no raw JWT and no application error.

## Preserved floors

- V150/V151+ rich Fluxo Diário behavior.
- V151 search/CSV and conservative FGTS rule.
- V147 classification-first Updates hierarchy.
- V148 save→refresh→`O que mudou` lifecycle contract.
- V149 association-versus-extracted-evidence read-only review.
- V1.15 approved 1312×1199 Dashboard density.
- V1.16 first-negative versus management-action planning distinction.
- Append-only, human-approval, session, route, backup and Supabase least-privilege boundaries.

## Explicitly open

- Authenticated real-data/write/document/backup lifecycle evidence.
- Physical-iPhone authenticated E2E.
- Remaining evidence-led Dashboard detail and historical financial audits.
- Public-root promotion, which remains unauthorized.
- A standalone final Reports visual; no approved model has been recovered, so none may be invented.
