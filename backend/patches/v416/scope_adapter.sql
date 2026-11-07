-- Generic, private, read-only budget adapter. Owner decisions are seeded separately.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_match_v416(p_item jsonb,p_rule jsonb,p_historical boolean)
RETURNS text LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE cfg jsonb:=p_rule->'budget_definition'; a jsonb; matches text[]:='{}';
 cat text:=lts_projection_private_v412.source_label(p_item->>'category');
 descr text:=lts_projection_private_v412.source_label(p_item->>'description');
 person text:=nullif(lts_projection_private_v412.source_label(p_item->>'beneficiary'),'');
 purchase_day date; selected jsonb;
BEGIN
 IF p_rule->>'card_budget_mode' IS DISTINCT FROM 'scoped' THEN RETURN 'general'; END IF;
 IF jsonb_typeof(cfg) IS DISTINCT FROM 'object'
 OR jsonb_typeof(cfg->'excluded_categories') IS DISTINCT FROM 'array'
 OR jsonb_typeof(cfg->'allowances') IS DISTINCT FROM 'array'
 OR nullif(cfg->>'decision_ref','') IS NULL THEN RAISE EXCEPTION 'Orçamento sem referência confirmada.';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements_text(cfg->'excluded_categories') x
  WHERE lts_projection_private_v412.source_label(x)=cat) THEN RETURN 'excluded';END IF;
 FOR a IN SELECT value FROM jsonb_array_elements(cfg->'allowances') LOOP
  IF nullif(a->>'id','') IS NULL OR a->>'id' IN('general','excluded','unresolved')
   OR coalesce(a->>'amount_brl','') !~ '^[0-9]{1,8}([.][0-9]{1,2})?$'
   OR NOT coalesce(pg_catalog.pg_input_is_valid(a->>'legacy_through','date'),false)
   OR nullif(a->>'funded_by_series','') IS NULL
   OR nullif(a->>'beneficiary','') IS NULL
   OR jsonb_typeof(a->'descriptions') IS DISTINCT FROM 'array'
   OR a->'descriptions'='[]'::jsonb THEN RAISE EXCEPTION 'Reserva de novos gastos incompleta.';END IF;
  IF EXISTS(SELECT 1 FROM jsonb_array_elements_text(a->'descriptions') x
   WHERE lts_projection_private_v412.source_label(x)=descr) THEN
   matches:=array_append(matches,a->>'id');selected:=a;
  END IF;
 END LOOP;
 IF cardinality(matches)>1 THEN RETURN 'unresolved';END IF;
 IF cardinality(matches)=0 THEN RETURN 'general';END IF;
 IF p_historical THEN RETURN 'excluded';END IF;
 IF NOT coalesce(pg_catalog.pg_input_is_valid(p_item->>'purchase_date','date'),false) THEN RETURN 'unresolved';END IF;
 purchase_day:=(p_item->>'purchase_date')::date;
 IF purchase_day<=(selected->>'legacy_through')::date THEN RETURN 'excluded';END IF;
 -- A named category prefix is explicit source information; card ownership alone is not.
 IF person IS NULL THEN
  IF cat LIKE lts_projection_private_v412.source_label(selected->>'beneficiary')||' — %'
   OR cat LIKE lts_projection_private_v412.source_label(selected->>'beneficiary')||' - %'
   THEN person:=lts_projection_private_v412.source_label(selected->>'beneficiary'); END IF;
 END IF;
 IF person IS NULL THEN RETURN 'unresolved'; END IF;
 IF person<>lts_projection_private_v412.source_label(selected->>'beneficiary') THEN RETURN 'excluded';END IF;
 RETURN selected->>'id';
END $f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_history_v416(p_policy jsonb,p_facts jsonb,p_rows jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
DECLARE f jsonb;r jsonb;e jsonb;out_rows jsonb:='[]';items jsonb;gross numeric;kept numeric;removed numeric;
 key_count int;n int;scope text;valid boolean;digest text;
 wf date:=(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date;
 wt date:=date_trunc('month',p_as_of::timestamp)::date-1;
BEGIN
 IF jsonb_typeof(p_rows) IS DISTINCT FROM 'array' OR jsonb_typeof(p_facts) IS DISTINCT FROM 'array' THEN
  RAISE EXCEPTION 'Detalhamento das faturas indisponível.';END IF;
 FOR f IN SELECT value FROM jsonb_array_elements(p_facts) LOOP
  SELECT value INTO r FROM jsonb_array_elements(p_policy->'rules')
   WHERE value->>'series_key'=f->>'series_key';
  IF r->>'card_budget_mode' IS DISTINCT FROM 'scoped'
   OR (f->>'month')::date NOT BETWEEN wf AND wt THEN out_rows:=out_rows||jsonb_build_array(f);CONTINUE;END IF;
  IF r->>'source_kind'<>'card_invoice' OR r->>'method'<>'history_total_budget'
   OR jsonb_typeof(r#>'{budget_definition,source_accounts}') IS DISTINCT FROM 'array'
   OR r#>'{budget_definition,source_accounts}'='[]'::jsonb THEN RAISE EXCEPTION 'Escopo do cartão incompleto.';END IF;
  SELECT coalesce(jsonb_agg(x ORDER BY x->>'row_key'),'[]'),count(*),count(DISTINCT x->>'row_key'),
   coalesce(sum((x->>'amount')::numeric),0)
  INTO items,n,key_count,gross FROM jsonb_array_elements(p_rows)x
  WHERE x->>'competence_month'=f->>'month'
   AND x->>'coverage_mode' IN('card_bank_closed_complete','card_detail_structured')
   AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(r#>'{budget_definition,source_accounts}') a
    WHERE lts_projection_private_v412.source_label(a)=lts_projection_private_v412.source_label(x->>'account_source'));
  valid:=n>0 AND n=key_count AND f->>'coverage' IN('complete','documented_zero')
   AND abs(gross-(f->>'amount_brl')::numeric)<=0.005;
  kept:=0;removed:=0;
  FOR e IN SELECT value FROM jsonb_array_elements(items) LOOP
   IF nullif(e->>'source_ref','') IS NULL OR nullif(e->>'row_key','') IS NULL
    OR coalesce(e->>'amount','') !~ '^-?[0-9]{1,9}([.][0-9]{1,2})?$' THEN valid:=false;CONTINUE;END IF;
   scope:=lts_projection_private_v412.scope_match_v416(e,r,true);
   IF scope='unresolved' THEN valid:=false;
   ELSIF scope='general' THEN kept:=kept+(e->>'amount')::numeric;
   ELSE removed:=removed+(e->>'amount')::numeric;END IF;
  END LOOP;
  IF kept<0 OR removed<0 THEN valid:=false;END IF;
  digest:=md5((r->'budget_definition')::text);
  out_rows:=out_rows||jsonb_build_array(f||jsonb_build_object('amount_brl',greatest(kept,0),
   'coverage',CASE WHEN valid THEN CASE WHEN kept=0 THEN 'documented_zero' ELSE 'complete' END ELSE 'observed' END,
   'gross_invoice_brl',gross,'excluded_from_recurring_brl',removed,'scope_digest',digest,
   'source_refs',coalesce(f->'source_refs','[]')||coalesce((SELECT jsonb_agg(x->>'row_key' ORDER BY x->>'row_key') FROM jsonb_array_elements(items)x),'[]')));
 END LOOP;
 RETURN out_rows;
END $f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_history_read_v416(p_user_id uuid,p_policy jsonb,p_facts jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE rows jsonb;wf date:=(date_trunc('month',p_as_of::timestamp)-interval '3 months')::date;
 wt date:=date_trunc('month',p_as_of::timestamp)::date-1;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_policy->'rules')r WHERE r->>'card_budget_mode'='scoped') THEN RETURN p_facts;END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(e) ORDER BY e.row_key),'[]') INTO rows
 FROM public.lts_v229_expense_rows(p_user_id,wf,wt)e
 WHERE e.coverage_mode IN('card_bank_closed_complete','card_detail_structured');
 RETURN lts_projection_private_v412.scope_history_v416(p_policy,p_facts,rows,p_as_of);
END $f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_slots_v416(p_policy jsonb,p_slots jsonb,p_cards jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SET search_path='' AS $f$
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
END $f$;

REVOKE ALL ON FUNCTION lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean),
 lts_projection_private_v412.scope_history_v416(jsonb,jsonb,jsonb,date),
 lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date),
 lts_projection_private_v412.scope_slots_v416(jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.scope_match_v416(jsonb,jsonb,boolean),
 lts_projection_private_v412.scope_history_v416(jsonb,jsonb,jsonb,date),
 lts_projection_private_v412.scope_history_read_v416(uuid,jsonb,jsonb,date),
 lts_projection_private_v412.scope_slots_v416(jsonb,jsonb,jsonb) TO service_role;
