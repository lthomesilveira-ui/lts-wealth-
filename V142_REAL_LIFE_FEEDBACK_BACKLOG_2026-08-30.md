# LTS Wealth — v142 real-life feedback backlog — 2026-08-30

This file is an append-only companion to `PROJECT_MASTER_BACKLOG.md` for feedback collected during real-life v142 use. Nothing here authorizes a financial/classification assumption. Material items must be synchronized back into the master backlog as coherent packages close.

## Feedback batch 1 — user review

### 1. Classification assistance must use history first, then public research
Status: IN PROGRESS.

Desired behavior:
- first look for a confirmed same/sufficiently matching establishment history in the LTS;
- when internal evidence is insufficient, research the establishment name publicly;
- show establishment identity, evidence and a category suggestion when evidence supports it;
- suggestion remains reviewable; never silently classify when taxonomy/context is ambiguous;
- marketplaces, payment intermediaries, people names and mult-category sellers remain contextual instead of being guessed.

Concrete example from user: `GULA GULA MORUMBI` should be publicly identified and surface a restaurant suggestion.

Implemented 30/08/2026:
- public merchant evidence registered for `gula gula morumbi` as `Gula Gula`;
- suggested category `Restaurantes`, confidence 0.99;
- status remains `taxonomy_review` because LTS currently protects historical ambiguity between restaurant taxonomies;
- no classification or financial event was auto-written.

### 2. Future completeness audit must be general, not Salary/IPVA-only
Status: BACKEND IMPLEMENTED / UI INTEGRATION IN PROGRESS.

Desired behavior:
- continuously compare frequent recent historical series with the future modeled horizon;
- proactively surface `appears frequently in recent history but no equivalent future coverage was found`;
- examples named by user: Benjamin school/education, Condomínio, IPTU — examples only, not a hardcoded whitelist;
- do this across recurring patterns that have sufficient evidence;
- never create a projection, recurrence, amount or commitment solely because the historical pattern exists.

Implemented backend 30/08/2026:
- `lts_recurring_future_gap_audit_v1` read-only audit;
- 18-month historical evidence window, 12-month future coverage horizon;
- excludes internal transfers, excluded-from-spend events and naive recurrence classes such as card settlements / financing / loans / investments;
- only recent repeated series qualify;
- `lts_recurring_future_gap_audit_qa_v1` = 9/9 PASS;
- auth-scoped browser read contract, anon blocked;
- `lts_updates_fix86plus_v10` now attaches the audit and creates review-only Atualizações items for genuine gaps.

Current evidence:
- covered: Condomínio - O Parque, Enel - O Parque, IPTU - O Parque, Benjamin - Educação;
- review signals only: Netflix, Benjamin - Saúde, seguro cartão Itaú, Larissa;
- observed medians are descriptive evidence only and do not become future amounts automatically.

Operational cache health and Core Financial regression remained green after integration.

### 3. User must not be the button-by-button QA tester
Status: AUTOMATION EXPANSION IN PROGRESS.

Requirement:
- systematically audit the candidate button/action surface before asking for user homologation;
- safe/navigation/non-mutating actions should receive automated click/runtime coverage where technically possible;
- mutation-capable actions must have handler/RPC contracts plus transactional/rollback QA rather than destructive test writes;
- produce a button census so orphan controls fail CI;
- authenticated visual E2E must remain explicitly `PENDING / NOT CLAIMED` until a real authenticated browser session is actually exercised.

Work started:
- branch `v142-button-contract-audit`;
- static composed-source census found 174 button templates in the v142 inheritance chain;
- first audit intentionally failed on 10 controls because direct global-id handlers were not yet recognized by the auditor itself;
- auditor v2 now recognizes direct `id.onclick` / `addEventListener` wiring and is being re-run before integration.

### 4. Continue historical reconciliation while v142 is used in real life
Status: ONGOING.

Keep working autonomously on documentary/categorical historical gaps while preserving exact economic totals and never filling composition by pattern alone.

Existing explicit gaps remain open, including Mastercard/Visa/C6 documentary composition gaps, C6 Aug/2024 R$66.70 detail gap, CIPÓ Consórcio Itaú R$303.60, CIPÓ Condomínio formula/cut and Volvo evidence refinement.

## Backlog continuity
Open Finance remains in `PROJECT_MASTER_BACKLOG.md` and is NOT dropped:
- provider-neutral architecture exists;
- Pluggy / Belvo / Klavi research remains preserved;
- pricing/SLA/product×bank coverage is still open;
- real provider consent/connection/spend requires explicit user decision.

Other prior open items remain binding. This feedback file adds requirements; it does not supersede unresolved master-backlog dependencies.
