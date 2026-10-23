"""Emit deterministic synthetic SQL, never a private financial manifest."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
patch = (ROOT / "backend/patches/v302/partial_obligation_evidence.sql").read_text()
helper = patch.split("DO $patch$", 1)[0]
assert "CREATE OR REPLACE FUNCTION public.lts_partial_obligation_settlement_valid_v302" in helper
assert "SECURITY DEFINER" not in helper
assert "FROM PUBLIC,anon,authenticated" in helper
assert "partial_paid_source_v302" in patch
assert "owner_confirmed_partial_obligation_v302" in patch
print("BEGIN; CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;")
print(helper)
print((ROOT / "backend/qa/lts_v302_partial_evidence.sql").read_text())
print("SELECT current_setting('lts.v302.synthetic_receipt')::jsonb receipt; ROLLBACK;")
