from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent
patch = (root / "install.sql").read_text()
params = "(date,date,integer,integer,text)"
targets = [
    "lts_browser_expense_review_queue_v229",
    "lts_browser_income_review_queue_v296",
]
card = "lts_browser_card_review_queue_v312"
sql = "BEGIN;\n"
for name in [*targets, card]:
    budget = " SET statement_timeout = '18s'" if name == card else ""
    sql += f"""CREATE FUNCTION public.{name}{params} RETURNS int LANGUAGE sql
        SET search_path = ''{budget} AS 'SELECT 7';\n"""
sql += """CREATE TEMP TABLE original AS SELECT oid,proname,prosrc,proacl,proowner,
    prosecdef,proconfig FROM pg_proc WHERE proname LIKE 'lts_browser_%review_queue_%';\n"""
sql += patch + "\n" + patch
sql += """DO $check$
BEGIN
    IF (SELECT count(*) FROM original) <> 3 THEN RAISE EXCEPTION 'Missing fixture'; END IF;
    IF EXISTS (SELECT 1 FROM original o JOIN pg_proc p ON p.oid=o.oid
        WHERE p.prosrc <> o.prosrc OR p.proacl IS DISTINCT FROM o.proacl
           OR p.proowner <> o.proowner OR p.prosecdef <> o.prosecdef
           OR p.proconfig IS DISTINCT FROM
              CASE WHEN o.proname = 'lts_browser_card_review_queue_v312' THEN o.proconfig
                   ELSE array_append(o.proconfig,'statement_timeout=18s') END) THEN
       RAISE EXCEPTION 'Unintended function change';
    END IF;
END $check$;
ROLLBACK;
"""
subprocess.run(["psql","-X","-v","ON_ERROR_STOP=1","-q"], input=sql, text=True, check=True)
