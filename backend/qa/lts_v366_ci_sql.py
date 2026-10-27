"""Native tests of the actual V366 writer and horizon worker with synthetic sources."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
patch=(R/'backend/patches/v366/recurring_continuity.sql').read_text().replace('public.','v366_fixture.')
key=(R/'backend/qa/fixtures/v366_series_key.sql').read_text().replace('public.','v366_fixture.')
print(r'''
BEGIN;
CREATE SCHEMA v366_fixture;GRANT USAGE ON SCHEMA v366_fixture TO authenticated;
CREATE SCHEMA auth;CREATE SCHEMA cron;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
CREATE FUNCTION auth.uid()RETURNS uuid LANGUAGE sql STABLE AS $$SELECT nullif(current_setting('request.jwt.claim.sub',true),'')::uuid$$;
CREATE FUNCTION cron.schedule(text,text,text)RETURNS bigint LANGUAGE sql AS $$SELECT 1::bigint$$;
CREATE TABLE v366_fixture.evento_base(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,usuario_id uuid,idx integer,dados jsonb);
CREATE TABLE v366_fixture.audit_log(user_id uuid,action text,entity_type text,entity_id text,details jsonb);
CREATE TABLE v366_fixture.lts_category_catalog(user_id uuid,category text,active boolean);
CREATE TABLE v366_fixture.lts_projection_replacement_rule(id text PRIMARY KEY,user_id uuid,source_table text,description_exact text,account_exact text,date_from date,date_to date,action text,replacement_source text,replacement_ref text,reason text,evidence jsonb,active boolean);
CREATE TABLE v366_fixture.lts_flow_future_read_cache(user_id uuid);
CREATE TABLE v366_fixture.lts_flow_future_read_cache_v2(user_id uuid);
CREATE FUNCTION v366_fixture.lts_browser_assert_user_v1()RETURNS uuid LANGUAGE plpgsql AS $$DECLARE u uuid:=auth.uid();BEGIN IF u IS NULL THEN RAISE EXCEPTION 'auth required';END IF;RETURN u;END$$;
CREATE FUNCTION v366_fixture.lts_category_name_v290(uuid,text)RETURNS text LANGUAGE sql AS $$SELECT $2$$;
CREATE FUNCTION v366_fixture.lts_v178_norm(text)RETURNS text LANGUAGE sql AS $$SELECT lower(coalesce($1,''))$$;
''')
print(key)
print(r'''
CREATE FUNCTION v366_fixture.lts_corrected_cashflow_operational_v1(uuid,date,date)RETURNS TABLE(event_date date,account text,description text,signed_amount numeric)LANGUAGE sql AS $$
SELECT(b.dados->>'dia')::date,b.dados->>'conta',b.dados->>'desc',(b.dados->>'valor')::numeric*CASE WHEN b.dados->>'efeito'='saida' THEN -1 ELSE 1 END
FROM v366_fixture.evento_base b WHERE b.usuario_id=$1 AND(b.dados->>'dia')::date BETWEEN $2 AND $3 AND NOT EXISTS(SELECT 1 FROM v366_fixture.lts_projection_replacement_rule r WHERE r.user_id=$1 AND r.active AND r.action='suppress_legacy' AND r.replacement_ref='evento_base:'||b.idx AND(b.dados->>'dia')::date BETWEEN r.date_from AND r.date_to)$$;
''')
print(patch)
print(r'''
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
CREATE TEMP TABLE inputs AS SELECT jsonb_build_object('description','Mensalidade sintética','direction','saida','account','Itaú','value_kind','fixed','amount',10,'cadence_months',1,'due_day',31,'starts_on',(date_trunc('month',current_date)+interval '1 month')::date,'ends_on',NULL,'category',NULL,'active',true)j;
DO $test$
DECLARE u uuid:=auth.uid();j jsonb:=(SELECT inputs.j FROM inputs);r jsonb;n integer;before_n integer;next_year date;plan uuid;old_event jsonb;
BEGIN
 r:=v366_fixture.lts_recurring_materialize_v366(u);IF(r->>'created')::int<>0 THEN RAISE EXCEPTION 'Empty rule created events';END IF;
 r:=v366_fixture.lts_browser_recurring_plan_save_v366(0,j);n:=(r->>'created')::int;plan:=(r->>'plan_id')::uuid;
 IF n<40 OR n>60 THEN RAISE EXCEPTION 'Five-year count: %',n;END IF;
 IF EXISTS(SELECT 1 FROM v366_fixture.evento_base WHERE(dados->>'dia')::date<=current_date)THEN RAISE EXCEPTION 'Past created';END IF;
 IF NOT EXISTS(SELECT 1 FROM v366_fixture.evento_base WHERE extract(month FROM(dados->>'dia')::date)=2 AND extract(day FROM(dados->>'dia')::date)IN(28,29))THEN RAISE EXCEPTION 'Month clipping absent';END IF;
 before_n:=(SELECT count(*)FROM v366_fixture.evento_base);
 r:=v366_fixture.lts_browser_recurring_plan_save_v366(0,j);IF r->>'already_saved'<>'true' OR(SELECT count(*)FROM v366_fixture.evento_base)<>before_n THEN RAISE EXCEPTION 'Retry duplicated';END IF;
 r:=v366_fixture.lts_recurring_materialize_v366(u);IF(r->>'created')::int<>0 THEN RAISE EXCEPTION 'Worker duplicated';END IF;
 next_year:=(date_trunc('year',current_date)+interval '1 year')::date;r:=v366_fixture.lts_recurring_materialize_v366(u,next_year);
 IF(r->>'created')::int<>12 OR extract(year FROM(r->>'horizon_end')::date)<>extract(year FROM next_year)+4 THEN RAISE EXCEPTION 'Rolling year did not extend';END IF;
 BEGIN PERFORM v366_fixture.lts_browser_recurring_plan_save_v366(0,j||'{"amount":11}');RAISE EXCEPTION 'Stale revision accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM='Stale revision accepted' THEN RAISE;END IF;END;
 BEGIN PERFORM v366_fixture.lts_browser_recurring_plan_save_v366(0,j||'{"description":"Salário","amount":11}');RAISE EXCEPTION 'Salary fixed invented';EXCEPTION WHEN raise_exception THEN IF SQLERRM='Salary fixed invented' THEN RAISE;END IF;END;
 BEGIN PERFORM v366_fixture.lts_browser_recurring_plan_save_v366(0,j||'{"description":"Transferência própria"}');RAISE EXCEPTION 'One-leg transfer accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM='One-leg transfer accepted' THEN RAISE;END IF;END;
 BEGIN PERFORM v366_fixture.lts_browser_recurring_plan_save_v366(0,j||jsonb_build_object('description','No passado','starts_on',current_date));RAISE EXCEPTION 'Past start accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM='Past start accepted' THEN RAISE;END IF;END;
 BEGIN PERFORM v366_fixture.lts_browser_recurring_plan_save_v366(0,j||'{"description":"Invalid amount","amount":10.123}');RAISE EXCEPTION 'Subcent value accepted';EXCEPTION WHEN raise_exception THEN IF SQLERRM='Subcent value accepted' THEN RAISE;END IF;END;
 before_n:=(SELECT count(*)FROM v366_fixture.evento_base);
 r:=v366_fixture.lts_browser_recurring_plan_save_v366(0,j||'{"description":"Variável sintética","value_kind":"variable","amount":null}');IF(r->>'created')::int<>0 OR(SELECT count(*)FROM v366_fixture.evento_base)<>before_n THEN RAISE EXCEPTION 'Variable inferred';END IF;
 r:=v366_fixture.lts_browser_recurring_plan_save_v366(1,j||'{"active":false}');IF(r->>'created')::int<>0 THEN RAISE EXCEPTION 'Cancel created';END IF;
 IF EXISTS(SELECT 1 FROM v366_fixture.lts_corrected_cashflow_operational_v1(u,current_date+1,(next_year+interval '5 years')::date)WHERE description='Mensalidade sintética')THEN RAISE EXCEPTION 'Cancelled rule left effective future';END IF;
 IF has_function_privilege('authenticated','v366_fixture.lts_recurring_materialize_v366(uuid,date)','EXECUTE') OR has_function_privilege('anon','v366_fixture.lts_browser_recurring_plan_save_v366(integer,jsonb)','EXECUTE')THEN RAISE EXCEPTION 'Helper privileges exposed';END IF;
 r:=v366_fixture.lts_browser_recurring_plan_save_v366(0,j||jsonb_build_object('description','Série com fim','ends_on',(j->>'starts_on')::date+interval '2 months'));IF(r->>'created')::int NOT BETWEEN 1 AND 3 THEN RAISE EXCEPTION 'End date ignored';END IF;
 IF EXISTS(SELECT 1 FROM v366_fixture.evento_base WHERE dados->>'desc'='Série com fim'AND(dados->>'dia')::date>((j->>'starts_on')::date+interval '2 months')::date)THEN RAISE EXCEPTION 'Past explicit end';END IF;
END $test$;
SET LOCAL ROLE authenticated;
DO $test$BEGIN IF(SELECT count(*) FROM v366_fixture.lts_recurring_plan_v366)<1 THEN RAISE EXCEPTION 'Owner RLS missing';END IF;END$test$;
RESET ROLE;
SELECT set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $test$BEGIN IF(SELECT count(*) FROM v366_fixture.lts_recurring_plan_v366)<>0 THEN RAISE EXCEPTION 'Other owner read rules';END IF;IF(v366_fixture.lts_browser_recurring_plans_v366()->'rules')<>'[]'::jsonb THEN RAISE EXCEPTION 'Other owner RPC read rules';END IF;END$test$;
RESET ROLE;
SELECT jsonb_build_object('version',366,'pass',true,'empty_rule_no_effect',true,'rolling_five_years',true,'retry_idempotence',true,'month_end_clipping',true,'explicit_end',true,'cancel_preserves_source',true,'variable_no_amount_inferred',true,'fixed_salary_rejected',true,'own_transfer_rejected',true,'stale_revision_rejected',true,'owner_isolation',true,'helper_acl_private',true,'synthetic_native',true);
ROLLBACK;
''')
