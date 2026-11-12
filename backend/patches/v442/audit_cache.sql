-- Derived result only; public access remains behind the existing owner guard.
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.audit_guard_v442(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
SELECT jsonb_build_object('user_id',p_user_id,'as_of',current_date,
 'source_epoch',(SELECT epoch::text FROM public.lts_read_cache_epoch_v242 WHERE singleton=true),
 'card_source_key',lts_product_refresh_private_v415.card_source_key(p_user_id),
 'audit_definition',md5(pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure)),
 'review_inputs',(SELECT coalesce(jsonb_agg(jsonb_build_array(chave,sha256,md5(valor_bruto)) ORDER BY chave),'[]'::jsonb)
 FROM public.legacy_namespace WHERE usuario_id=p_user_id
 AND chave IN('lts_owner_projection_policy_v412','lts_projection_reference_v412','lts_recurring_review_scope_v410')))
$fn$;
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.read_audit_cache_v442(p_user_id uuid,p_as_of date,p_horizon_end date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
SELECT m.j->'payload' FROM public.lts_product_read_cache c
JOIN lts_product_refresh_private_v415.queue q ON q.user_id=c.user_id
CROSS JOIN LATERAL(SELECT c.payload->'recurring_audit_v442' j)m
WHERE c.user_id=p_user_id AND p_as_of=current_date
AND q.state='ready' AND q.completed_version=q.request_version
AND m.j->>'request_version'=q.completed_version::text
AND m.j->'guard'=lts_product_refresh_private_v415.audit_guard_v442(p_user_id)
AND m.j#>>'{payload,as_of}'=p_as_of::text
AND m.j#>>'{payload,future_horizon_end}'=p_horizon_end::text
AND jsonb_typeof(m.j->'payload')='object'
AND jsonb_typeof(m.j#>'{payload,horizon_checks}')='array'
AND m.j->>'digest'=encode(sha256(convert_to((m.j->'payload')::text,'UTF8')),'hex')
$fn$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.audit_guard_v442(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.read_audit_cache_v442(uuid,date,date) FROM PUBLIC,anon,authenticated;
-- Same existing RPC and authorization; the complete original audit is the fallback.
CREATE OR REPLACE FUNCTION public.lts_browser_recurring_future_gap_audit_v5(p_as_of date DEFAULT CURRENT_DATE,p_horizon_end date DEFAULT '2031-12-31')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();c jsonb;d date:=coalesce(p_as_of,(now() AT TIME ZONE 'America/Sao_Paulo')::date);h date:=coalesce(p_horizon_end,date '2031-12-31');
BEGIN
 c:=lts_product_refresh_private_v415.read_audit_cache_v442(u,d,h);
 IF c IS NOT NULL THEN RETURN c;END IF;
 RETURN public.lts_recurring_future_gap_audit_v6(u,d,h);
END $fn$;
