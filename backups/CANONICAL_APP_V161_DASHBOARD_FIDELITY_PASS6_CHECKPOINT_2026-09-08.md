# LTS Wealth — Canonical v1.6 Dashboard Fidelity Pass 6 Checkpoint

Immutable evidence recorded: 2026-09-08 01:26 BRT (America/Sao_Paulo).

## Purpose

This checkpoint makes the approved Dashboard model, v1.6 capability recovery, release target and remaining gaps recoverable from GitHub without chat memory. It supersedes Pass 5 as the current homologation baseline; it does not erase the earlier checkpoints.

## Exact release state

- Repository: `lthomesilveira-ui/lts-wealth-`.
- Active implementation branch: `canonical-v157plus-product-recovery`.
- Product target: `9ae0ee37ab3332415523eeee287cdbf75102e1c4`.
- Homologation exposure: `4d3c7bc912a672ae7353c7028d8b05d047961dd5`.
- `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` are aligned at the exposure commit by normal fast-forward updates; no force was used.
- Fixed homologation: `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.
- Manifest build: `CANONICAL v1.6 · Dashboard Fidelity Pass 6`.
- Manifest target: `canonical-app.html?homologacao=9ae0ee37ab3332415523eeee287cdbf75102e1c4`.
- `promotion_status:not_promoted`.
- Protected public `index.html` remains unchanged at blob `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`.

## Recovered Dashboard contract

The approved original 1312×1199 image, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`, is authoritative for presentation and hierarchy only. Its printed amounts are illustrative and were not copied.

Pass 6 preserves the V150/V151 financial contract and adds the missing product structure:

- desktop intent order: Dashboard, Fluxo Diário, Despesas, Receitas, Cartões, Patrimônio, Planejamento, Atualizações, Relatórios, Documentos and Configurações;
- `Receitas` is an alias to the evidenced Flow, not a new or fabricated ledger;
- month/as-of toolbar and working `Hoje` reload;
- five liquidity-first KPIs: Dinheiro em contas, Contas + curto prazo, RSUs vested, FGTS and Despesas (mês);
- evidence signals for account count, D0, D+3, D+30 and a month comparison only when the backend marks it reliable;
- Evolução da Liquidez, Distribuição do Patrimônio, Posição por Banco, Fluxo de Caixa, Principais Despesas, Próximos Compromissos, Planejamento, FGTS and Atualizações Pendentes;
- working bank rows and drill-downs to real Flow, Despesas, Patrimônio, Atualizações and Planning surfaces;
- mobile retains exactly six primary destinations and exposes period controls without horizontal clipping.

The ten recovered v1.6 capabilities remain present in Central de Gestão: Planejamento, Entradas & compromissos, Recorrências, Simulações, Conciliação, Relatórios, Backup & restauração, Configurações & integrações, Financiamentos and Documentos.

## Product and gate blobs

- `canonical-app.html`: `2f324ac819f10d178a904f622b195221cd68bb92`.
- `canonical-dashboard-fidelity.css`: `719b30c7b35ec20aedb84235fb5b1da4a27614dc`.
- `canonical-liquidity.js`: `b94b15d43dedef1d7bdf401ec9f2e96ae6eca183`.
- `canonical-flow-v157.js`: `0be38677b4afe95a8b725e8f9fd09d443508e01a`.
- `canonical-product-v157.js`: `bb9bfe950e5de8fc87940c8e66b50729ba6fbed8`.
- `canonical-capabilities-v161.js`: `227649940f86741a1abce55c1dd4938bcd82b04a`.
- permanent browser gate: `8998c9904b62a56134633409178683b1b2c5ff5f`.
- canonical workflow: `9169007edcf345088aeacf06de64d5ddc1253b03`.
- recovery workflow: `e4c7b522e2d1fdfc9a97375969fe1877ed04311c`.
- candidate smoke workflow: `af7800ffa540dbbecec4f9c72abdf3fa2935a78e`.

## Deterministic evidence

- Recovery gate `34185954453`: SUCCESS, Chromium desktop 1312×1199 + WebKit mobile 390×844.
- Active candidate smoke `34185954506`: SUCCESS.
- Canonical gate `34186087590`: SUCCESS, same permanent browser contract.
- Canonical candidate smoke `34186087628`: SUCCESS.
- Main candidate smoke `34186301851`: SUCCESS.
- Main Pages deployment `34186300869`: SUCCESS.
- Post-exposure active/canonical/main candidate smokes `34186663110` / `34186664337` / `34186664887`: SUCCESS.
- Post-exposure Pages deployment `34186664347`: SUCCESS.
- Active artifact `10040515495`, size 2,116,035 bytes, digest `sha256:e8b4403df49125b5251f751378e4e84f7c9704abac55c40d8324e05a895009a2`.
- Canonical artifact `10040555899`, size 2,113,172 bytes, digest `sha256:e3d4685de0887ce0711f42fd16adcbecd33ef0311466749383b4d0c45bca7883`.
- Pass 6 visuals were reviewed at desktop and mobile dimensions. Desktop materially follows the approved hierarchy; mobile shows all panels and controls without horizontal clipping.

The first canonical Pass 6 run correctly blocked release after a mobile scenario timeout. The cause was redundant delayed panel remounts discarding the checked award between selection and calculation. Product target `9ae0ee3...` removes redundant replacement, preserves form state and passed both permanent gates. This is product hardening, not a weakened test.

## Public verification

After Pages deployment, the fixed URL was opened in a clean browser session and resolved to the exact target `9ae0ee3...`. It rendered:

- `canonical-dashboard-fidelity.css?v=20260908-pass6`;
- `canonical-liquidity.js?v=20260908-fidelity6`;
- the real login form;
- zero unauthenticated Dashboard KPI cards;
- zero iframes.

No fixture financial content was exposed while unauthenticated.

## Preserved invariants

- One canonical frontend; no wrapper/iframe chain.
- Realized and Projected remain separate; scenarios never become facts.
- Missing evidence remains unavailable; no false zero or copied reference amount.
- Bank↔liquidity-asset movement remains equal-and-opposite with consolidated economic effect R$0.
- FGTS remains documentary R$22.432,31 at 21/08/2026, restricted approximately D+30, never D+3, with no future accrual projection.
- Ledger/mutation semantics remain append-only and idempotent.
- Restore remains staged, checksummed, previewed and explicitly confirmed.
- Public root remains unpromoted.

## Explicitly open / not claimed

- Pixel-perfect Dashboard parity and richer evidence-backed historical chart detail.
- Authenticated physical-iPhone post-fix financial/data E2E.
- Real authenticated liquidity save→refresh→visible.
- Real authenticated classification save→refresh→resolved.
- Real authenticated transaction search/CSV and document interpretation/review.
- Real authenticated backup export→checksum→stage→preview→apply.
- Supabase security package: per-table RLS design, SECURITY DEFINER ownership mapping, authenticated regression and leaked-password protection review.
- Documentary gaps in Mastercard/Visa/C6, historical RSU sale, CIPÓ 396 and exact Volvo trim/km.
- Open Finance provider/consent/spend and public-root promotion remain user decisions.

## Next autonomous sequence

1. Preserve Pass 6 as the visual/product baseline.
2. Complete the per-table and per-function Supabase security map before any DDL or privilege change.
3. Add contract-preserving security tests and only then apply a bounded migration if the ownership model is complete.
4. Continue the unified definition-of-done receipt and evidence-led Dashboard/Despesas/Atualizações refinement.
5. Keep real authenticated and physical-device claims explicit until actually executed.
