# V162 Daily Flow — V11 frontend publication checkpoint

Date: 2026-09-11

## Scope
Recover only the user-validated V150 Daily Flow through the isolated V162 candidate. Dashboard and all other modules remain out of scope. Public `index.html` remains protected and unpromoted.

## Real-data timeout recovery
The first authenticated user attempt on 11/09/2026 exposed PostgreSQL statement timeout. Migration `canonical_flow_v18_cache_runtime_guard_2026_09_11` replaced the browser path with `lts_browser_flow_v11`, bounded cold refresh to the requested period plus D+30, added V18 daily prewarming and guarded mutation `lts_browser_flow_mutate_v2` with cache invalidation. Direct authenticated backend evidence for 11/09–10/10 completed at approximately 20 ms warm and approximately 2.9 s deliberately cold under an explicit eight-second timeout.

## Frontend bridge recovery
The frontend candidate already carried contract `v150-flow-direct-current-read-v3` and V11/V2, but the permanent candidate-smoke workflow still asserted obsolete V10/V2 markers and then incorrectly rejected the preserved legacy `lts_browser_flow_mutate_v1` call name that the bridge intentionally maps to V2. Only `.github/workflows/candidate-smoke.yml` was corrected. No financial fact, source `index.html`, candidate UI, Supabase writer or financial rule was changed by this gate repair.

## Deterministic evidence
- Recovery branch head before metadata checkpoint: `e9df9e434b1839bc2b7da537cebd87e8f380bff3`.
- Recovery candidate smoke run `34612905541`: SUCCESS.
- Artifact `10268379886`, digest `sha256:2f51443f1f5d572fbe1d5a5482c48d6c16ba78b7e4ed07dbcf2a63365880e4ef`.
- Browser gate: desktop 1440×900 PASS; mobile 390×844 PASS.
- Both profiles requested `lts_browser_flow_v11`, reported bridge contract `v150-flow-direct-current-read-v3`, `last_flow_ok:true`, passed historical tree and Visa/C6 invoice parity.
- `main` was advanced by normal non-force fast-forward only; compare was ahead 2 / behind 0 and changed only `.github/workflows/candidate-smoke.yml`.
- Main candidate smoke run `34613113790`: SUCCESS.
- Main GitHub Pages deployment `34613111683`: SUCCESS.

## Exposure
Fixed homologation continues to select `wip35-v162-candidate.html`. Manifest metadata is updated to truthfully state V11 reader / mutation V2. `promotion_status` remains `not_promoted`; public root is unchanged.

## Evidence boundary / next gate
Automated desktop/mobile and authenticated backend-performance evidence are green. This is not human approval and is not a claim of authenticated browser E2E against the user's actual session. The next material gate is the user's signed-in test of the fixed homologation Daily Flow, including the period that previously timed out. Physical-iPhone approval remains separate.
