# LTS Wealth — Next Homologation Gate

Purpose: evidence-backed sequence before asking the user to inspect a material candidate. Keep aligned with `PROJECT_MASTER_BACKLOG.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md` and immutable checkpoints.

## Current release baseline — 02/09/2026
- Public fallback: WIP35-v136 in `index.html`, unchanged; protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Fixed homologation currently serves **v148** through `wip35-v148-candidate.html` after the visible-version ownership correction.
- v148 corrected product SHA: `333bb3c4eb06c8e68d9de0c637da37c09db43989`.
- v148 exact exposure SHA: `966db03a64fdfadb4d27656044f220624f8debaf`; exact exposure Pages, candidate-smoke and v144–v148 workflows all SUCCESS.
- Fixed homologation stays v148 while v149 is integrated/gated so the user can continue testing today's resolved items.
- Promotion status remains `not_promoted`.
- Public promotion: NOT AUTHORIZED / NOT DONE.
- Authenticated visual E2E: PENDING / NOT CLAIMED.

## v149 document interpretation review — exact green branch evidence
- Scope: read-only PDF/image interpretation review layered on explicit v147 document association.
- Structured extraction is evidence only and remains separate from the association explicitly provided by the user.
- Missing required association is visibly manual; filename never infers account, card, competence, date or amount.
- No financial posting, reconciliation, category inference, balance effect or new financial writer.
- v148 save→refresh classification lifecycle remains preserved beneath v149.
- Exact green product/gate SHA: `050ca36dd14d4ffdbaa27dbfdfc579ddbfe54331`.
- Workflow `33692647025`: SUCCESS; job `100454598090`: SUCCESS.
- Artifact `9870669700`; digest `sha256:e470c3d9c46feb622b42371606cb11d0712ba057c6a4668ce2419e1b533d26ff`.
- The same run passed static architecture, button contracts, parser, v146 repeated navigation, v147 guided association, v148 classification lifecycle and v149 desktop/mobile smoke.
- v146 regression remains 10 cycles × 7 destinations × desktop/mobile = **140 physical Playwright clicks**.
- v149 smoke proves `financial_writer_changed=false`, `rpc_calls=0`, `filename_inference=false`, `manual_review_required=true`, `permanent_polling=false`, stable v149 visible labels and zero relevant browser errors.
- First v149 gate exposed a self-triggering label `MutationObserver`; the product was corrected with idempotent stamping before the green evidence above.
- Immutable checkpoint: `backups/WIP35_V149_PREINTEGRATION_CHECKPOINT_2026-09-02.md`.
- This is synthetic/unauthenticated browser evidence. Real authenticated PDF/image interpret→review and authenticated visual E2E remain pending/unclaimed.

## Current gate — v149 safe integration
1. Recompare `main` and `v149-document-interpretation-review` immediately before integration.
2. Require `main` to be an ancestor of the v149 branch with no divergence/behind commits.
3. Fast-forward `main` normally with `force=false`; do not change `homologacao-current.json` in the integration step.
4. On the exact integrated-main SHA require the v149 workflow SUCCESS, inherited v146/v147/v148 gates SUCCESS, Pages SUCCESS and protected `index.html` blob exactly `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
5. Keep fixed homologation v148 while the user is testing. v149 exposure is a separate controlled decision after integrated-main gates are green.
6. If/when v149 is exposed, use `promotion_status: not_promoted`, rerun exact exposure gates and verify the served fixed URL before requesting material homologation.
7. Public root promotion remains a separate explicit user authorization.

## Material checks already expected on current v148 fixed homologation
- Repeated navigation, especially `Cartões` → `Patrimônio`.
- Dashboard title/subtitle stable with no flicker.
- Atualizações remains classification-first with evidence/confidence and manual ambiguity handling.
- Guided document association requires explicit identity/competence/as-of and displays a visible reason when incomplete.
- Classification save→refresh removes a resolved item and shows `O que mudou`; safe read-only verification retry must not duplicate the writer.
- No large blank/whitespace regression on desktop/mobile.

## Financial/backend invariants — unchanged
- Planning: management point 08/01/2027; FGTS request-by 09/12/2026; documentary FGTS R$17.509,05; existing accrual R$3.700/mês; request-date FGTS R$32.309,05; worst before -R$21.046,80; worst after +R$11.262,25; no uncovered gap through 28/02/2027.
- Despesas invariant R$8.623.752,53; analytical cache 3.860/3.860 exact.
- Card certified allocation 38 cycles / 650 rows / R$885.855,19; aggregate fallback 314 rows / R$2.650.846,36 stays aggregate-only; C6 Aug/2024 R$66,70 gap remains explicit.
- RSU vested 459.483 units / R$32.772,30 / D+3; future awards excluded until vest/settle; R$578,68 historical sale difference remains unitemized.
- Volvo financing 60 × R$2.886,43 from 08/09/2026 to 08/08/2031, no duplicate economic effect.
- Backend fingerprint `85a1b60816a5b84dfe3b41341ed27948`; staged 411 checks / 35 suites PASS plus supplemental v143 16/16.

## Open blockers retained
- Human classification where evidence remains insufficient; GULA GULA MORUMBI/marketplaces remain manual where purpose is unproven.
- Real authenticated classification save→refresh/resolved disappearance/self-heal/`O que mudou`.
- Real authenticated PDF/image interpretation→review after v149 integration/exposure.
- Authenticated natural-liquidity save→refresh→visible result.
- Append-only auditable cancellation/reversal semantics; no destructive financial behavior by assumption.
- Expense density/insight refinement and evidence-only reduction of `A classificar`.
- Mastercard/Visa documentary gaps; never pattern-fill or infer purchase detail.
- CIPÓ R$303,60 delta, overlap/date ambiguity, condominium source, raw/dedup gaps and duplicate excess; no fabricated post-2029 TR and no automatic taxable/net-gain conclusion.
- Volvo exact trim/km before valuation refinement.
- Open Finance pricing/SLA/product×bank coverage; no consent/spend/credential/provider commitment without explicit user decision.
- Real authenticated visual E2E.
- Public promotion only after explicit user approval.
