# Despesas — Existing-reader adapters and request lifecycle

14/09/2026. Implementation supplement to LTS_WEALTH_DESPESAS_EXECUTION_PLAN.md. Does not replace financial rules, create a new app, or certify real totals.

## Current code recovered before implementation
The protected index.html contains despesas(), expenseDualState() and loadExpenseDual(): the active Caixa/Consumo component reads lts_browser_expense_dual_lens_v1 and also uses older D.expense_drilldown data for some detail sections. The executive v3/v4 and monthly-detail v2 paths inspected earlier are additional existing report paths, not interchangeable with the primary dual-lens component.

This turn read only the definitions of lts_browser_expense_dual_lens_v1 and lts_expense_dual_lens_v1. The concrete dual payload version is expense-dual-lens-v2-recent-cash. No function was executed to obtain expense values and no denied query was replayed. Cash, consumption and total-expense report meanings must not be compared as though they were identical.

## Implemented modules
lts-expense-read-model.js exports pure adapters for the actual dual-lens payload, monthly-detail v2 and executive-v12 versus same-month detail. It runs in Node or a browser and has no RPC names, SQL, credentials, network, storage, category inference or source mutations. Amounts are parsed into exact integer cents; missing/invalid values are not replaced with zero. Original categories, dates and signs remain intact.

Monthly normalization verifies the selected scope, source identity within the month, returned row count, total, category totals and documented detail levels. Transaction, category-only and total-only history remain distinct. Older purchase dates do not remove a documented current-period installment. Rankings retain descending original names. Summary/detail comparison rejects different date/category scopes and respects truncated top rankings; agreement between two reports is not proof of source correctness.

Dual normalization preserves separate cash and consumption amounts, checks bucket/month/category accounting identities and refuses to sum the two views. A missing monthly point remains null instead of becoming a fabricated zero. The recent cash list remains explicitly limited, not a full statement. Zero net unclassified value is not evidence of zero unclassified records. No source reconciliation or asset/financing redefinition is performed.

createReadSession provides selection-scoped asynchronous state. New selections invalidate older responses; late success/error cannot overwrite a newer selection. Loading/error/authentication states do not keep a stale total under a new period. Raw server errors are not sent to the view. Invalidation/disposal clears the in-memory result. There is no automatic retry or background polling. A caller must explicitly inject its already-authorized response loader; this module itself cannot open another path to a blocked operation.

.github/scripts/lts_expense_reader_adapter.cjs now connects monthly payload normalization to the EXISTING lts_expense_integrity.cjs checker. It requires independently verified bindings between exact report identities and canonical source references, explicit economic treatment, coverage and date basis. It never constructs a link from amount or merchant. Missing bindings fail rather than silently normalize the data into a passing comparison.

## Tests executed
Local Node syntax checks passed. Tests: 20 original integrity tests (original file SHA unchanged), 52 monthly/executive/adapter/session tests and 14 dual-lens tests: 86 PASS. The adapter was tested end-to-end against the unchanged original checker, including stale categories, payment/control double-consumption, open-invoice disclosure and missing-document binding.

An offline Chromium fixture passed eight lifecycle/presentation checks at each of 1366x900 and 390x844: sixteen checks. Every network request was denied, with zero attempts. This was a synthetic fixture using the module and text-only rendering, NOT the actual LTS screen, the user's session, an iPhone or real financial-data E2E.

.github/workflows/expense-read-contract.yml adds repeatable code-contract CI on relevant changes to main and the active recovery branch, plus manual dispatch. It has contents:read only and no financial credentials. It runs the three Node suites and isolated browser fixture and uploads synthetic JSON evidence. Local PASS does not claim a remote run has finished; inspect workflow receipts separately.

## Activation boundary
The new module is NOT referenced by index.html, the V162 candidate or its recovery runtime. The current app and fixed homologation remain unchanged. This package is a tested reader/lifecycle implementation ready for controlled integration, not an updated Despesas screen. No cached summary was refreshed, no source category applied and no numerical report reconciled.

The next permitted integration must connect the existing component to this module without another wrapper/iframe chain or permanent observers. Supply verified real-data lineage and closure status, prove source/report agreement, then use the new lifecycle state and explicit coverage in the component. Do not classify a primary-lens response as a monthly-detail response or force executive totals to equal a different consumption definition. The injected transport is not a bypass for denied calls.

All prior pending writes and technical reconciliation issues remain. The completed H questionnaire must not be asked again. Preserve the 07/07 inclusive scope, original history, deferred nomenclature map, protected Flow, source dates and confirmed monetary rules. Patrimônio and the new Dashboard retain their separate gates.
