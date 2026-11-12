-- Generic, private reconciliation of source-verified existing card obligations.
-- No owner data or source mutation belongs in this migration.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.verify_card_legacy_obligations(
 p_user_id uuid,p_rule jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE entries jsonb:=p_rule#>'{new_spend_provision,preserved_legacy_obligations}';
 item jsonb; data jsonb; seen text[]:='{}'; ref text; effective date; original date;
 amount numeric; result jsonb:='[]';
BEGIN
 IF entries IS NULL THEN RETURN result; END IF;
 IF jsonb_typeof(entries) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'Confira as referências das obrigações existentes do cartão.';END IF;
 IF jsonb_array_length(entries)>1000 THEN
  RAISE EXCEPTION 'Há referências demais para conferir.';END IF;
 PERFORM lts_projection_private_v412.card_new_spend_provision(p_rule,NULL);
 FOR item IN SELECT value FROM jsonb_array_elements(entries) LOOP
  ref:=item->>'source_ref';
  IF jsonb_typeof(item) IS DISTINCT FROM 'object'
   OR coalesce(ref,'') !~ '^evento_base:[0-9]{1,9}$' OR ref=ANY(seen)
   OR coalesce(item->>'source_sha256','') !~ '^[0-9a-f]{64}$'
   OR NOT coalesce(pg_catalog.pg_input_is_valid(item->>'event_date','date'),false)
   OR NOT coalesce(pg_catalog.pg_input_is_valid(item->>'original_date','date'),false)
   OR coalesce(item->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$'
   OR nullif(btrim(item->>'evidence_ref'),'') IS NULL THEN
   RAISE EXCEPTION 'Confira as referências das obrigações existentes do cartão.';END IF;
  effective:=(item->>'event_date')::date;original:=(item->>'original_date')::date;
  amount:=(item->>'amount_brl')::numeric;
  IF amount<=0 OR amount>100000000
   OR lts_projection_private_v412.card_new_spend_provision(p_rule,effective) IS NULL
   OR (p_rule->>'ends_on' IS NOT NULL AND effective>(p_rule->>'ends_on')::date) THEN
   RAISE EXCEPTION 'Confira a vigência e o valor da obrigação existente.';END IF;
  SELECT e.dados INTO STRICT data FROM public.evento_base e
   WHERE e.usuario_id=p_user_id AND e.idx=split_part(ref,':',2)::integer;
  IF encode(sha256(convert_to(data::text,'UTF8')),'hex')<>item->>'source_sha256'
   OR data->>'dia' IS DISTINCT FROM original::text
   OR data->>'efeito' IS DISTINCT FROM 'saida'
   OR data->>'conta' IS DISTINCT FROM p_rule->>'account'
   OR public.lts_forecast_series_key_v1(data->>'desc') IS DISTINCT FROM p_rule->>'series_key'
   OR NOT coalesce(pg_catalog.pg_input_is_valid(data->>'valor','numeric'),false)
   OR (data->>'valor')::numeric IS DISTINCT FROM amount
   OR public.lts_card_projection_date_v370(p_user_id,p_rule->>'card_family',
    date_trunc('month',original)::date,original,NULL) IS DISTINCT FROM effective THEN
   RAISE EXCEPTION 'Uma obrigação existente mudou; confira a referência antes de projetar.';END IF;
  seen:=array_append(seen,ref);
  result:=result||jsonb_build_array(jsonb_build_object('source_ref',ref,
   'event_date',effective,'amount_brl',amount,'evidence_ref',item->>'evidence_ref'));
 END LOOP;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.verify_card_legacy_obligations(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.verify_card_legacy_obligations(uuid,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_legacy_obligations_match(
 p_rule jsonb,p_slot jsonb)
RETURNS boolean LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE expected numeric:=0; item jsonb; ref text; matched text[]:='{}'; refs jsonb:=coalesce(p_slot->'source_refs','[]');
 legacy numeric:=coalesce((p_slot->>'legacy_estimate_brl')::numeric,0);
BEGIN
 IF jsonb_typeof(refs) IS DISTINCT FROM 'array' OR legacy<0 THEN RETURN false;END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(coalesce(p_rule->'_verified_legacy_obligations','[]'))
  WHERE value->>'event_date'=p_slot->>'event_date' LOOP
  IF NOT refs ? (item->>'source_ref') THEN RETURN false;END IF;
  matched:=array_append(matched,item->>'source_ref');
  expected:=expected+(item->>'amount_brl')::numeric;
 END LOOP;
 IF legacy>0 THEN
  FOR ref IN SELECT jsonb_array_elements_text(refs) LOOP
   IF ref LIKE 'evento_base:%' AND NOT ref=ANY(matched) THEN RETURN false;END IF;
  END LOOP;
 END IF;
 RETURN expected=legacy AND legacy<=coalesce((p_slot->>'known_amount_brl')::numeric,-1);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.card_legacy_obligations_match(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.card_legacy_obligations_match(jsonb,jsonb) TO service_role;
