-- Isolated invented data only. Never execute this fixture in a live project.
CREATE SCHEMA qa_v426;
DO $$BEGIN
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon;END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated;END IF;
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role;END IF;
END$$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,
 payload jsonb,refreshed_at timestamptz,source_fingerprint text,PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE TABLE public.accounts(id uuid,user_id uuid,legacy_id text,institution text,account_name text,
 account_type text,currency text,metadata jsonb);
CREATE TABLE public.lts_card_instruments(id uuid,user_id uuid,issuer text,product_name text,last4 text);
CREATE TABLE public.card_invoices(id uuid,user_id uuid,card_name text,metadata jsonb,due_date date,amount numeric,source text);
CREATE TABLE public.lts_card_purchase_detail(user_id uuid,source_id text,row_id bigint,bank text,card_name text,
 card_final text,purchase_date date,installment_amount numeric,description_raw text,source text);
CREATE TABLE public.asset_positions(id uuid,user_id uuid,metadata jsonb,asset_name text,as_of_date date,value_brl numeric,asset_type text);
CREATE TABLE public.lts_debt_position(id uuid,user_id uuid,institution text,contract_ref text,as_of_date date,debt_balance numeric,status text);
CREATE TYPE qa_v426.cash_row AS(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,
 confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean);
CREATE TYPE qa_v426.history_row AS(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,
 confidence text,account_assignment text,legacy_index integer,original_date date,displaced boolean,internal_transfer boolean,
 category text,counterparty text,center_cost text,excluded_from_spend boolean);
CREATE FUNCTION public.lts_open_finance_pilot_owner_v1() RETURNS uuid LANGUAGE sql IMMUTABLE
 AS $$SELECT '00000000-0000-0000-0000-000000000001'::uuid$$;
CREATE FUNCTION public.lts_current_evidence_position_v1(p_user_id uuid) RETURNS jsonb LANGUAGE sql STABLE
 AS $$SELECT jsonb_build_object('as_of',current_date-1)$$;
CREATE FUNCTION public.lts_corrected_cashflow_fix86_v1_engine_v247(p_user_id uuid,p_from date,p_to date)
 RETURNS SETOF qa_v426.cash_row LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
BEGIN
 PERFORM set_config('qa_v426.engine_calls',(coalesce(nullif(current_setting('qa_v426.engine_calls',true),''),'0')::int+1)::text,true);
 RETURN QUERY SELECT * FROM(VALUES
 (current_date-40,'Synthetic Bank','Invented historical purchase',-17.42::numeric,'legacy_fix86','row-1','synthetic','fixture',1,current_date-40,false),
 (current_date-2,'Synthetic Bank','Invented transfer',5.00::numeric,'current_event','row-2','synthetic','fixture',2,current_date-2,false),
 (current_date,'Synthetic Bank','Invented current movement',-3.10::numeric,'current_event','row-3','synthetic','fixture',3,current_date,false),
 (current_date-3,'Synthetic Bank','Invented displaced row',-7.01::numeric,'legacy_fix86','row-4','synthetic','fixture',4,current_date,true)
 )v WHERE v.column1 BETWEEN p_from AND p_to;
END$$;
-- These are bounded stubs for unavailable historical engines, not certifications
-- of production history. The exact deployed memo readers are installed next.
CREATE FUNCTION public.lts_historical_cash_engine_v243(p_user_id uuid,p_from date,p_to date)
 RETURNS SETOF qa_v426.history_row LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 WITH a AS MATERIALIZED(SELECT * FROM public.lts_corrected_cashflow_fix86_v1(p_user_id,p_from,p_to)),
 b AS MATERIALIZED(SELECT * FROM public.lts_corrected_cashflow_fix86_v1(p_user_id,p_from,p_to))
 SELECT a.*,false,'Synthetic category'::text,'Synthetic party'::text,'Unassigned'::text,false
 FROM a JOIN b USING(source,source_ref)
$$;
CREATE FUNCTION public.lts_historical_effective_cash_v5(p_user_id uuid,p_from date,p_to date)
 RETURNS SETOF qa_v426.history_row LANGUAGE sql SECURITY DEFINER SET search_path='' AS $$
 SELECT * FROM public.lts_historical_effective_cash_v4(p_user_id,p_from,p_to)
$$;
CREATE FUNCTION public.lts_corrected_cashflow_operational_v1(p_user_id uuid,p_from date,p_to date)
 RETURNS SETOF qa_v426.cash_row LANGUAGE sql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $$
 SELECT * FROM public.lts_corrected_cashflow_fix86_v1(p_user_id,p_from,p_to)
$$;
INSERT INTO public.accounts VALUES
 ('10000000-0000-0000-0000-000000000001',public.lts_open_finance_pilot_owner_v1(),'synthetic-1','Synthetic Bank','Synthetic checking','checking','BRL','{"balance":"100.00"}'),
 ('10000000-0000-0000-0000-000000000002','00000000-0000-0000-0000-000000000002','other-user','Other Bank','Other checking','checking','BRL','{"balance":"999.00"}');
INSERT INTO public.lts_card_instruments VALUES('20000000-0000-0000-0000-000000000001',public.lts_open_finance_pilot_owner_v1(),'Synthetic Bank','Synthetic Card','1234');
INSERT INTO public.card_invoices VALUES('30000000-0000-0000-0000-000000000001',public.lts_open_finance_pilot_owner_v1(),'Itaú Synthetic','{}',current_date,42.00,'fixture');
INSERT INTO public.lts_card_purchase_detail VALUES(public.lts_open_finance_pilot_owner_v1(),'synthetic-card',1,'Synthetic Bank','Synthetic Card','1234',current_date-1,4.20,'Synthetic purchase','fixture');
INSERT INTO public.asset_positions VALUES('40000000-0000-0000-0000-000000000001',public.lts_open_finance_pilot_owner_v1(),'{}','Synthetic asset',current_date,500.00,'fixture');
INSERT INTO public.lts_debt_position VALUES('50000000-0000-0000-0000-000000000001',public.lts_open_finance_pilot_owner_v1(),'Synthetic Bank','synthetic-contract',current_date,20.00,'fixture');
CREATE FUNCTION qa_v426.financial_signature() RETURNS text LANGUAGE sql AS $$
 SELECT md5(jsonb_build_array((SELECT jsonb_agg(to_jsonb(t))FROM public.accounts t),
 (SELECT jsonb_agg(to_jsonb(t))FROM public.lts_card_instruments t),(SELECT jsonb_agg(to_jsonb(t))FROM public.card_invoices t),
 (SELECT jsonb_agg(to_jsonb(t))FROM public.lts_card_purchase_detail t),(SELECT jsonb_agg(to_jsonb(t))FROM public.asset_positions t),
 (SELECT jsonb_agg(to_jsonb(t))FROM public.lts_debt_position t))::text)
$$;
GRANT USAGE ON SCHEMA public,qa_v426 TO service_role;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO service_role;
