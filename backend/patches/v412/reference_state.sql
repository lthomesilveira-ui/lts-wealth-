-- A complete prior annual reference survives a delayed statement in January.
-- This namespace contains derived planning evidence, never bank/payment records.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.reference_state(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE raw text;expected text;result jsonb;
BEGIN
 SELECT valor_bruto,sha256 INTO raw,expected FROM public.legacy_namespace
 WHERE usuario_id=p_user_id AND chave='lts_projection_reference_v412';
 IF NOT FOUND THEN RETURN jsonb_build_object('schema_version',1,'revision',0,'series','[]'::jsonb);END IF;
 IF expected IS DISTINCT FROM encode(sha256(convert_to(raw,'UTF8')),'hex')
  THEN RAISE EXCEPTION 'A última referência de projeção precisa ser conferida.';END IF;
 result:=raw::jsonb;
 IF result->>'schema_version' IS DISTINCT FROM '1' OR jsonb_typeof(result->'series') IS DISTINCT FROM 'array'
  OR coalesce(result->>'revision','')!~'^[0-9]+$'
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(result->'series')x
   GROUP BY x->>'series_key' HAVING count(*)>1)
  THEN RAISE EXCEPTION 'A última referência de projeção está incompleta.';END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.reference_state(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.reference_state(uuid) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh_reference(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id);old_state jsonb;
 result jsonb;previous_series jsonb;next_series jsonb;facts jsonb;r jsonb;candidate jsonb;key text;
 wf date;wt date;nr date;n int;partial_count int;total numeric;mean numeric;refs jsonb;hashes jsonb;
 raw text;digest text;changed int:=0;deferred int:=0;
BEGIN
 IF policy IS NULL THEN RETURN jsonb_build_object('changed',false,'updated_series',0); END IF;
 PERFORM pg_advisory_xact_lock(hashtextextended(p_user_id::text,166));
 old_state:=lts_projection_private_v412.reference_state(p_user_id);
 previous_series:=coalesce(old_state->'series','[]');next_series:=previous_series;
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(policy,p_as_of);
 SELECT coalesce(jsonb_agg(to_jsonb(f)ORDER BY series_key,month),'[]') INTO facts
 FROM lts_projection_private_v412.monthly_source_facts_v412(p_user_id,wf,wt,policy)f;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(facts)x
   WHERE coalesce(x->>'month','')!~'^[0-9]{4}-[0-9]{2}-01$'
    OR NOT coalesce(pg_catalog.pg_input_is_valid(x->>'month','date'),false)
    OR coalesce(x->>'amount_brl','')!~'^[0-9]+([.][0-9]+)?$'
    OR (x->>'coverage'='documented_zero' AND (x->>'amount_brl')::numeric<>0))
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(facts)x GROUP BY x->>'series_key',x->>'month' HAVING count(*)>1)
  THEN RAISE EXCEPTION 'A base mensal da revisão contém uma competência inválida.';END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(policy->'rules')
  WHERE coalesce(value->>'active','true')='true' AND(value->>'method'='history_total_budget'
   OR(value->>'method'='inflated_calendar' AND value->>'template_source'='history_mean'))
  ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';
  SELECT count(*)::int,count(*)FILTER(WHERE coalesce(x->>'coverage','') NOT IN('complete','documented_zero'))::int,
   sum((x->>'amount_brl')::numeric),round(avg((x->>'amount_brl')::numeric),2)
  INTO n,partial_count,total,mean FROM jsonb_array_elements(facts)x
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN wf AND wt;
  IF n<>12 OR partial_count<>0 THEN deferred:=deferred+1;CONTINUE;END IF;
  SELECT coalesce(jsonb_agg(DISTINCT a.value ORDER BY a.value),'[]') INTO refs
  FROM jsonb_array_elements(facts)x CROSS JOIN LATERAL jsonb_array_elements(coalesce(x->'source_refs','[]'))a(value)
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN wf AND wt;
  SELECT coalesce(jsonb_agg(DISTINCT a.value ORDER BY a.value),'[]') INTO hashes
  FROM jsonb_array_elements(facts)x CROSS JOIN LATERAL jsonb_array_elements(coalesce(x->'raw_hashes','[]'))a(value)
  WHERE x->>'series_key'=key AND (x->>'month')::date BETWEEN wf AND wt;
  IF jsonb_array_length(refs)=0 THEN deferred:=deferred+1;CONTINUE;END IF;
  candidate:=jsonb_build_object('series_key',key,'window_from',wf,'window_to',wt,
   'coverage_months',12,'sum_brl',total,'mean_brl',mean,'source_refs',refs,'raw_hashes',hashes);
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(next_series)x WHERE x=candidate)THEN CONTINUE;END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'series_key'),'[]')||jsonb_build_array(candidate) INTO next_series
  FROM jsonb_array_elements(next_series)x WHERE x->>'series_key'<>key;
  changed:=changed+1;
 END LOOP;
 SELECT coalesce(jsonb_agg(x ORDER BY x->>'series_key'),'[]') INTO next_series FROM jsonb_array_elements(next_series)x;
 IF changed=0 THEN RETURN jsonb_build_object('changed',false,'updated_series',0,'deferred_series',deferred);END IF;
 result:=jsonb_build_object('schema_version',1,'revision',coalesce((old_state->>'revision')::int,0)+1,
  'updated_on',p_as_of,'series',next_series);raw:=result::text;digest:=encode(sha256(convert_to(raw,'UTF8')),'hex');
 INSERT INTO public.legacy_namespace(usuario_id,chave,valor_bruto,sha256)
 VALUES(p_user_id,'lts_projection_reference_v412',raw,digest)
 ON CONFLICT(usuario_id,chave)DO UPDATE SET valor_bruto=excluded.valor_bruto,sha256=excluded.sha256,importado_em=clock_timestamp();
 INSERT INTO public.audit_log(user_id,action,entity_type,details)
 VALUES(p_user_id,'projection_reference_refreshed_v412','planning_reference',
  jsonb_build_object('as_of',p_as_of,'window_from',wf,'window_to',wt,'updated_series',changed,
   'deferred_series',deferred,'previous',old_state,'current',result,'sha256',digest));
 PERFORM lts_projection_private_v412.invalidate_reads(p_user_id);
 RETURN jsonb_build_object('changed',true,'updated_series',changed,'deferred_series',deferred,'revision',result->'revision');
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.refresh_reference(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.refresh_reference(uuid,date) TO service_role;
