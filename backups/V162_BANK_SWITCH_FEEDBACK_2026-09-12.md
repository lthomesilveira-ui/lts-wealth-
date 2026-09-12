# User feedback — bank switching, Bradesco and semantic recovery

12/09/2026. Read after the integrated-publication checkpoint. This is a UX candidate and durable feedback record; CI/publication evidence must be checked separately.

## What the user reported
The inspected Itaú balance/invoices appear correct. Bradesco reportedly did not open. The first screenshot shows a historical-reconciliation warning and a no-movement day; it does not capture an invoice failure. Another screenshot shows C6 selected while the Itaú invoice is still displayed. Expanded days also remain open across banks. The C6 payment row carries a pending-classification label. These observations are distinct; do not claim the warning explains the opening failure.

## Implemented UX contract
Different bank selection clears the daily expansions and summary/full/loading invoice context, including transitions through Consolidado. Returning to the prior bank starts closed. Same-bank selection preserves its disclosure. Keep the chosen dates and existing default window; reset only transient detail state. Invalidate outstanding invoice requests so delayed success/error/finally cannot resurrect the previous bank's panel or replace a newly opened invoice. Closing the panel and collapsing its owning day also cancel that view's result. No financial mutation or classification was executed.

Code changes are inside the existing recovery owner and its cache-keyed shell. No extra runtime wrapper or permanent observer/timer. Existing financial reads, protected index and prior invoice presentation are preserved. Expanded automated coverage uses isolated source-shape fixtures on Chromium desktop/mobile and WebKit mobile, including the actual observed cross-bank sequence and network-race cases.

## Bradesco checks and unresolved question
Controlled authenticated read-only database lookup returns the current Aeternum as matched, open, all 96 rows, total equal to detail. The smaller generic Bradesco event has no exact current document/cycle match. Historical-reconciliation metadata is independent. Ask only which date/card the user attempted to open if still needed. No invoice source needs re-uploading.

## Next phase explicitly requested
Finish Flow/UX closure first. Then comprehensively restore historical classification using the original spreadsheet and validated LTS nomenclature, both for Flow/bank events and card purchases. Restore review/reclassification from the Flow rather than limiting the work to the card queue. Preserve Categoria/Grupo/Macrogrupo and existing cost-center terminology. User decisions outrank heuristics; use exact reliable history before asking. Separate genuinely unknown cases from lost mappings/reader regressions. Do not misinterpret payment of a card invoice as another purchase or classify an ambiguous intermediary by merchant guess. No pending tag should be hidden merely to make the page appear complete. Raw evidence, dates, bank, amount and economic effect remain unchanged.

## Acceptance boundary
The user's partial positive feedback is not full Flow approval. Bradesco opening failure, historical residual, other-card evidence gaps and the real-session classification lifecycle remain tracked. Bulk classification remains unreleased. CI PASS and publication must be recorded separately; signed-in user-session/iPhone E2E is not claimed. All other master-backlog items and confirmed financial decisions remain preserved.
