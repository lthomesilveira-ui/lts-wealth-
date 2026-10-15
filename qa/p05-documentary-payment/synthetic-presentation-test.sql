BEGIN;
SET LOCAL statement_timeout='10s';
SET LOCAL lock_timeout='2s';
SET LOCAL TIME ZONE 'America/Sao_Paulo';
CREATE TEMP TABLE lts_open_finance_staging(id uuid,user_id uuid,resource_type text,provider_deleted_at timestamptz,institution_code text,provider_record_id text,provider_account_ref text,currency text,signed_amount numeric,normalized_payload jsonb,raw_payload jsonb,posting_date date,raw_hash text);
CREATE TABLE pg_temp.lts_card_documentary_payment_link_v272 (
 id uuid PRIMARY KEY,
 user_id uuid NOT NULL,
 invoice_source_id uuid NOT NULL,
 payment_source_id uuid NOT NULL,
 institution_code text NOT NULL,
 provider_item_id text NOT NULL,
 invoice_account_ref text NOT NULL,
 payment_account_ref text NOT NULL,
 expected_amount numeric(18,2) NOT NULL CHECK(expected_amount>0),
 expected_due_date date NOT NULL,
 expected_closing_date date NOT NULL,
 expected_payment_date date NOT NULL,
 invoice_raw_hash text NOT NULL,
 payment_raw_hash text NOT NULL,
 documentary_sources jsonb NOT NULL CHECK(jsonb_typeof(documentary_sources)='array' AND jsonb_array_length(documentary_sources)>=2),
 active boolean NOT NULL DEFAULT true,
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(invoice_source_id<>payment_source_id),
 CHECK(expected_payment_date>expected_closing_date)
);
CREATE UNIQUE INDEX lts_v272_one_invoice_link ON pg_temp.lts_card_documentary_payment_link_v272(user_id,invoice_source_id) WHERE active;
CREATE UNIQUE INDEX lts_v272_one_payment_link ON pg_temp.lts_card_documentary_payment_link_v272(user_id,payment_source_id) WHERE active;

CREATE FUNCTION pg_temp.lts_card_documentary_payment_presentation_v272(p_user_id uuid,p_payload jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path TO '' SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH links AS MATERIALIZED (
 SELECT l.id,l.invoice_source_id,l.expected_amount,l.expected_payment_date,l.expected_due_date,
 coalesce(
   b.id IS NOT NULL AND t.id IS NOT NULL
   AND b.resource_type='invoice' AND t.resource_type='transaction'
   AND b.provider_deleted_at IS NULL AND t.provider_deleted_at IS NULL
   AND b.institution_code=l.institution_code AND t.institution_code=l.institution_code
   AND split_part(b.provider_record_id,':',1)=l.provider_item_id
   AND split_part(t.provider_record_id,':',1)=l.provider_item_id
   AND b.provider_account_ref=l.invoice_account_ref
   AND t.provider_account_ref=l.payment_account_ref
   AND b.currency='BRL' AND t.currency='BRL'
   AND b.signed_amount=l.expected_amount AND t.signed_amount=-l.expected_amount
   AND b.normalized_payload->>'due_date'=l.expected_due_date::text
   AND b.normalized_payload->>'closing_date'=l.expected_closing_date::text
   AND t.posting_date=l.expected_payment_date
   AND t.normalized_payload->>'status'='POSTED' AND t.raw_payload->>'status'='POSTED'
   AND l.expected_payment_date<=current_date
   AND b.raw_hash=l.invoice_raw_hash AND t.raw_hash=l.payment_raw_hash,false) valid
 FROM pg_temp.lts_card_documentary_payment_link_v272 l
 LEFT JOIN pg_temp.lts_open_finance_staging b ON b.id=l.invoice_source_id AND b.user_id=p_user_id
 LEFT JOIN pg_temp.lts_open_finance_staging t ON t.id=l.payment_source_id AND t.user_id=p_user_id
 WHERE l.user_id=p_user_id AND l.active
), cards AS (
 SELECT c.ord,CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value||jsonb_build_object('cycles',coalesce((
 SELECT jsonb_agg((y.value-'documentary_payment_evidence')||CASE WHEN l.id IS NULL THEN '{}'::jsonb
 WHEN l.valid AND y.value->>'due_date'=l.expected_due_date::text AND CASE WHEN y.value->>'amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (y.value->>'amount')::numeric=l.expected_amount ELSE false END THEN jsonb_build_object('documentary_payment_evidence',jsonb_build_object(
 'status','identified_in_statement','basis','reviewed_documentary_alias_and_posted_bank_transaction',
 'payment_date',l.expected_payment_date,'amount',l.expected_amount,'currency','BRL','cash_effect','none'))
 ELSE jsonb_build_object('documentary_payment_evidence',jsonb_build_object('status','source_changed','cash_effect','none')) END ORDER BY y.ord)
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(c.value->'cycles')='array' THEN c.value->'cycles' ELSE '[]'::jsonb END) WITH ORDINALITY y(value,ord)
 LEFT JOIN links l ON l.invoice_source_id::text=y.value->>'invoice_source_id'
 ),'[]'::jsonb)) ELSE c.value END value
 FROM jsonb_array_elements(CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN p_payload->'cards' ELSE '[]'::jsonb END) WITH ORDINALITY c(value,ord)
)
SELECT CASE WHEN jsonb_typeof(p_payload->'cards')='array' THEN
jsonb_set(p_payload,'{cards}',coalesce((SELECT jsonb_agg(value ORDER BY ord) FROM cards),'[]'::jsonb),false)
ELSE p_payload END
$function$;

INSERT INTO pg_temp.lts_open_finance_staging VALUES
('00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000001','invoice',NULL,'999','synthetic-item:invoice','synthetic-card','BRL',100,jsonb_build_object('due_date',(current_date-2)::text,'closing_date',(current_date-10)::text),'{}',current_date-2,'invoice-hash'),
('00000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000001','transaction',NULL,'999','synthetic-item:payment','synthetic-bank','BRL',-100,'{"status":"POSTED"}','{"status":"POSTED"}',current_date-1,'payment-hash');
INSERT INTO pg_temp.lts_card_documentary_payment_link_v272 VALUES
('00000000-0000-4000-8000-000000000004','00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000003','999','synthetic-item','synthetic-card','synthetic-bank',100,current_date-2,current_date-10,current_date-1,'invoice-hash','payment-hash','[{"source":"synthetic-document-1"},{"source":"synthetic-document-2"}]',true,now());
CREATE TEMP TABLE payload(data jsonb);
INSERT INTO payload VALUES ('{"complete":true,"cards":[{"family":"synthetic-a","cycles":[{"invoice_source_id":"00000000-0000-4000-8000-000000000002","amount":100,"payment_status":"payment_not_reported","due_date":"2030-01-12"}]},{"family":"synthetic-b","cycles":[{"amount":55,"payment_status":"paid"}]}]}');
UPDATE pg_temp.payload SET data=jsonb_set(data,'{cards,0,cycles,0,due_date}',to_jsonb((current_date-2)::text));
DO $test$
DECLARE p jsonb:=(SELECT data FROM pg_temp.payload); r jsonb; original jsonb; c record; failed boolean;
BEGIN
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'identified_in_statement' THEN RAISE EXCEPTION 'valid evidence rejected'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'non-presentation payload changed'; END IF;
 original:=r;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',r) IS DISTINCT FROM r THEN RAISE EXCEPTION 'helper not idempotent'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000099',p) IS DISTINCT FROM p THEN RAISE EXCEPTION 'cross-owner leak'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001','{"cards":null}') IS DISTINCT FROM '{"cards":null}'::jsonb THEN RAISE EXCEPTION 'null shape changed'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001','{"cards":[{"family":"b"}]}') IS DISTINCT FROM '{"cards":[{"family":"b"}]}'::jsonb THEN RAISE EXCEPTION 'missing cycle shape changed'; END IF;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET currency='USD' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 0 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 0 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET signed_amount=-99 WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 1 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 1 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET signed_amount=100 WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 2 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 2 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET institution_code='998' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 3 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 3 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET provider_account_ref='other-bank' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 4 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 4 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET provider_record_id='other-item:payment' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 5 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 5 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET raw_hash='changed' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 6 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 6 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 7 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 7 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET normalized_payload='{"status":"PENDING"}' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 8 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 8 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET raw_payload='{"status":"PENDING"}' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 9 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 9 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET posting_date=current_date WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 10 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 10 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE id='00000000-0000-4000-8000-000000000003';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 11 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 11 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET raw_hash='changed' WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 12 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 12 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET signed_amount=99 WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 13 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 13 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET provider_account_ref='other-card' WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 14 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 14 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET user_id='00000000-0000-4000-8000-000000000099' WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 15 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 15 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET provider_deleted_at=now() WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 16 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 16 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{due_date}',to_jsonb((current_date-3)::text)) WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 17 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 17 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET normalized_payload=jsonb_set(normalized_payload,'{closing_date}',to_jsonb((current_date-11)::text)) WHERE id='00000000-0000-4000-8000-000000000002';
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'invalid case 18 accepted'; END IF;
 IF (r#-'{cards,0,cycles,0,documentary_payment_evidence}') IS DISTINCT FROM p THEN RAISE EXCEPTION 'invalid case 18 changed financial payload'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;

 BEGIN
 UPDATE pg_temp.lts_open_finance_staging SET posting_date=current_date+1 WHERE resource_type='transaction';
 UPDATE pg_temp.lts_card_documentary_payment_link_v272 SET expected_payment_date=current_date+1;
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p);
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'future payment accepted'; END IF;
 RAISE EXCEPTION USING ERRCODE='P0099',MESSAGE='restore synthetic case';
 EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL; END;
 FOR c IN SELECT path,value FROM (VALUES ('amount','99'::jsonb),('due_date',to_jsonb((current_date-3)::text))) x(path,value) LOOP
 r:=pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',jsonb_set(p,ARRAY['cards','0','cycles','0',c.path],c.value));
 IF r#>>'{cards,0,cycles,0,documentary_payment_evidence,status}' IS DISTINCT FROM 'source_changed' THEN RAISE EXCEPTION 'cycle mismatch accepted'; END IF;
 END LOOP;
 failed:=false;
 BEGIN
 INSERT INTO pg_temp.lts_card_documentary_payment_link_v272 SELECT '00000000-0000-4000-8000-000000000005'::uuid,user_id,invoice_source_id,payment_source_id,institution_code,provider_item_id,invoice_account_ref,payment_account_ref,expected_amount,expected_due_date,expected_closing_date,expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources,active,created_at FROM pg_temp.lts_card_documentary_payment_link_v272;
 EXCEPTION WHEN unique_violation THEN failed:=true; END;
 IF NOT failed THEN RAISE EXCEPTION 'duplicate association allowed'; END IF;
 FOR c IN SELECT 'invoice_source_id' col UNION ALL SELECT 'payment_source_id' LOOP
 failed:=false;
 BEGIN
 EXECUTE format('INSERT INTO pg_temp.lts_card_documentary_payment_link_v272 SELECT ''00000000-0000-4000-8000-000000000005''::uuid,user_id,%s,%s,institution_code,provider_item_id,invoice_account_ref,payment_account_ref,expected_amount,expected_due_date,expected_closing_date,expected_payment_date,invoice_raw_hash,payment_raw_hash,documentary_sources,active,created_at FROM pg_temp.lts_card_documentary_payment_link_v272',CASE WHEN c.col='invoice_source_id' THEN '$$00000000-0000-4000-8000-000000000099$$::uuid' ELSE 'invoice_source_id' END,CASE WHEN c.col='payment_source_id' THEN '$$00000000-0000-4000-8000-000000000099$$::uuid' ELSE 'payment_source_id' END);
 EXCEPTION WHEN unique_violation THEN failed:=true; END;
 IF NOT failed THEN RAISE EXCEPTION 'independent unique index missing: %',c.col; END IF;
 END LOOP;
 UPDATE pg_temp.lts_card_documentary_payment_link_v272 SET active=false;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',p) IS DISTINCT FROM p THEN RAISE EXCEPTION 'inactive evidence visible'; END IF;
 IF pg_temp.lts_card_documentary_payment_presentation_v272('00000000-0000-4000-8000-000000000001',original) IS DISTINCT FROM p THEN RAISE EXCEPTION 'stale prior annotation retained'; END IF;
END $test$;
SELECT 'PASS: documentary presentation contract; synthetic dependencies; no real source or cash changes' result;
ROLLBACK;
