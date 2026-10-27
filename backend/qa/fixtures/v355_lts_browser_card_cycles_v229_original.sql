CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v229()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; cards jsonb;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_card_cycles_v226();
 WITH source_dates AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 max(coalesce(nullif(s.normalized_payload->>'as_of',''),nullif(s.normalized_payload->>'provider_updated_at',''),nullif(s.raw_payload->>'updatedAt',''))::timestamptz) source_updated_at,
 max(s.last_seen_at) received_at
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL GROUP BY 1
 ) SELECT jsonb_agg(c||jsonb_build_object('source_updated_at',sd.source_updated_at,'received_at',sd.received_at,'source_time_basis','provider_resource_update')||jsonb_build_object('document_source_as_of',doc.as_of,'document_source_file',doc.source_file,'documented_supplement_items',doc.n)||CASE WHEN hint.amount IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(c->'cycles','[]'::jsonb)) q
 WHERE q->>'month'=((date_trunc('month',current_date)+interval '1 month')::date)::text) THEN jsonb_build_object(
 'cycles',coalesce(c->'cycles','[]'::jsonb)||jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',
 CASE WHEN c->>'last_due' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
 make_date(extract(year FROM current_date+interval '1 month')::int,extract(month FROM current_date+interval '1 month')::int,
 least(extract(day FROM (c->>'last_due')::date)::int,extract(day FROM date_trunc('month',current_date)+interval '2 months -1 day')::int)) END,
 'due_date_basis','estimate_from_received_due_day',
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN source_dates sd ON sd.family=c->>'family'
 LEFT JOIN LATERAL(SELECT max(d.source_as_of) as_of,min(d.source_file_ref) source_file,count(*) n
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.family=c->>'family'
 AND d.reference_month=date_trunc('month',current_date)::date) doc ON true
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_card_documentary_payment_presentation_v272(u,j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true)));
END $function$
