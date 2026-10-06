# V258 — evaluate each documentary row and merchant key once

The patch changes only two existing private STABLE SQL readers. It materializes the normalized target merchant key once in lts_bank_known_classification_v231 and the corrected documentary composite once in lts_card_workbook_bank_rows_v1. The original conditions, priority, ambiguity rules, evidence, precision, fields and privileges are preserved. No new endpoint, cache, financial source, table, schedule or grant is created.

Production migration lts_v258_single_evaluation_readers was applied after all candidate transactions rolled back and the original definitions/ACLs were confirmed. Leases use the complete original pg_get_functiondef hashes and deliberately reject a second application. Existing source snapshots must never be archived or removed by this patch.

## Exact comparisons before deployment

- All 690 bank transactions: identical JSON and text; 31,011.976 -> 18,696.156 ms for the whole classification sample. Earlier 80-row pair: 3,430.046 -> 1,734.875 ms.
- All 4,821 documentary card rows: identical complete rows/serialized JSON, 2,719.374 -> 651.324 ms.
- Expenses 2026 YTD: complete report exact, 1,050 rows, 12,412.863 -> 7,618.625 ms; 2019–2020 exact, 8,147.436 -> 6,167.577 ms; July–August exact, 10,725.886 -> 6,936.752 ms.
- Whole 2026–2027 Flow: exact JSON/text, 730 days, 10,448.551 -> 9,102.651 ms. Separate classification-only pair: 11,100.268 -> 9,484.849 ms. Shared physical buffers were warm; the enclosing memo was missed in each variant. These are SQL timings, not browser times.
- Wealth: complete result exact except the explicitly volatile current_liquidity.computed_at timestamp; 2,508.104 -> 2,325.296 ms. This small difference does not prove a Wealth speed improvement.

The unrelated canonical-category reuse alternative was discarded: its apparent initial gain did not repeat with the order reversed. It is not included in the patch.

SQL QA files are maintenance-only rollback diagnostics. They resolve the owner dynamically, contain no owner ID, credentials or private financial payload, and write no financial source rows. Do not reapply this migration or treat historical unknowns as zero. RLS and function grants stay identical. Sources, remaining cold latency, real owner sign-in/iPhone/upload, Auth configuration, full isolated restoration and source-dependent financial gaps remain open.


## Readonly historical fallback

A real BEGIN READ ONLY miss exposed the legacy lts_browser_flow_v1 audit INSERT failing with 25006. Separate guarded migration lts_v258_readonly_history_audit preserves the table audit for each writable call and catches only read_only_sql_transaction to emit a server log with hashed principal and dates. Authentication, range checks, financial JSON and ACL remain unchanged. Other errors still propagate. The normal audit regression proved one row for each call and exact serialized output. No readonly setting is overridden, no policy or permission is weakened.

The 15:15 BRT source refresh added eight expense rows. A fresh inverse comparison on those 1,058 rows also passed: candidate 8,597.635 ms versus original 14,470.304 ms, digest cb0966c24cb97f6ba187520602dfbaa0. Earlier fixed digests must not be treated as current financial values after a legitimate source update.
