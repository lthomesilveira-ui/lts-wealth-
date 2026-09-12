# LTS Wealth — Execution State

Latest update: 12/09/2026, confirmed Bradesco account yield applied. Read this before older statements calling the same residual unresolved. Prior main/work states are preserved byte-for-byte in backups/LTS_WEALTH_EXECUTION_STATE_MAIN_BEFORE_YIELD_2026-09-12.md and backups/LTS_WEALTH_EXECUTION_STATE_WORK_BEFORE_YIELD_2026-09-12.md. All unaffected requirements remain binding.

## Latest correction — APPLIED, not an unexplained difference
The user confirmed that the positive Bradesco residual shown against the 11/09 position is account yield and reminded us this treatment was already agreed. The operational database already contained prior July/August yield records and the prefix rule for RENTAB.INVEST FACILCRED*. The original spreadsheet label is Rentabilidade Conta Corrente Bradesco; its existing canonical category is Rendimentos financeiros. The error was leaving the new occurrence unresolved without applying the known economic treatment.

The specific user-confirmed cumulative yield was recognized once at the documented position date. Exact bank posting dates were not supplied, so metadata explicitly distinguishes as-of recognition from an issuer booking date. Raw evidence, existing observed bank balance and every future daily balance were preserved. No tolerance, rounding adjustment, automatic cents-to-income rule, real bank payment or second addition to the existing balance was created.

Private source_documents audit_key bradesco_yield_user_confirmed_position_20260911_v1 contains the user confirmation, original screenshot reference, before-account/day, source rule, new event, after-day and PASS assertions. The snapshot notice is no longer returned for this exact occurrence. New source event uses the known spreadsheet description and the existing income category, not a fabricated miscellaneous adjustment. Existing earlier yields were checked for duplication. This closes only the exact confirmed residual; unrelated mismatches still require evidence.

Latest checkpoint: backups/V162_BRADESCO_YIELD_CONFIRMED_2026-09-12.md. This explicitly supersedes the same unresolved-residual item in the older master delta, next gate and integrated/bank-switch checkpoints, without closing unrelated documentary or reconciliation issues.

## Version and publication boundary
Published frontend remains V162, integrated product f202ec7f24f832952ba62b9d27ab9d179135280a, fixed homologacao.html -> wip35-v162-candidate.html. Prior successful publication is documented in backups/V162_INTEGRATED_PUBLICATION_2026-09-12.md. This yield fix is shared backend data; no new frontend build is needed to read it after refresh.

The active recovery-v152-flow-20260910 branch has the bank-switch candidate originally committed as c5ef2eef5c31fedb2037ee871b4d667594636018. Its code is not yet on main. Do not claim its publication from this documentation-only update. It closes expanded days/invoices on bank changes, preserves the selected dates and ignores obsolete invoice responses. Its test/publication gate remains separate.

## Latest UX feedback — preserve
The user reports inspected Itaú balances/invoices appear correct, Bradesco opening trouble, daily expansions leaking between banks and an Itaú invoice remaining under C6. The screenshot's historical warning is not itself evidence of the reported invoice-opening failure. Keep that investigation separate from the now-resolved yield notice. Details remain in backups/V162_BANK_SWITCH_FEEDBACK_2026-09-12.md.

## Confirmed delivery sequence
First finish Flow functionality and UX. Then comprehensively recover classifications for BOTH bank/Flow movements and card purchases using the original spreadsheet, confirmed LTS rules and reliable historical mappings. Restore review/reclassification from the Flow. Preserve Categoria/Grupo/Macrogrupo and the existing cost-center scheme. Do not invent intermediary purchase purposes, create replacement taxonomy, double-count invoice payments as consumption or merely hide pending labels. Ask only about genuinely irreducible semantic ambiguity after retrieving existing evidence.

## Preserved data, rules and open gates
The already-received Itaú statement remains applied; card due/cash dates remain distinct; current Aeternum source, C6 fee/reversal and prior-payment exclusion remain; the financing edit, Larissa adjustment, single insurance obligation, dated separate Cofrinho and rejected Mercado Pago DDA remain intact. Default D-5 through D+30 (36 days) and manual date ranges remain unchanged. V150/V151 is the functional reference; the cumulative wrapper chain must not return.

Current other-Visa documentary identities, the Bradesco opening report, actual-session classification persistence, bulk-classification release and human homologation remain open. Browser fixture tests and controlled database tests are not the user's physical-device/session E2E. Dashboard remains out of scope pending a complete approved proposal; public-root promotion is unauthorized. Preserve all other entries in PROJECT_MASTER_BACKLOG.md and PROJECT_MASTER_BACKLOG_DELTA_2026-09-12.md.

## Restart / writes
Read this file, PROJECT_START_HERE.md, latest checkpoint, decision ledger, master backlog/delta, NEXT_HOMOLOGATION_GATE.md, LTS_WEALTH_CONTINUITY_HANDOFF.md and CANONICAL_DELIVERY_MASTER_PLAN.md. Refresh main, active branch and changed/relevant documents before writes; never force or overwrite parallel work. User updates use Concluído / Em execução / Próximos passos. Source evidence, classification confirmation, data application, consumer readback, browser tests, publication and user approval are distinct states.
