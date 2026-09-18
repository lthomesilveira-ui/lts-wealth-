# V175 — Source audit findings — 18/09/2026

Status: SOURCE AUDIT COMPLETE / IMPLEMENTATION IN PROGRESS
Baseline preserved: V174 fixed homologation
Public root: protected / unchanged

## 1. Historical workbook recovered
Authoritative historical workbook available in the user Library was materialized read-only:
- file: `Controle_Financeiro_v16.xlsm`;
- source Library file id: `file_000000007b20720ea920e6bbdc7147ac`;
- SHA-256: `57a7efb384f410d02f698de1bcefc6190112edcf68a41cb2f79b49fc8a102c1e`.

Relevant sheets include `Consolidado Cartão de Crédito`, `Balanço Mensal`, `Pagamentos e Recebimentos`, `Cartão Itaú VISA`, `Cartão Itaú`, `Cartão Aeternum`, `Cartão C6`, `Cartão Bradesco` and `Investimento Cipó 396`.

## 2. Restaurants / iFood / Rafiki gap root cause
The user's observation was correct. V174 was reading aggregate-only invoice rows for several months and therefore lacked the historical category breakdown even though the source workbook contains it.

The workbook monthly category matrix reconciles exactly to the current card total for every month from Nov/2025 through Jun/2026. The following source-backed category totals are now recovered:

| Month | Restaurants | iFood | Rafiki | Card total |
|---|---:|---:|---:|---:|
| Nov/2025 | R$ 3.627,53 | R$ 2.154,55 | R$ 1.322,40 | R$ 44.670,99 |
| Dec/2025 | R$ 8.696,00 | R$ 2.791,62 | R$ 1.862,40 | R$ 49.137,85 |
| Jan/2026 | R$ 2.274,69 | R$ 515,60 | R$ 1.706,17 | R$ 26.164,68 |
| Feb/2026 | R$ 708,70 | R$ 1.848,76 | R$ 1.651,89 | R$ 24.448,52 |
| Mar/2026 | R$ 1.284,70 | R$ 2.263,38 | R$ 3.302,19 | R$ 35.623,38 |
| Apr/2026 | R$ 2.751,09 | R$ 2.943,13 | R$ 2.606,36 | R$ 31.888,09 |
| May/2026 | R$ 4.269,15 | R$ 2.130,92 | R$ 7.554,86 | R$ 35.072,44 |
| Jun/2026 | R$ 4.051,72 | R$ 2.665,96 | R$ 5.312,54 | R$ 34.503,59 |

A new private source table `lts_v175_workbook_monthly_category_source` stores the non-zero category evidence. It is used only when:
- the sum of source categories equals the declared workbook card total; and
- that declared total equals the current LTS card total for the month.

This rule prevents a category allocation from changing total spend or being applied to a mismatched month. The July workbook total does not exactly reconcile to the current LTS card total, so July is not overwritten by the workbook source.

## 3. Expense universe
V175 keeps the economic total unchanged while improving category attribution:
- supported current-account expenses remain;
- supported card purchases remain;
- a full card month is replaced by the certified monthly category decomposition only when exact total parity holds;
- card settlement is not added again;
- internal transfers remain neutral;
- credits/estornos remain signed reductions;
- aggregate-only invoice coverage is retained for unrecovered months.

## 4. Itaú loan root cause
The V174 display of approximately R$ 567k as if it were `Itaú` was incorrect.

Root cause:
- 107 rows carried source category `Empréstimos`;
- their `origin_name` was `Itau`, which is the cash account;
- V174 used that account name as the loan subgroup;
- this collapsed multiple distinct historical lenders into a single false `Empréstimo · Itaú`.

Actual historical paid split by counterparty:
- Itaú: 20 rows, R$ 267.441,25;
- CooperMSD: 57 rows, R$ 224.164,59;
- Coopharma: 19 rows, R$ 84.569,38;
- CGI: 14 rows, R$ 50.569,72;
- CEF: 9 rows, R$ 20.345,40;
- Funcef: 7 rows, R$ 4.900,00.

Total historical loan/consignado payments remain R$ 651.990,34.

Financial meaning:
- these are historical cash payments, not current debt balances;
- Coopharma has a documented schedule: 48 installments, R$ 80.399,54 paid, R$ 131.816,69 remaining scheduled outflow as of 27/08/2026, but no documentary debt-stock value;
- no current documentary payoff/debt position for the Itaú personal loan was found.
Therefore no R$ 567k Itaú debt or loan amount may be displayed.

## 5. Família
The canonical historical rows classified `Família` in the expense ledger were checked against the cash reader. They are real negative/outgoing Itaú events, including rows explicitly described as `Larissa` and `Família`; they are not positive receipts accidentally treated as expenses.

V175 keeps these rows under the explicit presentation `Família — saídas`. Incoming family receipts, if present, remain in the income universe rather than being netted into these outflows.

## 6. Stock/share sale income
Canonical 2026 explicit stock-sale proceeds recovered from Flow:
- Jan/2026: R$ 9.903,59;
- Feb/2026: R$ 14.609,78;
- Mar/2026: R$ 21.924,71;
- Apr/2026: unresolved source gap;
- May/2026: R$ 19.154,73;
- Jun/2026: R$ 19.699,64;
- Jul/2026: R$ 19.566,43;
- Aug/2026: R$ 19.095,04.

September evidence:
- 02/09/2026, C6, R$ 18.808,69;
- source: `financial_events`;
- description: `Transferência de C6 Conta Global`;
- metadata explicitly records `sale_context_confirmed_by_user=true` and `documented_c6_global_to_c6_brl`.
V175 uses this evidence as the September extraordinary share-sale amount while subsequent C6 -> Itaú/Bradesco transfers remain consolidated-neutral.

April evidence gap:
The user confirms a sale occurred in Apr/2026, but no source amount was found after searching:
- `financial_events`;
- `evento_base`;
- `evento_usuario`;
- liquidity movements;
- reconciliation evidence;
- reviewed input applications;
- the recovered historical workbook.
No amount will be fabricated. Open issue persisted as `stock_sale_2026_04_missing_source`.

## 7. Property works / reform
Preserved reconciliation:
- workbook summary: R$ 2.177.714,78;
- confirmed source duplicate: R$ 2.937,26;
- reconciled unique amount: R$ 2.174.777,52.

V175 source-reconciled work components are used for the full-history category view. Acquisition/history remains separate. The current dated/card-classified portion is R$ 1.232.040,02; aggregate-only historical property-card evidence remains R$ 942.462,49. That gap is evidence without invented purchase dates.

## 8. Historical card inventory
Evidence now resolves the historical card set instead of limiting the UI to current cards:

### Itaú
- Mastercard / current Personnalite Black lineage, historical Flow 2013–2026;
- Visa Itaú, historical Flow 2013–2021;
- Visa Infinite Itaú, 2024–2026 evidence.

### Bradesco
- Visa Aeternum;
- Visa Infinite Prime, final 3980, explicitly independent from Aeternum in the raw card registry.

### C6
- historical final 6610;
- C6 Carbon final 7873;
- C6 Carbon final 8304.

Inactive historical cards remain visible as historical instruments.

## 9. Card screen semantics
Current future comparison must keep distinct:
- observed invoice;
- contracted installment floor;
- canonical Flow amount;
- considered amount.

Known Aeternum evidence:
- Sep/2026 documented invoice: R$ 24.390,64;
- Oct/2026 contracted installment floor: R$ 5.318,86;
- Oct/2026 canonical Flow amount currently: R$ 11.202,03.

The installment floor must never be labeled as the Flow amount.

## 10. Monthly balance / Desde 2013
The V175 backend reader `lts_browser_monthly_balance_v5` was tested directly over 10/10/2013 through 18/09/2026:
- 156 months returned;
- first month: Oct/2013;
- last month: Sep/2026;
- 92 expense groups;
- 4 extraordinary groups.

The V174 user-visible hang is therefore a layered client/render lifecycle problem, not missing backend history. V175 will avoid rendering a 156-month × ~90-group matrix and will use a bounded annual summary plus one selected year of monthly detail.

## 11. Additive database objects applied
Migrations:
- `v175_workbook_monthly_category_source`;
- `v175_expense_financial_audit_core`;
- `v175_expense_financial_audit_readers`;
- `v175_cipo_component_order_fix`.

No raw financial event, card source row or historical ledger row was rewritten.
