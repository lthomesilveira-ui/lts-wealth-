# WIP35 v155 functional-recovery checkpoint — 04/09/2026

## Trigger / user evidence
- v154 was visually improved but the user rejected it as functionally incomplete after testing from iPhone.
- Material defects observed in the real homologation: navigation buttons did not work reliably; `Disponível D+3` appeared as R$0,00; `Despesas (mês)` appeared as R$0,00 even when the monthly comparison was unavailable; `Ações pendentes` showed 0 while the same card reported 23 updates in queue.
- This is not treated as an iPhone/Safari problem. v154 remains rejected as a product-ready candidate.

## Root cause isolated
- v154's visual shell converted nullable values with `Number(v)`, so `Number(null) === 0` created false zeros.
- The v154 route bridge attempted the nested route transition only once and swallowed readiness errors, so a visually valid shell could still expose dead navigation.
- Prior fixture gate was therefore insufficient: it validated deterministic visual composition and a narrow synthetic route sequence, not the complete real integration surface.

## v155 product correction
- Branch: `v155-real-data-navigation-fix`.
- v155 reuses the approved v154 visual shell; it does not restart the app architecture.
- `wip35-v155-candidate.html` loads the v154 visual shell as the direct document and injects `wip35-v155-runtime.js`, avoiding an extra iframe layer.
- Runtime uses null-safe numeric parsing; missing financial values remain missing instead of becoming zero.
- D+3 can be recovered client-side only from already-known eligible components `bank_cash + d0 + d3_vested` when the explicit D+3 field is null/zero and the component sum is identifiable/nonzero. FGTS is never included.
- Missing monthly expenses display `—` with an explicit unavailable-data message; they are never rendered as a fabricated R$0,00.
- `Ações pendentes` falls back to the existing `top_actions` count when `actionable_count` is absent/zero while evidence exists.
- The client read-model normalization is display/read recovery only; no financial/backend writer was added.
- Navigation now captures all six established routes and retries until the nested application is ready: Dashboard, Fluxo Diário, Despesas, Patrimônio, Cartões, Atualizações.

## Deterministic browser evidence
- Latest complete v155 functional gate before this checkpoint: run `33928444995` on commit `be910f593e711d91c31c7afbd2623f9ac5ad2397`: SUCCESS.
- Deterministic desktop + mobile test physically clicked all six routes and returned successfully.
- Desktop viewport: 1312×1199; mobile viewport: 390×844.
- Both views: 5 KPI cards, at least 9 executive panels, no page-level horizontal overflow.
- False-zero guard passed.
- D+3 component-recovery guard passed.
- Artifact `9957671192`, digest `sha256:144662d3e31ac02d983ab24f507c8b3c4c9f9c731e31f534a77c5a150e531248`.

## No-fixture smoke
- The same run executed an additional browser smoke without `runtimeFixture`/`visualFixture`.
- Runtime loaded and physical mobile navigation `Fluxo Diário → Dashboard` passed.
- CI had no authenticated user session; its read model contained no usable financial values. Therefore this is **not** evidence of authenticated real-data correctness and is **not** claimed as authenticated E2E.
- It does prove the no-fixture boot/navigation path no longer depends on the visual fixture.

## Visual contract
- v155 preserves the v154 official-reference language: dark desktop rail, light executive canvas, five KPI row, dense multi-column cockpit, compact cards and persistent mobile navigation.
- Official source remains `/mnt/data/90A1F945-129C-4804-9926-AF9C014F8FA3.jpeg` in the working environment, 1312×1199, SHA-256 `0e5293a98bf3fce30b27ba508afdb2f17d82700a6134372938eaff38da73c06b`.

## Financial/product guardrails preserved
- FGTS latest documentary balance remains R$22.432,31 as of 21/08/2026; restricted/approximately D+30; excluded from D+3; no future FGTS contributions projected.
- Historical R$3.700/month FGTS assumption and dependent projected values remain historical evidence only.
- Facts remain above projections; scenarios are never facts.
- Public `index.html` remains untouched; public promotion remains unauthorized/not done.
- No authenticated visual E2E is claimed.

## Release status at checkpoint creation
- v155 is not yet public-promoted.
- Fixed homologation is not to be switched until v155 is integrated to current `main`, exact-main gates are green, and Pages deploy succeeds.
- User action is not required while integration/exposure QA continues.
