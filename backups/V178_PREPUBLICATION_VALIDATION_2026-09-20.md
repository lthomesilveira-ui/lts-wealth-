# V178 — Integrated review validation — 20/09/2026

Status: VALIDATED IMPLEMENTATION; NOT YET EXPOSED BY THE HOMOLOGATION MANIFEST.
Baseline: V177, protected public index SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`.

## Authorization and private continuity
The user ended feedback collection and authorized this integrated implementation, including the final RSU requirement. Full private decisions and examples are in the user's Library:
- `/LTS Wealth/Feedbacks/LTS_WEALTH_V177_REVISAO_USUARIO_2026-09-20.md`
- `/LTS Wealth/Feedbacks/LTS_WEALTH_V178_VALIDACAO_E_PENDENCIAS_2026-09-20.md`

Do not publish personal transactions, beneficiary/provider associations, financial amounts, screenshots of real accounts, auth tokens, or private SQL decision payloads to this public repository. Server-side migration history is the authoritative implementation record for private rules. The prior raw financial rows and public index have not been rewritten.

## Verified browser behavior
Integrated CI run `35539719210` on `c1eb693becefdd2af219c80dddd2ed22478689b7` completed SUCCESS, including:
- JavaScript syntax and protected index hash.
- Deliberate cash and forecast failures, recovery in place, negative and zero cash, null component, and date rollover; incomplete totals are never presented as complete.
- Independent short cash read and forecast; missing secondary future/pension components block an apparently complete subtotal.
- Drawer with 1,207 synthetic rows, three pages, final row visible on desktop and 390px mobile, scroll position retained on background render, search finding the last row, failed intermediate page/retry, and late-response cancellation after group switch.
- Property navigation starts with useful components instead of a mixed transaction list.
- Dashboard YTD and expense report periods remain independent and are propagated into detail requests.
- Full history remains 156 months with bounded yearly detail rendering.
- RSU position changes at vesting, not again at settlement. No RSU bank entry, no extra inline row height, noncash event detail only when the day is expanded; cash-only hide-zero preserves genuine same-day in/out with zero net.
- Pending-identity drawer/export, complete CSV despite a search filter, safe formula-text encoding, signed credit values, and access to categories after item 99.
- Protected predecessor static contracts plus Flow, bank scope, invoice order and documentary roll-forward regressions. Baseline browser tests include WebKit mobile.

The browser data above are controlled synthetic fixtures. This is NOT a claim of testing the user's authenticated browser session.

## Verified private SQL behavior
After the final source-boundary patches, real authenticated reader tests passed for all history, YTD, six months, twelve months, and calendar 2020:
- row count, amounts at cent precision, stable unique keys, source-account/card classification and period boundaries preserved;
- known beneficiaries represented in management groups across categories, not just descriptions;
- explicit review decisions and prior source metadata honored;
- no unsupported assignment of unknown beneficiaries to the account holder;
- no restaurant-name substring misclassified as a property;
- executive groups, detail and monthly sums reconcile at cent precision;
- nine-page complete-history traversal has one data revision, no missing/duplicate keys, final next_offset null and no fabricated day for monthly-only sources;
- each unresolved-identity item has a concrete question in the private detail response;
- current-day cash endpoint returns a complete internally consistent canonical Flow calculation; it is not a live bank balance feed.

## Source limitations remain OPEN, not hidden
Some records still lack sufficient beneficiary or property identity, and some historical invoices lack individual purchase breakdown. These remain in economic totals and have explicit private review/export access. They are not silently assigned to a person, a property, or a fabricated day. The pre-existing April 2026 share-sale source gap is unchanged.

## Deployment gate
Before exposure: compare final branch against current main; preserve V177; merge via normal PR; publish only candidate and homologation manifest. Require GitHub Pages completion and the new published-asset/signed-out verification. Record actual release identities and outcomes, then update continuity/issue status. Do not mark factual source questions or human acceptance as closed.
