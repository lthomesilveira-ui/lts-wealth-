# LTS Wealth — Immutable Checkpoint — Canonical Dashboard Fidelity Pass 4 — 07/09/2026

## Scope
Fourth Dashboard fidelity package on the canonical single-frontend architecture. This is a structural/presentation refinement over pass 3, preserving existing financial arithmetic, backend contracts, classification/evidence rules, six real routes and the protected public fallback.

## Exact source / gate evidence
- Final candidate branch: `canonical-app-v1`.
- Structural HTML commit: `22960d52064756b2122601b0ce6082e001bd6647` — `Apply canonical dashboard fidelity pass 4`.
- Final presentation polish commit: `7f90ec768a2dded24ccd00388129a7c375c0700e` — `Polish canonical dashboard pass 4 mobile and period hierarchy`.
- `canonical-app.html` blob: `08680a3fad789351d3bbd7c3b44aef0af7ea9757`.
- `canonical-dashboard-fidelity.css` blob: `8ca76632029a80b65ced58f0cf4a5704df2c0269`.
- Canonical app gate run `34140976882`: **SUCCESS**.
- Candidate smoke run `34140976922` / check `candidate-smoke`: **SUCCESS**.
- Deterministic browsers: Chromium desktop 1312×1199 and WebKit mobile 390×844.
- Gate artifact `10025902411`, digest `sha256:e446b008ecc74582001ee66e379259bd6a1dc740ba44b58c0a423b4397e576e6`.
- Static contract, browser contract and visual-evidence upload all completed successfully.

## Verified visual/product improvements versus pass 3
Direct review against the pass-3 evidence and the approved 1312×1199 presentation reference confirmed a material improvement:
- KPI hierarchy now follows the approved executive framing more closely while using only existing/evidenced values: Patrimônio líquido, Caixa Total (até D+3), Receitas (mês), Despesas (mês), Resultado do mês.
- Desktop navigation is visually broader/more useful without reintroducing wrappers or fake product routes.
- Monthly period control is explicit; final polish stacks month/year above the separate `dados até` evidence date on internal pages.
- Patrimônio panel uses an explicit current-position visualization when no historical wealth series is available; it does not fabricate historical points.
- Dashboard mobile cash-flow chart received additional top spacing/capped bar height so the tallest bar no longer crowds the panel heading.
- Undated cockpit actions are excluded from the `Próximos Compromissos` dated list rather than being assigned an unrelated cockpit date.
- Existing real Dashboard sections, Planning/FGTS, cards, Atualizações and liquidity preview remain available under the same canonical frontend.

## Truth boundaries
- No financial arithmetic, amount, classification, merchant, recurrence, account attribution, valuation, tax treatment or evidence rule was changed by this pass.
- Approved reference is presentation/hierarchy evidence only, never a source of financial facts.
- Current-only wealth visualization is explicitly not a synthetic historical series.
- Deterministic fixture screenshots are QA evidence, not authenticated user-financial evidence.
- Authenticated physical-iPhone financial/data E2E was **not** performed or claimed.
- Real authenticated liquidity save→refresh→visible remains pending; fixture tests do not post financial facts.
- Public `index.html` remains protected and is not promoted by this package.
- `promotion_status` remains `not_promoted` until any future explicit public-root authorization.

## Release decision
Pass 4 is visually and structurally superior to pass 3 on the gated evidence and is eligible for integration into `main` after the temporary atomic-apply workflow is removed, repository divergence is audited, and a normal non-force integration preserves the existing homologation-manifest commit. Fixed homologation must only be repointed after `main` smoke/gate and Pages are green.