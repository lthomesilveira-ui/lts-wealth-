# V439 backend and V440 independent candidate

This package contains generic dated card-spend provisions, fictional regression tests and a complete independent V440 frontend release based on immutable V439. It does not change the default mobile loader or seed an owner's policy.

Run `npm ci --ignore-scripts`, then `PROVISION_UI_FILE="$PWD/ui/lts-v412-projection-policy.js" node test_candidate.mjs` and `node ui/test.cjs` from this directory. Run `node .github/scripts/lts_v440_release_contract.cjs` from the repository root.

The default UI test exercises the model and isolated DOM only. Full rendered Chromium/WebKit desktop/mobile acceptance remains pending. Do not call these checks authenticated-device verification.

The dated provision migration is separate from `backend/patches/v439/refresh-prepare-cache-guard.sql` and `history-readonly-cache.sql`. These two guarded technical patches record earlier independently installed refresh/cache fixes. Do not blindly reapply an already installed guarded patch. No SQL in this PR is applied automatically by its frontend publication.

The independent entry is `releases/v440/app.html`; the loader remains V439. A branch or draft PR is not a deployed preview. Publishing requires separately authorized merge and a successful GitHub Pages deployment, then verification of the served release hashes. Full application review and any later default promotion remain separate steps.

## Incremental reconciliation

The original dated-provision migration remains byte-identical. The separate `20261112012739_v439_reconcile_verified_card_obligations.sql` migration adds generic support for a private allowlist of source-verified legacy card obligations. Public code contains no private allowlist entries. Unverified obligations must remain unresolved rather than guessed or silently counted as zero. The change reconciles projection inputs without mutating source transactions or obligations.

Run the additional fictional regression suite from `backend/qa/v439-reconciliation` using `npm ci --ignore-scripts` and `PROVISION_UI_FILE="$PWD/../v439/ui/lts-v412-projection-policy.js" node test_delta.mjs`. These tests do not establish owner-policy installation, all-month live coverage, or authenticated UI acceptance. Those checks remain separate publication gates; no default loader promotion is included.
