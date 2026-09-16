# V169 — V168 feedback closure published

Date: 16/09/2026  
Status: PUBLISHED IN FIXED HOMOLOGATION; PUBLIC ROOT UNCHANGED; HUMAN ACCEPTANCE PENDING

## Authorization and lineage

The user authorized sending V169 to `lthomesilveira-ui/lts-wealth-` for tests and publication only in homologation.

- V168 baseline / previous `main`: `59293c70baac6e0a1df25e9c42978b4d82b895a3`.
- V169 product head: `6c32ee78b19e1252e5615c8bc267e11f9e84ba5f`.
- Manifest exposure commit: `677e8a3fa4ccd52b6808962753cd191319c803d9`.
- Branch: `work/v169-v168-feedback-20260916`.
- Candidate: `wip35-v169-candidate.html`.
- Binding scope register: `backups/V169_V168_USER_FEEDBACK_REGISTER_2026-09-16.md`.

No force update was used. `index.html` stayed byte-for-byte unchanged with SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`. `promotion_status` remains `not_promoted`.

## Delivered scope

- Dashboard navigation spacing/alignment and V169 release ownership.
- Blue emphasis on the intended totals, not arbitrary cards.
- Clear labels for historical aggregate-only card evidence and the Coopharma payroll loan.
- Despesas > Cartões: future values by bank and month, separating known invoices from the contracted installment floor.
- Despesas > Balanço mensal: monthly revenues, extraordinary entries, consolidated expense groups, operating balance and balance after extraordinary entries, with explicit anti-double-counting rules.
- Patrimônio: Coopharma and Pai/Mãe obligations are visible while current payoff debt remains separate from scheduled future outflows.
- User-created internal transfers: both linked legs receive edit and delete controls; edits/cancellations are atomic and retain audit history.
- Brazilian-real presentation for the internal transfer in Dashboard/Flow.

## Data and audit evidence

Applied Supabase migrations:

- `canonical_v169_v168_feedback_2026_09_16`;
- `canonical_v169_flow_audit_contract_fix_2026_09_16`.

Authenticated QA covers 10/10/2013 through 16/09/2026: 4,724 expected and returned civil dates; zero missing dates; zero duplicate dates; zero daily-net mismatches; zero relative-balance mismatches; zero unsupported leaks. The paired-transfer reader returns exactly two linked legs with zero consolidated effect. No live validation mutation was performed.

## Exact automated evidence

- Branch V169: `35152832476` — SUCCESS.
- Main V169 before manifest: `35153170553` — SUCCESS.
- V168 compatibility before manifest: `35153170516` — SUCCESS.
- Product Pages before manifest: `35153169310` — SUCCESS.
- Post-manifest V169: `35153624108` — SUCCESS.
- Integrated Flow and invoices: `35153624205` — SUCCESS.
- Flow default window: `35153624105` — SUCCESS.
- Candidate smoke: `35153624208` — SUCCESS.
- V163 compatibility: `35153624116` — SUCCESS.
- V164 compatibility: `35153624211` — SUCCESS.
- V165 compatibility: `35153624175` — SUCCESS.
- Manifest Pages deployment: `35153622917` — SUCCESS.

The V169 gate exercises desktop and mobile layouts, Chromium and WebKit protection gates, monthly-period propagation, bank filtering, explicit liabilities, BRL formatting and paired transfer edit/cancel RPCs with controlled fixtures. Controlled fixtures are test evidence, not user financial data.

## Published browser verification

The fixed homologation entrypoint was opened after the manifest Pages deployment. It resolved to the exact V169 candidate with `homologacao=6c32ee78b19e1252e5615c8bc267e11f9e84ba5f`; the page title was `LTS Wealth · Homologação V169` and the visible product brand was `V169 · Homologação`.

The browser already held an authenticated session and the private product body was still loading when this publication check was captured. Therefore this receipt proves routing/title/brand publication, not a fresh signed-out login transition, complete private-data rendering, physical-device behavior or human approval.

## Next gate

The user should inspect V169 through the fixed homologation link on the intended notebook/phone session. Any new feedback belongs to a later version; this V169 receipt remains immutable.
