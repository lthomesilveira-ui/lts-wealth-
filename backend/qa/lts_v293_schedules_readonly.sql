-- Supply lts.qa_user_id through the authorized administrative session.
-- Source/account details are intentionally not returned.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
SELECT jsonb_build_object(
'confirmed_schedules',(SELECT count(*) FROM public.lts_confirmed_bank_transfer_schedules_v293(current_setting('lts.qa_user_id')::uuid)),
'projection_legs',(SELECT count(*) FROM public.lts_flow_projected_transfer_legs_v293(current_setting('lts.qa_user_id')::uuid,current_date,current_date+365)
 WHERE confidence='bank_scheduled_owner_confirmed_v293'),
'consolidated_effect',(SELECT coalesce(sum(signed_amount),0) FROM public.lts_flow_projected_transfer_legs_v293(current_setting('lts.qa_user_id')::uuid,current_date,current_date+365)
 WHERE confidence='bank_scheduled_owner_confirmed_v293'),
'historical_projection_legs',(SELECT count(*) FROM public.lts_flow_projected_transfer_legs_v293(current_setting('lts.qa_user_id')::uuid,current_date-60,current_date-1)
 WHERE confidence='bank_scheduled_owner_confirmed_v293'),
'private_helpers_denied',NOT has_function_privilege('authenticated','public.lts_confirmed_bank_transfer_schedules_v293(uuid)','EXECUTE')
 AND NOT has_function_privilege('anon','public.lts_flow_projected_transfer_legs_v293(uuid,date,date)','EXECUTE'),
'public_endpoint_denies_anon',NOT has_function_privilege('anon','public.lts_browser_future_bank_v293(date,date)','EXECUTE')
) verification;
ROLLBACK;
