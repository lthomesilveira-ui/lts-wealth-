-- Owner-scoped projection rules. Documentary sources remain authoritative.
CREATE SCHEMA IF NOT EXISTS lts_projection_private_v412;
REVOKE ALL ON SCHEMA lts_projection_private_v412 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_projection_private_v412 TO authenticated,service_role;

-- Dated documentary prices change amounts, never the monthly billing calendar.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.fixed_amount(p_rule jsonb,p_on date)
RETURNS numeric LANGUAGE plpgsql IMMUTABLE STRICT SECURITY INVOKER SET search_path='' AS $f$
DECLARE change jsonb; effective date; previous date; amount numeric; result numeric;
BEGIN
 IF p_rule->>'method' IS DISTINCT FROM 'fixed'
  OR coalesce(p_rule->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$'
  OR NOT coalesce(pg_catalog.pg_input_is_valid(p_rule->>'starts_on','date'),false)
  THEN RAISE EXCEPTION 'Confira a regra de valor fixo.'; END IF;
 result:=(p_rule->>'amount_brl')::numeric;
 IF result<=0 OR result>100000000 THEN RAISE EXCEPTION 'Valor fixo fora dos limites.'; END IF;
 IF p_rule ? 'amount_changes' THEN
  IF jsonb_typeof(p_rule->'amount_changes') IS DISTINCT FROM 'array'
   THEN RAISE EXCEPTION 'Confira as vigências de preço.'; END IF;
  FOR change IN SELECT value FROM jsonb_array_elements(p_rule->'amount_changes') LOOP
   IF jsonb_typeof(change) IS DISTINCT FROM 'object'
    OR coalesce(change->>'effective_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    OR NOT coalesce(pg_catalog.pg_input_is_valid(change->>'effective_on','date'),false)
    OR coalesce(change->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$'
    OR nullif(btrim(change->>'source_ref'),'') IS NULL
    THEN RAISE EXCEPTION 'Falta uma vigência de preço documentada.'; END IF;
   effective:=(change->>'effective_on')::date;amount:=(change->>'amount_brl')::numeric;
   IF effective<(p_rule->>'starts_on')::date OR (previous IS NOT NULL AND effective<=previous)
    OR amount<=0 OR amount>100000000
    THEN RAISE EXCEPTION 'Vigências de preço inválidas ou repetidas.'; END IF;
   previous:=effective;
   IF effective<=p_on THEN result:=amount; END IF;
  END LOOP;
 END IF;
 RETURN result;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.fixed_amount(jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.fixed_amount(jsonb,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.owner_policy(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE p jsonb; r jsonb; seen text[]:='{}'; k text; activated_at timestamptz;
BEGIN
 SELECT nullif(valor_bruto,'')::jsonb,importado_em INTO p,activated_at FROM public.legacy_namespace
 WHERE usuario_id=p_user_id AND chave='lts_owner_projection_policy_v412';
 IF NOT FOUND THEN RETURN NULL; END IF;
 IF p IS NULL OR activated_at IS NULL OR jsonb_typeof(p)<>'object' OR p->>'schema_version' IS DISTINCT FROM '1'
  OR p->>'review' IS DISTINCT FROM 'calendar_year' OR p->>'horizon_years' IS DISTINCT FROM '5'
  OR jsonb_typeof(p->'rules') IS DISTINCT FROM 'array'
  OR NOT coalesce(pg_catalog.pg_input_is_valid(p->>'approved_on','date'),false)
  OR nullif(btrim(p->>'owner_evidence_ref'),'') IS NULL
 THEN RAISE EXCEPTION 'A regra de projeção precisa ser conferida.'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p->'rules') LOOP
  k:=nullif(btrim(r->>'series_key'),'');
  IF k IS NULL OR k=ANY(seen) OR k<>public.lts_forecast_series_key_v1(k)
   OR nullif(btrim(r->>'description'),'') IS NULL
   OR (r->>'direction') NOT IN('income','expense') OR r->>'direction' IS NULL
   OR (r->>'account') NOT IN('Itaú','Bradesco','C6') OR r->>'account' IS NULL
   OR coalesce(r->>'method','') NOT IN('history_total_budget','fixed','salary_net','inflated_calendar','repeat_calendar')
   OR NOT coalesce(pg_catalog.pg_input_is_valid(r->>'starts_on','date'),false)
   OR (r->>'ends_on' IS NOT NULL AND NOT pg_catalog.pg_input_is_valid(r->>'ends_on','date'))
   OR coalesce(r->>'active','true') NOT IN('true','false')
  THEN RAISE EXCEPTION 'Há uma série de projeção inválida ou repetida.'; END IF;
  IF r->>'ends_on' IS NOT NULL AND (r->>'ends_on')::date<(r->>'starts_on')::date
   THEN RAISE EXCEPTION 'Confira a vigência da projeção.'; END IF;
  IF r->>'method' IN('fixed','salary_net') AND
   (coalesce(r->>'amount_brl','') !~ '^[0-9]+([.][0-9]{1,2})?$' OR (r->>'amount_brl')::numeric<=0)
   THEN RAISE EXCEPTION 'Falta o valor confirmado da projeção.'; END IF;
  IF r ? 'amount_changes' AND r->>'method'<>'fixed'
   THEN RAISE EXCEPTION 'Esta série não utiliza vigências de preço fixo.'; END IF;
  IF r->>'method'='fixed' THEN
   PERFORM lts_projection_private_v412.fixed_amount(r,(r->>'starts_on')::date); END IF;
  IF r->>'method'='inflated_calendar' AND
   (coalesce(r->>'annual_rate','') !~ '^0([.][0-9]+)?$' OR (r->>'annual_rate')::numeric>0.25
    OR coalesce(r->>'base_year','') !~ '^[12][0-9]{3}$')
   THEN RAISE EXCEPTION 'Confira a premissa anual da projeção.'; END IF;
  IF r->>'method'<>'inflated_calendar' AND coalesce((r->>'annual_rate')::numeric,0)<>0
   THEN RAISE EXCEPTION 'Esta série não utiliza reajuste automático.'; END IF;
  IF r->>'method'='salary_net' AND (nullif(btrim(r->>'withholding_commitment'),'') IS NULL
   OR NOT coalesce(pg_catalog.pg_input_is_valid(r->>'withholding_ends_on','date'),false)
   OR nullif(btrim(r->>'withholding_end_source_ref'),'') IS NULL)
   THEN RAISE EXCEPTION 'Falta a referência do término do desconto em folha.'; END IF;
  seen:=array_append(seen,k);
 END LOOP;
 -- Activation orders later UI decisions; it is not a claim about when the
 -- owner's original message was sent. An idempotent seed keeps this timestamp.
 RETURN p||jsonb_build_object('_activated_at',activated_at);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.owner_policy(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.owner_policy(uuid) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.horizon_end(p_as_of date)
RETURNS date LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path='' AS $f$
 SELECT make_date(extract(year FROM p_as_of)::integer+5,12,31)
$f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.review_window(p_policy jsonb,p_as_of date)
RETURNS TABLE(window_from date,window_to date,next_review_on date)
LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path='' AS $f$
 WITH boundary AS(
  SELECT CASE WHEN extract(year FROM p_as_of)>extract(year FROM(p_policy->>'approved_on')::date)
   THEN make_date(extract(year FROM p_as_of)::int,1,1)
   ELSE date_trunc('month',(p_policy->>'approved_on')::date)::date END finish)
 SELECT (finish-interval '12 months')::date,finish-1,
  make_date(extract(year FROM p_as_of)::int+1,1,1) FROM boundary
$f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.horizon_end(date),
 lts_projection_private_v412.review_window(jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.horizon_end(date),
 lts_projection_private_v412.review_window(jsonb,date) TO service_role;
