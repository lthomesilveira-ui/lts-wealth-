"""Emit a disposable synthetic fixture with exact reviewed reader definitions."""
from pathlib import Path

root = Path(__file__).resolve().parent
# SQL forward references in the bounded stubs resolve after all definitions load.
print("SET check_function_bodies=off;")
print((root / "fixture.sql").read_text())
for name in ("corrected_memo.sql", "historical_memo.sql", "source.sql"):
    print((root / "baseline" / name).read_text())
print("SET check_function_bodies=on;")
print("""
CREATE TABLE qa_v426.baseline AS SELECT
 public.lts_open_finance_sources_v226(public.lts_open_finance_pilot_owner_v1(),current_date-365,current_date) payload,
 qa_v426.financial_signature() financial_signature,
 (SELECT to_jsonb(p) FROM pg_proc p WHERE oid='public.lts_open_finance_sources_v226(uuid,date,date)'::regprocedure) attrs;
GRANT SELECT ON qa_v426.baseline TO service_role;
TRUNCATE public.lts_v229_read_cache;
""")
