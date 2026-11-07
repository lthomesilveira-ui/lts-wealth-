CREATE ROLE anon NOLOGIN;CREATE ROLE authenticated NOLOGIN;CREATE ROLE service_role NOLOGIN;
CREATE OR REPLACE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$DECLARE u uuid:=nullif(current_setting('qa.owner',true),'')::uuid;BEGIN IF u IS NULL THEN RAISE EXCEPTION 'Authentication required';END IF;RETURN u;END$$;
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,connection_id uuid,resource_type text,provider_record_id text,provider_account_ref text,institution_name text,provider_deleted_at timestamptz,normalized_payload jsonb,posting_date date,signed_amount numeric,description_raw text);
INSERT INTO public.lts_open_finance_staging
SELECT ('00000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'00000000-0000-4000-8000-000000000001',
 '00000000-0000-4000-8000-000000000099',CASE WHEN i=1 THEN 'account' ELSE 'transaction' END,'record-'||i,'example-account','Banco fictício',NULL,
 jsonb_build_object('account_type','CHECKING_ACCOUNT','as_of',(current_date-1)::text||'T18:00:00Z','source_sync_at',CASE WHEN i=4 THEN 'previous-snapshot' ELSE 'current-snapshot' END,'layer','bank_cash','status',CASE WHEN i=5 THEN 'POSTED' ELSE 'PENDING' END),
 CASE WHEN i=1 THEN NULL ELSE current_date-1 END,
 CASE i WHEN 1 THEN 980.50 WHEN 2 THEN -20 WHEN 3 THEN .50 ELSE -20 END,
 CASE i WHEN 1 THEN 'Banco fictício' WHEN 2 THEN 'Parcela de exemplo' WHEN 3 THEN 'Rendimento de exemplo' ELSE 'Registro excluído do recorte' END
FROM generate_series(1,5)i;
INSERT INTO public.lts_open_finance_staging SELECT '00000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000002',connection_id,resource_type,'other-owner',provider_account_ref,institution_name,provider_deleted_at,normalized_payload,posting_date,-999,'Other owner must not leak' FROM public.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000002';
CREATE TABLE public.qa_before AS SELECT md5(string_agg(to_jsonb(s)::text,'' ORDER BY id)) AS source_hash FROM public.lts_open_finance_staging s;
