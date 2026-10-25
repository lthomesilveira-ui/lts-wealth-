# V337 — monthly summary and current banks

The Dashboard adds a selectable monthly summary and current balances for the three connected banks. Monthly income, extraordinary entries, expenses and result come from the existing authenticated monthly reader. The current month stops on the business date; historical months use their full available period, starting on 10 October 2013.

The result uses expense competence and is not a bank cash balance. Own-account transfers and invoice payment duplication follow the existing canonical reader. The visual reference supplies layout ideas only, without importing its example amounts, changes or unproved asset history.

Bank rows require all three distinct banks, the current complete cash response and a reconciled total. Unknown or inconsistent data stays unavailable. Monthly responses must match the selected period and reconcile their components and totals. Superseded responses cannot replace another month or session. Source invalidation clears the summary and a new day clears the prior day's partial result. Failed reads use a human message and explicit retry.

Existing liquidity KPIs, assets, expenses, future cash, card actions, classifications and daily Flow are byte-identical to V335. There is no database or financial-data change.

Validation includes model rejection cases, immutable release hashes, the existing guarded-reader queue contract, and the actual release rendered with synthetic HTTP data at desktop and two mobile viewport sizes. The browser contract checks month switching, actual zero, stale responses, source failure and retry, collapsed source disclosures, bank totals, existing financial values, card actions and a 365-day clipboard export. Synthetic checks do not certify a private session or physical phone.
