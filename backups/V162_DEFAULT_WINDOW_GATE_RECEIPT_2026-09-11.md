# V162 — Default Flow window gate receipt

Date: 2026-09-11.

## Tested product
- Product: `41587c9d21904354b5dec7cb936452ffaae55eae`; tree `cb067b71cd68bf704a4061a0cf60356309fc3fec`.
- Window implementation: `1ec2b4a1945fbbeb3dae0fccd3364b7ded981110`.
- Recovery browser smoke `34646535785`: SUCCESS, including historical rows/tree, projection controls, invoice parity, vesting boundary and overflow.
- Dedicated default-window browser run `34646535781`: SUCCESS.
- Initial identical-code window run `34646238869`: SUCCESS; artifact `10282068604`, digest `sha256:f496f19712c67fb09eb43e9cbb983959c5a7d68e67e772708295bb5451a9abe7`. Its receipt and desktop/mobile screenshots were downloaded and visually inspected.
- The initial smoke `34646238780` failed only because its static assertion pinned the previous JavaScript cache key. The assertion now requires the new cache key and the new window contract, without removing any behavioral gate. The repeated full smoke passed.

## Window behavior
D-5 through D+30 inclusive, including today and zero-movement days, gives 36 calendar rows. The date reference is America/Sao_Paulo. Initial load, reload, entering Flow, default-range chip and the single Hoje button restore the window. Bank selection preserves a manually chosen period; existing presets and date inputs remain usable.

Deterministic Chromium profiles: desktop 1440x900, mobile 390x844 and cross-year desktop. All passed initial load, reload, re-entry, bank filters, manual range, Hoje and delayed boot callback tests, with zero page errors and zero measured horizontal overflow. Fixture values are not user data and no writer was called.

The real V11 mixed-range read separately passed under role authenticated with controlled database claims and an eight-second statement timeout: five historical plus thirty-one current/future days, approximately 890 ms. This is not the user's signed-in browser or physical-iPhone E2E. Local browser navigation was administrator-blocked, so CI is the browser evidence.

## Publication boundary
The manifest selects the tested product above for fixed homologation. Verify the latest main Pages and post-manifest workflow runs at the resulting publication commit; a metadata commit does not itself prove successful deployment. Public index.html is unchanged and public-root promotion is not authorized.

## Itaú boundary — still open
The user-reported checking-account mismatch is not closed by the window change. The audit recovered a later previously uploaded statement missing from the operational index, but no recovered checking-account evidence covers the current day. Do not set a stale balance as today's balance, infer settlement dates, cancel legacy commitments or create a synthetic balancing entry. Private audit key `itau-current-balance-20260911` contains source pointers, the exact calculation, before-image, temporal ambiguity and required current statement. All prior confirmed data and the classification/all-card gates remain preserved as specified in the master backlog.
