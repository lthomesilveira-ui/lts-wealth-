# V292: query-local reuse for the review queue

Backend-only continuation of the published V291 application. No release assets or links are replaced.

## Applied change

- Compute eligible C6 source rows, invoice calendars and documentary source IDs once per identity query rather than repeatedly scanning them.
- Preserve C6 calibration, conflicts, payment exclusions, due dates and unresolved identities.
- Keep merchant normalization and management-group expressions unchanged while avoiding per-row SQL-function execution overhead.
- Preserve function OIDs, owner, ACL, settings, security-definer status and volatility.
- The authenticated production timeout remains eight seconds.

## Verification performed on 21 October 2026

The atomic migration compared every full canonical expense row, including duplicate multiplicity; complete review-queue JSON; and every C6 cycle identity before and after the patch. It also compared all received merchant descriptions, catalog categories and bounded NULL/whitespace/precedence cases. All comparisons were equal.

The isolated C6 query retained its thirteen rows and decreased from 160.204 ms to 62.508 ms. An authenticated-role queue call before the patch took 7,294 ms. After the patch, a normal call took 5,452 ms and two source-key-invalidated calls took 6,381 and 6,289 ms, under the unchanged 8,000 ms limit. Those invalidations were rolled back, not committed. However, a subsequent call after a real classification and cache invalidation exceeded eight seconds. The latency defect remains OPEN; the earlier source-key-only checks do not prove a fully cold success.

These measurements are controlled database-role checks, not browser HTTP timings or a guarantee for all future data volumes. Private live-screen and physical-phone acceptance are not claimed. Existing V291 immutable-asset, classification, future-import and normalization regression tests also passed.

## Remaining work

Confirmed scheduled-transfer destinations still need safe integration with per-account forecasts and eventual bank reconciliation. A destination confirmation alone is not a payment or a forecast entry. Newly received unresolved items and unpaid forecasts remain visible. Fully cold review-queue latency also remains open. This patch does not certify the entire financial backlog.

