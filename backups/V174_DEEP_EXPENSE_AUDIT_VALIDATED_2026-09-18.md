# V174 — Deep Despesas audit validated — 18/09/2026

Status: BRANCH VALIDATED; HOMOLOGATION PUBLICATION PENDING
Baseline preserved: V173 fixed homologation
Validated branch: `work/v174-v173-user-review-20260918`
Validated head: `c01f166bea4140d581580e1986b21107594c3c9c`
Gate: GitHub Actions `35364448303` — SUCCESS
Public root: protected / unchanged

## User review scope closed by this candidate
The V174 package addresses the deep Despesas review registered in `backups/V174_V173_USER_REVIEW_REGISTER_2026-09-18.md`:
- property works / reform reconciliation;
- extraordinary share-sale income;
- Restaurants / iFood / Rafiki monthly gaps;
- Família appearing under expenses;
- historical Itaú loan presentation;
- full-period monthly balance since 2013;
- cards / invoices vs Flow precedence.

## Property investment / works
Private reconciliation proves:
- workbook `Reformas & Melhorias`: R$ 2.177.714,78;
- unique reconciled evidence: R$ 2.174.777,52;
- confirmed workbook duplicate: R$ 2.937,26 (`Móveis - O Parque`);
- real Flow contains only the unique economic R$ 2.937,26, split as R$ 1.780,00 on 26/11/2024 and R$ 1.157,26 on 11/02/2025;
- historical property-card aggregates documented in the workbook: R$ 1.465.713,29;
- currently individualized/recovered property-card detail: R$ 523.044,27;
- documented aggregate-only gap: R$ 942.669,02.

V174 separates generic acquisition/history `Cipó 396` from works and exposes the reconciled works value without inventing dates or purchases.

## Monthly balance
Backend `lts_browser_monthly_balance_v3` was verified for every annual slice from 2013 through 2026 and for the complete 2013-10-10 → 2026-09-18 range.
The complete reader returns 156 months.
The V174 client uses the audited full-range v3 reader directly and retains annual fallback if the direct read fails; the browser gate verifies that `Desde 2013` no longer blanks.

## Extraordinary stock sales
The prior monthly classifier excluded explicit stock-sale proceeds because they were asset movements / excluded from spend.
V174 restores explicit stock-sale realization as extraordinary income while keeping subsequent C6 → Itaú/Bradesco internal transfers neutral.
For 2026 through 18/09, the recovered stock-sale supplement is R$ 123.953,92.

## Categories with missing monthly purchase detail
The expense cache contains aggregate invoice coverage for historical months where purchase-level category detail is not available.
V174 no longer represents a category cell as a confident zero when the month has aggregate-only card coverage; such cells show `—*` with an explicit disclosure.
No Restaurant, iFood, Rafiki or other category is invented from an aggregate invoice.

## Família
Audit of current source rows confirms that `Família` in Despesas includes real outgoing payments/transfers (including outgoing Itaú → Larissa rows). V174 labels this explicitly as `Família — saídas`; it does not convert them to income by assumption.

## Loans
The large Itaú number in the expense composition is cumulative historical paid expense, not current debt.
V174 labels it `Histórico pago · Itaú`; current debt remains governed by documentary commitment readers.

## Cards vs Flow
V174 distinguishes:
- known invoice;
- contracted installment floor;
- actual value currently used in Flow;
- considered value.

Observed Aeternum example in current readers:
- Sep/2026 documented invoice: R$ 24.390,64;
- Oct/2026 contracted installment floor: R$ 5.318,86;
- Oct/2026 canonical Flow amount: R$ 11.202,03.

The previous card screen incorrectly made the floor look like the Flow value. V174 shows both and preserves Flow precedence.

## Database changes
Applied additive read-model migrations only; no financial source row mutation:
- `v174_expense_deep_audit_readers`;
- `v174_monthly_stock_sale_column_fix`.

Tracked migration file:
`supabase/migrations/20260918152137_v174_expense_deep_audit_readers.sql`.

## Validation
Run `35364448303` passed:
- V174 static contract;
- desktop browser gate;
- 390 px mobile browser gate;
- full-history monthly load;
- reconciled property display;
- extraordinary stock-sale presentation;
- aggregate-only monthly disclosure;
- card / Flow comparison;
- V173 / V172 / V171 / V170 protected contracts;
- integrated Flow;
- bank scope;
- invoice reading order;
- documentary Flow roll-forward.

No production promotion is authorized by this receipt.
