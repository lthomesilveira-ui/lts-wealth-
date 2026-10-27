CREATE OR REPLACE FUNCTION public.lts_card_operating_view_v3(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with b as (select public.lts_card_operating_view_v2(p_user_id,p_as_of) j),
     r as (select public.lts_card_classification_review_v2(p_user_id,100) j)
select (select j from b) || jsonb_build_object(
  'version','card-operating-v3-classification-parity',
  'classification_review',jsonb_build_object(
    'pending_groups',(select (j->>'pending_groups')::int from r),
    'pending_lines',(select (j->>'pending_lines')::int from r),
    'pending_value',(select (j->>'pending_value')::numeric from r),
    'safe_suggestion_groups',(select (j->>'safe_suggestion_groups')::int from r),
    'all_suggestion_groups',(select coalesce((j->>'all_suggestion_groups')::int,(j->>'safe_suggestion_groups')::int) from r)
  )
);
$function$
