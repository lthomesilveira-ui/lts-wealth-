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
