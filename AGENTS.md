# LTS Wealth — product rules

## Main interface

- The owner repeatedly requires a professional financial app, not a diagnostic screen. Do not put backend vocabulary, processing explanations, source identifiers, raw errors, reconciliation mechanics, or reassuring implementation narratives in the main interface.
- Show financial information, actions, and concise human-language warnings. Put provenance and separate consultation/source timestamps under a discreet **Atualização** or **Origem** disclosure, closed by default. Do not render healthy/empty diagnostic banners.
- A material uncertainty affecting a number must remain visible, briefly and in plain language, with a concrete next action. Moving diagnostics must not hide a missing payment, incomplete projection, unavailable balance, or genuine inconsistency.
- Check the actual rendered Flow and Dashboard at desktop and mobile widths. Add assertions for visible text and collapsed-state height; a source-code search alone does not verify the interface.
- Keep financial totals, dates, history, classifications and already approved functionality unchanged except for the specific requested correction. Never edit an already published release; publish a new version.

## Mandatory clean-report acceptance

- Read `UX_ACCEPTANCE.md` before changing any screen, report, chart, export or user-facing message. These requirements persist independently of conversation memory and apply to all future releases.
- Main reports answer financial questions: amount, date, projected result, material uncertainty and useful action. They are not a place to explain implementation or repeat internal calculation rules.
- Never render raw backend fields, SQL/RPC details, cache state, processing stages, internal version identifiers, validation narratives or source hashes as report copy. Do not translate technical diagnostics into long reassuring banners either.
- Calculation detail belongs in a deliberately opened, discreet **Premissas** disclosure when useful. Human-readable provenance belongs in **Origem** or **Atualização**. Raw technical details belong only in private diagnostics, not even in those customer disclosures.
- Preserve concise material warnings next to the affected number. Do not hide an incomplete result, substitute zero for unavailable information, remove a financial risk, or imply a failed update succeeded merely to make the screen cleaner.
- A release affecting the interface must include rendered default-state and expanded-state evidence on mobile and desktop, visible-text checks for technical leakage, and checks that warnings do not dominate the viewport. A successful server call or a clean source-code search is not visual acceptance.
- Documentation or a new test requirement alone does not mean existing interface defects have been repaired. Track the actual correction, publication and rendered verification separately. Preserve the owner's screenshots privately; never publish financial screenshots or personal explanations in this public repository.

## Accounting and evidence

- For history through July 2026, consult the owner's original Excel before merchant research or classification suggestions. Its source-specific categories take priority over inferred merchant activity and MCC. Preserve any later explicit owner correction. Recover a beneficiary or property only when the source explicitly identifies it; keep unmatched context unresolved.
- A transfer between the owner's accounts is neither income nor an expense. Preserve both original bank legs and their per-account cash effects; consolidated effect is zero.
- Record a source-specific explicit owner confirmation and reuse it. Do not ask the same purpose or destination again. Keep conflicting raw provider data intact in private audit evidence; do not keep an explicitly answered item pending solely because a provider field disagrees.
- Do not generalize one confirmed transfer to unrelated transfers. Matching amount, date or name alone is not enough for automatic pairing.
- Invoice payment is not a second expense; corporate cards are outside personal spending. Attribute a person only when specifically identified.
- A future or overdue scheduled movement is not a realized payment without evidence. Never erase overdue forecasts merely to clear a queue.
- When the owner changes a forecast averaging window, record the exact authorized scope in the private decision register. Update only those series, retain the existing window for unrelated series, use complete documented periods, and verify known-obligation precedence and no double counting. A proposed explanation for unusually large expenses is not authority to delete or reclassify those expenses.

## Delivery

- Work autonomously within the existing project authorization; do not request routine approval. Do not perform payments or money transfers.
- Report what was actually changed and tested, and state the remaining limitations honestly. Do not certify real-device, private-session, source, or full-backlog completion from synthetic browser fixtures.

## Flow options hierarchy

Read `UX_FLOW_OPTIONS.md` before editing Flow. Standalone collapsed premise/source panels still clutter the main report. Use the existing Options control, preserve material warnings and verify rendered default/open states.
