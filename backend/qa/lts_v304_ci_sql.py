"""Pure evidence tests; no private manifest or production dependency."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
patch = (ROOT / 'backend/patches/v304/posted_own_transfer.sql').read_text()
pure = patch.split('CREATE OR REPLACE FUNCTION public.lts_posted_own_transfer_out_v304', 1)[0]
assert 'IMMUTABLE' in pure and 'SECURITY DEFINER' not in pure
assert 'FROM PUBLIC,anon,authenticated' in pure
print('BEGIN;')
print(pure)
print((ROOT / 'backend/qa/lts_v304_evidence.sql').read_text())
print("SELECT current_setting('lts.v304.synthetic_receipt')::jsonb receipt;ROLLBACK;")
