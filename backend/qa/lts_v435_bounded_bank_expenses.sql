\set ON_ERROR_STOP on
\ir fixtures/v435/bounded_bank_setup.sql

CREATE TEMP TABLE scenarios (label text,who uuid,date_from date,date_to date);
INSERT INTO scenarios VALUES
 ('month',fixture_v435.id(1),'2026-02-01','2026-02-28'),
 ('single',fixture_v435.id(1),'2026-02-10','2026-02-10'),
 ('boundary',fixture_v435.id(1),'2026-02-11','2026-02-11'),
 ('empty dates',fixture_v435.id(1),'2026-02-01','2026-02-02'),
 ('empty owner',fixture_v435.id(3),'2026-02-01','2026-02-28'),
 ('other owner',fixture_v435.id(2),'2026-02-10','2026-02-10'),
 ('unbounded end',fixture_v435.id(1),'2026-02-10',NULL),
 ('null start',fixture_v435.id(1),NULL,'2026-02-28'),
 ('inverted',fixture_v435.id(1),'2026-02-11','2026-02-10');

CREATE FUNCTION pg_temp.results() RETURNS TABLE(label text,rows jsonb) LANGUAGE sql AS $$
 SELECT s.label,coalesce((SELECT jsonb_agg(to_jsonb(x) ORDER BY id) FROM public.lts_v229_new_bank_rows(s.who,s.date_from,s.date_to)x),'[]'::jsonb)
 FROM pg_temp.scenarios s
$$;
CREATE TEMP TABLE before_patch AS SELECT * FROM pg_temp.results();
CREATE TEMP TABLE before_acl AS
 SELECT oid,to_jsonb(p)-'prosrc' attrs FROM pg_proc p WHERE oid='public.lts_v229_new_bank_rows(uuid,date,date)'::regprocedure;

\ir ../patches/v435/bounded_bank_expense_reader.sql
\ir ../patches/v435/bounded_bank_expense_reader.sql

DO $$
BEGIN
 IF EXISTS(SELECT * FROM pg_temp.results() EXCEPT SELECT * FROM before_patch) THEN
  RAISE EXCEPTION 'Expense records differ from the previous reader';
 END IF;
 IF (SELECT array_agg(id ORDER BY id) FROM public.lts_v229_new_bank_rows(fixture_v435.id(1),'2026-02-10','2026-02-10'))
   IS DISTINCT FROM ARRAY[fixture_v435.id(108),fixture_v435.id(109)] THEN
  RAISE EXCEPTION 'Transfer, receipt, category or ambiguity fixture did not exercise the expected records';
 END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v229_new_bank_rows(fixture_v435.id(1),'2026-02-11','2026-02-11')) THEN
  RAISE EXCEPTION 'Filtering before monthly deduplication promoted a repeated debit';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p JOIN before_acl b ON p.oid=b.oid AND (to_jsonb(p)-'prosrc')=b.attrs) THEN
  RAISE EXCEPTION 'Function identity or execution permissions changed';
 END IF;
END $$;

ALTER SEQUENCE fixture_v435.context_calls RESTART WITH 1;
DO $$
BEGIN
 PERFORM * FROM public.lts_v229_new_bank_rows(fixture_v435.id(1),'2026-01-01','2026-02-02');
 PERFORM * FROM public.lts_v229_new_bank_rows(fixture_v435.id(1),'2026-02-11','2026-02-11');
 IF (SELECT is_called FROM fixture_v435.context_calls) THEN RAISE EXCEPTION 'Unnecessary context read'; END IF;
 PERFORM * FROM public.lts_v229_new_bank_rows(fixture_v435.id(1),'2026-02-10','2026-02-10');
 IF NOT (SELECT is_called AND last_value=1 FROM fixture_v435.context_calls) THEN
  RAISE EXCEPTION 'Eligible debit requires exactly one context read';
 END IF;
END $$;
SELECT 'V435 exact expense parity, owner isolation, replay and context gating passed';
