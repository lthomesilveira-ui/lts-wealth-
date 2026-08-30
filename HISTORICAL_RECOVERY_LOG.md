# LTS Wealth — Historical Recovery Log

Purpose: persistent evidence/recovery log so historical reconstruction never depends on chat memory. This file records only evidence-backed state and never authorizes inferred classification, merchant, purchase, competence or reconciliation.

## Guardrails
- Historical cash ledger is never rewritten by category-allocation recovery.
- Historical category allocation is analytics-only.
- A cycle is certified only when complete signed category composition closes to the ledger to the cent and source identity is explicit.
- Payment/reference equality alone is insufficient for category certification.
- Signed credits/reversals remain documentary evidence; they are not silently normalized away.
- Mastercard Itaú evidence must come from `Cartão Itaú`; Visa evidence is a distinct source.
- Retrieval failure is a technical blockage, never evidence absence.
- Fragmented settlements are never collapsed into one invoice without documentary proof.

## Canonical state — 2026-08-30 / recovery through 2019 registry
- Public fallback remains WIP35-v136; historical recovery has not changed the public build.
- Historical expense invariant: **R$8,623,752.53**.
- Current analytical expense cache after 2022 recovery: **3,860/3,860**, zero missing/extra/mismatch; total exact.
- Certified historical category-allocation: **38 cycles / 650 rows / R$885,855.19**.
- Aggregate fallback: **314 rows / R$2,650,846.36**.
- Card-history dynamic coverage QA v2: **8/8 PASS**; no certified cycle remains fallback.
- Historical validation registry: **68 open Mastercard cycles from 2019–2025**, internal-only.
- Registry QA v4: **16/16 PASS**; older-year totals/fragmented settlements are explicitly protected.
- Expense v9 19/19 PASS; Expense v10 18/18 PASS; core financial 15/15 PASS.
- Historical effective parity v2: **2,030 days / 147 months exact** through 2025; timeline 57/57; zero technical leak/overlap.
- FIX86 transversal guardrails v4: **10/10 PASS**.
- Extended heavy gate v7: **235/235 PASS across 16 suites**.
- Real authenticated visual E2E remains pending/unclaimed.

## Mastercard Itaú — 2025
### Certified exact
- Mar R$37,905.32; Apr R$34,559.66; May R$28,105.02; Jun R$33,817.15; Aug R$29,693.33; Nov R$5,883.96.

### Candidate partial — never certify until complete signed tail is recovered
- Jan — source matrix R$38,636.48; ledger `evento_base:2414` R$38,635.88; signed Crédito -R$0.30 explains sign-loss effect, but full tail missing.
- Feb — source matrix/ledger R$37,939.80; partial categories recovered, tail truncated; never fill by arithmetic difference.
- Jul — source R$33,870.67; ledger `evento_base:2778` R$33,870.17; Crédito -R$0.25 explains R$0.50 sign effect; full tail required.
- Oct — source/ledger R$16,086.02; Crédito +R$0.03; composition truncates after Projeto Automação.

### Documentary-blocked
- Sep — source R$26,582.10 vs ledger R$26,558.28; known credit does not close R$23.82 delta.
- Dec — source R$14,062.17 vs ledger R$13,195.37; known credit does not close R$866.80 delta.

## Mastercard Itaú — 2024
### Certified exact
- Mar, May, Aug, Sep, Oct, Dec.

### Settlement proven; composition missing
- Jan `evento_base:1829` R$53,652.87.
- Feb `evento_base:1871` R$58,667.61.
- Apr `evento_base:1966` R$47,802.70.
- Jun `evento_base:2061` R$48,393.80.
- Jul `evento_base:2104` R$51,947.18.
- Nov `evento_base:2281` R$45,259.24.
All six source totals equal ledger payment to the cent, but payment identity alone does not authorize category allocation.

## Mastercard Itaú — 2023
- Twelve ledger payments identified, total **R$496,689.05**.
- No independent complete category matrix recovered yet.
- All 12 months remain `ledger_only_source_composition_missing`; ledger identity is not category evidence.

## Mastercard Itaú — 2022
### Certified exact
Complete `Cartão Itaú` category matrices plus signed Crédito/reversal evidence were independently summed before insert; raw ledger remained unchanged.
- **2022-04 — R$11,910.91**; 23 category rows / 95 source occurrences; absolute matrix R$11,911.35; signed Crédito -R$0.22 closes exactly to `evento_base:1239`.
- **2022-06 — R$10,185.54**; 23 category rows / 93 source occurrences; signed Crédito -R$0.05 closes exactly to `evento_base:1311`.
- **2022-07 — R$13,486.29**; 24 category rows / 96 source occurrences; signed Crédito -R$2.76 closes exactly to `evento_base:1332`.
- **2022-10 — R$28,374.06**; 27 category rows / 103 source occurrences; signed Crédito -R$0.20 closes exactly to `evento_base:1410`.

### Remaining open 2022
- Jan — three ledger rows totaling R$12,888.65; fragmented settlement, full matrix not independently recovered. Never assume one invoice.
- Feb — two ledger rows totaling R$12,300.71; fragmented settlement, full matrix not independently recovered.
- Mar — two ledger rows totaling R$12,125.56; fragmented settlement, full matrix not independently recovered.
- May — partial documentary candidate; unresolved signed remainder currently R$0.08.
- Aug — partial documentary candidate; signed closure still incomplete.
- Sep — partial documentary candidate; unresolved amount currently R$1.54.
- Nov — partial documentary candidate; unresolved amount currently R$2.74.
- Dec — arithmetic sign evidence is promising (known Crédito -R$0.04), but complete category tail was not independently recovered; no certification until full tail closes.

## Mastercard Itaú — 2021
- 12 ledger-only monthly totals, **R$116,458.47** total.
- All 12 months contain fragmented settlements and remain evidence-only.
- No independent category matrix exists in current DB namespaces/staging; no category recovery authorized.

## Mastercard Itaú — 2020
- 12 ledger-only monthly totals, **R$99,107.08** total.
- 10/12 months have fragmented settlements; Apr/May have one ledger row each.
- No independent category matrix exists in current DB namespaces/staging; no category recovery authorized.

## Mastercard Itaú — 2019
- 12 ledger-only monthly totals, **R$164,402.94** total.
- 5/12 months have fragmented settlements (Jun/Jul/Oct/Nov/Dec).
- No independent category matrix exists in current DB namespaces/staging; no category recovery authorized.

## Historical validation registry
- Internal `lts_card_historical_validation_registry` tracks **68 open Mastercard cycles from 2019–2025**.
- Registry is evidence/status only; never a source for Despesas/category allocation; browser roles cannot read it.
- QA v4: **16/16 PASS**.
- It protects: explicit blockers and ledger identity for every row; no certified/registry overlap; no invented category payload; 2019–2021 totals and fragmented-month counts; 2022 fragmented/partial state; 2023 ledger-only; 2024 settlement-proven/composition-missing; 2025 partial/blocked state.

## C6 historical recovery
- Documentary target May/2024–Jun/2026 recovered except Aug/2024 individual-detail gap **R$66.70** in Táxi/Uber.
- Aug/2024 category total R$4,087.42 certified; staged individual detail R$4,020.72. No missing purchase invented.

## CIPÓ documentary linkage
- CIPÓ reconciliation remains separate from card-history analytics/consumption.
- 32 historical card aggregates remain pending; no promotion by category-name matching.
- Source aggregates R$1,465,713.29; same-category observed R$894,312.01; conservative capped floor R$569,196.83.
- 19/32 rubrics have some documentary coverage; 12/32 enough category amount but remain pending without instrument identity/composition proof.
- CIPÓ coverage QA 6/6 PASS. Consórcio Itaú R$303.60 and Condomínio formula/cut remain unresolved.

## FIX86 / historical invariants permanently gated
- `lts_effective_history_qa_v2`: dynamic current-contract parity, not obsolete hard-coded row counts.
- `lts_fix86_legacy_guardrails_qa_v4`: frozen projection baseline; stale/superado anchors excluded; Inbox preapproval zero write; approval-only document application; documented-only nonrecursive card estimates; read-only scenarios; append-only Flow mutations; core-owned no-double-count; CIPÓ core parity.
- Heavy gate v7 incorporates historical registry through 2019 and FIX86 guardrails without duplicating the expensive core suite.

## Retrieval state
- File Library intermittently returned valuable 2022 source matrices/signed credit evidence and then resumed instability.
- Latest 2019–2021 targeted retrieval failed before returning content.
- Current `fatura`, `legacy_namespace` card objects and searchable staging do not contain an independent historical category matrix for 2019–2021.
- Retrieval failure never changes cycle status. Do not hammer repeated failing retrieval; resume from the exact registry blocker when service is healthy.

## Next evidence work
1. Recover complete 2022 Dec tail, then May/Aug/Sep/Nov signed closures; Jan–Mar require proof of fragmented settlement composition.
2. Recover a complete independent 2023 Mastercard matrix; R$496,689.05 remains the largest single older fallback block.
3. Continue 2025 Jan/Feb/Jul/Oct tails and keep Sep/Dec blocked until genuine reversal evidence closes.
4. Recover 2024 Jan/Feb/Apr/Jun/Jul/Nov category matrices; payment identity remains insufficient.
5. Resume 2019–2021 only from independent documentary category evidence; fragmented ledger patterns must never be collapsed by inference.
6. After every exact recovery: refresh expense cache; rerun dynamic card coverage, Expense v9/v10, core, historical/FIX86 and heavy gate; update log/backlog/checkpoint.
