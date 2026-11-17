CREATE OR REPLACE FUNCTION lts_receipt_private_v460.utility_receipts(p_user_id uuid, p_as_of date)
 RETURNS TABLE(staging_id uuid, projection_ref text, projection_date date, description text, series_key text, direction text, actual_date date, actual_amount numeric, basis text)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
WITH candidates AS MATERIALIZED (
 SELECT s.id staging_id,'evento_base:'||e.idx::text projection_ref,(CASE WHEN pg_catalog.pg_input_is_valid(e.dados->>'dia','date') THEN (e.dados->>'dia')::date END) projection_date,
 e.dados->>'desc' description,public.lts_forecast_series_key_v1(e.dados->>'desc') series_key,
 'expense'::text direction,s.posting_date actual_date,s.signed_amount actual_amount,
 'proved_retired_utility_forecast'::text basis,
 count(*) OVER(PARTITION BY s.id) source_claims,
 count(*) OVER(PARTITION BY e.idx) forecast_claims
 FROM public.projecao_op o
 JOIN public.evento_base e ON e.usuario_id=o.usuario_id
  AND 'evento_base:'||e.idx::text=o.dados#>>'{reconciliation,source_ref}'
 JOIN public.lts_open_finance_staging s ON s.user_id=o.usuario_id
  AND s.id::text=o.dados#>>'{reconciliation,staging_id}'
 JOIN public.lts_v178_review_decision r ON r.user_id=s.user_id
  AND r.source_table='lts_open_finance_staging' AND r.source_ref=s.id::text
 WHERE o.usuario_id=p_user_id AND o.dados->>'tipo'='cancelamento'
 AND o.dados->>'escopo'='ocorrencia' AND o.dados->>'status'='ativa'
 AND o.dados->'revertidaEm'='null'::jsonb AND o.dados#>'{depois,cancelada}'='true'::jsonb
 AND o.dados#>>'{reconciliation,basis}'='posted_unique_utility_receiver_plus_prior_owner_classification'
 AND o.dados#>'{reconciliation,original_forecast}'=e.dados
 AND o.dados->>'dia'=e.dados->>'dia' AND o.dados->>'desde'=e.dados->>'dia'
 AND o.dados->>'desc'=e.dados->>'desc' AND o.dados->>'conta'=e.dados->>'conta'
 AND e.dados->>'efeito'='saida' AND e.dados->>'conta' IN('Itau','Itaú')
 AND e.dados->>'desc' ~* '^Enel([[:space:]-]|$)'
 AND e.dados->>'dia' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
 AND pg_catalog.pg_input_is_valid(e.dados->>'dia','date')
 AND CASE WHEN e.dados->>'valor' ~ '^[0-9]+([.][0-9]+)?$' THEN (e.dados->>'valor')::numeric>0 ELSE false END
 AND s.resource_type='transaction' AND s.currency='BRL' AND s.institution_code='341'
 AND s.provider_deleted_at IS NULL AND s.signed_amount<0 AND s.occurred_at<=current_timestamp
 AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.raw_hash ~ '^[0-9a-f]{64}$' AND s.raw_hash=o.dados#>>'{reconciliation,raw_hash}'
 AND s.posting_date::text=o.dados#>>'{reconciliation,actual_bank_posting_date}'
 AND CASE WHEN pg_catalog.pg_input_is_valid(o.dados#>>'{reconciliation,actual_signed_amount}','numeric')
 THEN (o.dados#>>'{reconciliation,actual_signed_amount}')::numeric=s.signed_amount ELSE false END
 AND s.description_raw ~* 'ELETROPAULO[[:space:]]+[0-9]{4,8}'
 AND s.posting_date BETWEEN date_trunc('month',p_as_of)::date AND p_as_of
 AND date_trunc('month',s.posting_date)=date_trunc('month',(CASE WHEN pg_catalog.pg_input_is_valid(e.dados->>'dia','date') THEN (e.dados->>'dia')::date END))
 AND r.category_label='Energia' AND r.property_code IS NOT NULL
 AND r.category_label=o.dados#>>'{reconciliation,category}'
 AND r.property_code=o.dados#>>'{reconciliation,property_code}'
 AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CNPJ'
 AND nullif(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','') IS NOT NULL
 AND EXISTS(
  SELECT 1 FROM public.lts_open_finance_staging prior
  JOIN public.lts_v178_review_decision owner_decision ON owner_decision.user_id=prior.user_id
   AND owner_decision.source_table='lts_open_finance_staging' AND owner_decision.source_ref=prior.id::text
  WHERE prior.user_id=p_user_id AND prior.id<>s.id AND prior.institution_code=s.institution_code
  AND prior.resource_type='transaction' AND prior.currency='BRL' AND prior.signed_amount<0
  AND prior.provider_deleted_at IS NULL AND prior.normalized_payload->>'status'='POSTED'
  AND prior.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND prior.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND prior.posting_date<date_trunc('month',s.posting_date)::date
  AND owner_decision.decision_basis='authenticated_user_v229'
  AND owner_decision.category_label=r.category_label AND owner_decision.property_code=r.property_code
  AND prior.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CNPJ'
  AND prior.raw_payload#>>'{paymentData,receiver,documentNumber,value}'=s.raw_payload#>>'{paymentData,receiver,documentNumber,value}'
  AND substring(prior.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
   =substring(s.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
 )
 AND EXISTS(
  SELECT 1 FROM public.lts_open_finance_staging b
  WHERE b.user_id=p_user_id AND b.resource_type='balance' AND b.currency='BRL'
  AND b.provider_deleted_at IS NULL AND b.institution_code=s.institution_code
  AND b.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND b.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND CASE WHEN pg_catalog.pg_input_is_valid(b.normalized_payload->>'as_of','timestamp with time zone')
   THEN (b.normalized_payload->>'as_of')::timestamptz END>=s.occurred_at
 )
 AND (SELECT count(*) FROM public.lts_open_finance_staging other
  WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code=s.institution_code
  AND other.provider_deleted_at IS NULL AND other.currency='BRL' AND other.signed_amount<0
  AND other.normalized_payload->>'status'='POSTED' AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND other.normalized_payload->>'provider_account_id'=s.normalized_payload->>'provider_account_id'
  AND date_trunc('month',other.posting_date)=date_trunc('month',s.posting_date)
  AND substring(other.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})')
   =substring(s.description_raw FROM '(?i)ELETROPAULO[[:space:]]+([0-9]{4,8})'))=1
)
SELECT staging_id,projection_ref,projection_date,description,series_key,direction,actual_date,actual_amount,basis
FROM candidates WHERE source_claims=1 AND forecast_claims=1;
$function$;
