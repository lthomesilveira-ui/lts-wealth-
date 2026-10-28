"""Execute the current production audit against explicit synthetic calendars."""
from pathlib import Path
import subprocess
import sys

R = Path(__file__).resolve().parents[2]
base = subprocess.run([sys.executable, str(R/'backend/qa/lts_v360_ci_sql.py')],
                      check=True, capture_output=True, text=True).stdout
assert base.rstrip().endswith('ROLLBACK;')
print(base[:base.rindex('ROLLBACK;')])
print(r'''
CREATE TABLE v303_fixture.lts_card_due_transition_v370(user_id uuid,family text,last_old_due date,first_new_due date,decision_source text,confirmed_at timestamptz);
INSERT INTO v303_fixture.lts_card_due_transition_v370 VALUES
('00000000-0000-4000-8000-000000000001','aeternum','2026-10-25','2026-12-03','synthetic-confirmation','2026-10-27T15:00:00Z');
CREATE TABLE v303_fixture.v371_flow(user_id uuid,event_date date,description text,source text,source_ref text,confidence text,signed_amount numeric,account text);
INSERT INTO v303_fixture.v371_flow VALUES
('00000000-0000-4000-8000-000000000001','2026-10-25','Visa Aeternum','card_invoice','oct-cycle','documented_open',-300,'Bradesco'),
('00000000-0000-4000-8000-000000000001','2026-12-03','Visa Aeternum','card_invoice','nov-cycle','documented_open',-350,'Bradesco'),
('00000000-0000-4000-8000-000000000001','2027-01-03','Visa Aeternum','card_invoice','dec-cycle','documented_open',-150,'Bradesco'),
('00000000-0000-4000-8000-000000000001','2026-11-16','Itaú Mastercard','card_invoice','itau-nov','documented_open',-80,'Itaú');
CREATE OR REPLACE FUNCTION v303_fixture.lts_corrected_cashflow_operational_v1(uuid,date,date)
RETURNS TABLE(event_date date,description text,source text,source_ref text,confidence text,signed_amount numeric,account text)
LANGUAGE sql AS $$SELECT event_date,description,source,source_ref,confidence,signed_amount,account
FROM v303_fixture.v371_flow WHERE user_id=$1 AND event_date BETWEEN $2 AND $3$$;
''')
print((R/'backend/qa/fixtures/v366_series_key.sql').read_text().replace('public.','v303_fixture.'))
print((R/'backend/qa/fixtures/v371/lts_recurring_future_gap_audit_v6.sql').read_text().replace('public.','v303_fixture.')+';')
print(r'''
CREATE TEMP TABLE v371_before AS SELECT v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2026-10-27','2027-03-31')j;
CREATE TEMP TABLE v371_other_before AS SELECT v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000002','2026-10-27','2027-03-31')j;
CREATE TEMP TABLE v371_attrs AS SELECT to_jsonb(p)-'prosrc' j FROM pg_proc p WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
CREATE TEMP TABLE v371_sources AS SELECT jsonb_build_object('flow',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_ref)FROM v303_fixture.v371_flow r),'legacy',(SELECT jsonb_agg(to_jsonb(r)ORDER BY idx)FROM v303_fixture.evento_base r),'staging',(SELECT jsonb_agg(to_jsonb(r)ORDER BY id)FROM v303_fixture.lts_open_finance_staging r))j;
''')
patch = (R/'backend/patches/v371/confirmed_calendar_coverage.sql').read_text().replace('public.','v303_fixture.')
patch = patch.replace('md5(definition)', "md5(replace(definition,'v303_fixture.','public.'))")
patch = patch.replace('md5(new_definition)', "md5(replace(new_definition,'v303_fixture.','public.'))")
print(patch)
print(r'''
DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';j jsonb;x jsonb;y jsonb;p jsonb;
BEGIN
 j:=v303_fixture.lts_recurring_future_gap_audit_v6(u,'2026-10-27','2027-03-31');
 IF(j-'horizon_checks')IS DISTINCT FROM(SELECT b.j-'horizon_checks' FROM v371_before b)THEN RAISE EXCEPTION 'Unrelated response changed';END IF;
 FOR x IN SELECT value FROM jsonb_array_elements(j->'horizon_checks')LOOP
  SELECT value INTO y FROM v371_before b,jsonb_array_elements(b.j->'horizon_checks')WHERE value->>'key'=x->>'key';
  IF x->>'key'<>'card_aeternum'AND x IS DISTINCT FROM y THEN RAISE EXCEPTION 'Other series changed';END IF;
  IF x->>'key'='card_aeternum'THEN
   IF(x->'missing_months')?'2026-11'OR NOT((x->'missing_months')?'2027-02')OR(x->>'gap_count')::int<>(y->>'gap_count')::int-1 THEN RAISE EXCEPTION 'Wrong month exempted';END IF;
   SELECT value INTO p FROM jsonb_array_elements(x->'period_coverage')WHERE value->>'period_start'='2026-11-01';
   IF p->>'status'<>'no_payment_due'OR p->>'actual_events'<>'0'OR p->>'future_events'<>'0'OR p#>>'{confirmed_transition,first_new_due}'<>'2026-12-03'THEN RAISE EXCEPTION 'Skip was represented as payment';END IF;
   IF(SELECT jsonb_agg(v)FROM jsonb_array_elements(x->'period_coverage')v WHERE v->>'period_start'<>'2026-11-01')IS DISTINCT FROM(SELECT jsonb_agg(v)FROM jsonb_array_elements(y->'period_coverage')v WHERE v->>'period_start'<>'2026-11-01')THEN RAISE EXCEPTION 'October or later period changed';END IF;
  END IF;
 END LOOP;
 IF v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000002','2026-10-27','2027-03-31')IS DISTINCT FROM(SELECT b.j FROM v371_other_before b)THEN RAISE EXCEPTION 'Confirmation leaked to another owner';END IF;
 -- A received movement wins even when a calendar says no payment is expected.
 INSERT INTO v303_fixture.v371_flow VALUES(u,'2026-11-20','Visa Aeternum','received','synthetic-received','bank_documented',-9,'Bradesco');
 j:=v303_fixture.lts_recurring_future_gap_audit_v6(u,'2026-10-27','2027-03-31');
 SELECT p0 INTO p FROM jsonb_array_elements(j->'horizon_checks')x0,jsonb_array_elements(x0->'period_coverage')p0 WHERE x0->>'key'='card_aeternum'AND p0->>'period_start'='2026-11-01';
 IF p->>'status'<>'covered'OR p->>'future_events'<>'1'OR p?'confirmed_transition'THEN RAISE EXCEPTION 'Received movement hidden by transition';END IF;
 DELETE FROM v303_fixture.v371_flow WHERE source_ref='synthetic-received';
 UPDATE v303_fixture.lts_card_due_transition_v370 SET first_new_due='2026-11-03';
 j:=v303_fixture.lts_recurring_future_gap_audit_v6(u,'2026-10-27','2027-03-31');
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'horizon_checks')x0 WHERE x0->>'key'='card_aeternum'AND(x0->'missing_months')?'2026-11')THEN RAISE EXCEPTION 'Ordinary date change invented a skip';END IF;
 UPDATE v303_fixture.lts_card_due_transition_v370 SET first_new_due='2026-12-03';
 IF(SELECT b.j FROM v371_attrs b)IS DISTINCT FROM(SELECT to_jsonb(p0)-'prosrc'FROM pg_proc p0 WHERE oid='v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)THEN RAISE EXCEPTION 'Function attributes changed';END IF;
 IF(SELECT b.j FROM v371_sources b)IS DISTINCT FROM jsonb_build_object('flow',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_ref)FROM v303_fixture.v371_flow r),'legacy',(SELECT jsonb_agg(to_jsonb(r)ORDER BY idx)FROM v303_fixture.evento_base r),'staging',(SELECT jsonb_agg(to_jsonb(r)ORDER BY id)FROM v303_fixture.lts_open_finance_staging r))THEN RAISE EXCEPTION 'Source mutated';END IF;
END $test$;
CREATE TEMP TABLE v371_replay AS SELECT pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)definition;
''')
print(patch)
print(r'''
DO $$BEGIN IF(SELECT definition FROM v371_replay)IS DISTINCT FROM pg_get_functiondef('v303_fixture.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)THEN RAISE EXCEPTION 'Replay changed body';END IF;END$$;
SELECT jsonb_build_object('version',371,'pass',true,'production_audit_body_executed',true,'intentional_no_payment_month',true,'october_unconfirmed_preserved',true,'later_gaps_preserved',true,'other_series_and_owner_preserved',true,'received_movements_win',true,'same_month_change_no_skip',true,'raw_sources_preserved',true,'attributes_preserved',true,'replay_noop',true);
ROLLBACK;
''')
