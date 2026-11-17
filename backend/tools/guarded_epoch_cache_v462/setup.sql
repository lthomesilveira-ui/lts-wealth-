CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE SCHEMA lts_product_refresh_private_v415;
CREATE TABLE lts_product_refresh_private_v415.queue(user_id uuid PRIMARY KEY,state text);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid,sync_run_id uuid,last_seen_at timestamptz,updated_at timestamptz,
 raw_hash text,raw_payload jsonb,normalized_payload jsonb,signed_amount numeric,posting_date date,
 currency text,provider_deleted_at timestamptz,resource_type text,institution_code text,
 future_semantic_field jsonb
);
CREATE TABLE public.card_invoices(id uuid PRIMARY KEY,user_id uuid,payload jsonb);
CREATE TABLE public.lts_card_document_supplement_v234(LIKE public.card_invoices INCLUDING ALL);
CREATE TABLE public.lts_card_documentary_payment_link_v272(LIKE public.card_invoices INCLUDING ALL);
CREATE TABLE public.lts_card_settlement_expense_contract_v273(payment_source_id uuid PRIMARY KEY,user_id uuid,payload jsonb);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,refreshed_at timestamptz,source_fingerprint text,PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE FUNCTION public.lts_card_cycles_v226(p_user_id uuid) RETURNS jsonb LANGUAGE plpgsql AS $$
BEGIN
 IF current_setting('lts_test.epoch_race',true)='on' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;END IF;
 RETURN jsonb_build_object('complete',coalesce(current_setting('lts_test.complete',true),'true')::boolean,'incomplete_families',CASE WHEN current_setting('lts_test.complete',true)='false' THEN '["synthetic"]'::jsonb ELSE '[]'::jsonb END);
END $$;
