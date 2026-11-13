CREATE OR REPLACE FUNCTION public.lts_browser_flow_event_editor_v1(p_source text, p_source_ref text, p_event_date date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$ declare u uuid; begin u:=public.lts_browser_assert_user_v1(); return public.lts_flow_event_editor_v1(u,p_source,p_source_ref,p_event_date); end $function$
