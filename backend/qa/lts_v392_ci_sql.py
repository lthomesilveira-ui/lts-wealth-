"""Execute the actual C6 invoice-output query, with invented records only."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
print("SET check_function_bodies=off;")
print((R/'backend/qa/fixtures/v392_invoice_engine_before.sql').read_text()+';')
print((R/'backend/qa/fixtures/v392_identity_helpers.sql').read_text())
print(r'''
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,0);
CREATE TABLE public.card_invoices(id uuid,user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text);
INSERT INTO public.card_invoices VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','C6 Carbon · synthetic A','2026-11-01','2026-11-05','closed',99,'invented-received'),
 ('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','C6 Carbon · synthetic A','2026-12-01','2026-12-07','projected',8.9,'invented-projected'),
 ('10000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000002','C6 Carbon · synthetic B','2026-11-01','2026-11-05','paid',77,'invented-received');
CREATE TABLE public.qa_v392_cards(user_id uuid,payload jsonb);
INSERT INTO public.qa_v392_cards
SELECT ('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,
 jsonb_build_object('cards',jsonb_build_array(jsonb_build_object('family','c6','name','Bandeirado','cycles',
 jsonb_build_array(jsonb_build_object('month','2097-04-01','due_date','2097-04-05','amount',12.34,'basis','derived_current_installments'),
 jsonb_build_object('month','2097-05-01','due_date','2097-05-05','amount',4.56,'basis','derived_current_installments'))))) FROM generate_series(1,3)i;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT payload FROM public.qa_v392_cards WHERE user_id=$1$$;
CREATE TABLE public.qa_v392_queries(kind text,sql text);
CREATE FUNCTION public.qa_v392_capture(kind text)RETURNS void LANGUAGE plpgsql AS $capture$
DECLARE def text;part text;BEGIN
 def:=pg_get_functiondef('public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure);
 part:=substring(def FROM position('), c6_cycles AS MATERIALIZED ('IN def)+3);
 part:=substring(part FOR position('$function$'IN part)-1);
 INSERT INTO public.qa_v392_queries VALUES(kind,'WITH legacy_output AS(SELECT $1::uuid user_id,''Visa Aeternum''::text card_name,date ''2097-04-01'' reference_month,date ''2097-04-03'' due_date,''projected''::text status,44.44::numeric amount,''invented-other-bank''::text source),'||replace(part,'p_user_id','$1'));
END $capture$;
SELECT public.qa_v392_capture('before');
''')
patch=(R/'backend/patches/v392/c6_projection_identity.sql').read_text()
print(patch)
print("SELECT public.qa_v392_capture('after');")
print(patch)
print(r'''
DO $verify$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';other uuid:='00000000-0000-4000-8000-000000000002';fallback uuid:='00000000-0000-4000-8000-000000000003';q text;BEGIN
 EXECUTE 'CREATE TEMP TABLE before_rows AS '||(SELECT sql FROM public.qa_v392_queries WHERE kind='before')USING u;
 EXECUTE 'CREATE TEMP TABLE after_rows AS '||(SELECT sql FROM public.qa_v392_queries WHERE kind='after')USING u;
 IF (SELECT count(*)FROM before_rows)<>5 OR(SELECT count(*)FROM after_rows)<>5 THEN RAISE EXCEPTION 'Row count changed';END IF;
 IF EXISTS((SELECT user_id,reference_month,due_date,status,amount,source FROM before_rows EXCEPT ALL SELECT user_id,reference_month,due_date,status,amount,source FROM after_rows)
 UNION ALL(SELECT user_id,reference_month,due_date,status,amount,source FROM after_rows EXCEPT ALL SELECT user_id,reference_month,due_date,status,amount,source FROM before_rows))THEN RAISE EXCEPTION 'Financial attributes changed';END IF;
 IF(SELECT count(*)FROM after_rows WHERE reference_month>=date '2097-01-01' AND card_name='C6 Carbon · synthetic A')<>2 THEN RAISE EXCEPTION 'Canonical identity not reused';END IF;
 IF EXISTS(SELECT 1 FROM after_rows WHERE public.lts_card_family_v226(card_name,card_name)='c6'AND public.lts_forecast_series_key_v1('Fatura '||card_name)<>'card_c6')THEN RAISE EXCEPTION 'C6 forecast series unrecognized';END IF;
 IF EXISTS((SELECT *FROM before_rows WHERE reference_month<date '2097-01-01'OR card_name='Visa Aeternum' EXCEPT ALL SELECT *FROM after_rows WHERE reference_month<date '2097-01-01'OR card_name='Visa Aeternum')
 UNION ALL(SELECT *FROM after_rows WHERE reference_month<date '2097-01-01'OR card_name='Visa Aeternum' EXCEPT ALL SELECT *FROM before_rows WHERE reference_month<date '2097-01-01'OR card_name='Visa Aeternum'))THEN RAISE EXCEPTION 'Existing invoice or other bank changed';END IF;
 EXECUTE 'CREATE TEMP TABLE other_owner AS '||(SELECT sql FROM public.qa_v392_queries WHERE kind='after')USING other;
 IF EXISTS(SELECT 1 FROM other_owner WHERE card_name='C6 Carbon · synthetic A')OR(SELECT count(*)FROM other_owner WHERE reference_month>=date '2097-01-01'AND card_name='C6 Carbon · synthetic B')<>2 THEN RAISE EXCEPTION 'Cross-owner identity';END IF;
 EXECUTE 'CREATE TEMP TABLE no_canonical_source AS '||(SELECT sql FROM public.qa_v392_queries WHERE kind='after')USING fallback;
 IF(SELECT count(*)FROM no_canonical_source WHERE card_name='Bandeirado')<>2 THEN RAISE EXCEPTION 'Missing identity guessed';END IF;
 IF(SELECT epoch FROM public.lts_read_cache_epoch_v242)<>1 THEN RAISE EXCEPTION 'Replay changed source epoch';END IF;
END $verify$;
SELECT jsonb_build_object('pass',true,'version',392,'canonical_c6_series',true,'existing_invoices_exact',true,'amounts_dates_statuses_sources_exact',true,'other_bank_exact',true,'owner_isolation',true,'unknown_identity_preserved',true,'replay_noop',true);
''')
