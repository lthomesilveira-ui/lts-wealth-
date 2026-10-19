CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN BYPASSRLS;
GRANT USAGE ON SCHEMA public TO anon,authenticated,service_role;
CREATE TABLE public.lts_open_finance_staging(institution_code text,resource_type text,provider_record_id text,posting_date date,signed_amount numeric,description_raw text,normalized_payload jsonb);
ALTER TABLE public.lts_open_finance_staging ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.lts_open_finance_staging TO service_role;
CREATE OR REPLACE FUNCTION public.lts_open_finance_card_pending_v1(p_institution_code text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with x as (
 select posting_date,abs(signed_amount) amount,description_raw,
 normalized_payload->>'last4' last4,normalized_payload->>'status' status
 from public.lts_open_finance_staging
 where institution_code=p_institution_code and resource_type='card_transaction'
 and posting_date>date '2026-09-22' and normalized_payload->>'status'='PENDING'
)
select jsonb_build_object('institution_code',p_institution_code,'baseline_boundary','2026-09-22',
'pending_total',coalesce(sum(amount),0),'transaction_count',count(*),
'net_signed',coalesce(sum(case when status='PENDING' then (select signed_amount from public.lts_open_finance_staging s2 where s2.institution_code=p_institution_code and s2.resource_type='card_transaction' and s2.posting_date=x.posting_date and s2.description_raw=x.description_raw limit 1) else 0 end),0),
'promotion_enabled',false) from x
$function$;
CREATE OR REPLACE FUNCTION public.lts_open_finance_pending_card_expense_v1(p_institution_code text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
with x as (
 select provider_record_id,posting_date,signed_amount,description_raw,normalized_payload->>'last4' last4
 from public.lts_open_finance_staging
 where institution_code=p_institution_code and resource_type='card_transaction'
 and posting_date>date '2026-09-22' and normalized_payload->>'status'='PENDING'
)
select jsonb_build_object('institution_code',p_institution_code,'treatment','provisional_expense_until_provider_update',
'gross_expense',coalesce(sum(case when signed_amount<0 then abs(signed_amount) else 0 end),0),
'credits',coalesce(sum(case when signed_amount>0 then signed_amount else 0 end),0),
'net_expense',coalesce(-sum(signed_amount),0),'transaction_count',count(*),'promotion_enabled',false)
from x
$function$;
GRANT EXECUTE ON FUNCTION public.lts_open_finance_card_pending_v1(text),public.lts_open_finance_pending_card_expense_v1(text) TO service_role;
