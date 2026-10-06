BEGIN;SET LOCAL statement_timeout='30s';
CREATE FUNCTION pg_temp.pair_probe_v258(p_rows jsonb,p_owned jsonb,p_owner uuid) RETURNS TABLE(debit_id uuid,credit_id uuid) LANGUAGE sql AS $probe$ WITH posted AS MATERIALIZED (
 SELECT tx_s.*,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf
 FROM jsonb_populate_recordset(NULL::public.lts_open_finance_staging,p_rows) tx_s
 WHERE tx_s.user_id=p_owner AND tx_s.resource_type='transaction'
 AND tx_s.currency='BRL' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'status'='POSTED'
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
), owned_identity AS MATERIALIZED (
 SELECT DISTINCT tx_s.institution_code,tx_s.provider_account_ref,
 regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM jsonb_populate_recordset(NULL::public.lts_open_finance_staging,p_owned) tx_s
 WHERE tx_s.user_id=p_owner AND tx_s.resource_type='balance' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(tx_s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
), eligible_pairs AS MATERIALIZED (
 SELECT tx_d.id debit_id,tx_c.id credit_id
 FROM posted tx_d JOIN posted tx_c ON tx_c.user_id=tx_d.user_id
 AND tx_c.posting_date=tx_d.posting_date AND tx_c.signed_amount=-tx_d.signed_amount
 AND tx_c.institution_code<>tx_d.institution_code
 JOIN owned_identity od ON od.institution_code=tx_d.institution_code
 AND od.provider_account_ref=tx_d.provider_account_ref AND od.cpf=tx_d.payer_cpf
 JOIN owned_identity oc ON oc.institution_code=tx_c.institution_code
 AND oc.provider_account_ref=tx_c.provider_account_ref AND oc.cpf=tx_c.receiver_cpf
 WHERE tx_d.signed_amount<0 AND tx_c.signed_amount>0
 AND tx_d.institution_code IN ('341','237','336') AND tx_c.institution_code IN ('341','237','336')
 AND tx_d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_d.payer_cpf~'^[0-9]{11}$' AND tx_d.payer_cpf=tx_d.receiver_cpf
 AND tx_c.payer_cpf=tx_d.payer_cpf AND tx_c.receiver_cpf=tx_d.receiver_cpf
 AND tx_d.raw_payload#>>'{paymentData,receiver,routingNumber}'=tx_c.institution_code
 AND tx_c.raw_payload#>>'{paymentData,payer,routingNumber}'=tx_d.institution_code
), counted_pairs AS (
 SELECT *,count(*) OVER(PARTITION BY debit_id) debit_count,
 count(*) OVER(PARTITION BY credit_id) credit_count FROM eligible_pairs
), own_pairs AS MATERIALIZED (
 SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
) SELECT * FROM own_pairs $probe$;
DO $cases$ DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();p record;d jsonb;c jsonb;o jsonb;records jsonb;alt jsonb;n int;receipt jsonb:='{}';BEGIN
 SELECT * INTO p FROM (WITH posted AS MATERIALIZED (
 SELECT tx_s.*,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf
 FROM public.lts_bank_posted_rows_v231(u) tx_s
), owned_identity AS MATERIALIZED (
 SELECT DISTINCT tx_s.institution_code,tx_s.provider_account_ref,
 regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging tx_s
 WHERE tx_s.user_id=u AND tx_s.resource_type='balance' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(tx_s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
), eligible_pairs AS MATERIALIZED (
 SELECT tx_d.id debit_id,tx_c.id credit_id
 FROM posted tx_d JOIN posted tx_c ON tx_c.user_id=tx_d.user_id
 AND tx_c.posting_date=tx_d.posting_date AND tx_c.signed_amount=-tx_d.signed_amount
 AND tx_c.institution_code<>tx_d.institution_code
 JOIN owned_identity od ON od.institution_code=tx_d.institution_code
 AND od.provider_account_ref=tx_d.provider_account_ref AND od.cpf=tx_d.payer_cpf
 JOIN owned_identity oc ON oc.institution_code=tx_c.institution_code
 AND oc.provider_account_ref=tx_c.provider_account_ref AND oc.cpf=tx_c.receiver_cpf
 WHERE tx_d.signed_amount<0 AND tx_c.signed_amount>0
 AND tx_d.institution_code IN ('341','237','336') AND tx_c.institution_code IN ('341','237','336')
 AND tx_d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_d.payer_cpf~'^[0-9]{11}$' AND tx_d.payer_cpf=tx_d.receiver_cpf
 AND tx_c.payer_cpf=tx_d.payer_cpf AND tx_c.receiver_cpf=tx_d.receiver_cpf
 AND tx_d.raw_payload#>>'{paymentData,receiver,routingNumber}'=tx_c.institution_code
 AND tx_c.raw_payload#>>'{paymentData,payer,routingNumber}'=tx_d.institution_code
), counted_pairs AS (
 SELECT *,count(*) OVER(PARTITION BY debit_id) debit_count,
 count(*) OVER(PARTITION BY credit_id) credit_count FROM eligible_pairs
), own_pairs AS MATERIALIZED (
 SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
) SELECT pair_row.* FROM own_pairs pair_row JOIN posted t ON t.id=pair_row.debit_id WHERE t.posting_date=current_date-1 AND t.signed_amount<0 ORDER BY t.id LIMIT 1) chosen;
 IF p.debit_id IS NULL THEN RAISE EXCEPTION 'V258_TRANSFER_NO_LIVE_FIXTURE';END IF;
 SELECT to_jsonb(s) INTO d FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=p.debit_id;
 SELECT to_jsonb(s) INTO c FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=p.credit_id;
 SELECT jsonb_agg(to_jsonb(s)) INTO o FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='balance';
 records:=jsonb_build_array(d,c);
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(records,o,u);
 IF n<>1 THEN RAISE EXCEPTION 'V258_TRANSFER_POSITIVE_FAILED';END IF;receipt:=receipt||jsonb_build_object('positive',n);
 alt:=jsonb_set(c,'{raw_payload,paymentData,payer,documentNumber,value}','"invalid"');
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_CPF_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('invalid_cpf',n);
 alt:=jsonb_set(c,'{raw_payload,paymentData,payer,routingNumber}','"000"');
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_BANK_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('wrong_bank',n);
 alt:=jsonb_set(c,'{normalized_payload,status}','"PENDING"');
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_PENDING_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('pending_leg',n);
 alt:=jsonb_set(c,'{user_id}',to_jsonb('00000000-0000-0000-0000-000000000001'::text));
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_OWNER_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('other_owner',n);
 alt:=jsonb_set(c,'{id}',to_jsonb('00000000-0000-0000-0000-000000000002'::text));
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,c,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_AMBIGUOUS_CREDIT_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('duplicate_credit',n);
 alt:=jsonb_set(d,'{id}',to_jsonb('00000000-0000-0000-0000-000000000003'::text));
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(jsonb_build_array(d,c,alt),o,u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_AMBIGUOUS_DEBIT_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('duplicate_debit',n);
 SELECT count(*) INTO n FROM pg_temp.pair_probe_v258(records,'[]',u);
 IF n<>0 THEN RAISE EXCEPTION 'V258_TRANSFER_NO_ACCOUNT_REJECTION_FAILED';END IF;receipt:=receipt||jsonb_build_object('no_owned_balance_identity',n);
 PERFORM set_config('lts.v258_pair_cases',receipt::text,true);
END $cases$;
SELECT current_setting('lts.v258_pair_cases')::jsonb receipt;ROLLBACK;
