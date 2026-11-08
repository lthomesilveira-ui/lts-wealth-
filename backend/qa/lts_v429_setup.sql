CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role;

CREATE TABLE public.card_invoices(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,card_name text NOT NULL,reference_month date NOT NULL,
 due_date date NOT NULL,amount numeric NOT NULL,status text,source text
);
CREATE TABLE public.lts_fact_confirmation(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,source_ref text NOT NULL,event_date date NOT NULL,
 account text,signed_amount numeric,confirmation_source text,note text,confirmed_at timestamptz
);
CREATE TABLE public.lts_card_documentary_payment_link_v272(
 user_id uuid NOT NULL,invoice_source_id uuid NOT NULL,payment_source_id uuid NOT NULL,
 expected_amount numeric NOT NULL,expected_due_date date NOT NULL,expected_payment_date date NOT NULL,active boolean NOT NULL
);
CREATE TABLE public.lts_card_settlement_expense_contract_v273(
 user_id uuid NOT NULL,payment_source_id uuid NOT NULL,active boolean NOT NULL,payload jsonb NOT NULL
);
CREATE TABLE public.lts_open_finance_staging(
 id uuid PRIMARY KEY,user_id uuid NOT NULL,normalized_payload jsonb NOT NULL,institution_name text
);
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint NOT NULL);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);

CREATE FUNCTION public.lts_card_family_v226(p_name text,p_institution text)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT split_part(lower(coalesce(nullif(trim(p_name),''),p_institution)),'-',1)
$$;
CREATE FUNCTION public.lts_card_payment_refresh_annotation_v273(
 p_user_id uuid,p_link jsonb,p_invoice jsonb,p_payment jsonb,p_contract jsonb,p_as_of date)
RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$
 SELECT CASE WHEN p_contract->>'valid'='true' THEN jsonb_build_object(
  'status','identified_in_statement','issuer_payment_type',p_contract->>'issuer_payment_type') END
$$;

\ir fixtures/v429/lts_card_invoice_settled_v290.sql
\ir fixtures/v429/lts_card_settlement_overlay_v290.sql
REVOKE ALL ON FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric),
 public.lts_card_settlement_overlay_v290(uuid,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric),
 public.lts_card_settlement_overlay_v290(uuid,jsonb) TO service_role;

DO $$BEGIN
 IF md5(pg_get_functiondef('public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)'::regprocedure))<>'fbcc6cd38b1143fdbb02555ae7611744'
 THEN RAISE EXCEPTION 'V429 invoice fixture drift'; END IF;
 IF md5(pg_get_functiondef('public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure))<>'f08c891bd14405aef28d11782c78a9ef'
 THEN RAISE EXCEPTION 'V429 overlay fixture drift'; END IF;
END$$;

INSERT INTO public.card_invoices VALUES
 ('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','c6-main','2026-11-01','2026-11-05',100,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','c6-main','2026-12-01','2026-12-05',70,'open','synthetic'),
 ('10000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','itau-main','2026-11-01','2026-11-10',50,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','prime-a','2026-11-01','2026-11-12',40,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','prime-b','2026-11-01','2026-11-12',40,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','dup-main','2026-11-01','2026-11-15',30,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000002','c6-main','2026-11-01','2026-11-05',999,'closed','synthetic'),
 ('10000000-0000-4000-8000-000000000008','00000000-0000-4000-8000-000000000001','c6-link','2026-10-01','2026-10-05',80,'closed','synthetic');
INSERT INTO public.lts_fact_confirmation VALUES
 ('20000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','c6-main|2026-11','2026-11-05',NULL,-100,'synthetic_exact',NULL,now()),
 ('20000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','itau-main|2026-11','2026-11-10',NULL,-50,'synthetic_exact',NULL,now()),
 ('20000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','prime-a|2026-11','2026-11-12',NULL,-40,'synthetic_exact',NULL,now()),
 ('20000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','prime-b|2026-11','2026-11-12',NULL,-40,'synthetic_exact',NULL,now()),
 ('20000000-0000-4000-8000-000000000005','00000000-0000-4000-8000-000000000001','dup-main|2026-11','2026-11-15',NULL,-30,'synthetic_exact',NULL,now()),
 ('20000000-0000-4000-8000-000000000006','00000000-0000-4000-8000-000000000001','dup-main|2026-11','2026-11-15',NULL,-30,'synthetic_duplicate',NULL,now()),
 ('20000000-0000-4000-8000-000000000007','00000000-0000-4000-8000-000000000002','c6-main|2026-11','2026-11-05',NULL,-999,'synthetic_foreign',NULL,now());

INSERT INTO public.lts_open_finance_staging VALUES
 ('30000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','{"card_name":"c6-link"}','C6'),
 ('30000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','{}','C6');
INSERT INTO public.lts_card_documentary_payment_link_v272 VALUES
 ('00000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002',80,'2026-10-05','2026-10-05',true);
INSERT INTO public.lts_card_settlement_expense_contract_v273 VALUES
 ('00000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000002',true,'{"valid":true,"issuer_payment_type":"OTHER_PAYMENT"}');

CREATE TABLE v429_sources_before AS
SELECT md5(coalesce(jsonb_agg(to_jsonb(x) ORDER BY to_jsonb(x)::text)::text,'[]')) hash FROM(
 SELECT 'invoice' kind,to_jsonb(i) row FROM public.card_invoices i
 UNION ALL SELECT 'fact',to_jsonb(f) FROM public.lts_fact_confirmation f
 UNION ALL SELECT 'link',to_jsonb(l) FROM public.lts_card_documentary_payment_link_v272 l
 UNION ALL SELECT 'contract',to_jsonb(c) FROM public.lts_card_settlement_expense_contract_v273 c
 UNION ALL SELECT 'staging',to_jsonb(s) FROM public.lts_open_finance_staging s
)x;
CREATE TABLE v429_attrs_before AS SELECT oid,to_jsonb(p)-'prosrc' attrs FROM pg_proc p WHERE oid IN(
 'public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)'::regprocedure,
 'public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure);
