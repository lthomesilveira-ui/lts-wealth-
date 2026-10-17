# Synthetic unit gate for the real V283 release

Copy only these 13 source files into `.github/fixtures/labels-v283/`. Run from repository/package root containing the unchanged published baseline in `releases/v282/` and the actual release under review in `releases/v283/`:

`node .github/fixtures/labels-v283/run.cjs`

The tests read V283 product assets directly. No `candidate/` directory, fixture asset copies, response overrides or product edits are used. `manifest.json` records the eight reviewed before/after asset hashes; the separate release gate must verify the full served release and its manifest.

This executes exactly the existing 198 assertions (65 + 28 + 26 + 69 + 5 + 5) and syntax-checks the unchanged Playwright hooks. The six test assertions and fixtures were preserved; only candidate paths were adapted from the V282 overlay gate. The filename `test_v282_roundtrip.cjs` remains unchanged to preserve the reviewed source inventory; its baseline is V282 and its candidate is now the real V283 release.

The runner does not start a browser, connect to any service, execute SQL or call a financial writer. Tests write synthetic result JSON files beside the scripts; generated results are not source inputs.

The public baseline file contains only 67 published V282 asset names/hashes and the published commit. Test rows/amounts/identities are invented. Product category constants (including the explicitly tested Benjamin prefix) are not transaction records. No real source UUID, exact transaction amount, private source document, original workbook, audit receipt or dimension investigation is included.

`PUBLIC_ALLOWLIST.json` lists the other 12 source files and hashes. Do not copy the parent directory or any private audit report into CI.

Playwright hooks are opt-in helpers for the separate synthetic network-blocked full-stack gate. Run the release gate using the real V283 assets in the 320/390/1440 viewports, preserving canonical ledger/session/range scenarios. These unit results do not certify browser/visual behavior or publication.
