# Financial-first Flow: permanent acceptance addendum

This supplements AGENTS.md and UX_ACCEPTANCE.md. It is a product requirement, not a statement that a release has already passed.

The default Flow screen prioritizes account selection, period, dated balances and movements. Calculation assumptions, projection-update controls, source timestamps and the applications breakdown belong inside the existing **Opções** control. A stack of separate collapsed disclosures still consumes the main report; merely collapsing or shortening them is insufficient. Do not add new standalone premises panels to this screen in future versions.

Keep the original useful controls and their handlers available through Options. The menu starts closed and closes on navigation to another screen. It must support keyboard interaction and Escape, fit small mobile viewports, scroll its own long content and avoid horizontal overflow. Do not duplicate controls after refresh or ordinary rerendering. The visible period already communicates the selected horizon; do not repeat it in a standalone projection card.

Known reference assumptions, such as the last complete average still in use, belong in the deliberately opened premises. Genuine unavailable or incomplete numbers require a short, specific warning and concrete action near the affected report. Do not suppress stale/unavailable bank warnings, omit liabilities, replace unknown amounts with zero or imply successful verification after a failed read. Financial risk must remain visible. Raw implementation details remain private even inside Options.

Acceptance requires the complete app rendered with invented HTTP data in Chromium and WebKit on mobile and desktop. Compare financial responses with the immutable predecessor, measure the reclaimed report area, inspect closed/open screenshots, and verify original controls, failed/incomplete states, bank warnings, navigation and absence of duplicates. No owner screenshot or financial data may be published. Synthetic success is distinct from real authenticated-device acceptance and from publication.

This request is additive. It does not close unrelated historical or recovery/security requests, and changes no approved financial policy.
