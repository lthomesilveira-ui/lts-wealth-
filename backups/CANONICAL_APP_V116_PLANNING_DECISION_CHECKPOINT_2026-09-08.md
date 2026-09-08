# LTS Wealth — Canonical v1.16 Planning Decision Checkpoint

Date: 2026-09-08

## Purpose

Recover the V151 planning distinction that remained visible in the approved Dashboard reference but was reduced to low-emphasis date pills in canonical v1.15: the first projected negative-liquidity date and the earlier management-action date must be presented as separate decision signals.

This package changes presentation and gate coverage only. It does not create, interpolate or modify a financial value.

## Exact release identity

- Product commit: `4028321fed599496d29798e3e2d1c47c48bc54d1`
- Product tree: `0776d7e4de0f63eae13ad92f01fc47acc799e148`
- Fixed-manifest exposure: `d9a63c96e2674f7bf8d615e29643598bd8146537`
- Exposure tree: `0c2dc3c7c38051f8c11008f35651aebf405149f3`
- Build label: `LTS v1.16`
- Asset tag: `20260908-planning16`
- Contract: `v151-first-negative-management-separation-v1`
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`
- Exposure status: `promotion_status:not_promoted`
- Public `index.html`: protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`, unchanged.

## Recovered evidence and decision

- `wip35-v151-reference-fidelity.js` and `wip35-v151-dashboard-updates.js` distinguish the first negative-liquidity horizon from the point at which management action must begin.
- The official 1312×1199 Dashboard reference shows the first negative point as a prominent red decision cue rather than a small metadata pill.
- The canonical product therefore exposes an explicit planning callout with both dates and their ordering.
- The chart draws a red marker/guide only when an exact horizon row exists for the first-negative date and its evidenced `base` value is below zero.
- When that exact negative point is absent, the UI remains date-only and never approximates or interpolates a financial value.
- The deterministic fixture proves the distinct dates `01/12/2026` for management and `12/01/2027` for first negative, including the fact that management begins first.

## Files in the product package

- `.github/scripts/lts_canonical_v157plus_browser_gate.js`
- `.github/workflows/candidate-smoke.yml`
- `.github/workflows/canonical-app.yml`
- `.github/workflows/canonical-v157plus-product-recovery.yml`
- `canonical-app.html`
- `canonical-dashboard-fidelity.css`
- `canonical-liquidity.js`

## Validation evidence

- Local permanent Chromium gate: `canonical V157+ permanent browser gate ok`.
- Desktop evidence: Chromium 1312×1199; document height 1199 px and Dashboard content remains inside the approved canvas.
- Mobile evidence: Chromium 390×844; intentionally scrollable, with no horizontal clipping.
- The receipt is `PASS` with delivery boundary `AUTOMATED_GATE_PASS_REAL_E2E_OPEN`.
- Product recovery gate/smoke `34262013499` / `34262013502`: SUCCESS.
- Canonical gate/smoke `34262279303` / `34262278639`: SUCCESS.
- Main smoke/Pages `34262576921` / `34262575286`: SUCCESS.
- Post-exposure active/canonical/main smokes `34262885534` / `34262887519` / `34262889285`: SUCCESS.
- Post-exposure Pages `34262887576`: SUCCESS.
- Recovery artifact `10070303869`, digest `sha256:4dc750647554451639e78d7bc4af15de8690b81fdf28f48b4e7908088632140b`.
- Canonical artifact `10070422301`, digest `sha256:5ac0f9b13f98820ab7ed87c79debdc8643703d0d82df9fbfa6e01689106492da`.
- Product Pages artifact `10070474844`, digest `sha256:d2e9eef2506ad7dc3b5490ee48aa5038421b9f0edaa8ca8145c5e3fdecaddfdc`.
- Exposure Pages artifact `10070593792`, digest `sha256:6c3e77988732f9852214e6c7eabb1f934973ad8e60616eb6d04c85faa625bbbc`.

## Fixed-URL verification

The live fixed URL resolved to `canonical-app.html?homologacao=4028321fed599496d29798e3e2d1c47c48bc54d1#Dashboard`, loaded the `20260908-planning16` CSS and scripts, rendered a truthful signed-out login with blank email/password, used zero iframes and exposed no fixture badge, raw JWT or application error.

## Protected inheritance

Canonical v1.16 preserves v1.15 approved 1312×1199 density, v1.14 V149 read-only document review, v1.13 classification-first guided intake, v1.12 reviewed text input, v1.11 layered liquidity, v1.10 fact/projection and commitment/task separation, v1.9 V150/V151+ Flow parity, v1.8 single-owner Despesas, route/session continuity, future-JWT recovery and the hardened Supabase baseline.

## Honest delivery boundary

Automated desktop/mobile fixture coverage and remote CI are green. Authenticated real-data/write/document/backup lifecycles, authenticated physical-iPhone verification and public-root promotion remain open and are not claimed. No approved standalone Reports visual has been recovered, so this package does not invent one.

## Next execution sequence

1. Keep v1.16 as the protected canonical baseline across the three branches.
2. Continue the evidence-led V150–V160 and two-project audit for the next objective omission.
3. Run authenticated real lifecycle checks when a valid test identity/session is available.
4. Keep physical-iPhone evidence and public-root promotion explicitly open until actually authorized and completed.
