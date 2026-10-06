BEGIN;SET LOCAL TimeZone='America/Sao_Paulo';SET LOCAL jit=off;SET LOCAL statement_timeout='90s';
CREATE OR REPLACE FUNCTION public.lts_bank_known_classification_baseline_v258(p_user_id uuid, p_staging_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH target AS (SELECT * FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND id=p_staging_id),
 candidates AS (
  SELECT d.category_label category,d.beneficiary person,0 priority,'user_decision' basis
  FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging'
   AND d.source_ref=p_staging_id::text AND d.category_label IS NOT NULL
  UNION ALL
  SELECT r.category,r.center_cost,CASE WHEN r.confidence='user_confirmed' THEN 1 ELSE 2 END,'confirmed_rule'
  FROM public.lts_semantic_rule r CROSS JOIN target t WHERE r.user_id=p_user_id AND r.active
   AND r.confidence IN ('user_confirmed','high','alta','system_high')
   AND ((r.match_type IN ('exact','prefix') AND public.lts_bank_merchant_key_v231(r.match_value)=public.lts_bank_merchant_key_v231(t.description_raw))
    OR (r.match_type='prefix' AND starts_with(public.lts_v178_norm(t.description_raw),public.lts_v178_norm(r.match_value))))
  UNION ALL
  SELECT r.category,r.center_cost,3,'known_employer_payroll' FROM public.lts_semantic_rule r CROSS JOIN target t
  WHERE r.user_id=p_user_id AND r.active AND r.category='Salário'
   AND t.signed_amount>0 AND t.normalized_payload->>'operation_type'='FOLHA_PAGAMENTO'
   AND nullif(r.counterparty,'') IS NOT NULL AND length(public.lts_bank_merchant_key_v231(r.counterparty))>=4
   AND strpos(public.lts_bank_merchant_key_v231(t.description_raw),public.lts_bank_merchant_key_v231(r.counterparty))>0
 UNION ALL
 SELECT 'Rendimentos financeiros',null,4,'explicit_bank_yield' FROM target t
 WHERE t.signed_amount>0 AND public.lts_v178_norm(t.description_raw) ~ '^rendimentos (remuner basica poup|juros poup)'
 ), ranked AS (SELECT *,min(priority) OVER() best FROM candidates
  WHERE public.lts_v178_norm(category) NOT IN ('','a classificar','nao identificado','sem categoria'))
 SELECT CASE WHEN count(DISTINCT category)=1 THEN jsonb_build_object('category',min(category),
  'beneficiary',CASE WHEN count(DISTINCT person)=1 THEN min(person) END,'basis',min(basis)) ELSE '{}'::jsonb END
 FROM ranked WHERE priority=best
$function$
;
REVOKE ALL ON FUNCTION public.lts_bank_known_classification_baseline_v258(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE TEMP TABLE classification_v258(id uuid,j jsonb,ms numeric) ON COMMIT DROP;
DO $baseline$ DECLARE r record;j jsonb;t timestamptz;u uuid:=public.lts_open_finance_pilot_owner_v1(); BEGIN
 FOR r IN SELECT id FROM public.lts_open_finance_staging WHERE user_id=u AND resource_type='transaction' AND provider_deleted_at IS NULL ORDER BY posting_date DESC,id LIMIT 800 LOOP
  t:=clock_timestamp();j:=public.lts_bank_known_classification_baseline_v258(u,r.id);
  INSERT INTO classification_v258 VALUES(r.id,j,extract(epoch FROM clock_timestamp()-t)*1000);
 END LOOP;END $baseline$;
CREATE OR REPLACE FUNCTION public.lts_bank_known_classification_v231(p_user_id uuid, p_staging_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH target AS MATERIALIZED (SELECT s.*,public.lts_bank_merchant_key_v231(s.description_raw) AS merchant_key,public.lts_v178_norm(s.description_raw) AS normalized_description FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.id=p_staging_id),
 candidates AS (
  SELECT d.category_label category,d.beneficiary person,0 priority,'user_decision' basis
  FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table='lts_open_finance_staging'
   AND d.source_ref=p_staging_id::text AND d.category_label IS NOT NULL
  UNION ALL
  SELECT r.category,r.center_cost,CASE WHEN r.confidence='user_confirmed' THEN 1 ELSE 2 END,'confirmed_rule'
  FROM public.lts_semantic_rule r CROSS JOIN target t WHERE r.user_id=p_user_id AND r.active
   AND r.confidence IN ('user_confirmed','high','alta','system_high')
   AND ((r.match_type IN ('exact','prefix') AND public.lts_bank_merchant_key_v231(r.match_value)=t.merchant_key)
    OR (r.match_type='prefix' AND starts_with(t.normalized_description,public.lts_v178_norm(r.match_value))))
  UNION ALL
  SELECT r.category,r.center_cost,3,'known_employer_payroll' FROM public.lts_semantic_rule r CROSS JOIN target t
  WHERE r.user_id=p_user_id AND r.active AND r.category='Salário'
   AND t.signed_amount>0 AND t.normalized_payload->>'operation_type'='FOLHA_PAGAMENTO'
   AND nullif(r.counterparty,'') IS NOT NULL AND length(public.lts_bank_merchant_key_v231(r.counterparty))>=4
   AND strpos(t.merchant_key,public.lts_bank_merchant_key_v231(r.counterparty))>0
 UNION ALL
 SELECT 'Rendimentos financeiros',null,4,'explicit_bank_yield' FROM target t
 WHERE t.signed_amount>0 AND t.normalized_description ~ '^rendimentos (remuner basica poup|juros poup)'
 ), ranked AS (SELECT *,min(priority) OVER() best FROM candidates
  WHERE public.lts_v178_norm(category) NOT IN ('','a classificar','nao identificado','sem categoria'))
 SELECT CASE WHEN count(DISTINCT category)=1 THEN jsonb_build_object('category',min(category),
  'beneficiary',CASE WHEN count(DISTINCT person)=1 THEN min(person) END,'basis',min(basis)) ELSE '{}'::jsonb END
 FROM ranked WHERE priority=best
$function$
;
DO $candidate$ DECLARE r record;j jsonb;t timestamptz;total_ms numeric:=0;u uuid:=public.lts_open_finance_pilot_owner_v1();BEGIN
 FOR r IN SELECT * FROM classification_v258 ORDER BY id LOOP
  t:=clock_timestamp();j:=public.lts_bank_known_classification_v231(u,r.id);
  total_ms:=total_ms+extract(epoch FROM clock_timestamp()-t)*1000;
  IF j::text IS DISTINCT FROM r.j::text THEN RAISE EXCEPTION 'V258_CLASSIFICATION_CHANGED:%',r.id; END IF;
 END LOOP;
 IF public.lts_bank_known_classification_v231(NULL,NULL)::text IS DISTINCT FROM public.lts_bank_known_classification_baseline_v258(NULL,NULL)::text THEN RAISE EXCEPTION 'NULL_CHANGED';END IF;
 PERFORM set_config('lts.v258_classification',jsonb_build_object('pass',true,'count',(SELECT count(*) FROM classification_v258),'baseline_ms',(SELECT sum(ms) FROM classification_v258),'candidate_ms',total_ms,'same_json_and_text',true)::text,true);END $candidate$;
SELECT current_setting('lts.v258_classification')::jsonb receipt;
ROLLBACK;
