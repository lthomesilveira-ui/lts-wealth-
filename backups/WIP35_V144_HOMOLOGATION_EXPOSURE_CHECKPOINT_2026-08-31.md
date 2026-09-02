# LTS Wealth — WIP35 v144 Homologation Exposure Checkpoint

Checkpoint date: 2026-08-31

## Purpose
Record the controlled fixed-homologation switch from v143 to v144 after branch and integrated-main gates passed. This checkpoint does **not** authorize public `index.html` promotion, does not change financial rules, and does not claim authenticated visual E2E.

## Proven before this exposure commit
- v144 branch freeze head: `b0d23e35be1d5d27400268a36bb3562395bb3513`.
- v144 branch freeze run `33413763757`: SUCCESS.
- Integrated-main SHA: `b0d23e35be1d5d27400268a36bb3562395bb3513` via fast-forward with `force=false`; no divergence overwritten.
- Integrated-main v144 smoke `33414249775`: SUCCESS.
- Integrated-main legacy candidate-smoke `33414249873`: SUCCESS.
- Integrated-main Pages `33414248379`: SUCCESS.
- Protected public `index.html` remains exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Before this switch, `homologacao-current.json` still targeted v143.

## What v144 corrects
User material homologation of v143 found a P0 regression in Atualizações:
- suggestion + research/evidence + certainty % was no longer clearly surfaced;
- layout had weak hierarchy and excessive blank space.

v144 restores classification first with `Sugestão + pesquisa + % de confiança, item por item`, preserving existing classification helpers/save controls and keeping ambiguous taxonomy for manual review.

Browser evidence remains unauthenticated/synthetic composition evidence:
- desktop 1440×1000 PASS;
- mobile 390×844 PASS;
- `Restaurantes` suggestion visible in synthetic Gula-like evidence;
- `83% sugestão`, `99% identificação`, ambiguous marketplace `91% identificação`;
- research/evidence visible;
- 2 save controls preserved;
- classification before secondary sections;
- secondary sections collapsed;
- ownership/navigation inherited from v143 intact;
- zero root overflow and zero console/page errors.

## Exposure change in this commit
`homologacao-current.json` is changed to:
- version `v144`;
- path `wip35-v144-candidate.html`;
- candidate head `b0d23e35be1d5d27400268a36bb3562395bb3513`;
- public fallback `index.html`;
- promotion status `not_promoted`.

## Required after this commit
On the exact exposure SHA, require:
1. v144 Updates/full-browser smoke SUCCESS;
2. legacy candidate-smoke SUCCESS;
3. Pages SUCCESS;
4. protected public `index.html` blob still exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
5. manifest resolves to v144.

Only after those exact-SHA gates are green may the user be told `Pode acessar` at the fixed homologation URL, starting with Atualizações.

## Open blockers carried forward
- real authenticated visual E2E remains pending/unclaimed;
- guided document-association UI;
- authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou` checks;
- authenticated natural-liquidity save→refresh→visible result;
- append-only cancellation/reversal semantics;
- Mastercard/Visa historical documentary gaps;
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps, no fabricated post-2029 TR;
- Volvo exact trim/km before valuation refinement;
- Open Finance pricing/SLA/product×bank coverage; no consent/spend without explicit user decision;
- human classification where evidence remains ambiguous;
- public `index.html` promotion only after explicit user approval.
