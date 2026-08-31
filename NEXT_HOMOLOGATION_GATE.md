# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Fixed homologation now targets **v145** via `wip35-v145-candidate.html`.
- Exposure SHA: `a99483543f3d1408be5b297dc66ec5f491be68dd`.
- Manifest candidate head: `9d4a52df566d74bdc77f92b0d227906fc46bddce`.
- Promotion status: `not_promoted`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v145 reason and correction
User material homologation of v144 found a real Dashboard title/subtitle flicker. Proven root cause was competing inherited cycles: v142 could repeatedly refresh/render the cockpit while v143 feedback polish rewrote the approved copy.

v145 is a stability-only correction:
- final H1 is generated as `Sua vida financeira, em uma tela.`;
- final subtitle is generated as `Tenho dinheiro hoje? O que exige ação? Para onde estou indo?`;
- inherited repeated Dashboard polling is locked after valid cockpit data exists;
- explicit read-only one-shot refresh remains available;
- no permanent v145 interval was added;
- v144 Atualizações/classification action center remains inherited;
- no financial rule, value, classification, backend writer or economic effect changed.

## Evidence before exposure
- Product commit `8ccd9fc6eca1f7da833f80b9788fefd98c601f18`.
- Hardened candidate/integrated SHA `9d4a52df566d74bdc77f92b0d227906fc46bddce`.
- Hardened branch run `33423228532`: SUCCESS.
- Integrated-main v145 run `33423462471`: SUCCESS; artifact `9769869448`.
- Integrated-main Pages `33423461388`: SUCCESS.
- Desktop 1440×1000 and mobile 390×844 temporal smoke: one title, one subtitle, `renderDelta=0`, `rpcDelta=0`, zero overflow/errors.

## Exact exposure-SHA evidence
All on `a99483543f3d1408be5b297dc66ec5f491be68dd`:
- v145 Dashboard stability `33424045510`: SUCCESS.
- v144 Updates/full ownership smoke `33424045367`: SUCCESS.
- legacy candidate-smoke `33424045318`: SUCCESS.
- Pages `33424044022`: SUCCESS.
- `homologacao-current.json` resolves v145 / `wip35-v145-candidate.html`.
- public `index.html` remains exact protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

This is synthetic/unauthenticated browser evidence. It is not authenticated visual E2E and executes no backend financial write.

## Financial/backend invariants — unchanged
- Planning: management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; existing accrual R$3.700/mês; request-date FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027.
- Despesas invariant R$8.623.752,53; cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 remains aggregate-only; C6 Aug/2024 R$66,70 gap explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle; R$578,68 historical sale difference remains unitemized.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031, no duplicate economic effect.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS plus supplemental 16/16.

## Open blockers retained
- Human classification where evidence remains insufficient.
- Guided document association and improved PDF/image interpretation with manual review.
- Authenticated classification save→refresh/resolved-item disappearance/self-heal/`O que mudou`.
- Authenticated natural-liquidity save→refresh→visible result and append-only cancellation/reversal semantics.
- Mastercard/Visa documentary gaps; never infer purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps; no fabricated post-2029 TR.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend without explicit decision.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.

## Current gate to advance
1. User performs **material visual homologation** of v145 at the fixed homologation URL, focusing first on Dashboard stability and then a quick Dashboard ↔ Atualizações transition.
2. If a material regression appears, open a new corrective package; do not patch public `index.html` directly.
3. If user approves the candidate, public promotion still requires a separate explicit authorization.
4. Until public promotion, protected public fallback remains untouched.
