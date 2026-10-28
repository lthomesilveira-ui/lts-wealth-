"""Execute leased production bodies; freeze only the clock in the isolated fixture."""
from pathlib import Path
R = Path(__file__).resolve().parents[2]
clock = "(DATE '2026-10-27')"
print(r"""
BEGIN;
SET LOCAL TIME ZONE 'America/Sao_Paulo';
CREATE SCHEMA auth;
CREATE TABLE auth.users(id uuid PRIMARY KEY);
INSERT INTO auth.users VALUES('00000000-0000-4000-8000-000000000001'),('00000000-0000-4000-8000-000000000002');
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$SELECT nullif(current_setting('test.owner',true),'')::uuid$$;
GRANT USAGE ON SCHEMA auth TO authenticated;
GRANT EXECUTE ON FUNCTION auth.uid() TO authenticated;
CREATE TABLE public.lts_card_due_rule_v290(user_id uuid,family text,effective_from date,due_day int,confirmed_at timestamptz DEFAULT now(),PRIMARY KEY(user_id,family,effective_from));
INSERT INTO public.lts_card_due_rule_v290(user_id,family,effective_from,due_day) VALUES
('00000000-0000-4000-8000-000000000001','aeternum','2026-12-01',3),
('00000000-0000-4000-8000-000000000001','itau_mastercard','2026-11-01',16);
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,currency text,institution_code text,provider_account_ref text,raw_payload jsonb,normalized_payload jsonb);
CREATE TABLE public.v370_sources(user_id uuid,family text,source_id uuid,provider_status text,is_payment boolean,total_installments int,installment_number int,purchase_date date,last4 text,reference_month date,description text,amount numeric,bill_id text,observed_at timestamptz,category_basis text);
CREATE FUNCTION public.lts_card_source_rows_v226(uuid) RETURNS SETOF public.v370_sources LANGUAGE sql AS $$SELECT * FROM public.v370_sources WHERE user_id=$1$$;
CREATE FUNCTION public.lts_card_merchant_key_v226(text) RETURNS text LANGUAGE sql AS $$SELECT lower($1)$$;
CREATE FUNCTION public.lts_card_family_v226(text,text) RETURNS text LANGUAGE sql AS $$SELECT CASE WHEN concat($1,$2)ILIKE '%aeternum%'THEN'aeternum'WHEN concat($1,$2)ILIKE'%itau%'THEN'itau_mastercard'ELSE'c6'END$$;
CREATE TABLE public.v370_bills(user_id uuid,family text,card_name text,last4 text,reference_month date,due_date date,amount numeric,invoice_source_id uuid);
CREATE FUNCTION public.lts_current_received_card_bills_v263(uuid) RETURNS SETOF public.v370_bills LANGUAGE sql AS $$SELECT * FROM public.v370_bills WHERE user_id=$1$$;
CREATE TABLE public.card_invoices(id uuid,user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text,metadata jsonb);
CREATE TABLE public.v370_base_invoices(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text);
CREATE FUNCTION public.lts_card_invoice_amounts_v230_engine_v243(uuid) RETURNS SETOF public.v370_base_invoices LANGUAGE sql AS $$SELECT * FROM public.v370_base_invoices WHERE user_id=$1$$;
CREATE FUNCTION public.lts_card_invoice_settled_v290(uuid,text,date,date,numeric) RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE FUNCTION public.lts_card_due_rule_changed_v290()RETURNS trigger LANGUAGE plpgsql AS $$BEGIN UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;RETURN NULL;END$$;
CREATE TABLE public.lts_v229_read_cache(user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,source_fingerprint text,refreshed_at timestamptz,UNIQUE(user_id,kind,as_of,from_date,to_date));
CREATE TABLE public.v370_flow_rows(user_id uuid,event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index int,original_date date,displaced boolean);
CREATE FUNCTION public.lts_corrected_cashflow_fix86_v4(uuid,date,date)RETURNS TABLE(event_date date,account text,description text,signed_amount numeric,source text,source_ref text,confidence text,account_assignment text,legacy_index int,original_date date,displaced boolean)LANGUAGE sql AS $$SELECT event_date,account,description,signed_amount,source,source_ref,confidence,account_assignment,legacy_index,original_date,displaced FROM public.v370_flow_rows WHERE user_id=$1 AND event_date BETWEEN $2 AND $3$$;
INSERT INTO public.v370_bills VALUES('00000000-0000-4000-8000-000000000001','aeternum','Visa Aeternum','0000','2026-10-01','2026-10-25',300,'10000000-0000-4000-8000-000000000001');
INSERT INTO public.lts_open_finance_staging VALUES('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','invoice',null,'BRL','synthetic','account-a','{}','{"provider_id":"bill-oct"}');
INSERT INTO public.v370_sources VALUES
('00000000-0000-4000-8000-000000000001','aeternum','20000000-0000-4000-8000-000000000001','POSTED',false,3,1,'2026-09-01','0000','2026-10-01','Synthetic A',100,'bill-oct','2026-10-27T12:00:00Z','confirmed'),
('00000000-0000-4000-8000-000000000001','aeternum','20000000-0000-4000-8000-000000000002','POSTED',false,2,1,'2026-09-02','0000','2026-10-01','Synthetic B',200,'bill-oct','2026-10-27T12:00:00Z','confirmed'),
('00000000-0000-4000-8000-000000000001','aeternum','20000000-0000-4000-8000-000000000003','PENDING',false,2,1,'2026-10-20','0000','2026-11-01','Synthetic C',50,null,'2026-10-27T12:00:00Z','unresolved');
INSERT INTO public.lts_open_finance_staging SELECT source_id,user_id,'card_transaction',null,'BRL','synthetic','account-a',jsonb_build_object('creditCardMetadata',jsonb_build_object('purchaseDate',purchase_date)),'{}'FROM public.v370_sources;
INSERT INTO public.card_invoices VALUES(null,'00000000-0000-4000-8000-000000000001','Visa Aeternum','2026-10-01','2026-10-25','open',300,'synthetic','{}');
INSERT INTO public.v370_base_invoices VALUES('00000000-0000-4000-8000-000000000001','Visa Aeternum','2026-10-01','2026-10-25','open',300,'synthetic'),('00000000-0000-4000-8000-000000000001','Visa Aeternum','2026-11-01','2026-11-25','projected',350,'legacy');
INSERT INTO public.v370_flow_rows SELECT '00000000-0000-4000-8000-000000000001',d,'Bradesco','Visa Aeternum',-v,'legacy_fix86','legacy:'||i,'legacy_projection_adjusted','assigned',i,d,false FROM(VALUES(1,DATE'2026-10-25',10),(2,DATE'2026-11-25',20),(3,DATE'2026-12-25',30),(4,DATE'2027-01-25',40))a(i,d,v);
INSERT INTO public.v370_flow_rows VALUES
('00000000-0000-4000-8000-000000000001','2026-11-16','Itaú','Itau Mastercard',-50,'card_invoice','Itau Mastercard|2026-11','documented_open','assigned',null,'2026-11-16',false),
('00000000-0000-4000-8000-000000000002','2026-11-25','Bradesco','Visa Aeternum',-60,'legacy_fix86','other-owner','legacy_projection_adjusted','assigned',10,'2026-11-25',false),
('00000000-0000-4000-8000-000000000001','2026-11-26','Bradesco','Visa Aeternum',-70,'current_event','bank-posted','bank_documented_settlement_precedence','assigned',null,'2026-11-26',false);
""")
names = ['lts_aeternum_forecast_cycles_v311','lts_card_due_overlay_v290','lts_card_projection_rows_v290','lts_corrected_cashflow_fix86_v5','lts_card_invoice_amounts_v230']
for name in names:
    print((R/f'backend/qa/fixtures/v370/{name}.sql').read_text().replace('current_date',clock)+';')
print("CREATE TEMP TABLE v370_attributes AS SELECT proname,to_jsonb(p)-'prosrc' attributes FROM pg_proc p WHERE pronamespace='public'::regnamespace AND proname IN("+','.join("'"+n+"'" for n in names)+");")
print(r"""
CREATE TEMP TABLE v370_raw AS SELECT jsonb_build_object('sources',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_id)FROM public.v370_sources r),'staging',(SELECT jsonb_agg(to_jsonb(r)ORDER BY id)FROM public.lts_open_finance_staging r),'invoices',(SELECT jsonb_agg(to_jsonb(r))FROM public.card_invoices r),'flow',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_ref)FROM public.v370_flow_rows r))data;
""")
patch = (R/'backend/patches/v370/aeternum_cycle_transition.sql').read_text().replace('current_date',clock)
patch = patch.replace('md5(definition)',"md5(replace(definition,'(DATE ''2026-10-27'')','current_date'))")
print(patch)
print(r"""
INSERT INTO public.lts_card_due_transition_v370(user_id,family,last_old_due,first_new_due,decision_source)VALUES('00000000-0000-4000-8000-000000000001','aeternum','2026-10-25','2026-12-03','synthetic-confirmed');
DO $test$DECLARE u uuid:='00000000-0000-4000-8000-000000000001';d date;a jsonb;b jsonb;j jsonb;BEGIN
 IF(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>2 THEN RAISE EXCEPTION 'Transition did not invalidate reads';END IF;
 IF public.lts_card_projection_date_v370(u,'aeternum','2026-11-01','2026-11-25','2026-10-25')<>'2026-12-03'OR public.lts_card_projection_date_v370(u,'aeternum','2026-12-01','2026-12-25','2026-10-25')<>'2027-01-03'THEN RAISE EXCEPTION 'Cycle was not advanced';END IF;
 IF public.lts_card_projection_date_v370(u,'aeternum','2027-01-01','2027-01-25','2026-12-03')<>'2027-01-03'T HEN RAISE EXCEPTION 'New bank calendar shifted twice';END IF;
 IF(SELECT count(*)FROM public.lts_aeternum_forecast_cycles_v311(u)WHERE reference_month='2026-11-01'AND due_date='2026-12-03'AND amount=350 AND item_count=3)<>1 THEN RAISE EXCEPTION 'November composition was lost or duplicated';END IF;
 IF(SELECT count(*)FROM public.lts_aeternum_forecast_cycles_v311(u)WHERE reference_month='2026-12-01'AND due_date='2027-01-03'AND amount=150 AND item_count=2)<>1 THEN RAISE EXCEPTION 'Following installments changed';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(u)WHERE due_date BETWEEN '2026-11-01'AND'2026-11-30') OR(SELECT count(*)FROM public.lts_card_projection_rows_v290(u)WHERE due_date='2026-12-03')<>1 THEN RAISE EXCEPTION 'Projection date duplicated';END IF;
 IF(SELECT count(*)FROM public.lts_card_invoice_amounts_v230(u)WHERE due_date='2026-12-03'AND amount=350)<>1 THEN RAISE EXCEPTION 'Shared invoice amount/date diverged';END IF;
 IF(SELECT event_date FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-12-03','2026-12-03')WHERE source_ref='legacy:2')<>'2026-12-03' THEN RAISE EXCEPTION 'Narrow-range move missing';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-11-01','2026-11-30')WHERE source='legacy_fix86')THEN RAISE EXCEPTION 'November legacy debit remains';END IF;
 IF(SELECT event_date FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-10-01','2027-02-28')WHERE source_ref='legacy:1')<>'2026-10-25'OR(SELECT event_date FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-10-01','2027-02-28')WHERE source_ref='Itau Mastercard|2026-11')<>'2026-11-16'OR(SELECT event_date FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-10-01','2027-02-28')WHERE source_ref='bank-posted')<>'2026-11-26'THEN RAISE EXCEPTION 'History, Itaú or real bank movement changed';END IF;
 IF(SELECT event_date FROM public.lts_corrected_cashflow_fix86_v5('00000000-0000-4000-8000-000000000002','2026-11-01','2027-01-31'))<>'2026-11-25'THEN RAISE EXCEPTION 'Other owner changed';END IF;
 FOR d IN SELECT generate_series('2026-11-01'::date,'2027-02-01'::date,'1 day')::date LOOP
  SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY source_ref),'[]')INTO a FROM public.lts_corrected_cashflow_fix86_v5(u,d,d)x;
  SELECT coalesce(jsonb_agg(to_jsonb(x)ORDER BY source_ref),'[]')INTO b FROM public.lts_corrected_cashflow_fix86_v5(u,'2026-10-01','2027-03-01')x WHERE event_date=d;
  IF a IS DISTINCT FROM b THEN RAISE EXCEPTION 'Full/slice mismatch:%',d;END IF;
 END LOOP;
 j:=public.lts_card_due_overlay_v290(u,'{"cards":[{"family":"aeternum","cycles":[{"month":"2026-10-01","due_date":"2026-10-25","amount":300,"invoice_source_id":"old","basis":"open_finance_invoice_v263"},{"month":"2026-11-01","due_date":"2026-11-25","amount":350,"basis":"received_and_projected_installments","projection_only":true},{"month":"2026-12-01","due_date":"2026-12-25","amount":150,"basis":"derived_current_installments","projection_only":true}]},{"family":"itau_mastercard","cycles":[{"month":"2026-11-01","due_date":"2026-11-16","amount":90}]}]}');
 IF j#>>'{cards,0,cycles,1,due_date}'<>'2026-12-03'OR j#>>'{cards,0,cycles,2,due_date}'<>'2027-01-03'OR j#>>'{cards,1,cycles,0,due_date}'<>'2026-11-16'THEN RAISE EXCEPTION 'Card overlay calendar differs';END IF;
 IF EXISTS(SELECT 1 FROM v370_attributes a JOIN pg_proc p ON p.proname=a.proname AND p.pronamespace='public'::regnamespace WHERE a.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc')THEN RAISE EXCEPTION 'Existing function attributes changed';END IF;
 IF(SELECT data FROM v370_raw)IS DISTINCT FROM jsonb_build_object('sources',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_id)FROM public.v370_sources r),'staging',(SELECT jsonb_agg(to_jsonb(r)ORDER BY id)FROM public.lts_open_finance_staging r),'invoices',(SELECT jsonb_agg(to_jsonb(r))FROM public.card_invoices r),'flow',(SELECT jsonb_agg(to_jsonb(r)ORDER BY source_ref)FROM public.v370_flow_rows r))THEN RAISE EXCEPTION 'Raw sources mutated';END IF;
END $test$;
-- The provider now returns the first bill on the new calendar. Its date wins,
-- and installments continue once in January without another month displacement.
INSERT INTO public.v370_bills VALUES('00000000-0000-4000-8000-000000000001','aeternum','Visa Aeternum','0000','2026-12-01','2026-12-03',350,'10000000-0000-4000-8000-000000000002');
INSERT INTO public.lts_open_finance_staging VALUES('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','invoice',null,'BRL','synthetic','account-a','{}','{"provider_id":"bill-dec"}');
INSERT INTO public.v370_sources SELECT user_id,family,CASE WHEN description='Synthetic A'THEN'30000000-0000-4000-8000-000000000001'::uuid WHEN description='Synthetic B'THEN'30000000-0000-4000-8000-000000000002'::uuid ELSE'30000000-0000-4000-8000-000000000003'::uuid END,'POSTED',false,total_installments,CASE WHEN description='Synthetic C'THEN 1 ELSE 2 END,purchase_date,last4,'2026-12-01',description,amount,'bill-dec',observed_at,category_basis FROM public.v370_sources;
INSERT INTO public.lts_open_finance_staging SELECT source_id,user_id,'card_transaction',null,'BRL','synthetic','account-a',jsonb_build_object('creditCardMetadata',jsonb_build_object('purchaseDate',purchase_date)),'{}'FROM public.v370_sources WHERE bill_id='bill-dec';
INSERT INTO public.v370_base_invoices VALUES('00000000-0000-4000-8000-000000000001','Visa Aeternum','2026-12-01','2026-12-03','open',350,'received');
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
DO $test$DECLARE u uuid:='00000000-0000-4000-8000-000000000001';j jsonb;BEGIN
 IF(SELECT count(*)FROM public.lts_aeternum_forecast_cycles_v311(u)WHERE due_date='2027-01-03'AND amount=150)<>1 OR EXISTS(SELECT 1 FROM public.lts_aeternum_forecast_cycles_v311(u)WHERE due_date='2027-02-03')THEN RAISE EXCEPTION 'Provider update shifted next installment twice';END IF;
 IF(SELECT count(*)FROM public.lts_card_invoice_amounts_v230(u)WHERE due_date='2026-12-03')<>1 THEN RAISE EXCEPTION 'Official bill duplicated by old cycle';END IF;
 j:=public.lts_card_due_overlay_v290(u,'{"cards":[{"family":"aeternum","cycles":[{"month":"2026-10-01","due_date":"2026-10-25","amount":300,"invoice_source_id":"old","basis":"open_finance_invoice_v263"},{"month":"2026-11-01","due_date":"2026-11-25","amount":350,"projection_only":true},{"month":"2026-12-01","due_date":"2026-12-03","amount":350,"invoice_source_id":"new","basis":"open_finance_invoice_v263"},{"month":"2027-01-01","due_date":"2027-01-03","amount":150,"basis":"derived_current_installments","projection_only":true}]}]}');
 IF jsonb_array_length(j#>'{cards,0,cycles}')<>3 OR(SELECT count(*)FROM jsonb_array_elements(j#>'{cards,0,cycles}')c WHERE c->>'due_date'='2026-12-03')<>1 THEN RAISE EXCEPTION 'Official card cycle duplicate remains';END IF;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.proname LIKE '%v370'AND p.prosecdef)THEN RAISE EXCEPTION 'New security definer';END IF;
 IF has_function_privilege('anon','public.lts_card_projection_date_v370(uuid,text,date,date,date)','EXECUTE')OR has_function_privilege('authenticated','public.lts_card_projection_date_v370(uuid,text,date,date,date)','EXECUTE')THEN RAISE EXCEPTION 'Helper exposed';END IF;
END $test$;
SELECT set_config('test.owner','00000000-0000-4000-8000-000000000001',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN IF(SELECT count(*)FROM public.lts_card_due_transition_v370)<>1 THEN RAISE EXCEPTION 'Owner policy failed';END IF;END$$;
RESET ROLE;
SELECT set_config('test.owner','00000000-0000-4000-8000-000000000002',true);
SET LOCAL ROLE authenticated;
DO $$BEGIN IF EXISTS(SELECT 1 FROM public.lts_card_due_transition_v370)THEN RAISE EXCEPTION 'Other owner can read confirmation';END IF;END$$;
RESET ROLE;
SELECT jsonb_build_object('pass',true,'version',370,'production_functions_executed',5,'no_november_debit',true,'december_first_cycle_once',true,'following_installments_preserved',true,'new_provider_calendar_not_shifted_twice',true,'official_statement_precedence',true,'itau_history_other_owner_preserved',true,'daily_slice_checks',93,'raw_sources_preserved',true,'function_attributes_preserved',true,'rls_owner_isolation',true,'clock','controlled2026-10-27');
ROLLBACK;
""".replace('T HEN','THEN'))
