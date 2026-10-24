-- Isolated synthetic data only. The partial-obligation dependency is explicitly a double.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated;END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role;END IF;
END $$;
CREATE TABLE public.accounts(id uuid PRIMARY KEY,user_id uuid,institution text);
CREATE TABLE public.financial_events(id uuid PRIMARY KEY,user_id uuid,account_id uuid,event_date date,amount numeric,
 description_raw text,legacy_id text,metadata jsonb,is_projection boolean,is_suppressed boolean,is_internal_transfer boolean,nature text,status text);
CREATE TABLE public.lts_open_finance_staging(id uuid PRIMARY KEY,user_id uuid,posting_date date,signed_amount numeric,
 currency text,resource_type text,provider_deleted_at timestamptz,normalized_payload jsonb,institution_code text,description_raw text);
CREATE TABLE public.lts_realized_bank_event_v238(user_id uuid,financial_event_id uuid,staging_id uuid,bank text,
 expected_date date,expected_amount numeric,category text,beneficiary text,property_code text,management_group text,
 management_subgroup text,property_component text,evidence jsonb);
CREATE TABLE public.lts_commitment_documentary_schedule(id uuid PRIMARY KEY,user_id uuid,commitment_id text,installment_number integer,
 due_date date,amount_total numeric,principal numeric,interest numeric,balance_after numeric,status text,paid_date date,paid_amount numeric,metadata jsonb);
CREATE TABLE public.lts_debt_position(id uuid PRIMARY KEY,user_id uuid,commitment_id text,as_of_date date,institution text,
 contract_ref text,debt_balance numeric,status text,source_label text,metadata jsonb,created_at timestamptz DEFAULT now());
CREATE TABLE public.evento_base(usuario_id uuid,idx integer,dados jsonb);
INSERT INTO public.evento_base VALUES
 ('00000000-0000-4000-8000-000000000001',1,'{"desc":"Pagamento Empréstimo Pai/Mãe","dia":"2021-01-01","valor":10}'),
 ('00000000-0000-4000-8000-000000000001',2,'{"desc":"Pagamento Empréstimo Pai/Mãe","dia":"2021-02-01","valor":40}');
CREATE FUNCTION public.lts_partial_obligation_settlement_valid_v302(jsonb,jsonb,jsonb,jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE AS $$SELECT false$$;
CREATE FUNCTION public.lts_browser_assert_user_v1() RETURNS uuid LANGUAGE sql AS $$SELECT '00000000-0000-4000-8000-000000000001'::uuid$$;
CREATE FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) RETURNS jsonb LANGUAGE sql AS $$SELECT $3$$;

INSERT INTO public.accounts VALUES('00000000-0000-4000-8000-000000000101','00000000-0000-4000-8000-000000000001','Bradesco');
INSERT INTO public.lts_commitment_documentary_schedule VALUES
 ('00000000-0000-4000-8000-000000000305','00000000-0000-4000-8000-000000000001','cipo_396',5,'2020-09-20',90,30,60,900,'paid','2020-09-21',99,'{"contract_ref":"SYNTHETIC-MORTGAGE"}'),
 ('00000000-0000-4000-8000-000000000306','00000000-0000-4000-8000-000000000001','cipo_396',6,'2020-10-20',80,30,50,870,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-MORTGAGE"}'),
 ('00000000-0000-4000-8000-000000000307','00000000-0000-4000-8000-000000000001','cipo_396',7,'2020-11-20',70,30,40,840,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-MORTGAGE"}'),
 ('00000000-0000-4000-8000-000000000308','00000000-0000-4000-8000-000000000001','cipo_396',8,'2020-12-20',60,30,30,810,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-MORTGAGE"}'),
 ('00000000-0000-4000-8000-000000000401','00000000-0000-4000-8000-000000000001','coopharma',1,'2020-08-31',10,8,2,32,'paid','2020-08-31',10,'{"contract_ref":"SYNTHETIC-PAYROLL"}'),
 ('00000000-0000-4000-8000-000000000402','00000000-0000-4000-8000-000000000001','coopharma',2,'2020-09-30',20,8,12,24,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-PAYROLL"}'),
 ('00000000-0000-4000-8000-000000000403','00000000-0000-4000-8000-000000000001','coopharma',3,'2020-10-31',30,8,22,16,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-PAYROLL"}'),
 ('00000000-0000-4000-8000-000000000404','00000000-0000-4000-8000-000000000001','coopharma',4,'2020-11-30',40,8,32,8,'scheduled',null,null,'{"contract_ref":"SYNTHETIC-PAYROLL"}');
INSERT INTO public.financial_events VALUES
 ('00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','2020-10-20',-88,'Synthetic mortgage','synthetic-mortgage-6','{"contract_ref":"SYNTHETIC-MORTGAGE","installment_number":6,"documentary_schedule_due_date":"2020-10-20","documentary_schedule_amount":80}',false,false,false,'expense','confirmed'),
 ('00000000-0000-4000-8000-000000000501','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','2020-09-05',-15,'Synthetic vehicle','synthetic-vehicle-1','{"contract_ref":"volvo_financing_2026","installment_number":1}',true,false,false,'expense','scheduled'),
 ('00000000-0000-4000-8000-000000000502','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','2020-10-06',-25,'Synthetic vehicle','synthetic-vehicle-2','{"contract_ref":"volvo_financing_2026","installment_number":2,"documentary_schedule_due_date":"2020-10-05","documentary_schedule_amount":25}',false,false,false,'expense','confirmed'),
 ('00000000-0000-4000-8000-000000000503','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000101','2020-11-05',-35,'Synthetic vehicle','synthetic-vehicle-3','{"contract_ref":"volvo_financing_2026","installment_number":3}',true,false,false,'expense','scheduled');
INSERT INTO public.lts_open_finance_staging VALUES
 ('00000000-0000-4000-8000-000000000606','00000000-0000-4000-8000-000000000001','2020-10-20',-88,'BRL','transaction',null,'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','237','Payment SYNTHETIC-MORTGAGE'),
 ('00000000-0000-4000-8000-000000000602','00000000-0000-4000-8000-000000000001','2020-10-06',-25,'BRL','transaction',null,'{"status":"POSTED","account_type":"CHECKING_ACCOUNT"}','237','Payment volvo_financing_2026');
INSERT INTO public.lts_realized_bank_event_v238(user_id,financial_event_id,staging_id,bank,expected_date,expected_amount,evidence) VALUES
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000206','00000000-0000-4000-8000-000000000606','Bradesco','2020-10-20',-88,'{"contract_ref":"SYNTHETIC-MORTGAGE"}'),
 ('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000502','00000000-0000-4000-8000-000000000602','Bradesco','2020-10-06',-25,'{"contract_ref":"volvo_financing_2026"}');
INSERT INTO public.lts_debt_position VALUES
 ('00000000-0000-4000-8000-000000000701','00000000-0000-4000-8000-000000000001','cipo_396','2020-08-26','Bradesco','SYNTHETIC-MORTGAGE',1000,'documented','Older synthetic statement','{"remaining_installments":4,"installment_paid_through":4,"remaining_schedule_current_terms":300,"final_due":"2020-12-20"}',now()),
 ('00000000-0000-4000-8000-000000000702','00000000-0000-4000-8000-000000000001','cipo_396','2020-09-02','Bradesco','SYNTHETIC-MORTGAGE',900,'documented','Dated synthetic statement','{"remaining_installments":4,"installment_paid_through":4,"remaining_schedule_current_terms":300,"final_due":"2020-12-20"}',now()),
 ('00000000-0000-4000-8000-000000000703','00000000-0000-4000-8000-000000000001','cipo_396','2020-11-01','Bradesco','SYNTHETIC-MORTGAGE',800,'documented','Future synthetic statement','{"remaining_installments":2,"installment_paid_through":6,"remaining_schedule_current_terms":130,"final_due":"2020-12-20"}',now()),
 ('00000000-0000-4000-8000-000000000704','00000000-0000-4000-8000-000000000001','coopharma','2020-08-27','Coopharma','SYNTHETIC-PAYROLL',null,'documented_schedule_only','Synthetic payroll schedule','{"paid_installments":0,"remaining_installments":4}',now());

CREATE FUNCTION public.lts_commitments_summary_v1(p_user_id uuid,p_as_of date DEFAULT CURRENT_DATE)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path='public' AS $function$
SELECT jsonb_build_object('version','synthetic-summary','as_of',p_as_of,'commitments',jsonb_build_array(
 jsonb_build_object('id','cipo_396','label','CIPÓ 396','remaining_events',4,'remaining_scheduled_outflow_current_terms',300,'current_documentary_debt_balance',800,'current_debt_as_of','2020-11-01','next_due','2020-09-20','next_amount',90,'total_events',8),
 jsonb_build_object('id','coopharma','label','Empréstimo Coopharma','remaining_events',2,'remaining_economic_outflow',70,'next_due','2020-08-31','next_amount',10),
 jsonb_build_object('id','volvo','label','Financiamento Volvo XC40','total_events',3,'remaining_events',1,'remaining_scheduled_outflow',35),
 jsonb_build_object('id','pai_mae','label','Empréstimo Pai e Mãe','total_events',1,'remaining_events',1,'remaining_scheduled_outflow',50)
));
$function$;
CREATE FUNCTION public.lts_documentary_commitments_v1(p_user_id uuid) RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='public' AS $function$
SELECT jsonb_build_object('items',coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('schedule_loaded',jsonb_build_object('remaining_loaded',99,'next_date','2020-09-20','future_loaded_total',999,'rows','[]'::jsonb)) ORDER BY as_of_date DESC),'[]'::jsonb))
FROM public.lts_debt_position p WHERE user_id=p_user_id;
$function$;
CREATE FUNCTION public.lts_browser_wealth_detail_v242() RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1();j jsonb;
BEGIN
 j:=jsonb_build_object('financing',jsonb_build_object('summary',public.lts_commitments_summary_v1(u,'2020-10-24'),'documentary',public.lts_documentary_commitments_v1(u)),
 'commitments',jsonb_build_object('stale',true),'documentary_commitments',jsonb_build_object('stale',true),
 'cipo_detail',jsonb_build_object('contractual_outflow_current_terms_brl',300),'wealth',jsonb_build_object('summary',jsonb_build_object('known_debt_total',900),'cash',12.34),'rsu_summary',jsonb_build_object('value',56.78));
 RETURN public.lts_card_read_finish_v269(u,'synthetic',j);
END
$function$;
REVOKE ALL ON FUNCTION public.lts_commitments_summary_v1(uuid,date),public.lts_documentary_commitments_v1(uuid),public.lts_browser_wealth_detail_v242() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_commitments_summary_v1(uuid,date),public.lts_documentary_commitments_v1(uuid),public.lts_browser_wealth_detail_v242() TO service_role;
GRANT EXECUTE ON FUNCTION public.lts_browser_wealth_detail_v242() TO authenticated;
