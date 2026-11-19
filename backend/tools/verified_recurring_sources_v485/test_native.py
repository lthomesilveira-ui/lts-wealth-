"""Exercise the recurring-source upgrade on top of the preceding native guard fixture."""
import json
import re
import runpy
from pathlib import Path


here = Path(__file__).resolve().parent
previous = runpy.run_path(str(here.parent / "verified_projection_sources_v473" / "test_native.py"))
sql = previous["sql"]
digest = previous["digest"]
function_hash = previous["function_hash"]
key = previous["key"]
profile = previous["profile"]
review = previous["review"]

# Restore the view deliberately changed by the preceding regression test.
sql("CREATE OR REPLACE VIEW public.fixture_calendar AS SELECT 1 AS month")
original = json.loads(sql(f"SELECT {profile}"))
assert key()
sql("CREATE OR REPLACE FUNCTION public.fixture_inputs() RETURNS int LANGUAGE sql AS $$SELECT 8$$")
sql("CREATE FUNCTION public.fixture_recurring() RETURNS int LANGUAGE sql AS $$SELECT 9$$")
assert not key()

signatures = ["public.fixture_inputs()", "public.fixture_recurring()"]
pins = [{"signature": sig, "md5": function_hash(sig)} for sig in signatures]
updated = dict(original, producers=[original["producers"][0], *pins])
expected = digest(updated)
substitutions = {
    "3a941712276413c8dc88ef621e7d0f66": digest(original),
    "c4e51592379f1caca088b740531ce940": expected,
    "78a07ebc6f58b8fae2e3d2b4c257199a": function_hash(profile),
    "cd1353fdd869841803cdb3007e7c3db1": function_hash(review),
    "11b67db251b1a4c9c06fa8a959cf220c": function_hash(previous["long_guard"]),
}
migration = (here / "install.sql").read_text()
assert all(marker in migration for marker in substitutions)
migration = re.sub(r"[0-9a-f]{32}", lambda m: substitutions.get(m[0], m[0]), migration)
migration = re.sub(r"\$pins\$.*?\$pins\$", lambda _: "$pins$" + json.dumps(pins) + "$pins$",
                   migration, flags=re.S)

def set_helper(value):
    sql(f"CREATE OR REPLACE FUNCTION public.fixture_recurring() RETURNS int LANGUAGE sql AS $$SELECT {value}$$")

set_helper(10)
try:
    sql("BEGIN;" + migration + "COMMIT;")
except RuntimeError as error:
    assert "Unexpected projection producer" in str(error)
else:
    raise AssertionError("Unknown input definition was accepted")
assert json.loads(sql(f"SELECT {profile}")) == original
set_helper(9)
sql("BEGIN;" + migration + "COMMIT;")
assert json.loads(sql(f"SELECT {profile}")) == updated
assert json.loads(sql(f"SELECT {previous['schema']}.review_guard_v450('{previous['owner']}')")) == expected
assert key() and key() == key()
set_helper(10)
assert not key()
print("Checked migration rollback, updated review and flow keys, and invalidation on helper change.")
