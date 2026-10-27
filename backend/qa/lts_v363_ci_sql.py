"""Run the deployed debit validator, documentary contract, writer and pair reader."""
from pathlib import Path
R=Path(__file__).resolve().parents[2]
print(r"""
BEGIN;
CREATE SCHEMA v363_fixture;
CREATE TABLE v363_fixture.accounts(id uuid,user_id uuid,institution text,is_active boolean,account_type text,currency text);
CREATE TABLE v363_fixture.lts_open_finance_staging(
 id uuid,user_id uuid,connection_id uuid,resource_type text,currency text,provider_deleted_at timestamptz,
 institution_code text,provider_account_ref text,provider_record_id text,posting_date date,signed_amount numeric,
 raw_hash text,raw_payload jsonb,normalized_payload jsonb,first_seen_at timestamptz,description_raw text);
CREATE TABLE v363_fixture.lts_open_finance_observation(id uuid,user_id uuid,connection_id uuid,resource_type text,
 provider_record_id text,raw_hash text,raw_payload jsonb,normalized_payload jsonb,observed_at timestamptz);
CREATE TABLE v363_fixture.audit_log(id bigint,user_id uuid,action text,entity_type text,entity_id text,details jsonb,created_at timestamptz);
CREATE TABLE v363_fixture.lts_reconciliation_evidence(id uuid default gen_random_uuid(),user_id uuid,evidence_date date,account text,
 amount numeric,description text,evidence_type text,source_ref text,status text,metadata jsonb,created_at timestamptz);
CREATE TABLE v363_fixture.lts_external_reference_fact(reference_key text,confidence text,metadata jsonb);
CREATE TABLE v363_fixture.financial_events(id uuid,user_id uuid,amount numeric);
CREATE TABLE v363_fixture.expenses(user_id uuid,source_ref text,amount numeric);
CREATE TABLE v363_fixture.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO v363_fixture.lts_read_cache_epoch_v242 VALUES(true,1);
INSERT INTO v363_fixture.accounts VALUES
 ('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','Itaú',true,'checking','BRL'),
 ('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','Bradesco',true,'checking','BRL');
INSERT INTO v363_fixture.lts_open_finance_staging
SELECT id,'00000000-0000-4000-8000-000000000001',conn,'transaction','BRL',null,bank,acct,item||':'||pid,current_date-1,amt,repeat(hash,64),
 jsonb_build_object('id',pid,'accountId',acct,'status','POSTED','currencyCode','BRL','amount',amt,
 'paymentData',jsonb_build_object('payer',jsonb_build_object('documentNumber',jsonb_build_object('type','CPF','value',payer),'routingNumber',payerbank),
 'receiver',jsonb_build_object('documentNumber',jsonb_build_object('type','CPF','value','11111111111'),'routingNumber',receiverbank))),
 jsonb_build_object('status','POSTED','account_type','CHECKING_ACCOUNT','date',(current_date-1)::text,'amount',amt,
 'item_id',item,'provider_id',pid,'provider_account_id',acct),now()-interval'3 days','Synthetic transfer'
FROM(VALUES
 ('00000000-0000-4000-8000-000000000005'::uuid,'00000000-0000-4000-8000-000000000007'::uuid,'341','from-checking','from-item','debit',-100,'d','11111111111',null,'237'),
 ('00000000-0000-4000-8000-000000000006'::uuid,'00000000-0000-4000-8000-000000000008'::uuid,'237','to-checking','to-item','credit',100,'c','22222222222','341',null)
)x(id,conn,bank,acct,item,pid,amt,hash,payer,payerbank,receiverbank);
INSERT INTO v363_fixture.lts_open_finance_staging(id,user_id,resource_type,institution_code,provider_account_ref,raw_payload,normalized_payload)
SELECT gen_random_uuid(),'00000000-0000-4000-8000-000000000001','balance',bank,acct,
 jsonb_build_object('taxNumber','11111111111'),jsonb_build_object('account_type','CHECKING_ACCOUNT')
FROM(VALUES('341','from-checking'),('237','to-checking'))x(bank,acct);
INSERT INTO v363_fixture.lts_open_finance_observation
SELECT '00000000-0000-4000-8000-000000000009',user_id,connection_id,resource_type,provider_record_id,repeat('b',64),
 jsonb_set(raw_payload,'{paymentData,payer,documentNumber,value}','"11111111111"'),normalized_payload,now()-interval'1 day'
FROM v363_fixture.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000006';
INSERT INTO v363_fixture.audit_log
SELECT 17,user_id,'confirm_scheduled_transfer_destination','open_finance_schedule',id::text,
 jsonb_build_object('version','owner-schedule-destination-v292','basis','owner_confirmed_registered_destination',
 'scope','destination_confirmation_only','source_status','PENDING','source_id',id,'source_raw_hash',repeat('a',64),
 'date',posting_date,'signed_amount',signed_amount,'financial_effect','none','does_not_mark_paid',true,
 'origin_bank','Itaú','destination_bank','Bradesco','destination_account_id','00000000-0000-4000-8000-000000000004'),now()-interval'2 days'
FROM v363_fixture.lts_open_finance_staging WHERE id='00000000-0000-4000-8000-000000000005';
INSERT INTO v363_fixture.expenses VALUES('00000000-0000-4000-8000-000000000001','untouched-expense',42);
CREATE FUNCTION v363_fixture.lts_v229_expense_rows(uuid,date,date)RETURNS TABLE(source_ref text,amount numeric)LANGUAGE sql AS $$SELECT source_ref,amount FROM v363_fixture.expenses WHERE user_id=$1$$;
""")
def sql(path): return (R/path).read_text().replace('public.','v363_fixture.')
debit=sql('backend/patches/v304/posted_own_transfer.sql').split('CREATE OR REPLACE FUNCTION v363_fixture.lts_posted_own_transfer_out_v304')[0]
print(debit)
print(sql('backend/qa/fixtures/v363_bank_rows.sql').replace('RETURNS SETOF lts_open_finance_staging','RETURNS SETOF v363_fixture.lts_open_finance_staging')+';')
print(sql('backend/qa/fixtures/v363_pair_reader.sql')+';')
print(sql('backend/qa/fixtures/v363_flow_reader.sql')+';')
print(r"""
REVOKE ALL ON FUNCTION v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)TO service_role;
CREATE TEMP TABLE v363_attributes AS SELECT to_jsonb(p)-'prosrc'j FROM pg_proc p WHERE oid='v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure;
CREATE TEMP TABLE v363_flow_attributes AS SELECT to_jsonb(p)-'prosrc'j FROM pg_proc p WHERE oid='v363_fixture.lts_browser_flow_pre_v238(date,date)'::regprocedure;
CREATE TEMP TABLE v363_raw AS SELECT jsonb_build_object('bank',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v363_fixture.lts_open_finance_staging x),'audit',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v363_fixture.audit_log x))j;
""")
patch=sql('backend/patches/v363/previously_proved_transfer.sql')
patch=patch.replace('md5(definition)',"md5(replace(definition,'v363_fixture.','public.'))").replace('md5(original)',"md5(replace(original,'v363_fixture.','public.'))")
print(patch)
print(r"""
SELECT set_config('lts.transfer_refresh.owner_id','00000000-0000-4000-8000-000000000001',true),
 set_config('lts.transfer_refresh.debit_id','00000000-0000-4000-8000-000000000005',true),
 set_config('lts.transfer_refresh.credit_id','00000000-0000-4000-8000-000000000006',true),
 set_config('lts.transfer_refresh.prior_credit_observation_id','00000000-0000-4000-8000-000000000009',true),
 set_config('lts.transfer_refresh.confirmation_audit_id','17',true),
 set_config('lts.transfer_refresh.debit_raw_hash',repeat('d',64),true),
 set_config('lts.transfer_refresh.credit_raw_hash',repeat('c',64),true),
 set_config('lts.transfer_refresh.prior_credit_raw_hash',repeat('b',64),true);
DO $test$BEGIN IF EXISTS(SELECT 1 FROM v363_fixture.lts_previously_proved_transfer_pairs_v363('00000000-0000-4000-8000-000000000001'))THEN RAISE EXCEPTION 'Unreviewed conflict automatically paired';END IF;END $test$;
""")
operation=sql('backend/operations/record_proved_transfer_refresh_v363.sql')
print(operation)
print(r"""
CREATE TEMP TABLE v363_inputs AS
SELECT jsonb_build_object('debit',to_jsonb(d),'credit',to_jsonb(c),'prior',to_jsonb(p),'confirmation',to_jsonb(a),
 'origin',to_jsonb(o),'destination',to_jsonb(t),'origin_balance',to_jsonb(ob),'destination_balance',to_jsonb(tb),'evidence',to_jsonb(e))j
FROM v363_fixture.lts_open_finance_staging d,v363_fixture.lts_open_finance_staging c,
v363_fixture.lts_open_finance_observation p,v363_fixture.audit_log a,v363_fixture.accounts o,v363_fixture.accounts t,
v363_fixture.lts_open_finance_staging ob,v363_fixture.lts_open_finance_staging tb,v363_fixture.lts_reconciliation_evidence e
WHERE d.id='00000000-0000-4000-8000-000000000005'AND c.id='00000000-0000-4000-8000-000000000006'
AND o.institution='Itaú'AND t.institution='Bradesco'AND ob.resource_type='balance'AND ob.institution_code='341'AND tb.resource_type='balance'AND tb.institution_code='237';
CREATE FUNCTION v363_fixture.test_valid(j jsonb)RETURNS boolean LANGUAGE sql AS $$SELECT v363_fixture.lts_transfer_refresh_valid_v363(
 '00000000-0000-4000-8000-000000000001',j->'debit',j->'credit',j->'prior',j->'confirmation',j->'origin',j->'destination',j->'origin_balance',j->'destination_balance',j->'evidence')$$;
DO $test$DECLARE j jsonb;r record;n integer:=0;expression text;basis text;BEGIN
 SELECT i.j INTO STRICT j FROM v363_inputs i;
 IF NOT v363_fixture.test_valid(j)THEN RAISE EXCEPTION 'Valid documentary continuity rejected';END IF;
 IF(SELECT count(*)FROM v363_fixture.lts_owner_confirmed_transfer_pairs_v263('00000000-0000-4000-8000-000000000001'))<>1 THEN RAISE EXCEPTION 'Shared pair reader did not use proof';END IF;
 expression:=pg_get_functiondef('v363_fixture.lts_browser_flow_pre_v238(date,date)'::regprocedure);
 expression:=split_part(substring(expression from strpos(expression,'''classification_basis'',CASE WHEN EXISTS')),E',\n ''own_transfer_counterparty_id''',1);
 expression:=substring(expression from length('''classification_basis'',')+1);
 EXECUTE 'SELECT '||expression||' FROM(SELECT $1::uuid u,$2::uuid id)p' INTO basis USING '00000000-0000-4000-8000-000000000001'::uuid,'00000000-0000-4000-8000-000000000006'::uuid;
 IF basis<>'prior_documented_pair_with_owner_destination_v363'THEN RAISE EXCEPTION 'Flow mislabeled a destination-only confirmation';END IF;
 FOR r IN SELECT * FROM(VALUES
 ('credit owner',ARRAY['credit','user_id'],'"00000000-0000-4000-8000-000000000002"'::jsonb),
 ('prior owner',ARRAY['prior','user_id'],'"00000000-0000-4000-8000-000000000002"'::jsonb),
 ('unposted credit',ARRAY['credit','normalized_payload','status'],'"PENDING"'::jsonb),
 ('deleted credit',ARRAY['credit','provider_deleted_at'],'"2026-01-01T00:00:00Z"'::jsonb),
 ('currency',ARRAY['credit','currency'],'"USD"'::jsonb),
 ('amount',ARRAY['credit','signed_amount'],'101'::jsonb),
 ('date',ARRAY['credit','posting_date'],'"2000-01-01"'::jsonb),
 ('current hash',ARRAY['credit','raw_hash'],to_jsonb(repeat('f',64))),
 ('debit hash',ARRAY['debit','raw_hash'],to_jsonb(repeat('f',64))),
 ('prior hash',ARRAY['prior','raw_hash'],to_jsonb(repeat('f',64))),
 ('other transaction',ARRAY['credit','id'],'"00000000-0000-4000-8000-000000000099"'::jsonb),
 ('other provider record',ARRAY['credit','provider_record_id'],'"other:credit"'::jsonb),
 ('other bank account',ARRAY['credit','provider_account_ref'],'"other-checking"'::jsonb),
 ('routing',ARRAY['credit','raw_payload','paymentData','payer','routingNumber'],'"336"'::jsonb),
 ('receiver identity',ARRAY['credit','raw_payload','paymentData','receiver','documentNumber','value'],'"33333333333"'::jsonb),
 ('prior payer identity',ARRAY['prior','raw_payload','paymentData','payer','documentNumber','value'],'"22222222222"'::jsonb),
 ('prior receiver identity',ARRAY['prior','raw_payload','paymentData','receiver','documentNumber','value'],'"22222222222"'::jsonb),
 ('prior not posted',ARRAY['prior','raw_payload','status'],'"PENDING"'::jsonb),
 ('prior wrong connection',ARRAY['prior','connection_id'],'"00000000-0000-4000-8000-000000000099"'::jsonb),
 ('prior wrong date',ARRAY['prior','normalized_payload','date'],'"2000-01-01"'::jsonb),
 ('prior wrong amount',ARRAY['prior','raw_payload','amount'],'101'::jsonb),
 ('audit scope',ARRAY['confirmation','details','scope'],'"exact_pair"'::jsonb),
 ('audit identity',ARRAY['confirmation','id'],'99'::jsonb),
 ('audit owner',ARRAY['confirmation','user_id'],'"00000000-0000-4000-8000-000000000002"'::jsonb),
 ('revoked proof',ARRAY['evidence','status'],'"revoked"'::jsonb),
 ('fabricated pair confirmation',ARRAY['evidence','metadata','owner_confirmation_scope'],'"explicit_exact_pair"'::jsonb),
 ('missing private proof',ARRAY['evidence','metadata'],'{}'::jsonb),
 ('inactive account',ARRAY['destination','is_active'],'false'::jsonb),
 ('foreign currency account',ARRAY['destination','currency'],'"USD"'::jsonb),
 ('different owner balance',ARRAY['destination_balance','raw_payload','taxNumber'],'"33333333333"'::jsonb)
 )x(name,path,value)LOOP
  IF v363_fixture.test_valid(jsonb_set(j,r.path,r.value))THEN RAISE EXCEPTION 'Accepted invalid case: %',r.name;END IF;n:=n+1;
 END LOOP;
 IF EXISTS(SELECT 1 FROM v363_fixture.lts_previously_proved_transfer_pairs_v363('00000000-0000-4000-8000-000000000002'))THEN RAISE EXCEPTION 'Owner isolation failed';END IF;
 IF(SELECT a.j FROM v363_attributes a)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid='v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure)THEN RAISE EXCEPTION 'Existing ACL/security attributes changed';END IF;
 IF(SELECT a.j FROM v363_flow_attributes a)IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc'FROM pg_proc p WHERE oid='v363_fixture.lts_browser_flow_pre_v238(date,date)'::regprocedure)THEN RAISE EXCEPTION 'Flow ACL/security attributes changed';END IF;
 IF has_function_privilege('authenticated','v363_fixture.lts_previously_proved_transfer_pairs_v363(uuid)','EXECUTE')OR has_function_privilege('anon','v363_fixture.lts_previously_proved_transfer_pairs_v363(uuid)','EXECUTE')THEN RAISE EXCEPTION 'Private helper exposed';END IF;
 IF(SELECT a.j FROM v363_raw a)IS DISTINCT FROM jsonb_build_object('bank',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v363_fixture.lts_open_finance_staging x),'audit',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v363_fixture.audit_log x))THEN RAISE EXCEPTION 'Sources or owner confirmation rewritten';END IF;
 RAISE NOTICE 'Rejected % invalid documentary transfer cases',n;
END $test$;
CREATE TEMP TABLE v363_replay AS SELECT pg_get_functiondef('v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure)definition;
""")
print(patch)
print(operation)
print(r"""
DO $test$BEGIN
 IF(SELECT count(*)FROM v363_fixture.lts_reconciliation_evidence)<>1 OR(SELECT epoch FROM v363_fixture.lts_read_cache_epoch_v242)<>2 THEN RAISE EXCEPTION 'Writer replay was not a no-op';END IF;
 IF(SELECT definition FROM v363_replay)IS DISTINCT FROM pg_get_functiondef('v363_fixture.lts_owner_confirmed_transfer_pairs_v263(uuid)'::regprocedure)THEN RAISE EXCEPTION 'Schema replay changed reader';END IF;
 UPDATE v363_fixture.lts_reconciliation_evidence SET status='revoked';
 IF EXISTS(SELECT 1 FROM v363_fixture.lts_owner_confirmed_transfer_pairs_v263('00000000-0000-4000-8000-000000000001'))THEN RAISE EXCEPTION 'Revoked proof still accepted';END IF;
END $test$;
SELECT jsonb_build_object('version',363,'pass',true,'invalid_cases_rejected',30,'real_debit_validator',true,'shared_reader',true,'owner_isolation',true,'private_acl',true,'sources_preserved',true,'replay_noop',true,'revocation_respected',true);
ROLLBACK;
""")
