CREATE OR REPLACE FUNCTION public.lts_bank_posted_rows_v231(p_user_id uuid)
 RETURNS SETOF lts_open_finance_staging
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
 WITH src AS MATERIALIZED (
  SELECT s.*,CASE WHEN normalized_payload->>'operation_type'='CARTAO'
   AND description_raw ~* ' - DOCTO: [0-9]+$'
   THEN institution_code||'|'||provider_account_ref||'|'||date_trunc('month',posting_date)::date||'|'||
    signed_amount::text||'|'||substring(description_raw from '(?i)DOCTO: ([0-9]+)$') END document_key
  FROM public.lts_open_finance_staging s WHERE user_id=p_user_id AND resource_type='transaction'
   AND currency='BRL' AND provider_deleted_at IS NULL
   AND normalized_payload->>'status'='POSTED'
   AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 ), chosen AS (
  SELECT DISTINCT ON (coalesce(document_key,id::text)) id FROM src
  ORDER BY coalesce(document_key,id::text),posting_date,first_seen_at,id
 )
 SELECT s.* FROM public.lts_open_finance_staging s JOIN chosen c USING(id)
$function$
