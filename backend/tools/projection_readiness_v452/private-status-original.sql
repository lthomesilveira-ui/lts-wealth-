CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.status(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE q lts_product_refresh_private_v415.queue%ROWTYPE; c jsonb; s text; need boolean;
BEGIN
 c:=lts_product_refresh_private_v415.cache_info(p_user_id);
 SELECT * INTO q FROM lts_product_refresh_private_v415.queue WHERE user_id=p_user_id;
 need:=NOT coalesce((c->>'current')::boolean,false)
  OR coalesce(q.completed_version<q.request_version,false)
  OR coalesce(q.state IN ('pending','running','failed'),false);
 s:=CASE WHEN NOT need THEN 'ready' WHEN q.state IN ('pending','running','failed') THEN q.state ELSE 'pending' END;
 RETURN jsonb_build_object('state',s,'required',need,
  'cached_available',coalesce((c->>'available')::boolean,false),
  'request_version',coalesce(q.request_version,0)::text,'completed_version',coalesce(q.completed_version,0)::text,
  'attempts',coalesce(q.attempts,0),'requested_at',q.requested_at,'started_at',q.started_at,
  'completed_at',q.completed_at,'next_attempt_at',q.next_attempt_at,'error_code',q.last_error_code,
  'cached_refreshed_at',c->'refreshed_at','server_today',current_date);
END $function$
