# Synthetic gate: person-context copy only

This package is a local CI proposal, not a release or deployment. Review the exact `PUBLIC_ALLOWLIST.json` before copying it. It contains synthetic tests, public product labels and published release hashes only. It contains no transaction exports, user identifiers, private reports, credentials or private workspace paths.

## Run

Place the allowlisted package in `.github/fixtures/person-context-copy/` of a checkout containing the unchanged published `releases/v282/` and `releases/v283/` (67 files each). From the checkout root, with Node.js available:

`node .github/fixtures/person-context-copy/run.cjs`

No install, network, browser, SQL, remote Git or credentials are required. Do not include generated local investigation files or parent directories.

The runner verifies its complete public package inventory and hashes, then all V282/V283 source hashes. It creates an owned temporary workspace, preserves one immutable V283 copy and materializes a single-asset overlay in another copy. The overlay is represented by four exact preimage-checked substitutions in `overlay/edits.json`, avoiding bundling unrelated product content. The final asset hash must match `overlay-manifest.json`.

Only temporary copies are modified. The runner executes 108 new copy-only checks, 17 unchanged detail/export-function checks and the existing 198 hash-pinned V283 synthetic assertions: **323 total**. It verifies the original release inputs and public package again, then removes its temporary workspace. Generated receipts never modify this package or the checkout. The final JSON line reports the assertion count and immutable-input verification.

## Scope

The overlay displays the existing residual context bucket as “Demais grupos” and removes the claim that categories without a person's name belong to the owner. Internal grouping keys, member rows, totals, raw selectors, people already displayed, review queue, writers, pagination and CSV behavior remain unchanged.

The tests distinguish synthetic generic, explicit-person and technical-NULL nominal-category inputs, preserve Lucas/Larissa/Benjamin/Rafiki raw labels and verify that identical visible headings never merge raw groups. Product names in these invented fixtures are not private transaction data.

This does not solve the known missing-provenance dimensional contract or remove pending markers. It does not certify browser layout, production state, backend behavior, deployment or a later release base. The integrator must revalidate the effective final base and its aggregate CI separately. No release manifest or application entrypoint is changed by this package.

`legacy/` contains the eleven unchanged source inputs required by the existing 198-assertion gate. Its older V282 filenames and label-manifest description are retained deliberately; the wrapper applies only the new copy overlay and runs those tests against the copied V283 assets. The Playwright file is syntax-checked only; no browser launches.
