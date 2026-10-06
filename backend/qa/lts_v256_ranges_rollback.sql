BEGIN;
SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
SELECT set_config('request.jwt.claims',(SELECT jsonb_build_object('sub',id,'email',email,'role','authenticated')::text FROM auth.users WHERE id=public.lts_open_finance_pilot_owner_v1()),true);
CREATE TEMP TABLE ranges_v256(lo date,hi date,prior jsonb,prior_ms numeric) ON COMMIT DROP;
CREATE TEMP TABLE results_v256(lo date,hi date,prior_ms numeric,candidate_ms numeric,digest text,days int) ON COMMIT DROP;
INSERT INTO ranges_v256(lo,hi) VALUES('2019-01-01','2020-12-31'),('2026-07-01','2026-07-31'),('2027-01-01','2027-12-31'),(current_date,'2027-12-31');
CREATE TEMP TABLE acls_v256 AS SELECT oid,proacl FROM pg_proc WHERE oid IN('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure,'public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
DO $before$ DECLARE r record;t timestamptz;j jsonb;
BEGIN
 FOR r IN SELECT lo,hi FROM ranges_v256 LOOP
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
  t:=clock_timestamp();j:=public.lts_browser_flow_v242(r.lo,r.hi);
  UPDATE ranges_v256 SET prior=j,prior_ms=round(extract(epoch from clock_timestamp()-t)*1000,3) WHERE lo=r.lo AND hi=r.hi;
 END LOOP;
END $before$;
-- V256: linear JSON assembly and one classification lookup per event.
DO $v256$
DECLARE s text; needle text;
BEGIN
 s:=pg_get_functiondef('public.lts_flow_observed_position_guard_v1(jsonb,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'8824224c21aaf1cc83623d9bd4294ac2' THEN RAISE EXCEPTION 'V256_GUARD_SOURCE_CHANGED';END IF;
 needle:=$old$ f jsonb:=p_flow; d jsonb; old_day jsonb; days jsonb:='[]'; bank_name text;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_DECLARATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ f jsonb:=p_flow; d jsonb; old_day jsonb; day_rows_v256 jsonb[]:=ARRAY[]::jsonb[]; bank_name text;$new$);
 needle:=$old$  days:=days||jsonb_build_array(d);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_APPEND_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$  day_rows_v256:=array_append(day_rows_v256,d);$new$);
 needle:=$old$ RETURN jsonb_set(f,'{current_future,days}',days);$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_GUARD_RETURN_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ RETURN jsonb_set(f,'{current_future,days}',to_jsonb(day_rows_v256));$new$);
 EXECUTE s;
 s:=pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure);
 IF md5(btrim(s,E' \t\r\n'))<>'d7b44020c937ef74e4698437af9497a9' THEN RAISE EXCEPTION 'V256_CLASSIFICATION_SOURCE_CHANGED';END IF;
 needle:=$old$ LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;$old$;
 IF (length(s)-length(replace(s,needle,'')))/length(needle)<>1 THEN RAISE EXCEPTION 'V256_CLASSIFICATION_NOT_UNIQUE';END IF;
 s:=replace(s,needle,$new$ -- Keep this expression behind a lateral evaluation barrier: the same
 -- classification JSON is consumed by several output fields.
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL OFFSET 0) k ON true;$new$);
 EXECUTE s;
END $v256$;

DO $after$ DECLARE r record;t timestamptz;j jsonb;again jsonb;ms numeric;ds jsonb;
BEGIN
 FOR r IN SELECT * FROM ranges_v256 LOOP
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
  t:=clock_timestamp();j:=public.lts_browser_flow_v242(r.lo,r.hi);ms:=round(extract(epoch from clock_timestamp()-t)*1000,3);
  again:=public.lts_browser_flow_v242(r.lo,r.hi);
  IF j::text IS DISTINCT FROM r.prior::text OR again::text IS DISTINCT FROM j::text THEN RAISE EXCEPTION 'V256_FULL_OR_REPEAT_CHANGED % %',r.lo,r.hi;END IF;
  ds:=coalesce(j#>'{flow,historical,days}','[]')||coalesce(j#>'{flow,current_future,days}','[]');
  IF jsonb_array_length(ds)<>r.hi-r.lo+1 THEN RAISE EXCEPTION 'V256_RANGE_DAYS_MISSING';END IF;
  INSERT INTO results_v256 VALUES(r.lo,r.hi,r.prior_ms,ms,md5(j::text),jsonb_array_length(ds));
 END LOOP;
 IF EXISTS(SELECT 1 FROM acls_v256 a JOIN pg_proc p ON p.oid=a.oid WHERE a.proacl IS DISTINCT FROM p.proacl) THEN RAISE EXCEPTION 'V256_ACL_CHANGED';END IF;
END $after$;
SELECT 'PASS' status,jsonb_agg(to_jsonb(r)) ranges,true full_json_and_text_exact,true repeat_exact,true acl_exact,false financial_source_changes,false ui_authenticated FROM results_v256 r;
ROLLBACK;
