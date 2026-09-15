# V163 post-login Dashboard fix — verified release receipt

Date: 15/09/2026

Status: **FIXED, PUBLISHED AND VERIFIED IN AN AUTHENTICATED REAL BROWSER SESSION; HUMAN/PHYSICAL-DEVICE ACCEPTANCE OPEN**

## Incident

The fixed V163 homologation page was published, but the user's real login path still presented the previous product route. The prior release verification covered deployment, redirect, the genuine signed-out login and a controlled browser fixture that started preauthenticated. It did not verify the signed-out → authenticated transition and therefore did not justify a claim that the post-login Dashboard had been delivered successfully.

Root cause: the V163 outer runtime treated the login state as terminal and did not rearm when the inner `index.html` stored a new session. The preserved V162 Flow layer remained active, so the real path could land on the prior Flow presentation.

## Correction

- branch: `work/v163-post-login-dashboard-fix-20260915`;
- tested/integrated remote head: `f4e2ce4cfc77b8bc3e1812f642f40fda5e36f43c`;
- rearm only on a newly stored `lts_supabase_session_v1` session;
- login hides the loading cover but is no longer considered successful Dashboard completion;
- runtime cache key: `20260915-post-login-rearm-v2`;
- new deterministic gate starts signed out, submits the app's actual login form against controlled authentication/read fixtures, and requires Dashboard without page or iframe reload;
- no financial writer, database, taxonomy, source reader, reconciled expense rule, V150/V151 Flow behavior or protected public root was changed.

## Automated evidence

- branch V163 gate: `34982425323` — SUCCESS;
- branch artifact: `10401124348`;
- artifact digest: `sha256:cdb0f02a5f921ad243cbf37aaa1aa8de53aae188320f4fda6acb36efa2c4d80f`;
- main V163 gate: `34982625911` — SUCCESS;
- native GitHub Pages: `34982624816` — SUCCESS.

The artifact explicitly labels its financial payload as controlled fixture data, not user validation.

## Published authenticated-browser verification

The fixed V163 candidate loaded the new runtime URL and, after secure authentication in the actual LTS Wealth login form, opened `Dashboard` rather than remaining on the previous route. Visible evidence included:

- `Sua posição financeira`;
- `Tenho dinheiro suficiente?`;
- a populated decision state;
- populated first-negative, covered-until and worst-projected-balance fields;
- five liquidity/expense KPI cards;
- projected cash evolution, bank position, commitments, expenses, Patrimônio validation notice, planning and updates;
- successful Dashboard → Fluxo Diário → Dashboard navigation.

No credential was exposed to the executor or recorded. Exact private financial values are intentionally omitted from this public receipt. The browser verification proves the delivered read/presentation path at that time; it does not certify every source document, physical iPhone rendering, public-root promotion or whole-product acceptance.

The first post-fix browser pass also exposed a metadata-only inconsistency: `homologacao-current.json` still encoded the pre-fix `6cc1e616` candidate hash even though Pages served the corrected runtime. The manifest was therefore updated to `f4e2ce4cfc77b8bc3e1812f642f40fda5e36f43c` before final handoff; this did not change application behavior or financial data.

## Remaining gates

- human review of the Dashboard presentation and numbers on notebook and phone;
- iterative visual/information adjustments requested from that review;
- independent Patrimônio verification;
- existing documentary and physical-device backlog items;
- public-root promotion remains a separate explicit decision.
