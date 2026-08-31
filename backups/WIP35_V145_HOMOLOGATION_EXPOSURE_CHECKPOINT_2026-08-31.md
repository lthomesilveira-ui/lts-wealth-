# LTS Wealth — WIP35 v145 Homologation Exposure Checkpoint

Checkpoint date: 2026-08-31

## Purpose
Record the controlled fixed-homologation switch from v144 to v145 after the Dashboard stability correction passed branch and integrated-main gates. This checkpoint does not authorize public `index.html` promotion, does not change any financial rule, and does not claim authenticated visual E2E.

## User-reported regression and correction
During material homologation of v144, Dashboard headings visibly alternated as if the screen had a bad contact. The root cause was competing inherited render cycles: v142 could repeatedly refresh/render the Dashboard while v143 feedback polish rewrote the approved title/subtitle. v145 stabilizes ownership so generated Dashboard HTML already contains the final copy and the legacy polling path is locked after valid cockpit data exists.

Final copy:
- `Sua vida financeira, em uma tela.`
- `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`

No financial rule, value, classification, backend writer or economic effect changed.

## Proven before exposure
- Hardened branch/integrated candidate SHA: `9d4a52df566d74bdc77f92b0d227906fc46bddce`.
- Hardened branch stability run `33423228532`: SUCCESS.
- Integrated-main stability run `33423462471`: SUCCESS.
- Integrated-main stability artifact `9769869448`.
- Integrated-main Pages run `33423461388`: SUCCESS.
- The v145 stability workflow reran inherited parser/static v142, v142 browser smoke, v143 runtime/navigation smoke and button contract audit; all PASS.
- Temporal browser evidence on desktop 1440×1000 and mobile 390×844 shows one stable title, one stable subtitle, `renderDelta=0`, `rpcDelta=0`, zero overflow and zero console/page errors.
- v144 Atualizações/classification action center remains inherited and was preserved by the same v145 smoke.
- Protected public `index.html` remains exact blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Before this exposure commit, `homologacao-current.json` still targeted v144.

This is synthetic/unauthenticated browser evidence. It is not authenticated visual E2E and performs no backend financial write.

## Exposure change
`homologacao-current.json` is switched to:
- version `v145`;
- path `wip35-v145-candidate.html`;
- candidate head `9d4a52df566d74bdc77f92b0d227906fc46bddce`;
- public fallback `index.html`;
- promotion status `not_promoted`.

## Required after this exposure commit
On the exact exposure SHA require all of the following:
1. v145 Dashboard stability workflow SUCCESS;
2. legacy candidate-smoke SUCCESS;
3. v144 Updates smoke SUCCESS, proving the inherited Atualizações/classification surface remains intact;
4. Pages SUCCESS;
5. protected public `index.html` blob still exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`;
6. manifest resolves to v145 / `wip35-v145-candidate.html`.

Only after all exact-SHA gates are green may the user be told to re-check the fixed homologation URL.

## Open blockers carried forward
- real authenticated visual E2E remains pending/unclaimed;
- guided document association and improved PDF/image interpretation with manual review;
- authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`;
- authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics;
- Mastercard/Visa historical documentary gaps;
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps, no fabricated post-2029 TR;
- Volvo exact trim/km before valuation refinement;
- Open Finance pricing/SLA/product×bank coverage; no consent/spend without explicit user decision;
- human classification where evidence remains ambiguous;
- public `index.html` promotion only after explicit user approval.
