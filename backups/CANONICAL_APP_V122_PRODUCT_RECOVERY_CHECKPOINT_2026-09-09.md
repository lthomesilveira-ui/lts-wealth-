# LTS Wealth — Canonical v1.22 Product Recovery Checkpoint

Date: 2026-09-09

## Exact release

- Product commit: `181546c8b6d90756229fdf3ca083f0cf05dacc4a`.
- Fixed-manifest exposure: `3e3fa9a37b4393d405d0cbd4c5f5a3e30de6ce22`.
- Branches `canonical-v157plus-product-recovery`, `canonical-app-v1` and `main` are aligned by normal no-force fast-forward.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` was not changed; protected blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Recovered product contracts

- Flow V1.20 restores the validated V150/V151+ floor: collapsed historical rows show only date, left `Histórico` label and closing balance; expansion restores opening, entries, exits, closing and movements without invading the Entries/Exits columns.
- Future events expose distinct Edit, Postpone, Duplicate and Split actions; cancellation remains protected and append-only inside the editor.
- Historical facts remain read-only; card invoice details remain inline; internal transfers retain zero consolidated economic effect.
- Reports V1.21 replaces the export-only placeholder with an evidence-backed executive report grouped by today/short term, projected cash, expenses, wealth/commitments and data quality. JSON and recurrence CSV remain available; backup remains separate and protected.
- Dashboard V1.22 preserves the approved liquidity-first five-KPI decision and the V151 first-negative/management-date distinction while improving readable density and executive hierarchy against the approved 1312×1199 reference.

## Automated evidence

- Product recovery gate `34306308228`: SUCCESS in Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Active candidate smoke `34306308235`: SUCCESS.
- Canonical gate `34306465733` and candidate smoke `34306465795`: SUCCESS.
- Main candidate smoke `34306466418` and Pages `34306465815`: SUCCESS.
- Post-exposure active/canonical/main smokes `34306705547` / `34306706458` / `34306706548`: SUCCESS.
- Post-exposure Pages `34306705941`: SUCCESS.

## Explicitly unclaimed external evidence

- Authenticated real financial mutation/readback, document upload lifecycle and backup/restore lifecycle still require a browser session owned by the user.
- Physical-iPhone material E2E still requires the physical device and is not claimed by deterministic WebKit.
- Documentary gaps and provider/commercial Open Finance decisions remain open; no value, classification or provider choice was invented.

