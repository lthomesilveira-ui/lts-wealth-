-- A different numbered debit of the same proved contract needs no invented confirmation.
BEGIN;
UPDATE public.financial_events SET metadata=metadata||'{"account_assignment_status":"user_confirmed","account_assignment":"Bradesco","installments_total":3}'::jsonb
 WHERE id='00000000-0000-4000-8000-000000000501';
INSERT INTO public.lts_open_finance_staging(id,user_id,posting_date,signed_amount,currency,resource_type,normalized_payload,
 institution_code,description_raw,raw_hash,occurred_at,provider_account_ref) VALUES
 ('00000000-0000-4000-8000-000000000601','00000000-0000-4000-8000-000000000001','2020-09-06',-15,'BRL','transaction',
 '{"status":"POSTED","account_type":"CHECKING_ACCOUNT","provider_account_id":"synthetic-checking"}',
 '237','CONTR 000123 PARC 001/003 - synthetic earlier installment',repeat('c',64),'2020-09-06T10:00:00Z','synthetic-checking');
DO $check$ DECLARE s jsonb;BEGIN
 s:=public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24');
 IF s#>>'{volvo,confirmed_loaded_paid_count}'<>'2' OR s#>>'{volvo,unconfirmed_past_count}'<>'0'
 OR s#>>'{volvo,future_count}'<>'1' OR s#>>'{volvo,confirmed_loaded_paid_total}'<>'40'
 THEN RAISE EXCEPTION 'Earlier exact numbered installment was lost';END IF;
 IF (SELECT count(*) FROM public.lts_v229_documentary_match)<>1 THEN RAISE EXCEPTION 'An owner confirmation was invented';END IF;
END $check$;
-- Same amount on another contract is insufficient.
UPDATE public.lts_open_finance_staging SET description_raw='CONTR 000999 PARC 001/003'
 WHERE id='00000000-0000-4000-8000-000000000601';
DO $check$ BEGIN
 IF (public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24')#>>'{volvo,confirmed_loaded_paid_count}')<>'1'
 THEN RAISE EXCEPTION 'Another bank contract was attributed';END IF;
END $check$;
ROLLBACK;
