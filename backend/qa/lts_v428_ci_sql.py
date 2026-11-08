"""Exercise exact deployed readers with invented receipts; never uses owner data."""
from pathlib import Path
import hashlib
import json

R=Path(__file__).resolve().parents[2]
print("CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role;")
print((R/'backend/patches/v351/reviewed_c6_settlement.sql').read_text().split('DO $patch$')[0])
print((R/'backend/qa/fixtures/v351_cycle_v301.sql').read_text()+';')
for name in ['lts_card_payment_refresh_annotation_v273','lts_card_settlement_evidence_valid_v273']:
    print((R/f'backend/qa/fixtures/v428/{name}.sql').read_text())

u='00000000-0000-4000-8000-000000000001'
inv='10000000-0000-4000-8000-000000000001'
pay='10000000-0000-4000-8000-000000000002'
item='10000000-0000-4000-8000-000000000003'
issuer={'id':'reviewed-issuer-payment','amount':100,'valueType':'OTHER_PAYMENT','paymentDate':'2026-02-05T00:00:00.000Z','paymentMode':'DEBIT_ACCOUNT','currencyCode':'BRL'}
later=issuer|{'id':'next-cycle-payment','amount':175,'paymentDate':'2026-03-05T00:00:00.000Z'}
link={'id':'10000000-0000-4000-8000-000000000004','user_id':u,'invoice_source_id':inv,'payment_source_id':pay,'institution_code':'336','provider_item_id':'synthetic-item','invoice_account_ref':'synthetic-card','payment_account_ref':'synthetic-checking','expected_amount':100,'expected_due_date':'2026-02-05','expected_closing_date':'2026-01-25','expected_payment_date':'2026-02-05','invoice_raw_hash':'invoice-hash','payment_raw_hash':'payment-hash','documentary_sources':[{'basis':'synthetic invoice'},{'basis':'synthetic bank'}],'active':True}
common={'user_id':u,'institution_code':'336','currency':'BRL','provider_deleted_at':None}
invoice=common|{'id':inv,'resource_type':'invoice','provider_record_id':'synthetic-item:invoice','provider_account_ref':'synthetic-card','signed_amount':100,'raw_hash':'invoice-hash','normalized_payload':{'due_date':'2026-02-05','closing_date':'2026-01-25','provider_id':'synthetic-invoice'},'raw_payload':{'updatedAt':'2026-03-06T12:00:00.000Z','payments':[issuer],'totalAmount':100,'currencyCode':'BRL'}}
payment=common|{'id':pay,'resource_type':'transaction','provider_record_id':'synthetic-item:payment','provider_account_ref':'synthetic-checking','signed_amount':-100,'posting_date':'2026-02-05','description_raw':'PGTO FAT CARTAO C6','raw_hash':'payment-hash','normalized_payload':{'status':'POSTED','account_type':'CHECKING_ACCOUNT'},'raw_payload':{'status':'POSTED'}}
purchase=common|{'id':item,'resource_type':'card_transaction','provider_account_ref':'synthetic-card','signed_amount':-100,'raw_hash':'purchase-hash','normalized_payload':{'status':'POSTED'},'raw_payload':{'status':'POSTED','operationType':'COMPRA','creditCardMetadata':{'billId':'synthetic-invoice'}}}
contract={'active':True,'amount':100,'user_id':u,'payment_id':pay,'invoice_id':inv,'link_contract':link,'invoice_current_hash':'invoice-hash','invoice_evidence_policy':'raw_except_updatedAt_v1','invoice_canonical_payload':{k:v for k,v in invoice['raw_payload'].items() if k!='updatedAt'},'issuer_payments':[issuer],'settlement_manifest':[issuer],'issuer_settlement_policy':'one_c6_other_payment_in_cycle_v351','reviewed_other_payment':{'basis':'one_c6_cycle_and_exact_posted_bank_debit','invoice_id':inv,'payment_id':pay,'bank_description':'PGTO FAT CARTAO C6','issuer_payment_id':issuer['id']},'manifest':[{'id':item,'raw_hash':'purchase-hash','signed_amount':-100,'status':'POSTED','raw_status':'POSTED','operation_type':'COMPRA'}],'consumption_manifest':[{'id':item,'signed_amount':-100}],'item_settlement_policy':'canonical_invoice_payment_flags_v351','competence_month':'2026-02-01','coverage_mode':'synthetic-item-composition'}
coverage=[{'source_ref':item,'amount':100,'competence_month':'2026-02-01','coverage_mode':'synthetic-item-composition'}]
fixture={'invoice':invoice,'payment':payment,'link':link,'contract':contract,'items':[purchase],'coverage':coverage,'later':later}
print("CREATE TABLE v428_fixture(j jsonb); INSERT INTO v428_fixture VALUES($json$"+json.dumps(fixture)+"$json$);")
print(r'''
CREATE FUNCTION v428_receipt(j jsonb) RETURNS jsonb LANGUAGE sql AS $$
 SELECT public.lts_card_payment_refresh_annotation_v273((j#>>'{link,user_id}')::uuid,j->'link',j->'invoice',j->'payment',j->'contract','2026-04-01')$$;
CREATE FUNCTION v428_valid(j jsonb) RETURNS boolean LANGUAGE sql AS $$
 SELECT public.lts_card_settlement_evidence_valid_v273((j#>>'{link,user_id}')::uuid,(j#>>'{link,payment_source_id}')::uuid,j->'link',j->'invoice',j->'payment',j->'items','2026-04-01',j->'contract',j->'coverage')$$;
DO $$DECLARE j jsonb; BEGIN SELECT f.j INTO j FROM v428_fixture f;
 IF v428_receipt(j) IS NULL OR NOT v428_valid(j) THEN RAISE EXCEPTION 'Invalid baseline fixture'; END IF;
 j:=jsonb_set(j,'{invoice,raw_payload,payments}',jsonb_build_array(j->'later',j#>'{contract,issuer_payments,0}'));
 IF v428_receipt(j) IS NOT NULL OR v428_valid(j) THEN RAISE EXCEPTION 'Predecessor did not reproduce regression'; END IF;
END$$;
CREATE TABLE v428_other_banks(j jsonb);
DO $$DECLARE j jsonb; code text; BEGIN
 FOR code IN SELECT unnest(ARRAY['341','237']) LOOP
  SELECT f.j INTO j FROM v428_fixture f;
  j:=jsonb_set(j,'{link,institution_code}',to_jsonb(code));
  j:=jsonb_set(j,'{invoice,institution_code}',to_jsonb(code));
  j:=jsonb_set(j,'{payment,institution_code}',to_jsonb(code));
  j:=jsonb_set(j,'{items,0,institution_code}',to_jsonb(code));
  j:=jsonb_set(j,'{contract,link_contract}',j->'link');
  j:=jsonb_set(j,'{contract,item_settlement_policy}','null');
  j:=jsonb_set(j,'{contract,issuer_settlement_policy}','"one_full_payment_in_cycle_v301"');
  j:=jsonb_set(j,'{invoice,raw_payload,payments,0,valueType}','"FULL_PAYMENT"');
  j:=jsonb_set(j,'{contract,issuer_payments}',j#>'{invoice,raw_payload,payments}');
  j:=jsonb_set(j,'{contract,settlement_manifest}',j#>'{contract,issuer_payments}');
  j:=jsonb_set(j,'{contract,invoice_canonical_payload}',(j#>'{invoice,raw_payload}')-'updatedAt');
  IF v428_receipt(j) IS NULL OR NOT v428_valid(j) THEN RAISE EXCEPTION 'Invalid other-bank baseline'; END IF;
  INSERT INTO v428_other_banks VALUES(j);
 END LOOP;
END$$;
CREATE TABLE v428_other_receipts AS SELECT v428_receipt(j) receipt FROM v428_other_banks;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE v428_sources_before AS SELECT md5(j::text) hash FROM v428_fixture;
CREATE TABLE v428_attrs_before AS SELECT oid,to_jsonb(p)-'prosrc' attrs FROM pg_proc p
 WHERE oid IN('public.lts_card_payment_refresh_annotation_v273(uuid,jsonb,jsonb,jsonb,jsonb,date)'::regprocedure,
 'public.lts_card_settlement_evidence_valid_v273(uuid,uuid,jsonb,jsonb,jsonb,jsonb,date,jsonb,jsonb)'::regprocedure);
''')
patch=(R/'backend/patches/v428/later_issuer_payments.sql').read_text()
print(patch)
print(patch)
print(r'''
DO $$DECLARE j jsonb; a jsonb; BEGIN
 SELECT f.j INTO j FROM v428_fixture f;
 a:=v428_receipt(j);
 IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<>2 THEN RAISE EXCEPTION 'Epoch changed incorrectly on replay'; END IF;
 IF a IS NULL OR NOT v428_valid(j) THEN RAISE EXCEPTION 'Original receipt regressed'; END IF;
 j:=jsonb_set(j,'{invoice,raw_payload,payments}',jsonb_build_array(j->'later',j#>'{contract,issuer_payments,0}'));
 IF v428_receipt(j) IS DISTINCT FROM a OR NOT v428_valid(j) THEN RAISE EXCEPTION 'Appended next-cycle payment rejected'; END IF;
 IF EXISTS(SELECT 1 FROM v428_attrs_before b JOIN pg_proc p ON p.oid=b.oid WHERE b.attrs IS DISTINCT FROM to_jsonb(p)-'prosrc')
 THEN RAISE EXCEPTION 'Existing function attributes changed'; END IF;
 IF EXISTS(SELECT 1 FROM v428_fixture f CROSS JOIN v428_sources_before b WHERE md5(f.j::text)<>b.hash)
 THEN RAISE EXCEPTION 'Source mutated'; END IF;
 IF has_function_privilege('anon','public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)','EXECUTE')
 OR NOT has_function_privilege('service_role','public.lts_card_later_issuer_payments_valid_v428(jsonb,jsonb,jsonb)','EXECUTE')
 THEN RAISE EXCEPTION 'Helper privilege drift'; END IF;
 IF EXISTS((SELECT v428_receipt(o.j) FROM v428_other_banks o EXCEPT ALL SELECT receipt FROM v428_other_receipts)
  UNION ALL (SELECT receipt FROM v428_other_receipts EXCEPT ALL SELECT v428_receipt(o.j) FROM v428_other_banks o))
 THEN RAISE EXCEPTION 'Other-bank receipt changed'; END IF;
 IF EXISTS(SELECT 1 FROM v428_other_banks o WHERE NOT v428_valid(o.j)) THEN RAISE EXCEPTION 'Other-bank evidence regressed'; END IF;
END$$;
CREATE TEMP TABLE v428_cases(name text,path text[],replacement jsonb);
INSERT INTO v428_cases VALUES
 ('changed reviewed amount','{invoice,raw_payload,payments,1,amount}','101'),
 ('changed reviewed id','{invoice,raw_payload,payments,1,id}','"other-id"'),
 ('changed reviewed date','{invoice,raw_payload,payments,1,paymentDate}','"2026-02-06T00:00:00.000Z"'),
 ('duplicate id','{invoice,raw_payload,payments,0,id}','"reviewed-issuer-payment"'),
 ('same-cycle added payment','{invoice,raw_payload,payments,0,paymentDate}','"2026-02-05T00:00:00.000Z"'),
 ('earlier-cycle added payment','{invoice,raw_payload,payments,0,paymentDate}','"2026-01-20T00:00:00.000Z"'),
 ('malformed added date','{invoice,raw_payload,payments,0,paymentDate}','"2026-02-31T00:00:00.000Z"'),
 ('changed invoice total','{invoice,raw_payload,totalAmount}','101'),
 ('missing raw invoice payments','{invoice,raw_payload,payments}','null'),
 ('bank source hash changed','{payment,raw_hash}','"other-hash"'),
 ('bank pending','{payment,normalized_payload,status}','"PENDING"'),
 ('bank raw pending','{payment,raw_payload,status}','"PENDING"'),
 ('bank amount changed','{payment,signed_amount}','-101'),
 ('foreign owner','{payment,user_id}','"00000000-0000-4000-8000-000000000002"'),
 ('foreign bank','{invoice,institution_code}','"237"'),
 ('different invoice account','{invoice,provider_account_ref}','"other-card"'),
 ('different checking account','{payment,provider_account_ref}','"other-checking"'),
 ('deleted invoice','{invoice,provider_deleted_at}','"2026-03-01T00:00:00Z"'),
 ('changed link amount','{link,expected_amount}','101'),
 ('disabled contract','{contract,active}','false'),
 ('inactive link','{link,active}','false'),
 ('added negative payment','{invoice,raw_payload,payments,0,amount}','-175'),
 ('added payment string amount','{invoice,raw_payload,payments,0,amount}','"175"'),
 ('added payment currency','{invoice,raw_payload,payments,0,currencyCode}','"USD"'),
 ('added partial payment','{invoice,raw_payload,payments,0,valueType}','"PARTIAL_PAYMENT"'),
 ('added different payment mode','{invoice,raw_payload,payments,0,paymentMode}','"OTHER"');
DO $$DECLARE original jsonb; j jsonb; c record; BEGIN
 SELECT jsonb_set(f.j,'{invoice,raw_payload,payments}',jsonb_build_array(f.j->'later',f.j#>'{contract,issuer_payments,0}')) INTO original FROM v428_fixture f;
 FOR c IN SELECT * FROM v428_cases LOOP
  j:=jsonb_set(original,c.path,c.replacement);
  IF v428_receipt(j) IS NOT NULL OR v428_valid(j) THEN RAISE EXCEPTION 'Accepted changed evidence: %',c.name; END IF;
 END LOOP;
 j:=jsonb_set(original,'{invoice,raw_payload,payments}',jsonb_build_array(original->'later'));
 IF v428_receipt(j) IS NOT NULL OR v428_valid(j) THEN RAISE EXCEPTION 'Missing reviewed payment accepted'; END IF;
 j:=jsonb_set(original,'{invoice,raw_payload,payments}',jsonb_build_array(original#>'{contract,issuer_payments,0}',original->'later'));
 IF v428_receipt(j) IS NULL OR NOT v428_valid(j) THEN RAISE EXCEPTION 'Payment list reordering rejected'; END IF;
 j:=jsonb_set(original,'{items,0,signed_amount}','-99');
 IF v428_valid(j) THEN RAISE EXCEPTION 'Changed consumption accepted'; END IF;
 j:=jsonb_set(original,'{coverage,0,amount}','99');
 IF v428_valid(j) THEN RAISE EXCEPTION 'Changed composition coverage accepted'; END IF;
END$$;
SELECT jsonb_build_object('pass',true,'reproduced_predecessor_regression',true,'later_payment_keeps_exact_receipt',true,'original_receipt_preserved',true,'negative_cases',(SELECT count(*)+3 FROM v428_cases),'reordered_payments_accepted',true,'source_writes',0,'existing_attributes_preserved',true,'replay_passed',true,'private_data_used',false);
''')
