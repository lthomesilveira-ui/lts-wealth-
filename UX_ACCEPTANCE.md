# Financial interface acceptance

This document is a permanent product requirement, not optional copy guidance. Read it with `AGENTS.md` before authoring or reviewing a user-facing change. It does not certify that current screens meet the requirements.

## Default screen

A report should show financial figures, dates, chart labels, useful actions and only material financial qualifications. Do not fill the screen with process explanations, reconciliation rules, internal guarantees or implementation notices. The default expanded page must remain useful without reading explanatory banners.

No raw technical vocabulary or machine identifiers may leak into visible report text, including backend, payload, RPC, SQLSTATE, source_ref, source_fingerprint, epoch, internal function names, database/cache state, private hashes and stack traces. Financial words such as projection, estimated net value and unavailable balance remain legitimate and must not be removed simply because they describe uncertainty.

Do not replace a technical paragraph with a long human-language paragraph explaining the same internal process. Put genuinely useful calculation assumptions behind a discreet **Premissas** control, closed by default. Put understandable source and timestamp information behind **Origem** or **Atualização**, also closed by default. Private implementation details stay outside the customer report entirely.

## Failed, incomplete or stale data

Keep a short, relevant warning near the affected information and one concrete action where available. Keep the known value and its date when supported. Never turn missing data into zero, silently remove a risk, or certify an incomplete update. Distinguish financial shares from action-list tasks when choosing labels; do not guess what failed from the word “ações” alone.

Do not duplicate the same warning across cards, chart, section heading and footer. Healthy states and successful checks normally need no banner.

## Required verification for interface releases

1. Render the changed screen at mobile and desktop sizes, scroll through the whole screen and inspect the chart, financial cards and navigation. Include normal, loading, incomplete, failed and empty states that the change can affect.
2. Check visible text in the default state for raw diagnostic leakage and repeated process explanations. Check the screen with **Premissas**, **Origem** and **Atualização** closed; confirm that details remain closed after ordinary navigation and refresh.
3. Open each disclosure deliberately and verify concise financial assumptions or understandable source details, never raw diagnostics. Validate accessible labels and controls.
4. Assert unchanged financial values, dates, source identity and material warnings except for the explicitly authorized correction. Include no-double-counting and missing-is-not-zero cases when applicable.
5. Measure rendered warning/disclosure height or inspect screenshots to ensure these elements do not dominate the report. A source-code search, unit-only pass or successful server call cannot replace this check.
6. Record separately: implemented, tested synthetically, installed/published, and observed on a real authenticated device. Never label one as another. Existing published releases remain immutable.

## Private evidence

Use invented data for public test fixtures. Owner screenshots, balances, grant lots, health/family explanations and supporting documents belong in the private evidence register only. A suspected reason for an exceptional expense remains unconfirmed until the source identifies it. Do not erase history to make a projection look better.

## Completion rule

Changing this document or `AGENTS.md` persists the requirement; it does not repair an existing screen or prove that a future defect is impossible. Actual defects stay open until corrected and verified on the rendered result.

## Flow options hierarchy

Read `UX_FLOW_OPTIONS.md` before editing Flow. Standalone collapsed premise/source panels still clutter the main report. Use the existing Options control, preserve material warnings and verify rendered default/open states.
