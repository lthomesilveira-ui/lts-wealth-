# Synthetic local/unit label gate

Copy these source files into `.github/fixtures/labels-v282/`, with the eight reviewed assets in `candidate/` beside them. Run from repository/package root, with the unchanged published baseline in `releases/v282/`:

`node .github/fixtures/labels-v282/run.cjs`

This executes 198 assertions (65 + 28 + 26 + 69 + 5 + 5) and syntax-checks the Playwright hooks. It does not start a browser, connect to any service, execute SQL or call a financial writer. The tests write their synthetic result JSON files beside the scripts; generated results are not source inputs.

Public baseline file contains only 67 published V282 asset names/hashes plus the published commit. Test rows/amounts/identities are invented. Product category constants (including the explicitly tested Benjamin prefix) are not transaction records. No real source UUID, exact transaction amount, private source document, original workbook, audit receipt or dimension investigation is included.

Only paths and the public baseline-hash input were adapted from the reviewed local tests. Assertions and candidate product bytes are unchanged. Do not copy the parent directory or any private audit report into CI.

Playwright hooks are opt-in helpers for an existing synthetic, network-blocked full-stack gate. Execute that gate separately in the 320/390/1440 viewports, preserving canonical ledger/session/range scenarios; the unit command does not certify browser/visual behavior.
