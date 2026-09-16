# LTS Wealth — V169 register for the complete V168 user review

Business date: 16/09/2026.

This is the non-compacted, binding implementation register for the feedback given on V168. It is additive to `backups/V167_COMPLETE_USER_REVIEW_REGISTER_2026-09-16.md`. Nothing in this register is considered accepted merely because an automated test passes.

## A. Version and delivery integrity

1. Preserve V168 exactly at commit `59293c70baac6e0a1df25e9c42978b4d82b895a3`; implement this round as V169 rather than rewriting V168.
2. Keep the public `index.html` protected. Expose a V169 homologation candidate only after the complete gate is green.
3. Independently audit the whole V168 product in addition to the items the user noticed.
4. Keep this register, implementation evidence and release receipt in the repository so work does not depend on chat memory.

## B. Dashboard

5. Center the `Dashboard` item in the dark left rail and restore deliberate spacing between its four-square icon and label.
6. Use dark blue consistently for primary totals, not arbitrary detail cards.
7. Highlight `Total disponível`, `Total de posições futuras`, `Total de previdência` and `Despesas do período`; keep supporting/detail cards white.
8. Preserve the current Liquidity chart and action-plan quality while preventing regressions.
9. Audit the source behind `Detalhe histórico não recuperado` for 01/01/2026–16/09/2026. Remove it only by fixing or honestly relabelling the underlying evidence state, never by hiding an unresolved gap.
10. Audit `Lucas compromissos financeiros`, determine exactly what it contains, relabel it in clear treasury language and prevent overlap/double counting with loans.
11. Preserve the improved future-flow block and format the R$ 20.665 transfer in the same pt-BR currency pattern as every other amount.

## C. Daily Flow and historical reconciliation

12. Re-audit every supported daily Flow year from 10/10/2013 through the business date.
13. Explicitly test the user-reported samples 2018, 2019, 2020 and 2021.
14. Opening balance + daily entries − daily exits must equal closing balance wherever documentary anchors support an absolute balance.
15. A missing historical documentary anchor must stay explicitly unavailable; today's balance must never be backfilled into history.
16. Do not claim reconciliation without a machine-readable audit showing the supported periods and any unavailable periods.

## D. Despesas and cards

17. Add a future-card view where the user can select a bank/card, such as Itaú, and see every future competence and amount considered by Flow.
18. Distinguish documented/open invoice values from projected future installments and expose the evidence status needed for comparison with the bank.
19. Keep card payments, internal transfers and investment movements from inflating consumption.
20. Add the `Balanço mensal` subtab inside `Despesas`.
21. At the top of the monthly balance, show revenue groups and their total.
22. Below, show principal consolidated expense groups and their total, with labels traceable to source classifications.
23. Show monthly inflows, outflows and net balance, with positive/negative states immediately readable.
24. On desktop, months may be columns; on mobile, the same content must remain understandable without destructive horizontal overflow.
25. Internal transfers, card-invoice settlements and investment movements must not distort the monthly operating balance.

## E. Patrimônio

26. The overview must reconcile the contents of `RSU Awards`, `Bens e Dívidas` and `Previdência`.
27. Include the Coopharma payroll loan as a liability without counting its payroll withholding twice.
28. Include the documented family loan `Pai e Mãe` as a liability.
29. Prevent duplicated CIPÓ, Coopharma or family-loan rows and recalculate net worth from the reconciled asset/liability layers.

## F. Reviewed text-entry edit/delete lifecycle

30. The user-created internal transfer on 16/09/2026, Itaú → Bradesco, amount R$ 20.665, must display edit and delete actions in Flow.
31. Every user-confirmed text entry that reaches Flow must expose edit and delete actions subject to documentary protection rules.
32. A transfer is one logical event with two equal-and-opposite legs. Edit must change date, value, description and accounts for both legs atomically.
33. Delete/cancel must suppress both legs atomically; it must never leave one bank leg behind.
34. Consolidated economic effect must remain exactly zero before and after edit/cancel.
35. Mutations must remain append-only/auditable, idempotent, authenticated and scoped to the current user.
36. The exact user-created transfer must be covered by a real-data structural check; controlled fixtures alone are insufficient.

## Acceptance rule

- Each item must be linked to implementation, source evidence, deterministic test, authenticated read proof, or an explicitly open evidence dependency.
- Automated green does not equal user acceptance.
- No financial gap is solved by invention, silent zero-filling, relabelling alone or hiding a warning.
- V169 must pass desktop and mobile visual gates, mutation-contract gates, financial parity checks and protected-root checks before the fixed homologation is changed.
