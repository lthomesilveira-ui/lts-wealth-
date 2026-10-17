-- SYNTHETIC ONLY. Fresh isolated PostgreSQL17 required.
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid NOT NULL,raw_hash text,resource_type text,provider_record_id text,provider_account_ref text,institution_code text,description_raw text,signed_amount numeric,currency text,posting_date date,normalized_payload jsonb,provider_deleted_at timestamptz,raw_payload jsonb);
CREATE TABLE public.lts_v178_review_decision(user_id uuid NOT NULL,source_table text NOT NULL,source_ref text NOT NULL,beneficiary text,property_code text,category_label text,decision_basis text NOT NULL,decided_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(user_id,source_table,source_ref));
CREATE TABLE public.lts_access_audit(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,user_id uuid,email text,action text,meta jsonb);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY CHECK(singleton),epoch bigint NOT NULL);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,cache_key text);
CREATE TABLE public.fixture_expense(id integer PRIMARY KEY,payload jsonb NOT NULL);
CREATE TYPE public.fixture_expense_type AS (amount numeric,row_key text,category text,event_date date,source_ref text,beneficiary text,description text,raw_category text,source_table text,coverage_mode text,property_code text,purchase_date date,raw_reference text,account_source text,identity_status text,competence_month date,management_group text,transaction_date date,property_component text,management_subgroup text);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,700);
CREATE FUNCTION public.lts_open_finance_pilot_owner_v1() RETURNS uuid LANGUAGE sql STABLE AS $f$ SELECT 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'::uuid; $f$;
CREATE FUNCTION public.lts_bank_known_classification_v231(uuid,uuid) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT NULL::text; $f$;
CREATE FUNCTION public.lts_card_installment_key_v231(s public.lts_open_finance_staging) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT s.raw_payload#>>'{creditCardMetadata,synthetic_key}'; $f$;
CREATE FUNCTION public.lts_card_source_rows_pre_v262(uuid) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT NULL::text; $f$;
CREATE FUNCTION public.lts_expense_rows_v230_baseline(uuid,date,date) RETURNS text LANGUAGE sql STABLE AS $f$ SELECT NULL::text; $f$;
CREATE OR REPLACE FUNCTION public.lts_v246_invalidate_finance_cache()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE changed boolean:=false; ignored text[]:=ARRAY[]::text[];
BEGIN
 IF TG_TABLE_SCHEMA='public' AND left(TG_TABLE_NAME,7)='health_' THEN RETURN NULL; END IF;
 IF TG_OP='TRUNCATE' THEN changed:=true;
 ELSIF TG_TABLE_NAME='lts_open_finance_observation' THEN
  IF TG_OP='INSERT' THEN
   SELECT EXISTS(SELECT 1 FROM new_rows n
    WHERE n.resource_type='balance' AND n.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
    AND NOT EXISTS(SELECT 1 FROM public.lts_open_finance_observation o
      WHERE o.user_id=n.user_id AND o.connection_id=n.connection_id AND o.resource_type='balance'
       AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
       AND o.provider_record_id=n.provider_record_id AND o.raw_hash=n.raw_hash
       AND o.normalized_payload=n.normalized_payload AND o.raw_payload=n.raw_payload
       AND NOT EXISTS(SELECT 1 FROM new_rows inserted WHERE inserted.id=o.id))) INTO changed;
  ELSIF TG_OP='DELETE' THEN
   SELECT EXISTS(SELECT 1 FROM old_rows WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT') INTO changed;
  ELSE
   SELECT EXISTS(
    (SELECT to_jsonb(n)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM new_rows n
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
     EXCEPT ALL
     SELECT to_jsonb(o)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM old_rows o
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT')
    UNION ALL
    (SELECT to_jsonb(o)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM old_rows o
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
     EXCEPT ALL
     SELECT to_jsonb(n)-ARRAY['sync_run_id','observed_at','ingest_action','reconciliation'] FROM new_rows n
      WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT')) INTO changed;
  END IF;
 ELSIF TG_OP='INSERT' THEN SELECT EXISTS(SELECT 1 FROM new_rows) INTO changed;
 ELSIF TG_OP='DELETE' THEN SELECT EXISTS(SELECT 1 FROM old_rows) INTO changed;
 ELSE
  IF TG_TABLE_NAME='lts_open_finance_staging' THEN ignored:=ARRAY['sync_run_id','last_seen_at','updated_at'];
  ELSIF TG_TABLE_NAME='lts_open_finance_connection' THEN ignored:=ARRAY['last_attempt_at','last_success_at','last_error_code','last_error_summary','updated_at']; END IF;
  SELECT EXISTS(
   (SELECT to_jsonb(n)-ignored FROM new_rows n EXCEPT ALL SELECT to_jsonb(o)-ignored FROM old_rows o)
   UNION ALL
   (SELECT to_jsonb(o)-ignored FROM old_rows o EXCEPT ALL SELECT to_jsonb(n)-ignored FROM new_rows n)) INTO changed;
 END IF;
 IF changed THEN
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
  DELETE FROM public.lts_v229_read_cache WHERE user_id IS NOT NULL;
 END IF;
 RETURN NULL;
END $function$
;
CREATE TRIGGER lts_v246_read_i AFTER INSERT ON public.lts_v178_review_decision REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_d AFTER DELETE ON public.lts_v178_review_decision REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_u AFTER UPDATE ON public.lts_v178_review_decision REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_t AFTER TRUNCATE ON public.lts_v178_review_decision FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache();
CREATE FUNCTION public.lts_v229_expense_rows(p_user uuid,p_start date,p_end date) RETURNS SETOF public.fixture_expense_type LANGUAGE plpgsql VOLATILE AS $f$
DECLARE r record; j jsonb; changed boolean;
BEGIN
 SELECT EXISTS(SELECT 1 FROM public.lts_v178_review_decision WHERE source_table='lts_open_finance_staging') INTO changed;
 IF current_setting('fixture.warm_cache',true)='on' THEN INSERT INTO public.lts_v229_read_cache VALUES(p_user,'synthetic-reader-warm'); END IF;
 FOR r IN SELECT f.id,f.payload,d.category_label,d.beneficiary FROM public.fixture_expense f LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user AND d.source_table=f.payload->>'source_table' AND d.source_ref=f.payload->>'source_ref' ORDER BY f.id LOOP
  j:=r.payload;
  IF r.category_label IS NOT NULL THEN j:=j||jsonb_build_object('category',r.category_label,'beneficiary',r.beneficiary,'identity_status','identified','row_key','synthetic-classified:'||(j->>'source_ref'),'management_group',r.category_label,'management_subgroup',r.category_label); END IF;
  IF changed AND r.id=6 AND current_setting('fixture.outside',true)='on' THEN j:=j||jsonb_build_object('category','SYNTHETIC UNRELATED CHANGE'); END IF;
  IF changed AND r.id=7 AND current_setting('fixture.null_outside',true)='on' THEN j:=j||jsonb_build_object('category','SYNTHETIC NULL CHANGE'); END IF;
  IF changed AND r.id=1 AND current_setting('fixture.amount',true)='on' THEN j:=j||jsonb_build_object('amount',999); END IF;
  IF changed AND r.id=1 AND current_setting('fixture.raw_reference',true)='on' THEN j:=j||jsonb_build_object('raw_reference','SYNTHETIC CHANGED REFERENCE'); END IF;
  IF changed AND r.id=1 AND current_setting('fixture.classification',true)='on' THEN j:=j||jsonb_build_object('identity_status','pending'); END IF;
  IF changed AND r.id=1 AND current_setting('fixture.missing',true)='on' THEN CONTINUE; END IF;
  RETURN NEXT jsonb_populate_record(NULL::public.fixture_expense_type,j);
 END LOOP;
END $f$;
