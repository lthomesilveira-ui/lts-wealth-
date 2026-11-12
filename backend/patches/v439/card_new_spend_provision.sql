
-- Dated replacement of a historical card budget by a fixed NEW-spend provision.
-- Existing obligations remain in the operational base; no source row is changed.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.card_new_spend_provision(
 p_rule jsonb,p_on date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE c jsonb:=p_rule->'new_spend_provision';starts date; amount numeric;
BEGIN
 IF c IS NULL THEN RETURN NULL; END IF;
 IF jsonb_typeof(c) IS DISTINCT FROM 'object'
  OR p_rule->>'method' IS DISTINCT FROM 'history_total_budget'
  OR p_rule->>'source_kind' IS DISTINCT FROM 'card_invoice'
  OR p_rule->>'direction' IS DISTINCT FROM 'expense'
  OR nullif(btrim(p_rule->>'card_family'),'') IS NULL
  OR coalesce(c->>'starts_on','') !~ '^[0-9]{4}-[0-9]{2}-01$'
  OR NOT coalesce(pg_catalog.pg_input_is_valid(c->>'starts_on','date'),false)
  OR coalesce(c->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$'
  OR nullif(btrim(c->>'source_ref'),'') IS NULL
  THEN RAISE EXCEPTION 'Confira a provisão de novos gastos do cartão.'; END IF;
 starts:=(c->>'starts_on')::date;amount:=(c->>'amount_brl')::numeric;
 IF starts<(p_rule->>'starts_on')::date OR amount<=0 OR amount>100000000
  OR (p_rule->>'ends_on' IS NOT NULL AND starts>(p_rule->>'ends_on')::date)
  THEN RAISE EXCEPTION 'Confira a vigência e o valor da provisão do cartão.'; END IF;
 IF p_on IS NULL OR p_on<starts THEN RETURN NULL; END IF;
 RETURN c;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.card_new_spend_provision(jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.card_new_spend_provision(jsonb,date) TO service_role;

