# V225 consolidation — implementation under verification

User-authorized corrective handoff: 27 September 2026.

The approved Dashboard is identified by its complete runtime chain, not the version text in an HTML wrapper. Frozen V181 files are historical evidence and must never be modified.

The consolidated release retains the V181 Dashboard render chain and the later validated V183/V185 capabilities. It consumes current cash, Flow v13, current Planning, expenses, invoices and authenticated Open Finance readers. New data must not substitute a new Dashboard composition.

## Preserved contract

| Surface | Implementation evidence | Release verification |
| --- | --- | --- |
| Dashboard | V181 dependency order, current cash recovery, original complete render owner | Authenticated real-data QA pending |
| Expenses | V183 historical periods, monthly group totals, exact source drilldowns, pagination and race guards | Regression and real-data QA pending |
| Cards | Source inventory, period selection, documentary payment status, one obligation per cycle | Regression and real-data QA pending |
| Flow | Existing filters, bank scope, editable manual entries, noncash awards and source navigation; v13 reader | Regression and real-data QA pending |
| Wealth | Statement components, award provenance, retention composition and debt coverage | Regression and real-data QA pending |
| Open Finance | Existing hourly server scheduler; authenticated refresh at entry and on request, per-bank success timestamps | Refresh lifecycle QA pending |

Every local script and stylesheet is included in the versioned directory. `manifest.json` records content hashes and the protected historical hashes; future releases must use another directory. `provenance.json` records the source commit of the retained modules. The public root and earlier wrappers are unchanged.

V224 was not accepted by the user. It now reaches the signed-out login in the agent browser, which is not authenticated QA. The freezing was incomplete: its index, dynamically injected model and styles remained mutable. A later source change also replaced the required V179 Dashboard owner with its predecessor, and removed installation dependencies. These regressions are not copied into V225.

The previous Open Finance wrapper read `window.S`, while the application declares `S` as a global lexical binding. It could therefore skip installation. V225 installs the additive refresh control inside the authenticated application scope and checks actual synchronization completion instead of declaring success after a timer.

Backend assertions are independent of browser acceptance. Do not promote this candidate or invite user testing before the required browser checks. Private financial anchors and documentary gaps remain in the private corrective handoff; none are resolved or classified by this frontend consolidation.
