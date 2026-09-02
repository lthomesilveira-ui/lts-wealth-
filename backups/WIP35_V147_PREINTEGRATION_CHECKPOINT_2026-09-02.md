# WIP35 v147 pre-integration checkpoint — 02/09/2026

Immutable evidence for guided document association before integration.

## Product head
- Branch: `v147-guided-document-association`
- Product/gate SHA: `8ae3eb92b1eb155ffdf029bbcb373fe1f3d3bace`
- Parent main at package start: `bb6ae12d2b0ee388d366e28808ed4dc80e598ec0`
- Public `index.html` protected blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`
- Fixed homologation remains v146; no exposure in this checkpoint.

## Exact green evidence
- Workflow run: `33647189124` — SUCCESS
- Artifact: `9853344026` (`wip35-v147-guided-document-association`)
- Digest: `sha256:0d04050fee20cbafba3eb8dee9870785f271ebbbfc3e47d00bb0ed36f4e45ca2`
- Architecture/guardrails: PASS
- Button wiring audit: PASS
- Inherited parser/static candidate gate: PASS
- Inherited v142 browser smoke: PASS
- Inherited v143 runtime/navigation smoke: PASS
- Inherited v146 repeated navigation/classification: PASS, including 140 physical clicks desktop/mobile.
- v147 guided document association: PASS desktop/mobile.

## Scope and guardrails
- Adds guided association for bank statements, card statements, financing positions and other financial documents.
- Bank/card require explicit identity plus competence.
- Financing requires explicit commitment plus as-of date.
- Association is saved only as additive task context and remains manual review.
- No financial writer, reconciliation, classification, filename inference or permanent polling was added.
- Classification remains primary in Atualizações; document action remains secondary/collapsible.
- Real authenticated visual E2E remains pending and unclaimed.

## Next gate
1. Freeze canonical documents on the branch.
2. Confirm branch is strictly ahead of main with no divergence.
3. Fast-forward main without force.
4. Require exact integrated-main v147, legacy candidate-smoke and Pages success.
5. Only then create a separate controlled v147 homologation exposure package; public index remains protected.
