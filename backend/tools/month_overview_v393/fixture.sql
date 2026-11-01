-- Invented data, disposable PostgreSQL only; no JWT or app login is created.
CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE SCHEMA qa;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,institution_code text);
CREATE TABLE qa.expense(user_id uuid,row_key text,event_date date,transaction_date date,competence_month date,
 amount numeric,category text,description text,account_source text,source_table text,source_ref text,coverage_mode text,purchase_date date);
CREATE TABLE qa.flow(user_id uuid,payload jsonb);
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE plpgsql AS $$
BEGIN IF nullif(current_setting('qa.owner',true),'') IS NULL THEN RAISE EXCEPTION 'No fixture owner';END IF;
RETURN current_setting('qa.owner')::uuid;END $$;
CREATE FUNCTION public.lts_card_read_start_v269(uuid) RETURNS text LANGUAGE sql AS $$SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT $3||jsonb_build_object('source_complete',true,'source_epoch',1)$$;
CREATE FUNCTION public.lts_prepared_card_cycles_v307(uuid) RETURNS jsonb LANGUAGE sql AS $$SELECT '{"cards":[]}'::jsonb$$;
CREATE FUNCTION public.lts_browser_flow_v242(p_from date,p_to date) RETURNS jsonb LANGUAGE plpgsql AS $$
DECLARE j jsonb;BEGIN SELECT payload INTO j FROM qa.flow WHERE user_id=public.lts_browser_assert_user_v1();
 IF current_setting('qa.drift',true)='yes' THEN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;END IF;
 RETURN jsonb_set(jsonb_set(j,'{flow,from}',to_jsonb(p_from::text)),'{flow,to}',to_jsonb(p_to::text));END $$;
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)
RETURNS SETOF qa.expense LANGUAGE sql AS $$SELECT * FROM qa.expense WHERE user_id=p_user_id AND event_date BETWEEN p_from AND p_to$$;
INSERT INTO qa.expense VALUES
 ('00000000-0000-4000-8000-000000000001','purchase-a','2026-11-01','2026-10-19','2026-11-01',101.23,'Teste','Compra fictícia A','Cartão fictício A','fixture','a','card_observed_pending','2026-10-19'),
 ('00000000-0000-4000-8000-000000000001','purchase-b','2026-11-01','2026-10-26','2026-11-01',202.34,'Teste','Compra fictícia B','Cartão fictício B','fixture','b','card_observed_documented','2026-10-26'),
 ('00000000-0000-4000-8000-000000000002','other-owner','2026-11-01','2026-10-12','2026-11-01',987.65,'Teste','Outro titular fictício','Outro cartão','fixture','other','card_observed_pending','2026-10-12');
INSERT INTO qa.flow VALUES('00000000-0000-4000-8000-000000000001',jsonb_build_object('flow',jsonb_build_object('from','2026-11-01','to','2026-11-30','historical',jsonb_build_object('events','[]'::jsonb),'current_future',jsonb_build_object('events',jsonb_build_array(
 jsonb_build_object('source','current_event','source_ref','salary','event_date','2026-11-10','account','Itaú','signed_amount',1100,'description','Receita fictícia','confidence','legacy_projection_adjusted'),
 jsonb_build_object('source','card_invoice','source_ref','invoice','event_date','2026-11-05','account','C6','signed_amount',-200,'description','Fatura fictícia','confidence','documented_closed'),
 jsonb_build_object('source','current_event','source_ref','rent','event_date','2026-11-20','account','Bradesco','signed_amount',-300,'description','Pagamento fictício','confidence','user_flow_editable'),
 jsonb_build_object('source','internal_transfer','source_ref','transfer-out','event_date','2026-11-04','account','Itaú','signed_amount',-1000,'internal_transfer',true),
 jsonb_build_object('source','internal_transfer','source_ref','transfer-in','event_date','2026-11-04','account','C6','signed_amount',1000,'internal_transfer',true),
 jsonb_build_object('source','future_rsu_available','source_ref','vesting','event_date','2026-11-09','account','Corretora','signed_amount',9000,'available_from_vesting',true),
 jsonb_build_object('source','current_event','source_ref','next-month','event_date','2026-12-05','account','Itaú','signed_amount',-800),
 jsonb_build_object('source','economic_withholding','source_ref','payroll-withheld','event_date','2026-11-01','account','Itaú','signed_amount',-70,'confidence','validated_contract','description','Retenção fictícia já abatida do salário líquido')
)))));
INSERT INTO qa.flow VALUES('00000000-0000-4000-8000-000000000002',jsonb_build_object('flow',jsonb_build_object('from','2026-11-01','to','2026-11-30','historical',jsonb_build_object('events','[]'::jsonb),'current_future',jsonb_build_object('events',jsonb_build_array(jsonb_build_object('source','current_event','source_ref','other-cash','event_date','2026-11-12','account','C6','signed_amount',-987.65))))));
