# WIP35 v148 pre-integration checkpoint — 02/09/2026

## Frozen scope
- Active branch: `v148-classification-lifecycle`
- Documentation head before this immutable checkpoint: `bbcd5e30c9b4b2b1050cd8eb69e4cd5c802f766f`
- Tree before checkpoint: `see commit bbcd5e30...`
- Exact green product/gate SHA: `b902f84a71a4dc1aa35d955e07b5280775cb9ca5`
- Candidate: `wip35-v148-candidate.html`
- Product layer: `wip35-v148-classification-lifecycle.js`
- Fixed homologation remains v147 during integration gating.

## Product contract
- Explicit classification save calls existing writer `lts_browser_semantic_feedback_v1` exactly once.
- Successful writer completion is followed by existing reader `lts_browser_product_v1`.
- If the item is absent after reload, the queue renders without it and `O que mudou` records before→after pending counts.
- If reload fails after the writer succeeded, the state is `verificação pendente`; manual retry calls only the reader and never repeats the writer.
- Mutation injection is state-idempotent; no permanent polling and no self-sustaining render loop.
- No financial amount, category inference, classification evidence hierarchy, backend schema, reconciliation rule or public fallback changed.

## Exact green evidence
- Workflow: `33659959930` — SUCCESS
- Artifact: `9858327121`
- Digest: `sha256:e87e90f77f156b90d5a481e84861284db84f5170f782389816f6ab082e14db0d`
- Desktop and mobile: success lifecycle, refresh-failure lifecycle, manual read retry, resolved disappearance, exact RPC call counts and zero browser errors — PASS.
- Inherited architecture/guardrails, button census, parser/static, v146 repeated navigation and v147 guided document association — PASS.
- Evidence limit: synthetic browser data with mocked RPC responses; not authenticated E2E and no backend financial write.

## Pre-integration relationship
- Main: `72294541ad9331821850b1cf4cad159ae91e1e58`
- Branch documentation head: `bbcd5e30c9b4b2b1050cd8eb69e4cd5c802f766f`
- Compare status: `ahead`
- Ahead: `10`
- Behind: `0`
- No force is authorized; re-fetch and recompare immediately before integration.

## Protected release state
- Public `index.html` blob: `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`
- Fixed manifest remains v147 / `wip35-v147-candidate.html` / `not_promoted`.
- v148 exposure must be a separate commit after exact integrated-main gates are green.
- Public root promotion remains blocked pending explicit user authorization.
- Real authenticated visual/save→refresh E2E remains pending and unclaimed.

## Backlog carried forward
PDF/image interpretation with manual review; natural-liquidity authenticated save→refresh and append-only reversal; Despesas density and evidence-only classification reduction; Mastercard/Visa documentary recovery; all CIPÓ blockers; Volvo trim/km; Open Finance pricing/SLA/product×bank; performance only after correctness; material homologation; public promotion only with explicit authorization.
