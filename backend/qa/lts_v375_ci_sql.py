"""Actual receipt, coverage and pending readers against isolated synthetic sources."""
from pathlib import Path
import json
import subprocess
import sys

R = Path(__file__).resolve().parents[2]
base = subprocess.run([sys.executable, str(R/'backend/qa/lts_v371_ci_sql.py')], check=True, capture_output=True, text=True).stdout
assert base.rstrip().endswith('ROLLBACK;')
print(base[:base.rindex('ROLLBACK;')])
print(r'''
ALTER TABLE v303_fixture.lts_open_finance_staging
 ADD COLUMN provider_record_id text,ADD COLUMN provider_account_ref text,
 ADD COLUMN raw_hash text,ADD COLUMN raw_payload jsonb,ADD COLUMN occurred_at timestamptz;
ALTER TABLE v303_fixture.lts_card_documentary_payment_link_v272
 ADD COLUMN id uuid DEFAULT gen_random_uuid(),ADD COLUMN institution_code text,
 ADD COLUMN provider_item_id text,ADD COLUMN invoice_account_ref text,ADD COLUMN payment_account_ref text,
 ADD COLUMN expected_amount numeric,ADD COLUMN expected_closing_date date,ADD COLUMN expected_payment_date date,
 ADD COLUMN invoice_raw_hash text,ADD COLUMN payment_raw_hash text,
 ADD COLUMN documentary_sources jsonb,ADD COLUMN created_at timestamptz DEFAULT now();
ALTER TABLE v303_fixture.lts_v229_documentary_match ADD COLUMN canonical_date date,ADD COLUMN evidence jsonb;
CREATE TABLE v303_fixture.accounts(user_id uuid,institution text,is_active boolean,metadata jsonb);
CREATE TABLE v303_fixture.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY,epoch bigint);
INSERT INTO v303_fixture.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE FUNCTION v303_fixture.v375_today()RETURNS date LANGUAGE sql AS $$SELECT date '2026-10-29'$$;
CREATE OR REPLACE FUNCTION v303_fixture.lts_card_family_v226(text,text)RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN $1='Mastercard'AND $2='Itaú'THEN'itau_mastercard'
 WHEN v303_fixture.lts_v178_norm($1)='visa aeternum'AND $2='Bradesco'THEN'aeternum'ELSE'other'END$$;
CREATE FUNCTION v303_fixture.lts_bank_fgts_combined_receipt_v261(uuid,uuid)RETURNS jsonb LANGUAGE sql AS $$SELECT NULL::jsonb$$;
CREATE FUNCTION v303_fixture.lts_flow_classification_decision_v1(uuid,jsonb)RETURNS jsonb LANGUAGE sql AS $$SELECT $2$$;
-- Fixture card_invoice obligations have no reviewed settlement; this existing
-- dependency is separate from the actual legacy receipt path tested below.
CREATE FUNCTION v303_fixture.lts_card_invoice_settled_v290(uuid,text,date,date,numeric)RETURNS boolean LANGUAGE sql AS $$SELECT false$$;
CREATE FUNCTION v303_fixture.lts_flow_operational_read_v229(uuid,date,date)RETURNS jsonb LANGUAGE sql AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object('source',source,'source_ref',source_ref,'event_date',event_date,
 'account',account,'description',description,'confidence',confidence,'signed_amount',signed_amount)), '[]')
 FROM v303_fixture.v371_flow WHERE user_id=$1 AND event_date BETWEEN $2 AND $3$$;
''')
for name in ['v351_cycle_v301.sql']:
    print((R/'backend/qa/fixtures'/name).read_text().replace('public.', 'v303_fixture.')+';')
for name in ['lts_card_payment_refresh_annotation_v273.sql', 'lts_recurring_receipt_identities_v303.sql', 'lts_pending_projections_v233.sql']:
    text = (R/'backend/qa/fixtures/v375'/name).read_text().replace('public.', 'v303_fixture.')
    if name == 'lts_pending_projections_v233.sql':
        text = text.replace('current_date', 'v303_fixture.v375_today()')
    print(text)

u = '00000000-0000-4000-8000-000000000001'
inv = '10000000-0000-4000-8000-000000000201'
pay = '10000000-0000-4000-8000-000000000202'
current_payment = {'id':'issuer-current', 'amount':300, 'valueType':'FULL_PAYMENT', 'paymentDate':'2026-10-26T00:00:00.000Z', 'paymentMode':'DEBIT_ACCOUNT', 'currencyCode':'BRL'}
prior_payment = current_payment | {'id':'issuer-prior', 'amount':90, 'paymentDate':'2026-09-25T00:00:00.000Z'}
invoice_raw = {'payments':[current_payment, prior_payment], 'updatedAt':'2026-10-28T12:00:00.000Z'}
common = {'user_id':u,'currency':'BRL','institution_code':'237','institution_name':'Bradesco'}
sources = [
    common | {'id':inv,'resource_type':'invoice','posting_date':'2026-10-25','signed_amount':300,'description_raw':'Synthetic card invoice','provider_record_id':'synthetic-item:invoice','provider_account_ref':'synthetic-card','raw_hash':'synthetic-invoice-hash','normalized_payload':{'card_name':'VISA AETERNUM','due_date':'2026-10-25','closing_date':'2026-10-14','provider_id':'synthetic-invoice'},'raw_payload':invoice_raw},
    common | {'id':pay,'resource_type':'transaction','posting_date':'2026-10-27','occurred_at':'2026-10-27T12:00:00Z','signed_amount':-300,'description_raw':'Synthetic raw bank card debit','provider_record_id':'synthetic-item:payment','provider_account_ref':'synthetic-checking','raw_hash':'synthetic-payment-hash','normalized_payload':{'status':'POSTED','account_type':'CHECKING_ACCOUNT','provider_account_id':'synthetic-checking'},'raw_payload':{'status':'POSTED'}},
    common | {'id':'10000000-0000-4000-8000-000000000203','resource_type':'balance','normalized_payload':{'account_type':'CHECKING_ACCOUNT','provider_account_id':'synthetic-checking','as_of':'2026-10-28T12:00:00Z'}}
]
print('INSERT INTO v303_fixture.lts_open_finance_staging SELECT *FROM jsonb_populate_recordset(NULL::v303_fixture.lts_open_finance_staging,$data$'+json.dumps(sources)+'$data$);')
print(r'''
INSERT INTO v303_fixture.accounts VALUES('00000000-0000-4000-8000-000000000001','Bradesco',true,'{"evidence_sha256":"synthetic-anchor","balance_as_of":"2026-10-20"}');
INSERT INTO v303_fixture.evento_base VALUES
('00000000-0000-4000-8000-000000000001',90,'{"dia":"2026-10-25","desc":"Visa Aeternum","conta":"Bradesco","valor":120,"efeito":"saida"}'),
('00000000-0000-4000-8000-000000000001',91,'{"dia":"2026-10-26","desc":"Other unpaid obligation","conta":"Bradesco","valor":55,"efeito":"saida"}');
DELETE FROM v303_fixture.v371_flow WHERE source_ref='oct-cycle';
INSERT INTO v303_fixture.v371_flow VALUES
('00000000-0000-4000-8000-000000000001','2026-10-25','Visa Aeternum','legacy_fix86','evento_base:90','legacy_projection_adjusted',-120,'Bradesco'),
('00000000-0000-4000-8000-000000000001','2026-10-26','Other unpaid obligation','legacy_fix86','evento_base:91','legacy_projection_adjusted',-55,'Bradesco');
INSERT INTO v303_fixture.lts_card_documentary_payment_link_v272(user_id,invoice_source_id,payment_source_id,expected_due_date,active,institution_code,provider_item_id,invoice_account_ref,payment_account_ref,expected_amount,expected_closing_date,expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources)
VALUES('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000201','10000000-0000-4000-8000-000000000202','2026-10-25',true,'237','synthetic-item','synthetic-card','synthetic-checking',300,'2026-10-14','2026-10-27','synthetic-invoice-hash','synthetic-payment-hash','[{"basis":"synthetic issuer"},{"basis":"synthetic posted bank"}]');
INSERT INTO v303_fixture.lts_card_settlement_expense_contract_v273
SELECT l.user_id,l.payment_source_id,true,jsonb_build_object('active',true,'amount',l.expected_amount,'user_id',l.user_id,
 'invoice_id',l.invoice_source_id,'payment_id',l.payment_source_id,'link_contract',to_jsonb(l)-'created_at',
 'invoice_current_hash',inv.raw_hash,'invoice_evidence_policy','raw_except_updatedAt_v1','invoice_canonical_payload',inv.raw_payload-'updatedAt',
 'issuer_payments',inv.raw_payload->'payments','settlement_manifest',jsonb_build_array(inv.raw_payload->'payments'->0),
 'issuer_settlement_policy','one_full_payment_in_cycle_v301','coverage_mode','card_bank_closed_complete',
 'consumption_manifest','[{"id":"synthetic-purchase","signed_amount":-300}]'::jsonb)
FROM v303_fixture.lts_card_documentary_payment_link_v272 l JOIN v303_fixture.lts_open_finance_staging inv ON inv.user_id=l.user_id AND inv.id=l.invoice_source_id
WHERE l.payment_source_id='10000000-0000-4000-8000-000000000202';
CREATE TEMP TABLE v375_before AS SELECT v303_fixture.lts_recurring_future_gap_audit_v6('00000000-0000-4000-8000-000000000001','2026-10-29','2027-03-31')j;
CREATE TEMP TABLE v375_pending_before AS SELECT v303_fixture.lts_pending_projections_v233('00000000-0000-4000-8000-000000000001')j;
CREATE TEMP TABLE v375_source_snapshot AS SELECT jsonb_build_object('staging',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_open_finance_staging x),
 'legacy',(SELECT jsonb_agg(to_jsonb(x)ORDER BY idx)FROM v303_fixture.evento_base x),
 'links',(SELECT jsonb_agg(to_jsonb(x)ORDER BY payment_source_id)FROM v303_fixture.lts_card_documentary_payment_link_v272 x),
 'contracts',(SELECT jsonb_agg(to_jsonb(x)ORDER BY payment_source_id)FROM v303_fixture.lts_card_settlement_expense_contract_v273 x))j;
CREATE TEMP TABLE v375_attributes AS SELECT p.oid::regprocedure::text signature,to_jsonb(p)-'prosrc' attrs FROM pg_proc p WHERE p.oid IN('v303_fixture.lts_recurring_receipt_identities_v303(uuid,date)'::regprocedure,'v303_fixture.lts_pending_projections_v233(uuid)'::regprocedure);
''')
patch = (R/'backend/patches/v375/reviewed_aeternum_receipt_identity.sql').read_text().replace('public.', 'v303_fixture.')
patch = patch.replace('current_date','v303_fixture.v375_today()')
patch = patch.replace('md5(definition)',"md5(replace(replace(definition,'v303_fixture.','public.'),'public.v375_today()','current_date'))")
print(patch)
print(r'''
CREATE FUNCTION v303_fixture.v375_event()RETURNS jsonb LANGUAGE sql AS $$SELECT '{"source":"legacy_fix86","source_ref":"evento_base:90","event_date":"2026-10-25","description":"Visa Aeternum","account":"Bradesco","signed_amount":-120,"internal_transfer":false}'::jsonb$$;
DO $test$
DECLARE u uuid:='00000000-0000-4000-8000-000000000001';j jsonb;x jsonb;y jsonb;p jsonb;receipt jsonb;pending jsonb;
BEGIN
 receipt:=lts_receipt_private_v375.legacy_aeternum_receipt(u,v303_fixture.v375_event(),'2026-10-29');
 IF receipt->>'staging_id'<>'10000000-0000-4000-8000-000000000202'OR receipt->>'actual_date'<>'2026-10-27'
 OR(receipt->>'actual_amount')::numeric<>-300 OR(receipt->>'projection_amount')::numeric<>120 THEN RAISE EXCEPTION 'Different forecast and actual amounts confused';END IF;
 IF(SELECT count(*)FROM v303_fixture.lts_recurring_receipt_identities_v303(u,'2026-10-29')r WHERE r.series_key='card_aeternum'AND r.projection_ref='evento_base:90')<>1 THEN RAISE EXCEPTION 'Actual identity absent or duplicated';END IF;
 j:=v303_fixture.lts_recurring_future_gap_audit_v6(u,'2026-10-29','2027-03-31');
 FOR x IN SELECT value FROM jsonb_array_elements(j->'horizon_checks')LOOP
  SELECT value INTO STRICT y FROM v375_before b CROSS JOIN LATERAL jsonb_array_elements(b.j->'horizon_checks')WHERE value->>'key'=x->>'key';
  IF x->>'key'<>'card_aeternum'AND x IS DISTINCT FROM y THEN RAISE EXCEPTION 'Other series changed';END IF;
  IF x->>'key'='card_aeternum'THEN
   SELECT value INTO STRICT p FROM jsonb_array_elements(x->'period_coverage')WHERE value->>'period_start'='2026-10-01';
   IF p->>'status'<>'covered'OR p->>'actual_events'<>'1'OR p->>'unconfirmed_obligations'<>'0'THEN RAISE EXCEPTION 'False unconfirmed cycle remains: %',p;END IF;
   IF(SELECT jsonb_agg(v)FROM jsonb_array_elements(x->'period_coverage')v WHERE v->>'period_start'<>'2026-10-01')IS DISTINCT FROM(SELECT jsonb_agg(v)FROM jsonb_array_elements(y->'period_coverage')v WHERE v->>'period_start'<>'2026-10-01')THEN RAISE EXCEPTION 'November no-debit or future periods changed';END IF;
  END IF;
 END LOOP;
 pending:=v303_fixture.lts_pending_projections_v233(u);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(pending)e WHERE e->>'source_ref'='evento_base:90')OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(pending)e WHERE e->>'source_ref'='evento_base:91')THEN RAISE EXCEPTION 'Pending queue changed unrelated obligations';END IF;
 IF pending IS DISTINCT FROM(SELECT coalesce(jsonb_agg(e ORDER BY e->>'event_date',e->>'source_ref'),'[]')FROM v375_pending_before b CROSS JOIN LATERAL jsonb_array_elements(b.j)e WHERE e->>'source_ref'<>'evento_base:90')THEN RAISE EXCEPTION 'Pending metadata or other items changed';END IF;
 IF lts_receipt_private_v375.legacy_aeternum_receipt('00000000-0000-4000-8000-000000000002',v303_fixture.v375_event(),'2026-10-29')IS NOT NULL
 OR lts_receipt_private_v375.legacy_aeternum_receipt(u,v303_fixture.v375_event(),'2026-10-25')IS NOT NULL THEN RAISE EXCEPTION 'Owner or future receipt leak';END IF;
END $test$;
CREATE TEMP TABLE v375_reject(name text,mutation text);
INSERT INTO v375_reject VALUES
('inactive link',$q$UPDATE v303_fixture.lts_card_documentary_payment_link_v272 SET active=false WHERE payment_source_id='10000000-0000-4000-8000-000000000202'$q$),
('inactive contract',$q$UPDATE v303_fixture.lts_card_settlement_expense_contract_v273 SET active=false WHERE payment_source_id='10000000-0000-4000-8000-000000000202'$q$),
('pending bank raw',$q$UPDATE v303_fixture.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{status}','"PENDING"')WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('pending normalized',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{status}','"PENDING"')WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('changed bank hash',$q$UPDATE v303_fixture.lts_open_finance_staging SET raw_hash='changed'WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('wrong amount',$q$UPDATE v303_fixture.lts_open_finance_staging SET signed_amount=-301 WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('deleted payment',$q$UPDATE v303_fixture.lts_open_finance_staging SET provider_deleted_at=now()WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('foreign payment',$q$UPDATE v303_fixture.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000002'WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('unrelated card',$q$UPDATE v303_fixture.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{card_name}','"Unknown Visa"')WHERE id='10000000-0000-4000-8000-000000000201'$q$),
('wrong institution',$q$UPDATE v303_fixture.lts_open_finance_staging SET institution_code='341'WHERE id='10000000-0000-4000-8000-000000000201'$q$),
('future bank date',$q$UPDATE v303_fixture.lts_open_finance_staging SET posting_date='2026-11-27'WHERE id='10000000-0000-4000-8000-000000000202'$q$),
('issuer partial',$q$UPDATE v303_fixture.lts_open_finance_staging SET raw_payload=jsonb_set(raw_payload,'{payments,0,valueType}','"PARTIAL_PAYMENT"')WHERE id='10000000-0000-4000-8000-000000000201'$q$),
('wrong legacy bank',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{conta}','"Itaú"')WHERE idx=90$q$),
('changed forecast amount',$q$UPDATE v303_fixture.evento_base SET dados=jsonb_set(dados,'{valor}','121')WHERE idx=90$q$),
('ambiguous plans',$q$INSERT INTO v303_fixture.evento_base SELECT usuario_id,92,dados FROM v303_fixture.evento_base WHERE idx=90$q$),
('ambiguous links',$q$INSERT INTO v303_fixture.lts_card_documentary_payment_link_v272 SELECT *FROM v303_fixture.lts_card_documentary_payment_link_v272 WHERE payment_source_id='10000000-0000-4000-8000-000000000202'$q$),
('incomplete consumption',$q$UPDATE v303_fixture.lts_card_settlement_expense_contract_v273 SET payload=jsonb_set(payload,'{consumption_manifest}','[]')WHERE payment_source_id='10000000-0000-4000-8000-000000000202'$q$);
DO $test$DECLARE r record;p jsonb;BEGIN
 FOR r IN SELECT*FROM v375_reject LOOP
  BEGIN
   EXECUTE r.mutation;
   p:=lts_receipt_private_v375.legacy_aeternum_receipt('00000000-0000-4000-8000-000000000001',v303_fixture.v375_event(),'2026-10-29');
   IF p IS NOT NULL THEN RAISE EXCEPTION 'Unproved payment accepted: %',r.name;END IF;
   RAISE EXCEPTION USING ERRCODE='V3750',MESSAGE='rollback fixture mutation';
  EXCEPTION WHEN SQLSTATE'V3750'THEN NULL;END;
 END LOOP;
 FOR p IN SELECT v303_fixture.v375_event()||x FROM jsonb_array_elements('[{"account":"Itaú"},{"source_ref":"evento_base:999"},{"source":"current_event"},{"description":"Another Visa"},{"signed_amount":120},{"signed_amount":-121},{"event_date":"2026-10-26"},{"internal_transfer":true},{"internal_transfer":"invalid"}]')x LOOP
  IF lts_receipt_private_v375.legacy_aeternum_receipt('00000000-0000-4000-8000-000000000001',p,'2026-10-29')IS NOT NULL THEN RAISE EXCEPTION 'Foreign event accepted: %',p;END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM v375_attributes a JOIN pg_proc proc_meta ON proc_meta.oid=a.signature::regprocedure WHERE a.attrs IS DISTINCT FROM to_jsonb(proc_meta)-'prosrc')THEN RAISE EXCEPTION 'Existing attributes or ACL changed';END IF;
 IF has_schema_privilege('anon','lts_receipt_private_v375','USAGE')OR has_function_privilege('authenticated','lts_receipt_private_v375.legacy_aeternum_receipt(uuid,jsonb,date)','EXECUTE')THEN RAISE EXCEPTION 'Private receipt helper exposed';END IF;
 IF(SELECT j FROM v375_source_snapshot)IS DISTINCT FROM jsonb_build_object('staging',(SELECT jsonb_agg(to_jsonb(x)ORDER BY id)FROM v303_fixture.lts_open_finance_staging x),
 'legacy',(SELECT jsonb_agg(to_jsonb(x)ORDER BY idx)FROM v303_fixture.evento_base x),'links',(SELECT jsonb_agg(to_jsonb(x)ORDER BY payment_source_id)FROM v303_fixture.lts_card_documentary_payment_link_v272 x),
 'contracts',(SELECT jsonb_agg(to_jsonb(x)ORDER BY payment_source_id)FROM v303_fixture.lts_card_settlement_expense_contract_v273 x))THEN RAISE EXCEPTION 'Financial source mutated';END IF;
END $test$;
CREATE TEMP TABLE v375_replay AS SELECT epoch FROM v303_fixture.lts_read_cache_epoch_v242;
''')
print(patch)
print(r'''
DO $$BEGIN IF(SELECT epoch FROM v375_replay)IS DISTINCT FROM(SELECT epoch FROM v303_fixture.lts_read_cache_epoch_v242)THEN RAISE EXCEPTION 'Replay changed epoch';END IF;END$$;
SELECT jsonb_build_object('version',375,'pass',true,'invalid_sources',(SELECT count(*)FROM v375_reject),'foreign_events',9,
 'actual_receipt_dates_preserved',true,'legacy_amount_not_rewritten',true,'coverage_and_pending_readers_executed',true,
 'november_no_payment_and_future_preserved',true,'unrelated_pending_preserved',true,'sources_and_acl_preserved',true,'replay_noop',true);
ROLLBACK;
''')
