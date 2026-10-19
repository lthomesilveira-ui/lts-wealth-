CREATE OR REPLACE FUNCTION public.lts_future_bank_identity_v290(p_user_id uuid,p_staging_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $f$
WITH s AS MATERIALIZED(SELECT * FROM public.lts_open_finance_staging
 WHERE user_id=p_user_id AND id=p_staging_id AND resource_type='transaction'
 AND provider_deleted_at IS NULL AND normalized_payload->>'status'='PENDING' AND posting_date>current_date),
owned AS(SELECT EXISTS(SELECT 1 FROM s JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id
 AND b.resource_type='balance' AND b.provider_account_ref=s.provider_account_ref AND b.provider_deleted_at IS NULL
 WHERE s.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(coalesce(b.raw_payload->>'taxNumber',''),'[^0-9]','','g')~'^[0-9]{11}$'
 AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')=regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g')
 AND regexp_replace(b.raw_payload->>'taxNumber','[^0-9]','','g')=regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')) yes),
plans AS MATERIALIZED(SELECT f.legacy_id,f.id,f.description_raw,f.category FROM s
 JOIN public.financial_events f ON f.user_id=s.user_id AND f.event_date=s.posting_date AND f.amount=s.signed_amount
 JOIN public.accounts a ON a.user_id=f.user_id AND a.id=f.account_id
 AND public.lts_v178_norm(a.institution)=public.lts_v178_norm(s.institution_name)
 WHERE f.is_projection AND NOT f.is_suppressed AND NOT f.is_internal_transfer AND f.status IN('scheduled','expected')
 AND f.metadata->>'bank_scheduled_received'='true' AND f.metadata->>'schedule_confirmed_on' IS NOT NULL
 AND jsonb_array_length(coalesce(f.metadata->'schedule_evidence_files','[]'))>0)
SELECT jsonb_build_object('kind',CASE WHEN owned.yes THEN 'own_transfer' ELSE 'scheduled_obligation' END,
 'own_identity_proven',owned.yes,'represented_in_flow',NOT owned.yes AND (SELECT count(*)=1 FROM plans),
 'projection_ref',CASE WHEN NOT owned.yes AND (SELECT count(*)=1 FROM plans) THEN (SELECT coalesce(legacy_id,id::text) FROM plans) END,
 'projection_description',CASE WHEN NOT owned.yes AND (SELECT count(*)=1 FROM plans) THEN (SELECT description_raw FROM plans) END,
 'basis',CASE WHEN owned.yes THEN 'source_owner_and_both_counterparty_taxpayer_identities_equal'
 WHEN (SELECT count(*)=1 FROM plans) THEN 'unique_exact_dated_account_amount_and_prior_documented_bank_schedule'
 ELSE 'unlinked_or_ambiguous' END) FROM owned
$f$;
REVOKE ALL ON FUNCTION public.lts_future_bank_identity_v290(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_future_bank_identity_v290(uuid,uuid) TO service_role;
DO $api$ DECLARE d text; BEGIN
 SELECT pg_get_functiondef('public.lts_browser_future_bank_v290(date,date)'::regprocedure) INTO d;
 IF position($a$'included_in_realized',false,'included_in_flow_totals',false,'link_status','review_required'$a$ IN d)=0
 THEN RAISE EXCEPTION 'Future source reader changed'; END IF;
 d:=replace(d,$a$'included_in_realized',false,'included_in_flow_totals',false,'link_status','review_required'$a$,
 $b$'included_in_realized',false,'included_in_flow_totals',(public.lts_future_bank_identity_v290(u,s.id)->>'represented_in_flow')::boolean,
 'identity',public.lts_future_bank_identity_v290(u,s.id),'link_status',CASE WHEN public.lts_future_bank_identity_v290(u,s.id)->>'represented_in_flow'='true' THEN 'already_represented'
 WHEN public.lts_future_bank_identity_v290(u,s.id)->>'own_identity_proven'='true' THEN 'own_transfer_destination_review' ELSE 'review_required' END$b$);
 EXECUTE d;
END $api$;
