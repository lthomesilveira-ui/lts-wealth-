-- Pure synthetic evidence; not proof of any actual receiving-bank credit.
DO $tests$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';s jsonb;a jsonb;o jsonb;d jsonb;b jsonb;
 r record;ss jsonb;aa jsonb;oo jsonb;dd jsonb;bb jsonb;n integer:=0;
BEGIN
 s:=jsonb_build_object('id','synthetic-source','user_id',u,'resource_type','transaction','currency','BRL',
 'signed_amount',-99,'posting_date','2020-04-03','raw_hash',repeat('a',64),'provider_record_id','item-A:tx-A',
 'provider_account_ref','account-A','institution_code','341','first_seen_at','2020-04-01T12:00:00Z',
 'normalized_payload',jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','amount',-99,
 'date','2020-04-03','item_id','item-A','provider_id','tx-A','provider_account_id','account-A'),
 'raw_payload',jsonb_build_object('id','tx-A','accountId','account-A','status','POSTED','amount',-99,'currencyCode','BRL',
 'paymentData',jsonb_build_object('payer',jsonb_build_object('documentNumber',jsonb_build_object('type','CPF','value','12345678901')),
 'receiver',jsonb_build_object('routingNumber','237','documentNumber',jsonb_build_object('type','CPF','value','12345678901')))));
 a:=jsonb_build_object('user_id',u,'action','confirm_scheduled_transfer_destination','entity_type','open_finance_schedule',
 'entity_id','synthetic-source','created_at','2020-04-02T12:00:00Z','details',jsonb_build_object(
 'version','owner-schedule-destination-v292','basis','owner_confirmed_registered_destination','scope','destination_confirmation_only',
 'source_status','PENDING','source_id','synthetic-source','source_raw_hash',repeat('b',64),'date','2020-04-03',
 'signed_amount',-99,'financial_effect','none','does_not_mark_paid',true,'destination_account_id','synthetic-destination',
 'destination_bank','Bradesco','origin_bank','Itaú'));
 o:=jsonb_build_object('id','synthetic-origin','user_id',u,'institution','Itaú','is_active',true,'account_type','checking','currency','BRL');
 d:=jsonb_build_object('id','synthetic-destination','user_id',u,'institution','Bradesco','is_active',true,'account_type','checking','currency','BRL');
 b:=jsonb_build_object('user_id',u,'resource_type','balance','provider_account_ref','account-A','institution_code','341',
 'normalized_payload',jsonb_build_object('account_type','CHECKING_ACCOUNT'),'raw_payload',jsonb_build_object('taxNumber','12345678901'));
 IF NOT public.lts_posted_own_transfer_valid_v304(u,s,a,o,d,b) THEN RAISE EXCEPTION 'valid posted own debit rejected';END IF;
 FOR r IN SELECT * FROM (VALUES
 ('source','{user_id}','"00000000-0000-4000-8000-000000000099"'),
 ('confirmation','{user_id}','"00000000-0000-4000-8000-000000000099"'),
 ('origin','{user_id}','"00000000-0000-4000-8000-000000000099"'),
 ('destination','{user_id}','"00000000-0000-4000-8000-000000000099"'),
 ('balance','{user_id}','"00000000-0000-4000-8000-000000000099"'),
 ('source','{normalized_payload,status}','"PENDING"'),('source','{raw_payload,status}','"PENDING"'),
 ('source','{normalized_payload,account_type}','"CREDIT_CARD"'),('source','{resource_type}','"invoice"'),
 ('source','{currency}','"USD"'),('source','{provider_deleted_at}','"2020-04-04T12:00:00Z"'),
 ('source','{signed_amount}','-98'),('source','{normalized_payload,amount}','-98'),('source','{raw_payload,amount}','-98'),
 ('source','{raw_payload,currencyCode}','"USD"'),('source','{normalized_payload,date}','"2020-04-04"'),
 ('source','{provider_record_id}','"different-identity"'),('source','{normalized_payload,provider_id}','"tx-B"'),
 ('source','{normalized_payload,item_id}','"item-B"'),('source','{provider_account_ref}','"account-B"'),
 ('source','{raw_payload,accountId}','"account-B"'),('source','{raw_hash}','"invalid"'),
 ('source','{raw_payload,paymentData,receiver,routingNumber}','"336"'),
 ('source','{raw_payload,paymentData,receiver,documentNumber,value}','"12345678902"'),
 ('source','{raw_payload,paymentData,payer,documentNumber,value}','"12345678902"'),
 ('source','{raw_payload,paymentData,receiver,documentNumber,type}','"CNPJ"'),
 ('source','{first_seen_at}','"2020-04-03T12:00:00Z"'),
 ('confirmation','{entity_id}','"another-source"'),('confirmation','{action}','"other"'),
 ('confirmation','{details,scope}','"other"'),('confirmation','{details,source_id}','"another-source"'),
 ('confirmation','{details,date}','"2020-04-04"'),('confirmation','{details,signed_amount}','-98'),
 ('confirmation','{details,source_raw_hash}','"invalid"'),('confirmation','{details,destination_bank}','"C6"'),
 ('confirmation','{details,destination_account_id}','"another-account"'),('confirmation','{details,does_not_mark_paid}','false'),
 ('destination','{is_active}','false'),('destination','{currency}','"USD"'),('destination','{account_type}','"card"'),
 ('origin','{institution}','"C6"'),('balance','{provider_account_ref}','"account-B"'),
 ('balance','{raw_payload,taxNumber}','"12345678902"'),('balance','{provider_deleted_at}','"2020-04-04T12:00:00Z"')
 )x(scope,path,value) LOOP
  ss:=s;aa:=a;oo:=o;dd:=d;bb:=b;
  CASE r.scope WHEN 'source' THEN ss:=jsonb_set(s,r.path::text[],r.value::jsonb);
  WHEN 'confirmation' THEN aa:=jsonb_set(a,r.path::text[],r.value::jsonb);
  WHEN 'origin' THEN oo:=jsonb_set(o,r.path::text[],r.value::jsonb);
  WHEN 'destination' THEN dd:=jsonb_set(d,r.path::text[],r.value::jsonb);
  ELSE bb:=jsonb_set(b,r.path::text[],r.value::jsonb);END CASE;
  IF public.lts_posted_own_transfer_valid_v304(u,ss,aa,oo,dd,bb) THEN
   RAISE EXCEPTION 'unsafe evidence accepted: % %',r.scope,r.path;END IF;n:=n+1;
 END LOOP;
 IF public.lts_posted_own_transfer_valid_v304(u,NULL,a,o,d,b) THEN RAISE EXCEPTION 'null accepted';END IF;
 IF has_function_privilege('anon','public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb)','EXECUTE')
 THEN RAISE EXCEPTION 'private validator exposed';END IF;
 PERFORM set_config('lts.v304.synthetic_receipt',jsonb_build_object('status','PASS','negative_cases',n,
 'different_scheduled_and_posted_hashes_accepted',true,'no_receiving_credit_proven',true)::text,true);
END $tests$;
