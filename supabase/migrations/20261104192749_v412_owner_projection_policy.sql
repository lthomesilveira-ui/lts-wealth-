-- V412: owner-authorized projection policy; generic code only.
BEGIN;

-- SOURCE: schema.sql
-- Owner-scoped projection rules. Documentary sources remain authoritative.
CREATE SCHEMA IF NOT EXISTS lts_projection_private_v412;
REVOKE ALL ON SCHEMA lts_projection_private_v412 FROM PUBLIC,anon,authenticated;
GRANT USAGE ON SCHEMA lts_projection_private_v412 TO authenticated,service_role;

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


-- SOURCE: cache.sql
CREATE OR REPLACE FUNCTION lts_projection_private_v412.invalidate_reads(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path='' AS $f$
BEGIN
 IF p_user_id IS NULL THEN RAISE EXCEPTION 'Invalid projection owner';END IF;
 DELETE FROM public.lts_flow_future_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_flow_future_read_cache_v2 WHERE user_id=p_user_id;
 DELETE FROM public.lts_v229_read_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_dashboard_cockpit_cache WHERE user_id=p_user_id;
 DELETE FROM public.lts_product_read_cache WHERE user_id=p_user_id;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.invalidate_reads(uuid) TO service_role;


-- SOURCE: base_flow.sql
-- Keep the exact installed, withholding-aware reader as a private predecessor.
-- No data is copied and no caller gains access to another owner's rows.
DO $guard$
DECLARE original oid:=to_regprocedure('public.lts_corrected_cashflow_operational_v1(uuid,date,date)');
 saved oid:=to_regprocedure('lts_projection_private_v412.base_flow(uuid,date,date)');definition text;
BEGIN
 IF original IS NULL THEN RAISE EXCEPTION 'V412 requires the installed operational reader';END IF;
 IF saved IS NULL THEN
  IF md5(pg_get_functiondef(original))<>'0a687b1bf642ab20cdadfb96ec0f0bed'
   THEN RAISE EXCEPTION 'V412 operational predecessor differs; review before applying';END IF;
  definition:=replace(pg_get_functiondef(original),
   'FUNCTION public.lts_corrected_cashflow_operational_v1(',
   'FUNCTION lts_projection_private_v412.base_flow(');
  EXECUTE definition;
 ELSE
  definition:=replace(pg_get_functiondef(saved),
   'FUNCTION lts_projection_private_v412.base_flow(',
   'FUNCTION public.lts_corrected_cashflow_operational_v1(');
  IF md5(definition)<>'0a687b1bf642ab20cdadfb96ec0f0bed'
   THEN RAISE EXCEPTION 'V412 saved predecessor differs';END IF;
 END IF;
END $guard$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.base_flow(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.base_flow(uuid,date,date) TO service_role;



-- SOURCE: source_adapter.sql
-- Read-only, owner-scoped source adapters. No personal source or policy is seeded.
-- A complete classified corpus is distinct from a month with positive spending.
-- Card purchases and their settlement never become a second direct-cash expense.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.source_label(p_value text)
RETURNS text LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
 SELECT regexp_replace(translate(lower(btrim(coalesce(p_value,''))),
  'áàâãäéèêëíìîïóòôõöúùûüçñ','aaaaaeeeeiiiiooooouuuucn'),'[[:space:]]+',' ','g')
$f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.monthly_source_facts_v412(
 p_user_id uuid,p_from date,p_to date,p_policy jsonb)
RETURNS TABLE(series_key text,month date,amount_brl numeric,coverage text,
 source_kind text,source_refs jsonb,raw_hashes jsonb,observed_days jsonb)
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
BEGIN
 IF p_user_id IS NULL OR p_from IS NULL OR p_to IS NULL OR p_from>p_to
  OR p_from<>date_trunc('month',p_from)::date
  OR p_to<>(date_trunc('month',p_to)+interval '1 month -1 day')::date
  OR jsonb_typeof(p_policy->'rules') IS DISTINCT FROM 'array'
 THEN RAISE EXCEPTION 'A janela de fontes deve conter meses de calendário completos.';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_policy->'rules')r
  WHERE coalesce(r->>'active','true')='true' AND r->>'source_kind'='expense'
   AND (coalesce(r->>'expense_scope','')<>'non_card_cash'
    OR coalesce(r->>'expense_source','classified_ledger') NOT IN('classified_ledger','posted_bank')
    OR (coalesce(r->>'expense_source','classified_ledger')='posted_bank'
     AND coalesce(jsonb_array_length(r->'description_aliases'),0)=0
     AND coalesce(jsonb_array_length(r->'description_patterns'),0)=0)
    OR (coalesce(r->>'expense_source','classified_ledger')='classified_ledger'
     AND coalesce(jsonb_array_length(r->'category_aliases'),0)=0
     AND coalesce(jsonb_array_length(r->'description_aliases'),0)=0)))
 THEN RAISE EXCEPTION 'Falta uma seleção explícita da fonte de despesa.';END IF;
 RETURN QUERY
 WITH bounds AS (
  -- A future-date scenario may request a later review window. Only already
  -- closed real calendar months can supply observed facts for that window.
  SELECT least(p_to,(date_trunc('month',current_date)-interval '1 day')::date) AS observed_to
 ), rules AS MATERIALIZED (
  SELECT r.value AS rule,r.value->>'series_key' AS key
  FROM jsonb_array_elements(p_policy->'rules')r
  WHERE coalesce(r.value->>'active','true')='true'
   AND r.value->>'source_kind' IN('card_invoice','expense')
 ), months AS (
  SELECT d::date AS period FROM generate_series(p_from,p_to,interval '1 month')d
 ), bank AS MATERIALIZED (
  SELECT b.* FROM public.lts_bank_posted_rows_v231(p_user_id)b
  WHERE b.user_id=p_user_id AND b.posting_date BETWEEN p_from AND (SELECT observed_to FROM bounds)
 ), bank_coverage AS (
  SELECT date_trunc('month',b.posting_date)::date AS period,count(*) AS rows_seen,
   encode(sha256(convert_to(jsonb_agg(jsonb_build_object('source_id',b.id,'posting_date',b.posting_date,
    'signed_amount',b.signed_amount,'currency',b.currency,'account_ref',b.provider_account_ref,
    'institution_code',b.institution_code,'description',b.description_raw,'status',b.normalized_payload->>'status')
    ORDER BY b.id)::text,'UTF8')),'hex') AS source_hash
  FROM bank b GROUP BY 1
 ), expenses AS MATERIALIZED (
  SELECT e.*,to_jsonb(e) AS source_record,lts_projection_private_v412.source_label(e.category) AS category_key,
   lts_projection_private_v412.source_label(e.beneficiary) AS beneficiary_key,
   lts_projection_private_v412.source_label(e.description) AS description_key,
   EXISTS(SELECT 1 FROM public.lts_card_documentary_payment_link_v272 l
    JOIN public.lts_open_finance_staging p ON p.user_id=l.user_id AND p.id=l.payment_source_id
    WHERE l.user_id=p_user_id AND l.active
     AND e.source_table='lts_open_finance_staging' AND l.payment_source_id::text=e.source_ref
     AND p.provider_deleted_at IS NULL AND p.raw_hash=l.payment_raw_hash
     AND p.posting_date=l.expected_payment_date AND p.signed_amount=-l.expected_amount
     AND p.provider_account_ref=l.payment_account_ref) AS documented_settlement
  FROM bounds b CROSS JOIN LATERAL public.lts_v229_expense_rows(p_user_id,least(p_from,b.observed_to),b.observed_to)e
  WHERE e.competence_month BETWEEN p_from AND b.observed_to
 ), ledger AS (
  SELECT e.competence_month AS period,count(*) AS rows_seen,
   count(*) FILTER(WHERE e.coverage_mode NOT LIKE 'card_%'
    AND e.source_table NOT IN('card_purchase_detail','lts_v175_workbook_monthly_category_source')) AS noncard_rows,
   encode(sha256(convert_to(jsonb_agg(e.source_record ORDER BY e.row_key)::text,'UTF8')),'hex') AS source_hash
  FROM expenses e GROUP BY 1
 ), relevant AS MATERIALIZED (
  SELECT r.key,r.rule,e.*
  FROM rules r JOIN expenses e ON r.rule->>'source_kind'='expense'
   AND coalesce(r.rule->>'expense_source','classified_ledger')='classified_ledger'
  WHERE e.coverage_mode NOT LIKE 'card_%'
   AND e.source_table NOT IN('card_purchase_detail','lts_v175_workbook_monthly_category_source')
   AND NOT e.documented_settlement
 ), ledger_matches AS MATERIALIZED (
  SELECT e.* FROM relevant e
  WHERE (coalesce(jsonb_array_length(e.rule->'category_aliases'),0)=0
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(e.rule->'category_aliases')v
     WHERE lts_projection_private_v412.source_label(v)=e.category_key))
   AND (e.rule->>'beneficiary' IS NULL
    OR lts_projection_private_v412.source_label(e.rule->>'beneficiary')=e.beneficiary_key)
   AND (e.rule->>'property_code' IS NULL OR e.rule->>'property_code'=e.property_code)
   AND (coalesce(jsonb_array_length(e.rule->'description_aliases'),0)=0
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(e.rule->'description_aliases')v
     WHERE lts_projection_private_v412.source_label(v)=e.description_key))
 ), uncertain AS (
  SELECT e.key,e.competence_month AS period,count(*) AS unknown_rows
  FROM relevant e
  WHERE e.category_key IN('','a classificar','unknown','desconhecido','sem categoria','nao classificado')
   OR (e.rule->>'beneficiary' IS NOT NULL AND e.beneficiary_key IN('','a classificar','unknown')
    AND coalesce(e.identity_status,'unknown')<>'identified'
    AND EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(e.rule->'category_aliases','[]'))v
     WHERE lts_projection_private_v412.source_label(v)=e.category_key))
  GROUP BY e.key,e.competence_month
 ), ledger_totals AS (
  SELECT e.key,e.competence_month AS period,sum(e.amount) AS amount,count(*) AS match_count,
   jsonb_agg(e.source_table||':'||e.source_ref ORDER BY e.row_key) AS refs,
   jsonb_agg(extract(day FROM e.event_date)::int ORDER BY e.row_key) AS days
  FROM ledger_matches e GROUP BY e.key,e.competence_month
 ), ledger_facts AS (
  SELECT r.key,m.period,coalesce(t.amount,0) AS amount,
   CASE WHEN verified.complete
    THEN CASE WHEN coalesce(t.match_count,0)=0 THEN 'documented_zero' ELSE 'complete' END
    ELSE 'observed' END AS coverage,
   coalesce(t.refs,'[]'::jsonb)||jsonb_build_array('classified_ledger:'||m.period) AS refs,
   jsonb_build_array(l.source_hash,b.source_hash) AS hashes,coalesce(t.days,'[]'::jsonb) AS days
  FROM rules r CROSS JOIN months m
  LEFT JOIN ledger l ON l.period=m.period LEFT JOIN bank_coverage b ON b.period=m.period
  LEFT JOIN uncertain u ON u.key=r.key AND u.period=m.period
  LEFT JOIN ledger_totals t ON t.key=r.key AND t.period=m.period
  CROSS JOIN LATERAL (
   -- Presence of transactions is not proof of a complete imported month.
   -- The explicit audit is bound to the current classified corpus and stable
   -- bank facts. A changed or unaudited future month cannot replace the last
   -- verified reference, and an empty corpus never supplies a zero.
   SELECT coalesce(r.rule->>'coverage_basis'='classified_ledger' AND l.rows_seen>0
    AND l.noncard_rows>0 AND b.rows_seen>0 AND coalesce(u.unknown_rows,0)=0
    AND EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(p_policy->'audited_coverage','[]'))proof
     WHERE proof->>'series_key'=r.key AND proof->>'month'=m.period::text
      AND proof->>'coverage'='complete'
      AND proof->>'ledger_sha256'=l.source_hash AND proof->>'bank_sha256'=b.source_hash
      AND proof->>'audit_sha256' ~ '^[0-9a-f]{64}$' AND nullif(btrim(proof->>'audit_ref'),'') IS NOT NULL
      AND CASE WHEN pg_catalog.pg_input_is_valid(proof->>'reviewed_on','date')
       THEN (proof->>'reviewed_on')::date>=(m.period+interval '1 month -1 day')::date ELSE false END),false) AS complete
  )verified
  WHERE r.rule->>'source_kind'='expense'
   AND coalesce(r.rule->>'expense_source','classified_ledger')='classified_ledger'
   AND (coalesce(t.match_count,0)>0 OR verified.complete)
 ), posted_matches AS MATERIALIZED (
  SELECT r.key,b.* FROM rules r JOIN bank b ON r.rule->>'source_kind'='expense'
   AND r.rule->>'expense_source'='posted_bank'
  WHERE b.signed_amount<0 AND b.signed_amount::text ~ '^-[0-9]+([.][0-9]+)?$'
   AND b.raw_hash ~ '^[0-9a-f]{64}$'
   AND (EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(r.rule->'description_aliases','[]'))v
     WHERE lts_projection_private_v412.source_label(v)=lts_projection_private_v412.source_label(b.description_raw))
    OR EXISTS(SELECT 1 FROM jsonb_array_elements_text(coalesce(r.rule->'description_patterns','[]'))v
     WHERE b.description_raw ~* v))
 ), posted_facts AS (
  SELECT b.key,date_trunc('month',b.posting_date)::date AS period,-sum(b.signed_amount) AS amount,
   CASE WHEN count(*)=1 THEN 'complete' ELSE 'observed' END AS coverage,
   jsonb_agg('lts_open_finance_staging:'||b.id ORDER BY b.id) AS refs,
   jsonb_agg(b.raw_hash ORDER BY b.id) AS hashes,
   jsonb_agg(extract(day FROM b.posting_date)::int ORDER BY b.id) AS days
  FROM posted_matches b GROUP BY b.key,date_trunc('month',b.posting_date)::date
 ), invoice_inputs AS MATERIALIZED (
  SELECT s.id,s.raw_hash,s.signed_amount,v.due_date,
   public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) AS family
  FROM public.lts_open_finance_staging s
  CROSS JOIN LATERAL public.lts_bill_source_fields_v286(s.normalized_payload,s.raw_payload,s.posting_date)v
  WHERE s.user_id=p_user_id AND s.resource_type='invoice' AND s.provider_deleted_at IS NULL
   AND s.currency='BRL' AND s.signed_amount>=0 AND s.signed_amount::text ~ '^[0-9]+([.][0-9]+)?$'
   AND s.raw_hash ~ '^[0-9a-f]{64}$' AND v.header_valid AND v.source_updated_at IS NOT NULL
   AND v.due_date BETWEEN p_from AND (SELECT observed_to FROM bounds)
   AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging a
    WHERE a.user_id=p_user_id AND a.resource_type='credit_card' AND a.provider_deleted_at IS NULL
     AND a.institution_code=s.institution_code
     AND a.normalized_payload->>'provider_account_id'=s.provider_account_ref
     AND public.lts_card_family_v226(a.normalized_payload->>'name',a.institution_name)
       =public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name))
 ), invoice_unique AS (
  SELECT i.*,count(*) OVER(PARTITION BY i.family,date_trunc('month',i.due_date)) AS candidates
  FROM invoice_inputs i
 ), invoice_facts AS (
  SELECT r.key,date_trunc('month',i.due_date)::date AS period,i.signed_amount AS amount,
   CASE WHEN i.signed_amount=0 THEN 'documented_zero' ELSE 'complete' END AS coverage,
   jsonb_build_array('lts_open_finance_staging:'||i.id) AS refs,jsonb_build_array(i.raw_hash) AS hashes,
   jsonb_build_array(extract(day FROM i.due_date)::int) AS days
  FROM rules r JOIN invoice_unique i ON r.rule->>'source_kind'='card_invoice'
   AND r.rule->>'card_family'=i.family AND i.candidates=1
 )
 SELECT x.key,x.period,x.amount,x.coverage,'expense'::text,x.refs,x.hashes,x.days FROM ledger_facts x
 UNION ALL
 SELECT x.key,x.period,x.amount,x.coverage,'expense'::text,x.refs,x.hashes,x.days FROM posted_facts x
 UNION ALL
 SELECT x.key,x.period,x.amount,x.coverage,'card_invoice'::text,x.refs,x.hashes,x.days FROM invoice_facts x;
END $f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.calendar_templates_v412(p_user_id uuid,p_policy jsonb)
RETURNS TABLE(series_key text,template_year int,event_month int,event_day int,
 amount_brl numeric,source_ref text,raw_hash text)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' AS $f$
 WITH rules AS MATERIALIZED (
  SELECT r.value AS rule,r.value->>'series_key' AS key,
   coalesce(r.value->>'template_year',r.value->>'base_year')::int AS source_year
  FROM jsonb_array_elements(p_policy->'rules')r
  WHERE coalesce(r.value->>'active','true')='true'
   AND r.value->>'method' IN('inflated_calendar','repeat_calendar')
   AND coalesce(r.value->>'template_source','calendar')='calendar'
 ), source_rows AS MATERIALIZED (
  SELECT b.idx,b.dados,CASE WHEN pg_catalog.pg_input_is_valid(b.dados->>'dia','date')
   THEN (b.dados->>'dia')::date END AS source_date,
   CASE WHEN b.dados->>'valor' ~ '^[0-9]+([.][0-9]+)?$'
    THEN (b.dados->>'valor')::numeric END AS amount
  FROM public.evento_base b WHERE b.usuario_id=p_user_id
 )
 SELECT r.key,r.source_year,extract(month FROM b.source_date)::int,extract(day FROM b.source_date)::int,
  b.amount,'evento_base:'||b.idx,
  encode(sha256(convert_to(b.dados::text,'UTF8')),'hex')
 FROM rules r JOIN source_rows b ON extract(year FROM b.source_date)::int=r.source_year
  AND public.lts_forecast_series_key_v1(b.dados->>'desc')=r.key
 WHERE b.amount>0
  AND b.dados->>'efeito'=CASE WHEN r.rule->>'direction'='income' THEN 'entrada' ELSE 'saida' END
$f$;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.known_card_periods_v412(p_user_id uuid)
RETURNS TABLE(series_key text,reference_month date,due_date date,amount_brl numeric,
 closed boolean,paid boolean,complete boolean,source_refs jsonb)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
 WITH payload AS MATERIALIZED (
  -- This canonical reader already applies the current owner due-date transition.
  -- Do not derive a future date from the historic modal invoice due day.
  SELECT public.lts_card_cycles_v226(p_user_id) AS data
 ), cycles AS MATERIALIZED (
  SELECT c.value AS card,x.value AS cycle,c.value->>'family' AS family,
   CASE WHEN pg_catalog.pg_input_is_valid(x.value->>'month','date') THEN (x.value->>'month')::date END AS period,
   CASE WHEN pg_catalog.pg_input_is_valid(x.value->>'due_date','date') THEN (x.value->>'due_date')::date END AS cash_date,
   CASE WHEN x.value->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (x.value->>'amount')::numeric END AS amount
  FROM payload p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.data->'cards','[]'))c
  CROSS JOIN LATERAL jsonb_array_elements(coalesce(c.value->'cycles','[]'))x
 ), enriched AS (
  SELECT c.*,v.header_valid,v.closing_date,count(*) OVER(PARTITION BY c.family,c.period) AS candidates
  FROM cycles c LEFT JOIN public.lts_open_finance_staging s ON s.user_id=p_user_id
   AND s.id::text=c.cycle->>'invoice_source_id' AND s.resource_type='invoice' AND s.provider_deleted_at IS NULL
  LEFT JOIN LATERAL public.lts_bill_source_fields_v286(s.normalized_payload,s.raw_payload,s.posting_date)v ON s.id IS NOT NULL
 )
 SELECT CASE e.family WHEN 'c6' THEN 'card_c6' WHEN 'itau_mastercard' THEN 'card_itau'
   WHEN 'aeternum' THEN 'card_aeternum' ELSE 'card_'||e.family END,
  e.period,e.cash_date,e.amount,
  coalesce(e.header_valid AND e.closing_date<=current_date,false)
   OR coalesce(e.cycle->>'payment_status'='paid',false),
  coalesce(e.cycle->>'settlement_confirmed'='true',false)
   OR coalesce(e.cycle->>'payment_status'='paid',false),
  e.amount IS NOT NULL AND e.period IS NOT NULL AND e.cash_date IS NOT NULL AND e.candidates=1
   AND coalesce(e.card->>'complete','true')='true' AND coalesce(e.cycle->>'complete','true')='true',
  jsonb_build_array('card_cycle:'||e.family||':'||e.period)
   ||CASE WHEN e.cycle->>'invoice_source_id' IS NOT NULL
      THEN jsonb_build_array('lts_open_finance_staging:'||(e.cycle->>'invoice_source_id')) ELSE '[]'::jsonb END
 FROM enriched e
$f$;

REVOKE ALL ON FUNCTION lts_projection_private_v412.source_label(text),
 lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb),
 lts_projection_private_v412.calendar_templates_v412(uuid,jsonb),
 lts_projection_private_v412.known_card_periods_v412(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.source_label(text),
 lts_projection_private_v412.monthly_source_facts_v412(uuid,date,date,jsonb),
 lts_projection_private_v412.calendar_templates_v412(uuid,jsonb),
 lts_projection_private_v412.known_card_periods_v412(uuid) TO service_role;


-- SOURCE: calculation.sql
-- Pure calculation over normalized documentary facts and future calendar slots.
-- A missing fact is never synthesized as a zero. Numeric amounts stay decimal.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.calculate(
 p_policy jsonb,p_history jsonb,p_slots jsonb,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path='' AS $f$
DECLARE r jsonb; s jsonb; f jsonb; stats jsonb; series jsonb:='[]'; events jsonb:='[]'; replacements jsonb:='[]';
 warnings jsonb:='[]'; slot_warnings jsonb; key text; method text; horizon date; wf date; wt date; nr date;
 count_months integer; spend_months integer; partial_months integer; source_count integer; amount_sum numeric;
 mean_amount numeric; q1 numeric; q3 numeric; outliers jsonb; amount numeric; known numeric; replacement_amount numeric;
 target numeric; extra numeric; effective_date date; protected boolean; cancelled boolean; complete boolean;
 skipped integer; generated integer; invalid_slots integer; annual jsonb; slot_result jsonb; results jsonb:='[]';
 reference jsonb; reference_from date;reference_to date;reference_stale boolean;uses_history boolean;
BEGIN
 IF p_policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 IF p_as_of IS NULL OR NOT pg_catalog.isfinite(p_as_of) OR p_as_of<(p_policy->>'approved_on')::date
  OR jsonb_typeof(p_history) IS DISTINCT FROM 'array' OR jsonb_typeof(p_slots) IS DISTINCT FROM 'array'
  THEN RAISE EXCEPTION 'Escopo de projeção inválido.'; END IF;
 horizon:=lts_projection_private_v412.horizon_end(p_as_of);
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(p_policy,p_as_of);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_history)x
  WHERE coalesce(x->>'coverage','') NOT IN('complete','observed','documented_zero')
   OR coalesce(x->>'month','')!~'^[0-9]{4}-[0-9]{2}-01$'
   OR NOT coalesce(pg_catalog.pg_input_is_valid(x->>'month','date'),false)
   OR coalesce(x->>'amount_brl','') !~ '^[0-9]+([.][0-9]+)?$'
   OR (x->>'coverage'='documented_zero' AND (x->>'amount_brl')::numeric<>0))
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_history)x
   GROUP BY x->>'series_key',x->>'month' HAVING count(*)>1)
  OR EXISTS(SELECT 1 FROM jsonb_array_elements(p_slots)x
   GROUP BY x->>'series_key',x->>'event_date' HAVING count(*)>1)
 THEN RAISE EXCEPTION 'A base mensal contém valores inválidos ou competências repetidas.'; END IF;
 FOR r IN SELECT value FROM jsonb_array_elements(p_policy->'rules')
  WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';results:='[]';generated:=0;skipped:=0;invalid_slots:=0;
  uses_history:=method='history_total_budget' OR(method='inflated_calendar' AND r->>'template_source'='history_mean');
  SELECT count(*)::int,count(*)FILTER(WHERE (x->>'amount_brl')::numeric>0)::int,
   count(*)FILTER(WHERE x->>'coverage'='observed')::int,
   coalesce(sum((x->>'amount_brl')::numeric),0),
   round(avg((x->>'amount_brl')::numeric),2),
   percentile_disc(.25)WITHIN GROUP(ORDER BY (x->>'amount_brl')::numeric),
   percentile_disc(.75)WITHIN GROUP(ORDER BY (x->>'amount_brl')::numeric),
   coalesce(sum(jsonb_array_length(coalesce(x->'source_refs','[]'))),0)::int
  INTO count_months,spend_months,partial_months,amount_sum,mean_amount,q1,q3,source_count
  FROM jsonb_array_elements(p_history)x WHERE x->>'series_key'=key
   AND (x->>'month')::date BETWEEN wf AND wt;
  SELECT coalesce(jsonb_agg(x->>'month' ORDER BY x->>'month'),'[]') INTO outliers
  FROM jsonb_array_elements(p_history)x WHERE x->>'series_key'=key
   AND (x->>'month')::date BETWEEN wf AND wt
   AND ((x->>'amount_brl')::numeric>q3+1.5*(q3-q1)
     OR (x->>'amount_brl')::numeric<greatest(0,q1-1.5*(q3-q1)));
  slot_warnings:='[]';
  reference_from:=wf;reference_to:=wt;reference_stale:=false;
  IF uses_history AND count_months=0 THEN
   slot_warnings:=slot_warnings||jsonb_build_array('history_unavailable');
  ELSIF uses_history AND (count_months<12 OR partial_months>0) THEN
   slot_warnings:=slot_warnings||jsonb_build_array('partial_history');
  END IF;
  IF uses_history AND jsonb_array_length(outliers)>0 THEN
   slot_warnings:=slot_warnings||jsonb_build_array('outliers_included'); END IF;
  IF uses_history AND (count_months<>12 OR partial_months>0) THEN
   -- An annual review must never erase the last approved complete reference.
   -- Nor may a mean of only the months with transactions masquerade as 12 months.
   mean_amount:=NULL;
   SELECT v INTO reference FROM jsonb_array_elements(coalesce(p_policy#>'{_history_reference,series}','[]'))v
    WHERE v->>'series_key'=key;
   IF reference IS NOT NULL THEN
    IF reference->>'coverage_months' IS DISTINCT FROM '12'
     OR coalesce(reference->>'sum_brl','')!~'^[0-9]+([.][0-9]+)?$'
     OR coalesce(reference->>'mean_brl','')!~'^[0-9]+([.][0-9]{1,2})?$'
     OR NOT coalesce(pg_catalog.pg_input_is_valid(reference->>'window_from','date'),false)
     OR NOT coalesce(pg_catalog.pg_input_is_valid(reference->>'window_to','date'),false)
     OR coalesce(jsonb_array_length(reference->'source_refs'),0)=0
     OR round((reference->>'sum_brl')::numeric/12,2)<>(reference->>'mean_brl')::numeric
     THEN RAISE EXCEPTION 'A última base de projeção precisa ser conferida.'; END IF;
    reference_from:=(reference->>'window_from')::date;reference_to:=(reference->>'window_to')::date;
    IF reference_to>wt OR reference_from<>date_trunc('month',reference_from)::date
     OR reference_to<>(reference_from+interval '12 months -1 day')::date
     THEN RAISE EXCEPTION 'A janela da última base de projeção é inválida.'; END IF;
    mean_amount:=(reference->>'mean_brl')::numeric;reference_stale:=true;
    slot_warnings:=slot_warnings||jsonb_build_array('previous_complete_window');
   END IF;
  END IF;
  FOR s IN SELECT value FROM jsonb_array_elements(p_slots)
   WHERE value->>'series_key'=key ORDER BY value->>'event_date' LOOP
   IF NOT coalesce(pg_catalog.pg_input_is_valid(s->>'event_date','date'),false)
    THEN RAISE EXCEPTION 'Há uma data inválida no calendário de projeção.'; END IF;
   effective_date:=(s->>'event_date')::date;
   IF effective_date<=p_as_of OR effective_date>horizon OR effective_date<(r->>'starts_on')::date
    OR (r->>'ends_on' IS NOT NULL AND effective_date>(r->>'ends_on')::date)
    THEN CONTINUE; END IF;
   cancelled:=coalesce((s->>'cancelled')::boolean,false);
   protected:=coalesce((s->>'authoritative')::boolean,false);
   complete:=coalesce((s->>'known_complete')::boolean,true);
   known:=nullif(s->>'known_amount_brl','')::numeric;
   replacement_amount:=coalesce((s->>'replacement_amount_brl')::numeric,0);
   IF known IS NULL OR known<0 OR replacement_amount<0 OR replacement_amount>known
    THEN complete:=false; END IF;
   IF replacement_amount>0 AND coalesce(jsonb_array_length(s->'replacement_refs'),0)=0
    THEN RAISE EXCEPTION 'Falta a identidade da estimativa que será substituída.'; END IF;
   IF cancelled OR protected THEN
    skipped:=skipped+1;
    results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'budget_total_brl',known,'additional_brl',0,'basis',CASE WHEN cancelled THEN 'owner_cancelled' ELSE 'documentary_precedence' END));
    CONTINUE;
   END IF;
   IF NOT complete THEN invalid_slots:=invalid_slots+1;CONTINUE;END IF;
   target:=NULL;
   CASE method
    WHEN 'history_total_budget' THEN target:=mean_amount;
    WHEN 'fixed' THEN target:=(r->>'amount_brl')::numeric;
    WHEN 'salary_net' THEN
     IF coalesce((s->>'withholding_known')::boolean,false) AND nullif(s->>'withholding_brl','') IS NOT NULL
      AND (s->>'withholding_brl')::numeric>=0
      THEN target:=(r->>'amount_brl')::numeric-(s->>'withholding_brl')::numeric;
     ELSE invalid_slots:=invalid_slots+1;CONTINUE;END IF;
    WHEN 'inflated_calendar' THEN
     target:=round(CASE WHEN uses_history THEN mean_amount ELSE(s->>'base_amount_brl')::numeric END
       *power(1+(r->>'annual_rate')::numeric,
       greatest(0,extract(year FROM effective_date)::int-CASE WHEN uses_history
        THEN extract(year FROM reference_to)::int ELSE(r->>'base_year')::int END)),2);
    WHEN 'repeat_calendar' THEN target:=(s->>'base_amount_brl')::numeric;
   END CASE;
   IF target IS NULL THEN CONTINUE;END IF;
   IF target<0 OR target>100000000 OR target<>round(target,2)
    THEN RAISE EXCEPTION 'Valor de projeção fora dos limites.';END IF;
   IF method='history_total_budget' THEN
    -- A total budget floor. It is deliberately not "new spending plus installments".
    extra:=greatest(0,target-known);amount:=greatest(target,known);
   ELSIF method='inflated_calendar' THEN
    -- Replace only identified, non-documentary future estimates at this exact slot.
    IF known>replacement_amount THEN
     skipped:=skipped+1;
     results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
      'budget_total_brl',known,'additional_brl',0,'basis','existing_occurrence'));
     CONTINUE;
    END IF;
    extra:=target;amount:=target;
   ELSE
    IF known>0 THEN
     skipped:=skipped+1;
     results:=results||jsonb_build_array(jsonb_build_object('event_date',effective_date,
      'budget_total_brl',known,'additional_brl',0,'basis','existing_occurrence'));
     CONTINUE;
    END IF;
    extra:=target;amount:=target;
   END IF;
   slot_result:=jsonb_build_object('event_date',effective_date,'budget_total_brl',amount,
    'additional_brl',extra,'known_amount_brl',known,'basis',
    CASE WHEN method='history_total_budget' THEN 'owner_authorized_12m_history' ELSE method END);
   results:=results||jsonb_build_array(slot_result);
   IF extra>0 THEN
    IF method='inflated_calendar' THEN
     replacements:=replacements||coalesce(s->'replacement_refs','[]'); END IF;
    events:=events||jsonb_build_array(jsonb_build_object('event_date',effective_date,
     'account',r->>'account','description',r->>'description',
     'signed_amount',CASE WHEN r->>'direction'='income' THEN extra ELSE -extra END,
     'source','planning_projection_v412','source_ref','projection:v412:'||key||':'||effective_date,
     'confidence',CASE WHEN method='history_total_budget' THEN 'owner_authorized_12m_history' ELSE 'owner_authorized_planning_rule' END,
     'account_assignment','owner_policy','legacy_index',NULL,'original_date',effective_date,'displaced',false,
     'series_key',key,'method',method,'budget_total_brl',amount,'known_amount_brl',known,
     'source_refs',coalesce(s->'source_refs','[]')));
    generated:=generated+1;
   END IF;
  END LOOP;
  IF invalid_slots>0 THEN slot_warnings:=slot_warnings||jsonb_build_array('unreconciled_periods'); END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_slots)x WHERE x->>'series_key'=key)
   THEN slot_warnings:=slot_warnings||jsonb_build_array('calendar_unavailable'); END IF;
  SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY year),'[]') INTO annual FROM(
   SELECT extract(year FROM(x->>'event_date')::date)::int AS year,
    round(sum((x->>'budget_total_brl')::numeric),2) budget_total_brl,
    round(sum((x->>'additional_brl')::numeric),2) additional_brl,
    extract(year FROM(x->>'event_date')::date)::int=extract(year FROM p_as_of)::int partial_year
   FROM jsonb_array_elements(results)x GROUP BY 1,4)a;
  series:=series||jsonb_build_array(jsonb_build_object('series_key',key,'description',r->>'description',
   'direction',r->>'direction','account',r->>'account','method',method,
   'reference_amount_brl',CASE WHEN uses_history THEN mean_amount ELSE nullif(r->>'amount_brl','')::numeric END,
   'history_total_brl',CASE WHEN uses_history THEN amount_sum END,'uses_history',uses_history,
   'template_source',r->>'template_source','template_year',r->'template_year',
   'reference_window',jsonb_build_object('from',reference_from,'to',reference_to),
   'reference_stale',reference_stale,
   'coverage_months',count_months-partial_months,'observed_months',count_months,
   'months_with_spend',spend_months,'partial_months',partial_months,
   'expected_months',12,'source_count',source_count,'outlier_months',outliers,
   'annual_rate',coalesce((r->>'annual_rate')::numeric,0),'warnings',slot_warnings,
   'projected_occurrences',generated,'preserved_occurrences',skipped,'unresolved_periods',invalid_slots,
   'annual_totals',annual,'due_day_basis',r->>'due_day_basis'));
  IF jsonb_array_length(slot_warnings)>0 THEN
   warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key',key,'description',r->>'description','codes',slot_warnings));
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements_text(replacements)x GROUP BY x HAVING count(*)>1)
  THEN RAISE EXCEPTION 'Uma previsão antiga não pode ser substituída duas vezes.'; END IF;
 RETURN jsonb_build_object('version','projection-policy-v412','schema_version',1,'enabled',true,
  'as_of',p_as_of,'horizon_end',horizon,'next_review_on',nr,
  'history_window',jsonb_build_object('from',wf,'to',wt),
  'series',series,'warnings',warnings,'events',events,'replacement_refs',replacements,
  'card_method','total_budget_floor','outliers_excluded',false,'missing_months_assumed_zero',false,
  'financial_sources_modified',false,'current_year_partial',extract(doy FROM p_as_of)>1);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.calculate(jsonb,jsonb,jsonb,date) TO service_role;


-- SOURCE: reference_state.sql
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


-- SOURCE: orchestration.sql
-- Read-only construction of future slots. No financial event is inserted here.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.build(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id); horizon date;
 wf date;wt date;nr date;history jsonb;templates jsonb;baseline jsonb;cycles jsonb;slots jsonb:='[]';
 r jsonb;t jsonb;period record;key text;method text;d date;nominal date;day_number int;
 base_amount numeric;known numeric;replace_amount numeric;replace_refs jsonb;refs jsonb;authoritative boolean;
 known_complete boolean;cancelled boolean;withholding numeric;withholding_known boolean;calendar_days jsonb;canonical_due date;
 seen_dates date[];replacement_seen text[]:='{}';withholding_rows int;invoice_amount numeric;invoice_count int;
BEGIN
 IF policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));
 horizon:=lts_projection_private_v412.horizon_end(p_as_of);
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(policy,p_as_of);
 SELECT coalesce(jsonb_agg(to_jsonb(f)ORDER BY series_key,month),'[]') INTO history
 FROM lts_projection_private_v412.monthly_source_facts_v412(p_user_id,wf,wt,policy)f;
 SELECT coalesce(jsonb_agg(to_jsonb(template_row)ORDER BY series_key,event_month,event_day,source_ref),'[]') INTO templates
 FROM lts_projection_private_v412.calendar_templates_v412(p_user_id,policy)template_row;
 SELECT coalesce(jsonb_agg(to_jsonb(b)ORDER BY event_date,source_ref),'[]') INTO baseline
 FROM lts_projection_private_v412.base_flow(p_user_id,p_as_of+1,horizon)b;
 SELECT coalesce(jsonb_agg(to_jsonb(c)ORDER BY series_key,due_date),'[]') INTO cycles
 FROM lts_projection_private_v412.known_card_periods_v412(p_user_id)c;

 FOR r IN SELECT value FROM jsonb_array_elements(policy->'rules')
  WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';seen_dates:='{}';calendar_days:='[]';
  IF method IN('inflated_calendar','repeat_calendar') AND coalesce(r->>'template_source','calendar')<>'history_mean' THEN
   -- Templates may include several installments and a separate license in a year.
   -- Equal calendar dates aggregate once, retaining all original references.
   SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY event_month,event_day),'[]') INTO calendar_days
   FROM(SELECT (v->>'event_month')::int event_month,(v->>'event_day')::int event_day,
    sum((v->>'amount_brl')::numeric) amount_brl,jsonb_agg(v->>'source_ref') source_refs
    FROM jsonb_array_elements(templates)v WHERE v->>'series_key'=key
    GROUP BY 1,2)a;
  ELSE
   day_number:=nullif(r->>'due_day','')::int;
   IF day_number IS NULL THEN
    -- Modal observed day; ties use the earlier day and remain explicitly estimated.
    SELECT value::int INTO day_number FROM jsonb_array_elements(history)f
    CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(f->'observed_days','[]'))x(value)
    WHERE f->>'series_key'=key AND value~'^[0-9]{1,2}$' AND value::int BETWEEN 1 AND 31
    GROUP BY value ORDER BY count(*) DESC,value::int LIMIT 1;
   END IF;
   IF day_number BETWEEN 1 AND 31 THEN
    SELECT jsonb_agg(jsonb_build_object('event_month',n,'event_day',day_number,
     'amount_brl',r->'amount_brl','source_refs','[]'::jsonb)ORDER BY n) INTO calendar_days
    FROM generate_series(1,12)n;
   END IF;
  END IF;
  FOR period IN SELECT generate_series(extract(year FROM p_as_of)::int,extract(year FROM horizon)::int) AS calendar_year LOOP
   FOR t IN SELECT value FROM jsonb_array_elements(calendar_days) ORDER BY (value->>'event_month')::int,(value->>'event_day')::int LOOP
    nominal:=make_date(period.calendar_year,(t->>'event_month')::int,1);
    d:=nominal+least((t->>'event_day')::int,extract(day FROM nominal+interval '1 month -1 day')::int)-1;
    IF r->>'card_family' IS NOT NULL THEN
     -- Current owner calendar and an explicit transition outrank a historical mode.
     SELECT min((v->>'due_date')::date) INTO canonical_due FROM jsonb_array_elements(cycles)v
     WHERE v->>'series_key'=key AND date_trunc('month',(v->>'due_date')::date)=nominal;
     -- A cycle's cash date already includes the V370 transition. Apply that
     -- transition only to a new nominal date, never a second time to a cycle.
     d:=CASE WHEN canonical_due IS NOT NULL THEN canonical_due
      ELSE public.lts_card_transition_cash_date_v370(p_user_id,r->>'card_family',d) END;
    END IF;
    IF d<=p_as_of OR d>horizon OR d<(r->>'starts_on')::date OR d=ANY(seen_dates)
     OR(r->>'ends_on' IS NOT NULL AND d>(r->>'ends_on')::date) THEN CONTINUE; END IF;
    seen_dates:=array_append(seen_dates,d);base_amount:=nullif(t->>'amount_brl','')::numeric;
    SELECT coalesce(sum(abs((v->>'signed_amount')::numeric)),0),
     coalesce(jsonb_agg(v->>'source_ref' ORDER BY v->>'source_ref'),'[]')
    INTO known,refs FROM jsonb_array_elements(baseline)v
    WHERE public.lts_forecast_series_key_v1(v->>'description')=key
     AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
     AND date_trunc('month',(v->>'event_date')::date)=date_trunc('month',d);
    authoritative:=false;known_complete:=true;replace_amount:=0;replace_refs:='[]';
    IF r->>'card_family' IS NOT NULL THEN
     SELECT count(*)::int,coalesce(bool_or(coalesce((v->>'closed')::boolean,false) OR coalesce((v->>'paid')::boolean,false)),false),
      coalesce(bool_and(coalesce((v->>'complete')::boolean,false)),true),sum((v->>'amount_brl')::numeric)
     INTO invoice_count,authoritative,known_complete,invoice_amount
     FROM jsonb_array_elements(cycles)v WHERE v->>'series_key'=key
      AND date_trunc('month',(v->>'due_date')::date)=date_trunc('month',d);
     -- If a canonical cycle is missing from this reader, do not hide the mismatch
     -- by estimating a smaller residual against a different amount.
     IF invoice_count>0 AND invoice_amount IS NOT NULL AND NOT authoritative
      AND abs(invoice_amount-known)>0.005 THEN known_complete:=false;END IF;
    END IF;
    cancelled:=EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule c
     WHERE c.user_id=p_user_id AND c.active AND c.action='suppress_legacy'
      AND c.replacement_source='owner_confirmation' AND coalesce(c.evidence->>'policy_action','')<>'revise'
      AND public.lts_forecast_series_key_v1(c.description_exact)=key AND d BETWEEN c.date_from AND c.date_to)
     OR EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366 p
      WHERE p.user_id=p_user_id AND p.series_key=key
       AND (p.direction='entrada')=(r->>'direction'='income')
       AND p.confirmed_at >= (policy->>'_activated_at')::timestamptz
       AND ((NOT p.active AND d>=p.starts_on) OR (p.ends_on IS NOT NULL AND d>p.ends_on)));
    IF method='inflated_calendar' THEN
     -- The new annual template may split an old lump-sum estimate. Suppress all
     -- identified estimates for the same future year once, on its first slot.
     SELECT coalesce(jsonb_agg(v->>'source_ref' ORDER BY v->>'source_ref'),'[]'),
      coalesce(sum(abs((v->>'signed_amount')::numeric)),0)
     INTO replace_refs,replace_amount FROM jsonb_array_elements(baseline)v
     WHERE public.lts_forecast_series_key_v1(v->>'description')=key
      AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
      AND extract(year FROM(v->>'event_date')::date)=period.calendar_year
      AND v->>'source'='legacy_fix86' AND v->>'confidence'='legacy_projection_adjusted'
      AND NOT (v->>'source_ref'=ANY(replacement_seen));
     -- Documentary amounts in a month replace that month's estimate, preserving
     -- their identity/date and preventing a budget from adding a second payment.
     authoritative:=EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)v
      WHERE public.lts_forecast_series_key_v1(v->>'description')=key
       AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
       AND date_trunc('month',(v->>'event_date')::date)=date_trunc('month',d)
       AND NOT(v->>'source'='legacy_fix86' AND v->>'confidence'='legacy_projection_adjusted'));
     IF NOT authoritative AND NOT cancelled THEN
      SELECT coalesce(array_agg(value),'{}')||replacement_seen INTO replacement_seen
      FROM jsonb_array_elements_text(replace_refs);
      known:=replace_amount;
     ELSE replace_refs:='[]';replace_amount:=0; END IF;
    END IF;
    withholding:=NULL;withholding_known:=false;
    IF method='salary_net' THEN
     SELECT count(*)::int,sum(abs(amount_total)) INTO withholding_rows,withholding
     FROM public.lts_commitment_documentary_schedule c WHERE c.user_id=p_user_id
      AND c.commitment_id=r->>'withholding_commitment'
      AND date_trunc('month',c.due_date)=date_trunc('month',d);
     withholding_known:=withholding_rows>0;
     IF withholding_rows=0 AND pg_catalog.pg_input_is_valid(r->>'withholding_ends_on','date')
      AND nullif(btrim(r->>'withholding_end_source_ref'),'') IS NOT NULL
      AND d>(r->>'withholding_ends_on')::date
      THEN withholding:=0;withholding_known:=true;END IF;
    END IF;
    slots:=slots||jsonb_build_array(jsonb_build_object('series_key',key,'event_date',d,
     'base_amount_brl',base_amount,'known_amount_brl',known,'known_complete',known_complete,
     'authoritative',authoritative,'cancelled',cancelled,
     'replacement_amount_brl',replace_amount,'replacement_refs',replace_refs,
     'withholding_brl',withholding,'withholding_known',withholding_known,
     'source_refs',refs||coalesce(t->'source_refs','[]')));
   END LOOP;
  END LOOP;
 END LOOP;
 RETURN lts_projection_private_v412.calculate(policy,history,slots,p_as_of);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.build(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build(uuid,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.read_policy()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 result:=lts_projection_private_v412.build(u,current_date);
 RETURN (result-'events'-'replacement_refs')||jsonb_build_object('read_at',clock_timestamp());
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.read_policy() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.read_policy() TO authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_projection_policy_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT lts_projection_private_v412.read_policy()
$f$;
REVOKE ALL ON FUNCTION public.lts_browser_projection_policy_v412() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_projection_policy_v412() TO authenticated;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text,166));
 PERFORM lts_projection_private_v412.refresh_reference(u,current_date);
 -- Reuse the installed V366/V376 materializer for its existing fixed plans.
 PERFORM public.lts_recurring_materialize_v366(u,current_date);
 PERFORM lts_projection_private_v412.invalidate_reads(u);
 result:=lts_projection_private_v412.read_policy();
 RETURN result||jsonb_build_object('refreshed',true);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.refresh() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.refresh() TO authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_projection_refresh_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT lts_projection_private_v412.refresh()
$f$;
REVOKE ALL ON FUNCTION public.lts_browser_projection_refresh_v412() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_projection_refresh_v412() TO authenticated;


-- SOURCE: integration.sql
-- Replace only the two reviewed function bodies. Signatures, language, owner,
-- SECURITY DEFINER, TimeZone, search_path and ACL remain as installed.
DO $install$
DECLARE target oid;before_definition text;new_definition text;body text;old_md5 text;
 signature text;new_body text;prior_acl aclitem[];prior_owner oid;prior_config text[];
 prior_security boolean;current_body text;
BEGIN
 FOR signature,old_md5,new_body IN
 SELECT * FROM(VALUES
 ('public.lts_corrected_cashflow_operational_v1(uuid,date,date)',
  '0a687b1bf642ab20cdadfb96ec0f0bed',
  $flow$
-- lts-projection-v412: add derived future budget residuals once.
WITH baseline AS MATERIALIZED (
 SELECT * FROM lts_projection_private_v412.base_flow(p_user_id,p_from,p_to)
), projection AS MATERIALIZED (
 SELECT CASE WHEN p_to>current_date AND p_from<=lts_projection_private_v412.horizon_end(current_date)
  THEN lts_projection_private_v412.build(p_user_id,current_date)
  ELSE '{}'::jsonb END AS data
)
SELECT b.* FROM baseline b CROSS JOIN projection p
WHERE NOT(b.event_date>current_date AND coalesce(p.data->'replacement_refs','[]'::jsonb) ? b.source_ref)
UNION ALL
SELECT x.* FROM projection p
CROSS JOIN LATERAL jsonb_to_recordset(coalesce(p.data->'events','[]'::jsonb)) AS x(
 event_date date,account text,description text,signed_amount numeric,source text,
 source_ref text,confidence text,account_assignment text,legacy_index integer,
 original_date date,displaced boolean)
WHERE x.event_date BETWEEN p_from AND p_to;
$flow$),
 ('public.lts_recurring_maintenance_v366()',
  '64fe0a7ace2fb8a4d3b78e4ec7b5def9',
  $maintenance$
-- lts-projection-v412: reuse the existing daily schedule and fixed-plan engine.
DECLARE u uuid;results jsonb:='[]';reference_result jsonb;
BEGIN
 FOR u IN
  SELECT user_id FROM public.lts_recurring_plan_v366 WHERE active AND value_kind='fixed'
  UNION
  SELECT usuario_id FROM public.legacy_namespace WHERE chave='lts_owner_projection_policy_v412'
 LOOP
  reference_result:=lts_projection_private_v412.refresh_reference(u,current_date);
  results:=results||jsonb_build_array(public.lts_recurring_materialize_v366(u,current_date));
  IF EXISTS(SELECT 1 FROM public.legacy_namespace WHERE usuario_id=u AND chave='lts_owner_projection_policy_v412')
   THEN PERFORM lts_projection_private_v412.invalidate_reads(u);END IF;
 END LOOP;
 RETURN results;
END
$maintenance$)) AS versions(signature,old_md5,new_body)
 LOOP
  target:=to_regprocedure(signature);
  IF target IS NULL THEN RAISE EXCEPTION 'V412 predecessor missing: %',signature;END IF;
  SELECT prosrc,proacl,proowner,proconfig,prosecdef
  INTO current_body,prior_acl,prior_owner,prior_config,prior_security FROM pg_proc WHERE oid=target;
  before_definition:=pg_get_functiondef(target);
  IF md5(before_definition)<>old_md5 AND current_body IS DISTINCT FROM new_body
   THEN RAISE EXCEPTION 'V412 predecessor changed: %',signature;END IF;
  -- pg_get_functiondef supplies a canonical $function$ delimiter. Replacing its
  -- body alone avoids resetting installation-specific function properties.
  new_definition:=split_part(before_definition,'AS $function$',1)
   ||'AS $function$'||new_body||'$function$';
  EXECUTE new_definition;
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=target AND
    (proacl IS DISTINCT FROM prior_acl OR proowner<>prior_owner
     OR proconfig IS DISTINCT FROM prior_config OR prosecdef<>prior_security))
   THEN RAISE EXCEPTION 'V412 changed protected function metadata: %',signature;END IF;
 END LOOP;
END $install$;


COMMIT;
