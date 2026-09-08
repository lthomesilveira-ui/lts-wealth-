# LTS Wealth — Execution State

Purpose: compact operational bootstrap so project execution never depends on a long ChatGPT conversation. This file is intentionally short and must be updated after every material package/gate/integration.

## Restart-safe operating protocol
1. Read this file first in every new chat.
2. Fetch only branch refs and file SHAs/targeted line ranges for freshness. Do **not** re-load entire long project documents unless their SHA changed or the current task needs a specific section.
3. GitHub remains the operational source of truth. Chat history is not required for continuity.
4. Immutable checkpoints remain evidence archives; do not replay them into chat unless needed for a concrete decision or regression audit.
5. Never echo tool logs, giant diffs, workflow payloads or historical context to the user. User updates stay concise under exactly: `Concluído / Em execução / Próximos passos`.
6. No intermediate QA delegation to the user. Execute deterministic QA first; ask only for real financial/classification/documentary/provider decisions or final material homologation.
7. Before a repository write, freshness-check `main`, active branch, this file, and the SHAs of `PROJECT_MASTER_BACKLOG.md`, `NEXT_HOMOLOGATION_GATE.md`, `LTS_WEALTH_CONTINUITY_HANDOFF.md`, `CANONICAL_DELIVERY_MASTER_PLAN.md` and latest immutable checkpoint. Use line-limited reads; fully re-read only a file whose SHA changed or whose relevant section is needed.
8. After every material package, gate, integration or newly discovered blocker, update this file so a chat may be abandoned/restarted at any moment without reconstruction work.

## Current execution state — 07/09/2026 21:15 BRT
- Repo: `lthomesilveira-ui/lts-wealth-`.
- Exposed product baseline shared by `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery`: `3b3048fa4660868e161582fcd8704438a13e300c` — gated V157+ recovery exposed through the fixed homologation manifest; later documentation/CI-trigger checkpoints do not change that product target; public root still protected.
- Active recovery branch: `canonical-v157plus-product-recovery`.
- Product/gate implementation commit: `76f888dc0e668fb0e768c8cc825f56778f043f50`; green canonical baseline and manifest target: `c44d401497e14d842d433a302006ff5648b956a9`; exposure manifest commit: `3b3048fa4660868e161582fcd8704438a13e300c`.
- V157+ recovery gate run `34160992326`: **SUCCESS**.
- V157+ presentation-polish gate run `34161414516`: **SUCCESS**.
- V157+ modular recovery gate run `34170935882`: **SUCCESS** in desktop Chromium 1312×1199 and mobile WebKit 390×844.
- Active candidate smoke `34170935887`, permanent canonical gate `34171231918`, canonical candidate smoke `34171231935`, main candidate smoke `34171338575` and Pages `34171338335`: **SUCCESS**.
- Post-manifest candidate smokes on active `34171452083`, canonical `34171452913`, main `34171453488`, and Pages `34171452759`: **SUCCESS**.
- Permanent canonical gate now validates the split `canonical-liquidity-core.js`, `canonical-flow-v157.js`, `canonical-product-v157.js` and `canonical-presentation-v157.js` architecture while retaining prior classification, search/CSV, document and neutral liquidity-movement contracts.
- Recovery covers the richer Flow contract, executive Despesas/Patrimônio/Cartões surfaces, mobile Flow layers, visible build identification and the canonical single-frontend architecture.
- Current Flow recovery uses backend `lts_browser_flow_v8`; deterministic gate is green. Authenticated physical-iPhone financial/data E2E is still **not claimed**.
- Dashboard remains P0 for visual convergence to the approved 1312×1199 reference; do not roll it back to the historical wrapper architecture.
- Public `index.html` remains protected; public-root promotion is not authorized.
- Fixed homologation `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html` resolves to `canonical-app.html?homologacao=c44d401497e14d842d433a302006ff5648b956a9`; live verification showed the canonical script and truthful unauthenticated login, not fixture financial content.
- Historical v144–v160 workflows remain manually/branch runnable but no longer run automatically on `main`; their wrapper-specific failures are not canonical release gates.

## Immediate next execution sequence
1. Keep `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` aligned by normal no-force updates only.
2. Continue Dashboard fidelity P0 against the approved 1312×1199 reference using real data only.
3. Continue remaining report/updates product recovery without reintroducing wrapper architecture.
4. Keep authenticated physical-iPhone financial/data E2E explicitly unclaimed until it is actually performed.
5. Preserve `promotion_status:not_promoted` and protected `index.html` until explicit user authorization.

## Product invariants not to lose
- One canonical frontend; no iframe/wrapper chain as primary architecture.
- Six real routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.
- Flow: Consolidado/Itaú/Bradesco/C6, historical coverage where evidenced, operational balance + liquidity layers, expandable movements, internal transfers neutral in consolidated economics.
- No invented amount, merchant, classification, recurrence, competence, valuation, tax or documentary fact.
- FGTS remains restricted/D+30 context, never automatic current cash.
- Public fallback remains protected until explicit authorization.

## One-line new-chat bootstrap for the user
`Continue LTS Wealth. Leia LTS_WEALTH_EXECUTION_STATE.md no GitHub e continue autonomamente do estado real, sem reconstruir contexto do chat.`

That one line is sufficient. The assistant must recover everything else from GitHub and continue execution.
