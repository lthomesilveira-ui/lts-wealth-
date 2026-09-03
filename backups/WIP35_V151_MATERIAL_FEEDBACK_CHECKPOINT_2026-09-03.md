# WIP35 v151 material-feedback checkpoint — 03/09/2026

## User feedback captured
- Atualizações transaction lookup is not acceptable when it requires a broad Flow query and times out.
- Desired interaction: type text such as `Mastercard` and see matching launches immediately, without a new top-level navigation tab.
- Search must cover supported history from 2013 forward, including future launches already present in LTS.
- User wants the resulting list exportable to Excel.

## Technical response
- v151 replaces the timeout-prone broad `lts_browser_flow_v4` search with read-only server-side `lts_browser_transactions_v1`.
- Search is type-as-you-go, debounced, returns a preview + total, and provides Excel-compatible CSV export of all matches.
- Backend evidence check for `Mastercard` found 239 matches spanning 01/11/2013 through 12/04/2028.
- No financial writer is added by the search/export layer.

## FGTS documentary evidence
- CAIXA statement issued 03/09/2026 17:48; evidence SHA-256 `d6dfdf9a0f02994ca80346b0dba519120c7ba4539dba3ba0815a13444de32e45`.
- 21/04/2026 balance R$25.585,03; 07/05/2026 full withdrawal to R$0.
- 21/07/2026 balance R$17.509,05 after annual result credit.
- 19/08/2026 Jul/2026 deposit +R$4.849,74; 21/08/2026 JAM +R$73,52.
- Latest documentary balance: **R$22.432,31 as of 21/08/2026**.
- A new append-only `asset_positions` snapshot was recorded for `FGTS Organon` at 21/08/2026 / R$22.432,31; prior snapshots were not overwritten.
- Operational product cache and Dashboard cockpit cache were refreshed; current restricted FGTS read model now resolves to R$22.432,31.

## User financial rule — supersedes old planning assumption
- FGTS must remain conservative.
- Do **not** estimate future FGTS deposits/accrual.
- Prior model using R$3.700/month and R$32.309,05 projected request-date FGTS is historical model evidence only until Planning is reconciled to the new rule.
- FGTS remains restricted / approximately D+30 contingency, never immediate cash.
- `Valor para fins rescisórios` is not treated as the current withdrawable balance.

## Release guardrails
- v151 remains on branch until all inherited + v151 gates are green.
- Fixed homologation remains v150 until controlled v151 exposure after integrated-main gates.
- Protected public `index.html` remains untouched; promotion requires explicit user authorization.
- Authenticated visual E2E remains pending/unclaimed.
