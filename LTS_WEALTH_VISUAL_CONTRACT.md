# LTS Wealth — Visual Contract

Canonical visual reference for the product.

## Official reference asset
- File: `design/LTS_WEALTH_DASHBOARD_REFERENCE_OFFICIAL_2026-09-04.jpeg`
- SHA-256: `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`
- Status: mandatory visual contract, not inspiration.

## Acceptance rule
Before asking the user to homologate a Dashboard candidate:
1. render the real candidate in desktop and mobile;
2. capture screenshots;
3. build side-by-side evidence against the official reference;
4. inspect visual hierarchy, density, spacing, proportions, typography, card language and navigation;
5. test mobile `Dashboard → Fluxo Diário → Dashboard` with physical browser clicks;
6. continue correcting if the candidate is still visually distant.

Having equivalent blocks or passing DOM geometry alone is not visual parity.

## Desktop language
- Dark left navigation rail; light executive content canvas.
- Dashboard title/subtitle and compact position/date control.
- Dense five-KPI first row.
- Multi-column cockpit cards with subtle borders/shadows and compact spacing.
- Charts, composition, bank position, commitments and action areas must read at a glance.
- Avoid large unused whitespace.

## Mobile language
- Preserve the same visual identity and information hierarchy.
- Use persistent, physically testable primary navigation.
- Never trap the user inside Fluxo Diário or another cockpit.
- No horizontal page overflow.

## Financial/data constraints
- Reference image values are illustrative unless separately evidenced by LTS data.
- Production values must come from LTS read models/evidence.
- FGTS current documentary balance is R$ 22.432,31 as of 21/08/2026.
- FGTS is restricted contingency with approximately D+30 operational access.
- FGTS is never included in Disponível D+3.
- Do not project future FGTS contributions.
- Historical R$ 3.700/month and derived projected FGTS values are historical model evidence only, not current forecast.
- If planning has not been reconciled to the conservative FGTS rule, show it as revalidation pending rather than reusing legacy projections.

## Scope
This visual language is the baseline for Dashboard and must guide Despesas, Cartões, Patrimônio and later executive cockpits without changing established financial/data invariants.
