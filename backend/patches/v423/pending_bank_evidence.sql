BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
CREATE SCHEMA IF NOT EXISTS lts_pending_evidence_private_v423;
REVOKE ALL ON SCHEMA lts_pending_evidence_private_v423 FROM PUBLIC,anon;
GRANT USAGE ON SCHEMA lts_pending_evidence_private_v423 TO authenticated,service_role;
CREATE OR REPLACE FUNCTION lts_pending_evidence_private_v423.read_pending()
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 WITH accounts AS MATERIALIZED(
  SELECT s.*,CASE WHEN pg_catalog.pg_input_is_valid(s.normalized_payload->>'as_of','timestamp with time zone')
   THEN ((s.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date END AS source_date
  FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='account'
   AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 ), candidates AS MATERIALIZED(
  SELECT a.id AS account_id,p.id,p.provider_record_id,p.posting_date,p.signed_amount,p.description_raw,
   p.normalized_payload->>'status' AS provider_status,
   row_number() OVER(PARTITION BY a.id ORDER BY p.posting_date,p.id) AS rn,
   count(*) OVER(PARTITION BY a.id,p.provider_record_id) AS duplicate_count
  FROM accounts a JOIN public.lts_open_finance_staging p
   ON p.user_id=u AND p.connection_id=a.connection_id AND p.provider_account_ref=a.provider_account_ref
    AND p.resource_type='transaction' AND p.provider_deleted_at IS NULL
    AND p.normalized_payload->>'layer'='bank_cash' AND p.normalized_payload->>'status'='PENDING'
    AND nullif(p.normalized_payload->>'source_sync_at','')=nullif(a.normalized_payload->>'source_sync_at','')
  WHERE a.source_date BETWEEN current_date-7 AND current_date
   AND (p.posting_date IS NULL OR p.posting_date BETWEEN a.source_date-7 AND a.source_date)
 ), totals AS MATERIALIZED(
  SELECT account_id,count(*) AS n,sum(signed_amount) AS amount,
   bool_and(posting_date IS NOT NULL AND signed_amount IS NOT NULL AND nullif(description_raw,'') IS NOT NULL
    AND nullif(provider_record_id,'') IS NOT NULL AND duplicate_count=1) AS valid
  FROM candidates GROUP BY account_id
 )
 SELECT jsonb_build_object('version','pending-bank-evidence-v423','as_of',current_date,
  'accounts',coalesce((SELECT jsonb_agg(jsonb_build_object('bank',a.institution_name,'balance_brl',a.signed_amount,
   'source_date',a.source_date,'pending_count',t.n,'pending_total_brl',t.amount,
   'complete',coalesce(t.valid,false) AND t.n<=200 AND a.signed_amount IS NOT NULL,
   'movements',coalesce((SELECT jsonb_agg(jsonb_build_object('key',c.id,'date',c.posting_date,
    'amount',c.signed_amount,'description',c.description_raw,'status',c.provider_status) ORDER BY c.posting_date,c.id)
    FROM candidates c WHERE c.account_id=a.id AND c.rn<=200),'[]'::jsonb)) ORDER BY a.institution_name,a.id)
   FROM accounts a JOIN totals t ON t.account_id=a.id),'[]'::jsonb)) INTO result;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION lts_pending_evidence_private_v423.read_pending() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION lts_pending_evidence_private_v423.read_pending() TO authenticated,service_role;
CREATE OR REPLACE FUNCTION public.lts_browser_pending_bank_evidence_v423()
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $function$
 SELECT lts_pending_evidence_private_v423.read_pending();
$function$;
REVOKE ALL ON FUNCTION public.lts_browser_pending_bank_evidence_v423() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_pending_bank_evidence_v423() TO authenticated,service_role;
COMMIT;
