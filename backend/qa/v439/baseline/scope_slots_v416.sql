CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_slots_v416(p_policy jsonb, p_slots jsonb, p_cards jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE r jsonb;c jsonb;card jsonb;item jsonb;slot jsonb;a jsonb;
 result jsonb:='[]';periods jsonb:='[]';period_rec jsonb;allocation jsonb;scopes jsonb;slot_period text;
 tag text;token text;seen text[];amount numeric;total numeric;declared numeric;valid boolean;known numeric;
 general_consumed numeric;own_consumed numeric;other_consumed numeric;fixed_target numeric;cycle_count int;allowance_valid boolean;
BEGIN
 IF jsonb_typeof(p_cards->'cards') IS DISTINCT FROM 'array' THEN RETURN p_slots;END IF;
 -- Validate all supplied canonical cycles once; use their already-resolved cash dates.
 FOR card IN SELECT value FROM jsonb_array_elements(p_cards->'cards') LOOP
  SELECT value INTO r FROM jsonb_array_elements(p_policy->'rules')
   WHERE value->>'card_family'=card->>'family' AND value->>'card_budget_mode'='scoped';
  IF r IS NULL THEN CONTINUE;END IF;
  FOR c IN SELECT value FROM jsonb_array_elements(coalesce(card->'cycles','[]')) LOOP
   IF NOT coalesce(pg_catalog.pg_input_is_valid(c->>'due_date','date'),false) THEN CONTINUE;END IF;
   valid:=coalesce(card->>'complete','true')='true' AND coalesce(c->>'complete','true')='true'
    AND jsonb_typeof(c->'items')='array' AND coalesce(c->>'amount','')~'^[0-9]{1,9}([.][0-9]{1,2})?$';
   total:=0;allocation:='{}';seen:='{}';
   FOR item IN SELECT value FROM jsonb_array_elements(coalesce(c->'items','[]')) LOOP
    IF coalesce(item->>'is_payment','false')='true' THEN CONTINUE;END IF;
    IF coalesce(item->>'amount','') !~ '^-?[0-9]{1,9}([.][0-9]{1,2})?$'
     OR nullif(item->>'source_id','') IS NULL THEN valid:=false;CONTINUE;END IF;
    token:=jsonb_build_array(item->>'source_id',item->>'reference_month',item->>'installment_number')::text;
    IF token=ANY(seen) THEN valid:=false;END IF;seen:=array_append(seen,token);
    amount:=(item->>'amount')::numeric;total:=total+amount;
    tag:=lts_projection_private_v412.scope_match_v416(item,r,false);
    IF tag='unresolved' THEN valid:=false;END IF;
    allocation:=jsonb_set(allocation,ARRAY[tag],to_jsonb(coalesce((allocation->>tag)::numeric,0)+amount));
   END LOOP;
   declared:=(c->>'amount')::numeric;
   valid:=coalesce(valid,false) AND abs(total-declared)<=0.005 AND total>=0
    AND NOT EXISTS(SELECT 1 FROM jsonb_each_text(allocation)x WHERE x.value::numeric<0);
   periods:=periods||jsonb_build_array(jsonb_build_object('series_key',r->>'series_key',
    'period',date_trunc('month',(c->>'due_date')::date)::date,'valid',valid,'amount',declared,'scopes',allocation));
  END LOOP;
 END LOOP;
 FOR slot IN SELECT value FROM jsonb_array_elements(p_slots) LOOP
  SELECT value INTO r FROM jsonb_array_elements(p_policy->'rules') WHERE value->>'series_key'=slot->>'series_key';
  IF r->>'card_budget_mode' IS DISTINCT FROM 'scoped' OR coalesce(slot->>'authoritative','false')='true'
   OR coalesce(slot->>'cancelled','false')='true' THEN result:=result||jsonb_build_array(slot);CONTINUE;END IF;
  slot_period:=date_trunc('month',(slot->>'event_date')::date)::date::text;
  known:=(slot->>'known_amount_brl')::numeric;
  SELECT count(*),coalesce(sum((x->>'amount')::numeric),0),coalesce(bool_and((x->>'valid')::boolean),true),
   coalesce(sum(coalesce((x#>>'{scopes,general}')::numeric,0)),0)
  INTO cycle_count,total,valid,general_consumed FROM jsonb_array_elements(periods)x
  WHERE x->>'series_key'=r->>'series_key' AND x->>'period'=slot_period;
  IF cycle_count=0 AND known>0 AND known=coalesce((slot->>'legacy_estimate_brl')::numeric,0) THEN
   total:=known;general_consumed:=known;
  END IF;
  valid:=valid AND known IS NOT NULL AND known>=0 AND abs(total-known)<=0.005;
  scopes:=jsonb_build_array(jsonb_build_object('scope','general','consumed_brl',general_consumed));
  FOR a IN SELECT value FROM jsonb_array_elements(r#>'{budget_definition,allowances}') LOOP
   IF a->>'funded_by_series'<>r->>'series_key' THEN CONTINUE;END IF;
   -- A documented new purchase on another card reduces the one shared allowance.
   SELECT coalesce(sum(coalesce((x#>>ARRAY['scopes',a->>'id'])::numeric,0)) FILTER(WHERE x->>'series_key'=r->>'series_key'),0),
    coalesce(sum(coalesce((x#>>ARRAY['scopes',a->>'id'])::numeric,0)) FILTER(WHERE x->>'series_key'<>r->>'series_key'),0),
    coalesce(bool_and((x->>'valid')::boolean),true)
   INTO own_consumed,other_consumed,allowance_valid FROM jsonb_array_elements(periods)x WHERE x->>'period'=slot_period
    AND (x->>'series_key'=r->>'series_key' OR x#>ARRAY['scopes',a->>'id'] IS NOT NULL OR x#>'{scopes,unresolved}' IS NOT NULL);
   valid:=valid AND allowance_valid AND known IS NOT NULL AND known>=0 AND abs(total-known)<=0.005;
   fixed_target:=greatest(0,(a->>'amount_brl')::numeric-other_consumed);
   scopes:=scopes||jsonb_build_array(jsonb_build_object('scope',a->>'id','target_brl',fixed_target,'consumed_brl',own_consumed));
  END LOOP;
  IF NOT coalesce(valid,false) THEN
   result:=result||jsonb_build_array((slot-'verified_budget_scopes')||jsonb_build_object('known_complete',false));
  ELSE result:=result||jsonb_build_array(slot||jsonb_build_object('verified_budget_scopes',scopes));END IF;
 END LOOP;
 RETURN result;
END $function$
