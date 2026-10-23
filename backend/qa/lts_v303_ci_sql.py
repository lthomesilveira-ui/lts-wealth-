"""Emit isolated synthetic SQL; no private identities or financial manifest."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
patch = (ROOT / 'backend/patches/v303/paid_audit_identity.sql').read_text()
helper = patch.split('DO $patch$', 1)[0]
assert 'SECURITY DEFINER' not in helper
assert 'FROM PUBLIC,anon,authenticated' in helper
old = (ROOT / 'backend/patches/recurring_obligation_evidence_v266.sql').read_text()
old = old[old.index('CREATE OR REPLACE FUNCTION'):old.index('DO $access$')]
card = (ROOT / 'backend/patches/v291/settled_legacy_card_plan.sql').read_text()
card = card[card.index('CREATE OR REPLACE FUNCTION'):card.index('REVOKE')]
chunks = [
    'BEGIN;',
    (ROOT / 'backend/qa/lts_v303_fixture.sql').read_text(),
    card, old,
    "CREATE TEMP TABLE v303_baseline AS SELECT v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2020-04-20','2020-06-30') audit;",
    patch,
    (ROOT / 'backend/qa/lts_v303_receipt_cases.sql').read_text(),
    "CREATE TEMP TABLE v303_replay AS SELECT pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) definition;",
    patch,
    "DO $$ BEGIN IF (SELECT definition FROM v303_replay) IS DISTINCT FROM pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure) THEN RAISE EXCEPTION 'replay changed function'; END IF; END $$;",
    "SELECT current_setting('lts.v303.synthetic_receipt')::jsonb receipt; ROLLBACK;",
]
for chunk in chunks:
    print(chunk.replace('public.', 'v303_fixture.'))
