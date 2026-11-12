CREATE OR REPLACE FUNCTION lts_projection_private_v412.scope_history_v416(p_policy jsonb, p_facts jsonb, p_rows jsonb, p_as_of date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
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
END $function$
