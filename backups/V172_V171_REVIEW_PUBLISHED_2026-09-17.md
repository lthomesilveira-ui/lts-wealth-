# V172 — V171 review closure published

Date: 17/09/2026  
Status: PUBLISHED IN FIXED HOMOLOGATION; PUBLIC ROOT UNCHANGED; HUMAN ACCEPTANCE PENDING

## Authorization and lineage

The user authorized autonomous implementation and publication only in homologation for `lthomesilveira-ui/lts-wealth-`.

- Previous main at implementation start: `f0c40837d144644e7435b4250cc5d8b1b6b1879a`.
- Tested V172 branch head: `5789fe38fe101d175c72ffe727e5bbd4bb647058`.
- Product squash merge on main: `1af047cbac2919c2a51f1b850afdf982153d78d8`.
- Manifest squash merge on main: `5a8cbfb27d3a806880cd309f7c8f70fc022681dd`.
- Product branch: `work/v172-v171-user-review-20260917`; release branch: `work/v172-release-20260917`.
- Candidate: `wip35-v172-candidate.html`.
- Pull requests: `#13` and `#14`.

No public promotion was authorized. `index.html` remained byte-for-byte unchanged with SHA-256 `cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b`.

## Root cause and Flow correction

V171 requested two ranges and inherited a compatibility remap that sent both through the heavier V12 reader. One slow historical call rejected the all-or-nothing promise and blanked the entire table, including data already available. Measured against the authenticated readers, the five-day historical V12 call took about 9.2 seconds while the bounded V11 history took about 2.5 seconds; the future V12 call was fast.

V172 now:

- opens from five days before today through 31 December of the current year;
- loads bounded V11 history and V12 future independently, so one failure cannot erase the other result;
- upgrades historical rows asynchronously through V12 when available, without blanking the fast result on timeout;
- deduplicates layered default requests;
- preserves the validated `RSU vested` and `Saldo c/ RSU` columns and removes internal audit wording.

The browser gate deliberately times out the historical V12 upgrade and still requires non-empty rows, exact opening/closing arithmetic and both RSU columns.

## Expense and monthly-balance correction

- Dashboard and Despesas remove redundant grey subtype captions; `Empréstimos e consignado` is presented as `Empréstimos`.
- Management rankings contain evidenced financial groups only. Generic property labels are not used as categories, and work/reform, financing and recurring property costs remain separate.
- Card and current-account totals are combined without double counting. The audited 12-month total is R$ 1.046.624,74: R$ 486.565,76 in cards plus R$ 560.058,98 in accounts. The 2026 selected-period total is R$ 752.104,87: R$ 338.718,59 in cards plus R$ 413.386,28 in accounts.
- The R$ 270.849,19 historical card amount is no longer shown as a fake category. It is the total of 24 invoice cycles for which the source has a reconciled invoice total but no individual purchase rows. Those amounts were already included in card totals; inventing merchants or categories would be false.
- The monthly balance reads long selections in annual chunks and merges them chronologically, covering the supported history from 2013 without one long blocking request.
- Extraordinary income explicitly names sales of shares and RSUs as well as other assets; the existing historical `Venda Ações` records remain in that source group.

No database migration or financial write was required for V172.

## Patrimônio correction

- Visão geral is grouped into current net worth, current assets, known debt, pensions and future compensation instead of mixing apartments, shares, vehicles and liabilities in one flat sequence.
- Non-product explanations such as `valor central documentado` and `obrigações sem saldo de quitação` were removed.
- The Morgan/RSU summary prioritizes the decisions requested by the user: gross statement total, available now, future projected net and total projected net. The projected tax reserve remains a secondary explanatory note, not a primary KPI.
- Bulk and individual vesting price/FX controls remain available.

## Automated and publication evidence

- V172 branch gate `35273688049` — SUCCESS.
- V171 protected regression on the V172 branch `35273688138` — SUCCESS.
- V172 main gate `35274059546` — SUCCESS.
- Product Pages deployment `35274059060` — SUCCESS.
- Manifest-branch V172/V171 gates `35274441560` / `35274441618` — SUCCESS.
- Post-manifest V172 `35274767490` — SUCCESS.
- V171/V170/V169 compatibility `35274767603` / `35274768120` / `35274767547` — SUCCESS.
- Integrated Flow and invoices `35274767653` — SUCCESS.
- Flow default window `35274767686` — SUCCESS.
- Candidate smoke `35274767723` — SUCCESS.
- V163/V164/V165 compatibility `35274767549` / `35274767697` / `35274767646` — SUCCESS.
- Fixed-manifest Pages deployment `35274766884` — SUCCESS.
- Desktop 1440 × 1000 and mobile 390 × 844 — PASS.
- Static V170/V171 contracts and protected Flow, invoice and bank-scope regressions — PASS.

Live HTTP verification returned the V172 manifest, `LTS Wealth · Homologação V172`, the V172 runtime asset and the unchanged public root hash. The fixed target is `https://lthomesilveira-ui.github.io/lts-wealth-/homologacao.html`.

## Remaining gate

The user should perform human authenticated review in the fixed homologation link, with Flow loading as the first priority. Public-root promotion remains a separate explicit decision and was not performed.
