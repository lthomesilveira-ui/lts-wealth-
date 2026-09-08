# Canonical app v1.12 Reviewed Text Input checkpoint — 08/09/2026

## Purpose
- Preserve a concrete V150 capability that was lost on the canonical line: reviewed natural-language input inside `Atualizações`.
- Make the operational source of truth explicit so future chats cannot mistake a documented checkbox for a rendered, tested product surface.
- Preserve v1.11 layered liquidity, v1.10 decision truth, v1.9 V150/V151+ Flow parity and all later security/session improvements.

## Exact release
- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product base: v1.11 closure `23ac0307bf675e9507b8d366ebc6dd3c92d81569`.
- Product commit: `70c49b1b50b7faca09b71889e14d33183a7f9092`.
- Product tree: `3001bc89241f08f2b8a6e52c8288097a42675572`.
- Fixed-manifest exposure commit: `adac528dbde6d0dcd6268a52c780d3abf43dc9a9`.
- Exposure tree: `f1dc18bb4fb03a330e259fe37420db66611f8a00`.
- Input contract: `review-before-explicit-apply-v1`.
- Writer contract: `lts_browser_apply_reviewed_input_v1`.
- Parser: `phrase-preview-v1.0-canonical`.
- Build label: `LTS v1.12 · Lançamento revisado`.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Public `index.html` remains blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; `promotion_status:not_promoted` remains binding.

## Historical finding
- `wip35-v150-recomposition.js` contains the visible `Lançamento por texto` tool and an explicit review action.
- Canonical v1.11 `updatesView()` contained queue, transaction search, classifications and documents, but no text-input surface.
- `PROJECT_MASTER_BACKLOG.md` and `LTS_WEALTH_REQUIREMENTS_TRACEABILITY.md` nevertheless described the input as implemented. V1.12 resolves that source/product contradiction.
- The recovered project history did not establish one final approved standalone Reports visual. V1.12 therefore does not invent one; existing executive JSON/recurrence CSV controls remain preserved until stronger evidence or explicit user direction exists.

## Product behavior protected
- A natural phrase produces an editable proposal; it is not a financial fact.
- Date, amount, nature, account, card, category, context/person, counterparty and description remain editable.
- Date, positive value, description and an account or card are required before confirmation.
- Known account/card/category/context proposals are bounded to explicit lexical evidence; unknowns stay `A classificar` or blank.
- Supported value forms include `5 mil`, `R$5.000`, `5000`, `3k` and `R$1.250,50`.
- Preview sets `write_allowed:false`. A real submission requires the review checkbox, an explicit confirmation button, one idempotency key and post-write product/cockpit readback.
- Fixture mode renders review evidence but no apply button; the gate requires both `writer_called:false` and `write_accepted:false`.
- Applying/rescuing bank liquidity and RSU operations remains in its separate equal-and-opposite movement surface with economic effect R$0; text input cannot silently convert those movements into income or expense.

## Deterministic evidence
- Local permanent gate: PASS in Chromium desktop 1312×1199 and mobile 390×844.
- Local visual evidence was reviewed for `Atualizações` desktop/mobile and the protected V150 Flow surface.
- Recovery product gate `34235638676`: SUCCESS in Chromium desktop + WebKit mobile.
- Recovery candidate smoke `34235638646`: SUCCESS.
- Canonical gate `34235911409`: SUCCESS on the exact same product commit.
- Canonical candidate smoke `34235911280`: SUCCESS.
- Main candidate smoke `34236205811`: SUCCESS.
- GitHub Pages `34236204118`: SUCCESS.
- Post-exposure recovery/canonical/main smokes `34236480960` / `34236541857` / `34236635343`: SUCCESS.
- Post-exposure GitHub Pages `34236635451`: SUCCESS.
- Recovery artifact `10059792070`, digest `sha256:db41ecbe329e9166c60241a4461fd33ef963aedd3a7953ac072356cbcc0e3eae`.
- Canonical artifact `10059891042`, digest `sha256:a84c36b967cba64d524241a19a476d7a9747386046b7bb86799f4b8a328e34eb`.
- The permanent receipt adds `reviewed_input: PASS_AUTOMATED_PREVIEW` while retaining all six routes, Dashboard, Flow, Despesas, Cartões, Patrimônio, Central de Gestão, route/session, unauthenticated truth and overflow regressions.

## Live fixed-URL evidence
- The fixed URL resolved to `canonical-app.html?homologacao=70c49b1b50b7faca09b71889e14d33183a7f9092&…#Dashboard`.
- GitHub Pages loaded `canonical-liquidity.js?v=20260908-input12`.
- Signed-out state rendered the real LTS Wealth login, not fixture financial content.
- Zero iframes were present. The reviewed-input module is intentionally deferred until the authenticated canonical product is ready.

## Validation boundary
- CI and local fixture tests prove the review/guard UI and prove that fixture writes do not occur.
- They do not prove one authenticated financial save or physical-iPhone behavior.
- Authenticated save→refresh→visible readback, production failure/retry behavior and physical-iPhone validation remain open and must not be inferred.
- Public-root promotion is not authorized and was not performed.

## Next execution sequence
1. Preserve v1.12 product `70c49b1…` and exposure `adac528…` as the current baseline.
2. Continue the two-project audit and the next evidence-backed product gap without inventing a standalone Reports model that was not recovered.
3. Close authenticated input/search/classification/document/backup-restore and physical-device receipt rows only with actual evidence.
4. Preserve every documentary/reconciliation/Open Finance dependency; provider, consent, spend and public-root promotion remain explicit user decisions.
