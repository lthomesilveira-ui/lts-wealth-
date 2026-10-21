-- Synthetic evidence only; executes the actual private PostgreSQL validator, without financial writes.
WITH ids AS(SELECT '00000000-0000-4000-8000-000000002930'::uuid u),
fixture AS(SELECT u,
jsonb_build_object('id','synthetic-schedule','user_id',u,'resource_type','transaction','currency','BRL',
 'signed_amount',-100,'posting_date','2026-11-04','raw_hash',repeat('a',64),'institution_code','341','provider_account_ref','synthetic-owned-account',
 'normalized_payload',jsonb_build_object('status','PENDING','account_type','CHECKING_ACCOUNT'),
 'raw_payload',jsonb_build_object('paymentData',jsonb_build_object('payer',jsonb_build_object('documentNumber',jsonb_build_object('type','CPF','value','11111111111')),
 'receiver',jsonb_build_object('routingNumber','237','documentNumber',jsonb_build_object('type','CPF','value','11111111111'))))) s,
jsonb_build_object('user_id',u,'action','confirm_scheduled_transfer_destination','entity_type','open_finance_schedule','entity_id','synthetic-schedule',
 'details',jsonb_build_object('version','owner-schedule-destination-v292','basis','owner_confirmed_registered_destination','scope','destination_confirmation_only',
 'source_status','PENDING','source_id','synthetic-schedule','source_raw_hash',repeat('a',64),'date','2026-11-04','signed_amount',-100,
 'financial_effect','none','does_not_mark_paid',true,'destination_account_id','destination','destination_bank','Bradesco','origin_bank','Itaú')) c,
jsonb_build_object('id','origin','user_id',u,'is_active',true,'account_type','checking','currency','BRL','institution','Itaú') o,
jsonb_build_object('id','destination','user_id',u,'is_active',true,'account_type','checking','currency','BRL','institution','Bradesco') d,
jsonb_build_object('user_id',u,'resource_type','balance','institution_code','341','provider_account_ref','synthetic-owned-account',
 'normalized_payload',jsonb_build_object('account_type','CHECKING_ACCOUNT'),'raw_payload',jsonb_build_object('taxNumber','11111111111')) b
FROM ids), cases AS(
SELECT 'valid exact confirmation' name,u,s,c,o,d,b,true expected FROM fixture
UNION ALL SELECT 'wrong owner',u,s,c,o,jsonb_set(d,'{user_id}','"someone-else"'),b,false FROM fixture
UNION ALL SELECT 'stale raw hash',u,jsonb_set(s,'{raw_hash}',to_jsonb(repeat('b',64))),c,o,d,b,false FROM fixture
UNION ALL SELECT 'changed amount',u,jsonb_set(s,'{signed_amount}','-101'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'changed date',u,jsonb_set(s,'{posting_date}','"2026-11-05"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'posted is not scheduled',u,jsonb_set(s,'{normalized_payload,status}','"POSTED"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'deleted bank source',u,jsonb_set(s,'{provider_deleted_at}','"2026-11-04"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'different receiver CPF',u,jsonb_set(s,'{raw_payload,paymentData,receiver,documentNumber,value}','"22222222222"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'missing owner tax identity',u,s,c,o,d,b-'raw_payload',false FROM fixture
UNION ALL SELECT 'wrong routing',u,jsonb_set(s,'{raw_payload,paymentData,receiver,routingNumber}','"336"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'different destination account',u,s,c,o,jsonb_set(d,'{id}','"other"'),b,false FROM fixture
UNION ALL SELECT 'inactive destination',u,s,c,o,jsonb_set(d,'{is_active}','false'),b,false FROM fixture
UNION ALL SELECT 'non-BRL destination',u,s,c,o,jsonb_set(d,'{currency}','"USD"'),b,false FROM fixture
UNION ALL SELECT 'savings destination not inferred',u,s,c,o,jsonb_set(d,'{account_type}','"savings"'),b,false FROM fixture
UNION ALL SELECT 'origin equals destination',u,s,c,jsonb_set(o,'{id}','"destination"'),d,b,false FROM fixture
UNION ALL SELECT 'wrong confirmation version',u,s,jsonb_set(c,'{details,version}','"unknown"'),o,d,b,false FROM fixture
UNION ALL SELECT 'null confirmation',u,s,null,o,d,b,false FROM fixture
UNION ALL SELECT 'amount has invalid type',u,jsonb_set(s,'{signed_amount}','"invalid"'),c,o,d,b,false FROM fixture
UNION ALL SELECT 'unrelated balance account',u,s,c,o,d,jsonb_set(b,'{provider_account_ref}','"other"'),false FROM fixture
UNION ALL SELECT 'confirmation claims paid',u,s,jsonb_set(c,'{details,does_not_mark_paid}','false'),o,d,b,false FROM fixture
), results AS(SELECT name,expected,public.lts_bank_schedule_evidence_valid_v293(u,s,c,o,d,b) actual FROM cases)
SELECT count(*) cases,count(*)FILTER(WHERE actual=expected) passed,
coalesce(jsonb_agg(to_jsonb(results))FILTER(WHERE actual IS DISTINCT FROM expected),'[]') failures FROM results;
