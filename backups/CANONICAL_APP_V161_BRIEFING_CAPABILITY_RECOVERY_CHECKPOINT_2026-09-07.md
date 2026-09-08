# LTS Wealth — Canonical v1.6 Briefing Capability Recovery Checkpoint

Date: 2026-09-07 BRT (America/Sao_Paulo)

Purpose: immutable handoff for the coherent package that recovered secondary product capabilities from the original briefing and historical models, integrated them into the single canonical app, exposed the exact green candidate to fixed homologation and preserved all honest validation boundaries.

## Exact scope and repository identity

- Repository: `lthomesilveira-ui/lts-wealth-`.
- Product commit: `501fb48265b02a5416f0fc198a54abf8688ddd14`.
- Homologation exposure commit: `39689a3ba6648eeb633cddec8feee26b7d8f6766`.
- `main`, `canonical-app-v1` and `canonical-v157plus-product-recovery` were aligned at the exposure commit.
- Fixed homologation selects `canonical-app.html?homologacao=501fb48265b02a5416f0fc198a54abf8688ddd14`.
- Manifest build: `CANONICAL v1.6 · Briefing Capability Recovery`.
- Exposure mode: `canonical_single_frontend_v161_briefing_capability_recovery`.
- Promotion status: `not_promoted`.
- Protected public `index.html` blob remains `a130eafe5f7ee5b7f60a95b5ff988669d0c401d9`; public promotion was neither requested nor performed.

Exact changed blobs:

| File | Blob SHA |
| --- | --- |
| `canonical-app.html` | `c84cfa9d54cd299819ca5e64cb63af20217dd296` |
| `canonical-liquidity.js` | `a0020ffd755dd493d7c807b554d78456dd0f1e09` |
| `canonical-capabilities-v161.js` | `d55e0ada107df185d806404225599c38143d64f8` |
| `.github/scripts/lts_canonical_v157plus_browser_gate.js` | `5bd646bb0b6de1bad5d1460f395d78dd9181681d` |
| `.github/workflows/canonical-v157plus-product-recovery.yml` | `e454012063aacdb9f32fd14c522eb29371567a74` |

## Recovered briefing capabilities

Central de Gestão now lives inside the existing `Atualizações` route. Desktop receives compact secondary intent links; mobile keeps exactly the six primary routes: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões and Atualizações.

| Capability | Canonical surface / contract | Deterministic state |
| --- | --- | --- |
| Planejamento | Executive cash bridge, first insufficiency, worst position and management/action point; no future FGTS accrual. | Visible and gated. |
| Entradas & compromissos | Future recurring coverage and gaps tied to planning/reconciliation. | Visible and gated. |
| Recorrências | Read-only series and coverage audit; detected historic frequency creates review, never an automatic future fact. | Visible and gated. |
| Simulações | Read-only vested-award scenario; result never becomes a financial fact. | Interactive fixture path gated. |
| Conciliação | Documentary status with required difference `R$ 0,00`. | Visible and gated. |
| Relatórios | Executive JSON and recurrence CSV; separate from the private full backup. | Export surface gated. |
| Backup & restauração | Private versioned export and guarded non-destructive restore lifecycle. | Guardrails gated; real authenticated lifecycle pending. |
| Configurações & integrações | Provider-neutral Open Finance status, connections and sync health; provider/consent/spend remain explicit decisions. | Visible and gated. |
| Financiamentos | Existing wealth/detail contract, including Volvo exactly once economically. | Visible and gated. |
| Documentos | Existing document lifecycle reader and review contract; upload never auto-posts financial facts. | Visible and gated. |

## Authenticated RPC boundary used by v1.6

- `lts_browser_planning_executive_v1`
- `lts_browser_recurring_future_gap_audit_v4`
- `lts_browser_vesting_scenario_v1`
- `lts_browser_backup_status_v1`
- `lts_browser_backup_export_v1`
- `lts_browser_restore_stage_v1`
- `lts_browser_restore_apply_v1`
- `lts_browser_open_finance_status_v1`
- `lts_browser_wealth_detail_v1`
- `lts_browser_document_lifecycle_v1`

All ten functions were verified with EXECUTE allowed to `authenticated` and denied to `anon`. They are `SECURITY DEFINER`; this reachability is intentional but is not, by itself, proof that every historical function has a complete ownership guard. That broader review remains an explicit security work package.

## Safety and financial semantics preserved

- Planning does not create projected future FGTS accrual.
- Recurrences and vesting scenarios are read-only; scenario values do not mutate the ledger.
- Documentary reconciliation remains exact at `R$ 0,00` difference.
- Reports do not masquerade as a full financial backup.
- Backup export includes build/schema identity and SHA-256 integrity metadata.
- Restore verifies the client checksum, stages and previews on the backend, requires an exact confirmation phrase and a second browser confirmation, then applies through the backend contract.
- Restore is staged/non-destructive and must preserve append-only auditability.
- Fixture mode disables backup export and restore writes.
- No financial amount from the visual reference was copied into product data.

## Deterministic proof

| Branch/surface | Run | Result |
| --- | ---: | --- |
| Recovery gate | `34179625830` | SUCCESS |
| Recovery candidate smoke | `34179625805` | SUCCESS |
| Canonical permanent gate | `34179823179` | SUCCESS |
| Canonical candidate smoke | `34179823167` | SUCCESS |
| Main candidate smoke | `34179954294` | SUCCESS |
| Main Pages deployment | `34179953893` | SUCCESS |
| Post-exposure recovery smoke | `34180090300` | SUCCESS |
| Post-exposure canonical smoke | `34180147055` | SUCCESS |
| Post-exposure main smoke | `34180249928` | SUCCESS |
| Post-exposure Pages deployment | `34180249315` | SUCCESS |

Recovery artifact:

- Artifact ID `10038447098`.
- Digest `sha256:76e4a3093eea11f34ac6c96345a1d623a3d1a8621b19ac10db345ff134ab2f23`.
- Size `2,093,235` bytes.
- Contains the canonical source set plus desktop/mobile screenshots for Dashboard, Flow, Despesas, Patrimônio, Cartões, Atualizações and Planejamento.

The permanent browser gate proves:

- Chromium desktop at 1312×1199 and WebKit mobile at 390×844;
- six primary routes, with exactly six mobile destinations;
- Central de Gestão presence and all ten capability labels;
- management pane switching and deterministic Planning/Recurrence/Scenario/Reconciliation/Reports/Backup/Settings contracts;
- no iframe, horizontal overflow, page error or leaked fixture UI in the clean unauthenticated state;
- truthful login with no fabricated financial KPIs;
- bounded recovery from a persisted future-issued JWT without exposing the raw JWT error.

## Visual proof reviewed

The following artifact screenshots were directly inspected:

- `canonical-updates-desktop.png`
- `canonical-updates-mobile.png`
- `canonical-management-planning-desktop.png`
- `canonical-management-planning-mobile.png`

They show the dense Central de Gestão and Planning surfaces without horizontal overflow. Fixed mobile navigation may appear within a full-page capture because it is intentionally viewport-fixed; the browser gate separately verifies that all six buttons fit within the 390px viewport.

## Fixed homologation verification

The public fixed URL was opened after Pages completed. It resolved to the exact product target, loaded `canonical-liquidity.js?v=20260908-capabilities1`, displayed one clean LTS Wealth login form and displayed no unauthenticated financial KPI surface. This was a public unauthenticated verification, not an authenticated material-data E2E.

## Supabase security audit finding

The following 13 `public` tables currently have RLS disabled:

1. `lts_asset_market_valuation`
2. `lts_card_history_recovery_staging`
3. `lts_card_history_recovery_target`
4. `lts_category_alias`
5. `lts_dashboard_cockpit_cache`
6. `lts_external_reference_fact`
7. `lts_flow_future_read_cache_v2`
8. `lts_homologation_stage_evidence`
9. `lts_projection_audit_component`
10. `lts_projection_audit_rule`
11. `lts_semantic_amount_signature`
12. `lts_taxonomy_ambiguity_guard`
13. `lts_ui_artifacts`

Exact privilege checks showed that neither `anon` nor `authenticated` has direct SELECT, INSERT, UPDATE or DELETE privilege on any of the 13 tables. Therefore this audit did not demonstrate direct browser-table exposure. It also does not make disabled RLS acceptable as a final posture.

No DDL or grant change was applied in this package. Blindly enabling RLS or mass-revoking `SECURITY DEFINER` functions could break the canonical authenticated RPC boundary. The required next package is: map each function to `auth.uid()` / allowed-user guards, design per-table policies, apply the smallest changes, run full authenticated regressions and retain rollback evidence. Supabase Auth leaked-password protection is also reported disabled and belongs in that controlled package.

## Honest boundaries at checkpoint

- No authenticated physical-iPhone financial/data E2E was performed; none is claimed.
- No real authenticated backup export, restore stage/apply, liquidity write, classification write or document interpretation was executed.
- No provider, Open Finance consent, credential or commercial spend was selected or authorized.
- No public `index.html` promotion was performed.
- Dashboard hierarchy and density are improved/preserved, but pixel-perfect parity with the approved 1312×1199 reference is not claimed.
- Historical documentary gaps for cards, RSU, CIPÓ 396 and Volvo remain open exactly as recorded in the master backlog.

## Autonomous continuation order

1. Converge Dashboard presentation and interaction against the approved original reference while preserving real-data truth.
2. Deliver the controlled Supabase RLS / SECURITY DEFINER / Auth hardening package with authenticated regression proof.
3. Close route/session restoration and the unified automatic definition-of-done receipt.
4. Execute authenticated desktop and physical-iPhone E2Es for material reads and guarded writes.
5. Continue documentary gaps and Open Finance evidence without making user-owned provider/consent/spend decisions.
6. Keep `index.html` unpromoted until explicit authorization.

User action required at this checkpoint: **NONE**.
