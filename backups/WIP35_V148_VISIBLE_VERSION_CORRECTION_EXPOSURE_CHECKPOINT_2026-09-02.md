# WIP35 v148 visible-version correction exposure checkpoint — 02/09/2026

## Incident and cause
- User/mobile symptom: fixed homologation resolved to the v148 wrapper but visible product labels still showed v142.
- Public reproduction confirmed the mismatch; it was not attributed to browser cache.
- Cause: inherited v142 UX retained a 60 ms version-label ownership loop plus a MutationObserver after higher candidate wrappers loaded.

## Correction
- Corrected product SHA: `333bb3c4eb06c8e68d9de0c637da37c09db43989`.
- v148 owns the badge/brand/footer across the full same-origin frame chain, retires the inherited brand observer, protects replacement nodes, uses bounded retries only and tolerates discarded-frame teardown.
- No financial amount, category inference, financial rule, backend writer, reconciliation, database schema or public fallback changed.

## Product and integrated evidence
- Corrective branch workflow: `33687727964` SUCCESS; artifact `9868838991`; digest `sha256:d2858ea51e4f36595dfa766c72e31c011c8943fcd0223ac9ebc32e72e549a917`.
- Integrated-main workflow on exact product SHA: `33688014674` SUCCESS; artifact `9868954004`; digest `sha256:ec40b31cc24c972347529f82210ae5b22bc57518c349936d22d862bfac0e7646`.
- Integrated-main Pages on exact product SHA: `33688013452` SUCCESS.

## Controlled exposure
- Exact exposure SHA: `966db03a64fdfadb4d27656044f220624f8debaf`.
- Manifest: v148 / `wip35-v148-candidate.html` / candidate `333bb3c4eb06c8e68d9de0c637da37c09db43989` / `not_promoted`.
- Pages `33688619281`, candidate-smoke `33688621067`, v144 `33688620994`, v145 `33688621358`, v146 `33688621053`, v147 `33688621179`, v148 `33688621145`: all SUCCESS.
- Exposure artifact: `9869171950`; digest `sha256:e573380396d0a0edb414383712ff98a83a0af17400041298e08d980d18dc3c12`.

## Live public verification
- Fixed URL resolved to `wip35-v148-candidate.html?homologacao=333bb3c4...`.
- Observed title: `LTS Wealth · Homologação v148`.
- Login brand and candidate badge remained v148 after delayed timers; the visible DOM contained no v142 label.
- This was public unauthenticated browser verification. Authenticated visual/save→refresh E2E remains pending and is not claimed.

## Protections and remaining gates
- Public `index.html` remains protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.
- Public promotion is not authorized and was not performed.
- Material user homologation and the complete historical backlog remain open as recorded in the canonical documents.
