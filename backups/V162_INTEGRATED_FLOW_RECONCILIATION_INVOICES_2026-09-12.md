# Integrated Flow reconciliation and invoice model

Date: 2026-09-12. This is the implementation checkpoint; browser CI and final publication must be checked separately.

## Financial application
The user's renewed delivery request was executed through the authorized Supabase connector. The previously blocked Itaú statement reconciliation now committed successfully in the same channel; no alternate permission route was used. The exact already-received PDF is indexed privately with a before-image and checksum. Six missing statement facts were added once, two matching monthly forecasts were linked to their documentary payments without deleting originals, four dated statement closes were appended and the account anchor updated to the source date, not today's date. No bank payment or synthetic balancing transaction was executed.

The condominium identity is supported by the bank descriptor and the existing O Parque subsetor apart-hotel condominium correspondence. Unknown Pix purposes remain unclassified. Source posting dates prevail over dates embedded in descriptors. Prior manual financing, Larissa, insurance, Cofrinho and DDA decisions remain unchanged.

## Historical/current read consistency
A generic documented-close overlay corrects the historical reader's older carried-anchor mismatch using only snapshots on or before each displayed date plus effective intervening movements. It preserves the former calculation as provenance and never backfills older days from a later current position. The new dated Itaú source closes and current projection agree. C6 remains a single paid-cycle debit ending at the documentary zero balance. Bradesco's current observed balance is preserved; an unresolved small historical-to-observed residual is explicitly returned, not hidden in a made-up transaction. Bank evidence dates are returned so a projection cannot pretend to be a live bank consultation.

Applied runtime functions: lts_flow_documentary_close_overlay_v1 and the read-only integration in lts_browser_flow_v11. A preflight column-name ambiguity was corrected before final consumer testing. No grants or authentication boundaries were relaxed.

## Invoice linkage and source truth
lts_browser_card_settlement_detail_v3 requires exact bank, amount and an evidenced due/cash/payment date; ambiguous candidates return unmatched rather than taking the nearest month. The existing V2 consumer delegates to it. The Itaú cash-date case now resolves to its contractual invoice. Current open Aeternum uses its current verified source snapshot, not old legacy detail. Closed C6 retains its fee/reversal and excludes prior payment from new consumption. Unknown current Prime/other-Visa evidence is not fabricated.

Source dates, card finals and installments are shown only as documented. Open PDFs with printed day/month and no year keep that uncertainty. Credits awaiting classification are separate from unclassified spending. Existing LTS semantic rules and unambiguous exact historical categories are reused, never issuer categories or invented assignments.

## One presentation contract
The recovery owner now renders every card through all-cards-aeternum-summary-source-v1: inline summary, descending net category totals, documentary status and total, separate due/cash dates, pending charges/credits and full documented detail with back/close controls. An unmatched cycle gets the same surface with an explicit evidence gap. Protected index.html and the historical wrapper files are untouched. There are no permanent timers/observers. Late boot callbacks no longer force the user out of Updates. D-5 through D+30 and manual/bank-filter behavior are preserved.

## Verification boundary
Real consumer-shaped database reads confirm the updated Itaú source closes/current balance and exact Mastercard, Aeternum and C6 details; ambiguous generic Bradesco input remains unmatched. The new browser workflow tests the five supported card-name shapes, missing evidence, open/closed model, credit presentation, source-only fields, default/manual window, route stability and stateful classification save/refresh/reload in isolated fixtures on Chromium desktop/mobile and WebKit mobile. CI is pending at this checkpoint. This is not the user's signed-in browser session or physical-device E2E.

## Remaining gates
Verify all three browser workflows and Pages before final fixed-link exposure. Preserve the unresolved historical Bradesco residual, missing current other-Visa documentary identities, real-session classification lifecycle and every unrelated master-backlog dependency. Bulk classification is not automatically released by fixture tests. Dashboard remains out of scope and public-root promotion unauthorized. Store private data/QA in the private source-document layer, not this public repository.
