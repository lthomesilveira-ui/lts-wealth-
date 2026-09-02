# WIP35 v149 document interpretation review — integrated-main checkpoint — 02/09/2026

## Integration
- Source branch: `v149-document-interpretation-review`.
- Pre-integration compare: `ahead_by=9`, `behind_by=0`; no divergence.
- `main` advanced by normal fast-forward with `force=false`.
- Exact integrated-main SHA: `797bcc458dc4fe4fd9ac7cce4722d61238e542a0`.
- No change to `homologacao-current.json` during integration; fixed homologation remains v148.

## Exact integrated-main gates
- v149 workflow run `33693382626`: SUCCESS.
- Job `100456903413`: SUCCESS.
- Artifact `9870938762`.
- Artifact digest `sha256:401ebbd1c788a0d8731439864d09a49061f911a2836d9f07c64d41fbc9fbbcba`.
- Pages run `33693381251`: SUCCESS on the same integrated-main SHA.
- Inherited parser/static and button contracts: SUCCESS.
- Inherited v146 repeated navigation: SUCCESS, preserving 10 cycles × 7 destinations × desktop/mobile = 140 physical Playwright clicks.
- Inherited v147 guided document association: SUCCESS.
- Inherited v148 classification save→refresh lifecycle: SUCCESS.
- v149 document interpretation review desktop/mobile: SUCCESS.

## Product/financial guardrails
- Structured PDF/image extraction remains evidence only, separated from the user-provided document association.
- Missing required association remains manual and visible.
- Filename never infers account/card/competence/date/amount.
- `financial_writer_changed=false`.
- `rpc_calls=0`.
- `filename_inference=false`.
- `manual_review_required=true`.
- `permanent_polling=false`.
- No financial posting, reconciliation, category inference, balance effect or new writer was added.

## Release safety
- Public `index.html` remains protected blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9` after integration.
- Fixed homologation remains v148 / `wip35-v148-candidate.html` / `not_promoted` while the user tests the current release.
- v149 is integrated but NOT exposed in fixed homologation.
- Public promotion remains unauthorized/not done.
- Authenticated visual E2E remains pending/not claimed.
- Real authenticated PDF/image interpret→review remains pending/not claimed.
