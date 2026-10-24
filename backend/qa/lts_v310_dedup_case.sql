BEGIN;
UPDATE public.financial_events SET is_projection=false,status='confirmed',event_date='2020-10-06'
 WHERE id='00000000-0000-4000-8000-000000000502';
UPDATE public.lts_open_finance_staging SET description_raw=description_raw||' volvo_financing_2026'
 WHERE id='00000000-0000-4000-8000-000000000602';
INSERT INTO public.lts_realized_bank_event_v238(user_id,financial_event_id,staging_id,bank,expected_date,expected_amount,evidence)
 VALUES('00000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000502',
 '00000000-0000-4000-8000-000000000602','Bradesco','2020-10-06',-25,'{"contract_ref":"volvo_financing_2026"}');
DO $check$ DECLARE s jsonb;BEGIN
 s:=public.lts_commitment_read_state_v309('00000000-0000-4000-8000-000000000001','2020-10-24');
 IF s#>>'{volvo,confirmed_loaded_paid_count}'<>'1' OR s#>>'{volvo,confirmed_loaded_paid_total}'<>'25'
 THEN RAISE EXCEPTION 'Same physical payment counted twice';END IF;
END $check$;
ROLLBACK;
