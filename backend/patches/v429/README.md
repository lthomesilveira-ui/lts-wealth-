# V429 — canonical card-cycle settlement

V429 makes an existing exact `lts_fact_confirmation` visible to the card-cycle
readers. It does not create or change a payment, invoice, expense, cash event, or
source snapshot.

The fallback requires one exact invoice and one exact confirmation for the same
owner, card name, reference month, due date, and amount. Ambiguous or changed
evidence remains unsettled. The prior reviewed documentary-link path is retained.
