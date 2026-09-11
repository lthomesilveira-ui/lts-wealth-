# V162 Flow — real-data timeout recovery checkpoint

Date: 2026-09-11

## User evidence
- The first authenticated user test of the V162 Daily Flow failed for 11/09/2026–10/10/2026 with PostgreSQL error `canceling statement due to statement timeout`.
- Therefore the previous fixture-only green gate was insufficient and must not be represented as real-data approval.

## Root cause
- `lts_browser_flow_v10` requires `lts_flow_future_read_cache_v2` at engine `daily-flow-fix86-v18-future-award-economic-parity`.
- The daily operational cron still called `lts_refresh_product_read_cache_operational_v4`, whose final Flow cache was engine V14.
- On a new day the V10 request found no matching V18 cache and synchronously rebuilt a fixed 730-day horizon inside the authenticated eight-second request.

## Recovery
- Applied Supabase migration `canonical_flow_v18_cache_runtime_guard_2026_09_11`.
- Added `lts_flow_future_read_slice_v8`: exact requested-period-plus-D+30 coverage, but a cold request rebuilds only the necessary horizon instead of forcing 730 days.
- Added guarded browser reader `lts_browser_flow_v11` and guarded mutation endpoint `lts_browser_flow_mutate_v2`.
- Mutation V2 keeps the existing append-only financial writer and additionally invalidates the active V2 Flow cache so edits cannot leave stale projections.
- Added `lts_refresh_product_read_cache_operational_v5`; the existing daily cron now finishes by preparing the 730-day V18 cache.
- Candidate contract is `v150-flow-direct-current-read-v3`; V3/V4 reads map to V11 and the preserved V150 mutation call maps to mutation V2.

## Direct evidence
- V18 full 730-day refresh succeeded: 731 days, 305 events, approximately 5.4 seconds.
- Warm V11 authenticated read for 11/09/2026–10/10/2026 completed in approximately 20 ms.
- Deliberate cold-cache V11 authenticated read for the same range, under an explicit eight-second statement timeout, completed in approximately 2.9 seconds.
- Daily operational V5 refresh succeeded and left the cache on V18. No financial fact, value, classification or vesting rule was changed.
- `authenticated` can execute V11/mutation V2; `anon` cannot.

## Open gates
- Publish the V11 frontend bridge and pass the permanent desktop/mobile fixture gate in GitHub Actions.
- Verify the published fixed link and ask the user to repeat the real-data load. This checkpoint does not claim physical-device or user acceptance.
- Dashboard remains out of scope and public `index.html` remains protected.

