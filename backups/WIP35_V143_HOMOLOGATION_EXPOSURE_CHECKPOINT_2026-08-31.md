# LTS Wealth — WIP35 v143 Homologation Exposure Checkpoint

Checkpoint date: 2026-08-31

## What this checkpoint authorizes
This checkpoint records the controlled move of the fixed homologation manifest from v142 to v143 after integration gates passed. It does **not** authorize public `index.html` promotion, any new financial assumption, or a claim of authenticated visual E2E.

## Proven before manifest switch
- v143 implementation code freeze: `0291737238b6b0bd69fe4c9bf3c348598a4b2277`.
- Branch runtime/navigation smoke on code freeze: desktop 1440×1000 PASS, mobile 390×844 PASS, all v143 owners true, inherited v142 pointers redirected, all main nav clicks PASS, zero root overflow, zero errors.
- Static button census: 197 identifiable / 197 wired / 0 unresolved / 0 anonymous.
- Backend fingerprint before/after final battery: `85a1b60816a5b84dfe3b41341ed27948`.
- Backend staged gates: v14 293/24 + v15 67/5 + v16 19/2 + v17 32/4 = 411 checks / 35 suites PASS; not one monolithic gate.
- Supplemental v143 backend QA v2: 16/16 PASS on same fingerprint.
- PR #6 integrated normally; no force.
- Integrated main baseline: `0526033f33ef90086388a946470313bd5002180c`.
- Candidate-smoke run `33401135988` SUCCESS on integrated baseline.
- Pages run `33401135026` SUCCESS on integrated baseline.
- Protected public index blob on integrated baseline remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Exposure change in this package
- `homologacao-current.json`: v142 → v143.
- target: `wip35-v143-candidate.html`.
- `candidate_head`: integrated audited baseline `0526033f33ef90086388a946470313bd5002180c`.
- `public_fallback`: `index.html`.
- `promotion_status`: `not_promoted`.
- Canonical backlog/gate/handoff synchronized in the same commit so release state does not depend on chat memory.

## Required after this package lands
- candidate-smoke PASS on the manifest-switch main SHA;
- Pages PASS on the same manifest-switch SHA;
- fixed homologation entrypoint resolves v143;
- public index blob remains exactly protected;
- only then request user material visual homologation.

Authenticated visual E2E remains pending/unclaimed. Public promotion remains prohibited without explicit user approval.
