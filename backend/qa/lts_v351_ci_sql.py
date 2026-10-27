"""Native settlement and actual cash contracts. All source rows are synthetic."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2]
policy=(R/'backend/patches/v351/reviewed_c6_settlement.sql').read_text()
activate=(R/'backend/patches/v351/activate_reviewed_card_cash.sql').read_text()
print(r'''
BEGIN;
CREATE TABLE public.lts_open_finance_staging(id uuid,user_id uuid,resource_type text,institution_code text,institution_name text,provider_record_id text,provider_account_ref text,provider_deleted_at timestamptz,currency text,posting_date date,signed_amount numeric,description_raw text,raw_hash text,normalized_payload jsonb,raw_payload jsonb);
CREATE TABLE public.lts_card_documentary_payment_link_v272(id uuid DEFAULT gen_random_uuid(),user_id uuid,institution_code text,provider_item_id text,invoice_source_id uuid,payment_source_id uuid,invoice_account_ref text,payment_account_ref text,expected_amount numeric,expected_due_date date,expected_closing_date date,expected_payment_date date,invoice_raw_hash text,payment_raw_hash text,documentary_sources jsonb,active boolean,created_at timestamptz DEFAULT now());
CREATE TABLE public.lts_card_settlement_expense_contract_v273(user_id uuid,payment_source_id uuid,payload jsonb,revision text,active boolean);
CREATE TABLE public.lts_reconciliation_evidence(id uuid DEFAULT gen_random_uuid(),user_id uuid,evidence_date date,account text,amount numeric,description text,evidence_type text,source_ref text,status text,metadata jsonb);
CREATE TABLE public.lts_projection_replacement_rule(id text,user_id uuid,source_table text,description_exact text,account_exact text,date_from date,date_to date,action text,replacement_source text,replacement_ref text,reason text,evidence jsonb,active boolean);
CREATE TABLE public.evento_base(usuario_id uuid,idx integer,dados jsonb);
CREATE TABLE public.lts_expense_realized(user_id uuid,source_table text,source_ref text,exclude_from_spend boolean);
CREATE FUNCTION public.lts_v178_norm(text)RETURNS text LANGUAGE sql IMMUTABLE AS $$SELECT lower(translate($1,'ú','u'))$$;
''')
for name in ['v351_cycle_v301.sql','v351_lts_card_payment_refresh_annotation_v273.sql','v351_lts_card_settlement_evidence_valid_v273.sql','v351_lts_card_settlement_overlay_v290.sql']:print((R/'backend/qa/fixtures'/name).read_text()+';')
print("SELECT pg_get_functiondef('public.lts_card_settlement_overlay_v290(uuid,jsonb)'::regprocedure);")
print(policy)
u='00000000-0000-4000-8000-000000000001'
def uid(n):return f'10000000-0000-4000-8000-{n:012d}'
data=[]
for bank,code,inv,pay,amount,due,post,kind in [('C6','336',1,2,100,'2026-02-05','2026-02-05','OTHER_PAYMENT'),('Itaú','341',3,4,150,'2026-02-12','2026-02-14','FULL_PAYMENT'),('Bradesco','237',5,6,5,'2026-02-20','2026-02-21','FULL_PAYMENT')]:
    desc='PGTO FAT CARTAO C6'if inv==1 else'Synthetic '+bank+' card debit'
    issuer={'id':f'issuer-payment-{inv}','paymentDate':due+'T00:00:00.000Z','valueType':kind,'amount':amount,'paymentMode':'DEBIT_ACCOUNT','currencyCode':'BRL'}
    common={'user_id':u,'institution_code':code,'institution_name':bank,'currency':'BRL','provider_deleted_at':None}
    data.append(common|{'id':uid(inv),'resource_type':'invoice','provider_record_id':f'item-{code}:invoice-{inv}','provider_account_ref':f'{code}-card','posting_date':due,'signed_amount':amount,'description_raw':'Synthetic invoice','raw_hash':f'invoice-hash-{inv}','normalized_payload':{'provider_id':f'invoice-{inv}','due_date':due,'closing_date':'2026-01-25'},'raw_payload':{'payments':[issuer],'updatedAt':'2026-02-25T00:00:00.000Z'}})
    data.append(common|{'id':uid(pay),'resource_type':'transaction','provider_record_id':f'item-{code}:payment-{pay}','provider_account_ref':f'{code}-checking','posting_date':post,'signed_amount':-amount,'description_raw':desc,'raw_hash':f'payment-hash-{pay}','normalized_payload':{'status':'POSTED','account_type':'CHECKING_ACCOUNT'},'raw_payload':{'status':'POSTED','description':desc}})
for i,amt,desc,op,cat in [(7,-100,'Synthetic purchase','COMPRA','Shopping'),(8,20,'Inclusao de Pagamento Ciclo Corrente',None,'Transfers'),(9,100,'Pagamento recebido','PAGAMENTO_FATURA','Credit card payment')]:
    data.append({'id':uid(i),'user_id':u,'resource_type':'card_transaction','institution_code':'336','institution_name':'C6','currency':'BRL','provider_account_ref':'336-card','posting_date':'2026-02-01','signed_amount':amt,'description_raw':desc,'raw_hash':f'item-hash-{i}','normalized_payload':{'status':'POSTED'},'raw_payload':{'status':'POSTED','description':desc,'operationType':op,'category':cat,'creditCardMetadata':{'billId':'invoice-1'}}})
data.append({'id':uid(10),'user_id':u,'resource_type':'credit_card','institution_code':'336','provider_account_ref':'336-card'})
print('INSERT INTO public.lts_open_finance_staging SELECT *FROM jsonb_populate_recordset(NULL::public.lts_open_finance_staging,$data$'+json.dumps(data)+'$data$);')
print(r'''
INSERT INTO public.evento_base VALUES('00000000-0000-4000-8000-000000000001',9,'{"dia":"2026-02-12","conta":"Itau","desc":"Mastercard","valor":90,"efeito":"saida"}');
INSERT INTO public.lts_card_documentary_payment_link_v272(user_id,institution_code,provider_item_id,invoice_source_id,payment_source_id,invoice_account_ref,payment_account_ref,expected_amount,expected_due_date,expected_closing_date,expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources,active)
SELECT b.user_id,b.institution_code,split_part(b.provider_record_id,':',1),b.id,p.id,b.provider_account_ref,p.provider_account_ref,b.signed_amount,b.posting_date,'2026-01-25',p.posting_date,b.raw_hash,p.raw_hash,'[{"basis":"synthetic invoice"},{"basis":"synthetic bank"}]',true
FROM public.lts_open_finance_staging b JOIN public.lts_open_finance_staging p ON p.user_id=b.user_id AND p.institution_code=b.institution_code AND p.resource_type='transaction' WHERE b.resource_type='invoice'AND b.institution_code<>'336';
INSERT INTO public.lts_card_settlement_expense_contract_v273 SELECT l.user_id,l.payment_source_id,jsonb_build_object('active',true,'user_id',l.user_id,'amount',l.expected_amount,'invoice_id',l.invoice_source_id,'payment_id',l.payment_source_id,'link_contract',to_jsonb(l)-'created_at','issuer_payments',b.raw_payload->'payments','settlement_manifest',b.raw_payload->'payments','issuer_settlement_policy','one_full_payment_in_cycle_v301','invoice_current_hash',b.raw_hash),'synthetic-existing',true FROM public.lts_card_documentary_payment_link_v272 l JOIN public.lts_open_finance_staging b ON b.id=l.invoice_source_id;
CREATE FUNCTION public.lts_expense_effective_rows_v176(uuid,date,date)RETURNS TABLE(source_table text,source_ref text,amount numeric,competence_month date,coverage_mode text)LANGUAGE sql AS $$SELECT 'lts_open_finance_staging','10000000-0000-4000-8000-000000000007',100::numeric,date '2026-02-01','card_bank_closed_complete'$$;
CREATE FUNCTION public.lts_v229_expense_rows(uuid,date,date)RETURNS TABLE(row_key text,amount numeric)LANGUAGE sql AS $$SELECT 'synthetic-history',100::numeric$$;
CREATE FUNCTION public.lts_flow_future_read_slice_v9(uuid,date,date)RETURNS jsonb LANGUAGE sql AS $$SELECT '{"events":[]}'::jsonb$$;
CREATE FUNCTION public.lts_daily_flow_fix86_v12(p_uid uuid,p_from date,p_to date)RETURNS jsonb LANGUAGE sql AS $$
WITH e AS(
 SELECT jsonb_build_object('source','card_invoice','source_ref','synthetic-c6-forecast','event_date','2026-02-05','account','C6','signed_amount',-100,'description','C6 forecast')j WHERE NOT EXISTS(SELECT 1 FROM public.lts_card_documentary_payment_link_v272 l WHERE l.user_id=p_uid AND l.institution_code='336'AND l.active)
 UNION ALL SELECT jsonb_build_object('source','legacy_fix86','source_ref','evento_base:9','event_date','2026-02-12','account','Itaú','signed_amount',-90,'description','Mastercard')WHERE NOT EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule WHERE user_id=p_uid AND active)
 UNION ALL SELECT jsonb_build_object('source','synthetic-unrelated','source_ref','unrelated','event_date','2026-02-10','account','Itaú','signed_amount',-20,'description','Unrelated')
 UNION ALL SELECT jsonb_build_object('source','reconciliation_evidence','source_ref',id,'event_date',evidence_date,'account',account,'signed_amount',amount,'description',description)FROM public.lts_reconciliation_evidence WHERE user_id=p_uid AND evidence_type='bank_statement'AND metadata->>'cash_effect'='statement_fact_not_new_projection')SELECT jsonb_build_object('events',jsonb_agg(j))FROM e$$;
SELECT set_config('lts.v351_owner','00000000-0000-4000-8000-000000000001',true);
SELECT set_config('lts.v351_manifest',jsonb_build_object('window_from','2026-02-01','window_to','2026-02-28','c6',jsonb_build_object('invoice_id','10000000-0000-4000-8000-000000000001','payment_id','10000000-0000-4000-8000-000000000002','invoice_hash','invoice-hash-1'),
 'bank_payments',(SELECT jsonb_agg(jsonb_build_object('source_id',id,'raw_hash',raw_hash,'bank',institution_name,'date',posting_date,'amount',signed_amount,'description',description_raw))FROM public.lts_open_finance_staging WHERE resource_type='transaction'),
 'legacy_replacement',jsonb_build_object('id','synthetic-replace-mastercard','source_ref','9','source_payload',(SELECT dados FROM public.evento_base WHERE idx=9),'payment_source_id','10000000-0000-4000-8000-000000000004'),
 'old_events',(SELECT jsonb_agg(x)FROM jsonb_array_elements(public.lts_daily_flow_fix86_v12('00000000-0000-4000-8000-000000000001','2026-02-01','2026-02-28')->'events')x WHERE x->>'source_ref'IN('synthetic-c6-forecast','evento_base:9')))::text,true);
CREATE TEMP TABLE v351_batch(sql text);
''')
print('INSERT INTO v351_batch VALUES($qa$'+activate+'$qa$);')
print(r'''
CREATE TEMP TABLE v351_cases(name text,mutation text);
INSERT INTO v351_cases VALUES
 ('bank still pending',$q$UPDATE public.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"')WHERE resource_type='transaction'AND institution_code='336'$q$),
 ('bank raw pending',$q$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{status}','"PENDING"')WHERE resource_type='transaction'AND institution_code='336'$q$),
 ('changed bank hash',$q$UPDATE public.lts_open_finance_staging SET raw_hash='changed'WHERE resource_type='transaction'AND institution_code='336'$q$),
 ('wrong owner',$q$SELECT set_config('lts.v351_owner','00000000-0000-4000-8000-000000000002',true)$q$),
 ('wrong legacy identity',$q$UPDATE public.evento_base SET dados=jsonb_set(dados,'{valor}','91')WHERE idx=9$q$),
 ('ambiguous billing account',$q$INSERT INTO public.lts_open_finance_staging(id,user_id,resource_type,institution_code,provider_account_ref)VALUES('10000000-0000-4000-8000-000000000099','00000000-0000-4000-8000-000000000001','credit_card','336','other-card')$q$),
 ('issuer partial payment',$q$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{payments,0,valueType}','"PARTIAL_PAYMENT"')WHERE resource_type='invoice'AND institution_code='336'$q$),
 ('unrelated issuer payment date',$q$UPDATE public.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{payments,0,paymentDate}','"2026-02-06T00:00:00.000Z"')WHERE resource_type='invoice'AND institution_code='336'$q$),
 ('cash source changed',$q$SELECT set_config('lts.v351_manifest',jsonb_set(current_setting('lts.v351_manifest')::jsonb,'{old_events,0,signed_amount}','-101')::text,true)$q$);
DO $test$DECLARE x record;m text;BEGIN FOR x IN SELECT *FROM v351_cases LOOP BEGIN
 EXECUTE x.mutation;m:=NULL;BEGIN EXECUTE(SELECT sql FROM v351_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS NULL OR m NOT LIKE 'V351_%'THEN RAISE EXCEPTION 'Invalid source accepted: % / %',x.name,m;END IF;
 RAISE EXCEPTION USING ERRCODE='V3510',MESSAGE='rollback mutation';EXCEPTION WHEN SQLSTATE 'V3510'THEN NULL;END;END LOOP;END$test$;
''')
print(activate)
print(r'''
DO $test$DECLARE receipt jsonb;m text;j jsonb;BEGIN
 receipt:=current_setting('lts.v351_receipt')::jsonb;
 IF(receipt->>'cash_delta')::numeric<>-65 OR(receipt->>'c6_purchase_count')::int<>1 OR(receipt->>'c6_raw_items')::int<>3 THEN RAISE EXCEPTION 'Wrong cash/consumption result';END IF;
 IF public.lts_card_item_is_invoice_payment_v351('{"raw_payload":{"description":"Estorno de compra","category":"Shopping"}}')THEN RAISE EXCEPTION 'Refund treated as payment';END IF;
 SELECT public.lts_card_settlement_overlay_v290('00000000-0000-4000-8000-000000000001','{"cards":[{"family":"c6","cycles":[{"invoice_source_id":"10000000-0000-4000-8000-000000000001","amount":100,"due_date":"2026-02-05","payment_status":"payment_not_reported"}]}]}')INTO j;
 IF j#>>'{cards,0,cycles,0,payment_status}'IS DISTINCT FROM 'paid'OR j#>>'{cards,0,cycles,0,settlement_confirmed}'IS DISTINCT FROM 'true'THEN RAISE EXCEPTION 'Unpaid overlay';END IF;
 BEGIN EXECUTE(SELECT sql FROM v351_batch);EXCEPTION WHEN raise_exception THEN m:=SQLERRM;END;
 IF m IS DISTINCT FROM 'V351_ALREADY_APPLIED_REVIEW_REQUIRED'THEN RAISE EXCEPTION 'Replay accepted';END IF;
END$test$;
''')
print(policy)
print((R/'backend/qa/lts_v301_cycle_window.sql').read_text())
print(r'''
SELECT jsonb_build_object('pass',true,'version',351,'rejection_cases',(SELECT count(*)FROM v351_cases),'posted_payments_once',true,'previous_invoice_payment_not_consumption',true,'refund_not_payment',true,'other_payment_type_preserved',true,'existing_contracts_preserved',true,'future_events_preserved',true,'replay_rejected',true);
ROLLBACK;
''')
