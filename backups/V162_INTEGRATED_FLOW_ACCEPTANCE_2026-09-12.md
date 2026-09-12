# Integrated Flow — implementation and automated acceptance receipt

Date: 2026-09-12. This receipt separates applied financial data, consumer tests, browser fixtures, publication and human approval. Detailed implementation is in V162_INTEGRATED_FLOW_RECONCILIATION_INVOICES_2026-09-12.md.

## Exact tested product
Product f202ec7f24f832952ba62b9d27ab9d179135280a; tree 0f967d91858af39c4123997c6743c6a41410cb62.
Recovery smoke 34696883261: SUCCESS.
Default-window contract 34696883239: SUCCESS.
Integrated Flow/invoice contract 34696883289: SUCCESS.
Integrated artifact 10299535213, SHA-256 326fa4912de65d1d134a1b2b9683ac2748d4e23b8c61bb7e96e6b824e1aa05e3. Receipt and screenshots were downloaded; representative WebKit mobile summary and complete credit-detail captures were visually inspected.

All three integrated profiles passed: Chromium desktop 1440x900, Chromium mobile 390x844 and WebKit mobile 390x844. Five documented card-name shapes plus one deliberately unmatched generic case were tested. Assertions cover summary/full/back/close, descending category totals, separated due/cash dates, source-only year/final fields, pending credits, default/manual/bank-filter ranges, stateful classification save-refresh-reload, late route stability, zero page errors and zero horizontal overflow. CI uses isolated fixtures and no real financial writer.

## Applied source data and real consumer QA
The supplied current Itaú statement was applied in an allowed transaction through the same authorized Supabase connector. Six missing facts, two separately audited forecast substitutions, four dated closes and the current source-date anchor were read back successfully. No original forecast was deleted; no balancing cash transaction was fabricated. The original PDF/Drive provenance and financial before-image are in the private applied source_documents record.

Integrated real-input consumer assertions completed in approximately 1570.9 ms under an eight-second limit. They checked dated Itaú closes; six unique source facts; old forecast absence; single card cash events; the three current source invoice sums/counts; due versus cash dates; wrong bank/month and undocumented current Prime rejection; C6 pending-credit separation; preserved financing, Larissa, insurance, Cofrinho and rejected-DDA decisions. The current Bradesco/C6 positions agree with the user's evidence. The historical Bradesco residual is explicit, not silently cleared.

The consumer receipt and checksumed definitions of the changed Flow/invoice functions are privately retained under integrated_consumer_qa_20260912 and runtime_definition_snapshot_20260912. An anonymous-access probe was rejected and anon execution is denied. No RLS/authentication boundary was relaxed. A daily-backup invocation returned inserted=0 and is not claimed as a newly created full backup.

## What the tests caught before main exposure
The first integrated test caught an unconnected preserved inline entrypoint; it was wired to the common invoice renderer. A later assertion was normalized for CSS uppercase/nonbreaking-space rendering without dropping behavioral checks. The classification lifecycle then exposed a missing toast helper after saving; the shell now supplies bounded accessible feedback. All checks were repeated after these corrections. Failed drafts were kept off main.

## Publication boundary
The manifest metadata package selects this tested product. Its deployment/main post-manifest tests must be checked before reporting the URL live. Public index.html remains byte-for-byte protected, and promotion_status remains not_promoted. This is a fixed-homologation exposure, not approval of Dashboard or all modules.

## Open gates
Human signed-in/physical-device homologation and actual-session classification persistence are not claimed by fixture or controlled-database tests. Bulk classification remains gated. The current other-Visa documentary gaps and the small historical Bradesco residual are explicitly retained. Existing master backlog plus PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md is the complete remaining list. Do not repeat old requests for the current Itaú/Aeternum sources or treat their applied data as still blocked.
