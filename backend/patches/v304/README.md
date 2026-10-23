# V304: retain confirmed destination when a bank schedule becomes posted

A posted outgoing transfer to the owner's already-confirmed registered account
is not spending, even when the receiving institution has not delivered its leg.
The old scheduled-source validator correctly stops treating it as a projection
once posted. This narrower reader proves the debit with its stable source ID,
prior exact owner confirmation, unchanged date/amount/origin/destination,
provider identities, raw POSTED record, same CPF as the owned origin balance,
reciprocal destination routing, and unique active registered accounts.

The old scheduled raw hash remains in the confirmation; it is not falsely
required to equal the new posted raw hash. Both versions remain distinct.
Source status alone, recipient name or amount/date equality are insufficient.
Another person's Pix and ambiguous or changed identities remain reviewable.

Only the proved debit is excluded from expenses and annotated as an internal
transfer in the existing Flow reader. No receiving credit, financial event,
match, real-world transfer or balancing adjustment is created. Bank cash
amounts/dates/balances stay intact. The unmatched receiving leg remains an
explicit source limitation. Existing matched-pair annotations take precedence.

Both helpers are private; existing reader identity/ACL/configuration/security
attributes are preserved. There is no layout or published asset change.

The pure validator has 44 synthetic rejection cases. The separate live-source
rollback test compares complete source/decision/audit rows and every other
canonical expense, checks the exact monthly transfer-only delta, unchanged
cash/date/balance fields, unchanged prior-day history and event identities,
and definition replay (cache-epoch invalidation is intentional). No test is
receiving-bank proof or real private-session/device certification.
