-- Replace only the two reviewed function bodies. Signatures, language, owner,
-- SECURITY DEFINER, TimeZone, search_path and ACL remain as installed.
DO $install$
DECLARE target oid;before_definition text;new_definition text;body text;old_md5 text;
 signature text;new_body text;prior_acl aclitem[];prior_owner oid;prior_config text[];
 prior_security boolean;current_body text;
BEGIN
 FOR signature,old_md5,new_body IN
 SELECT * FROM(VALUES
 ('public.lts_corrected_cashflow_operational_v1(uuid,date,date)',
  '0a687b1bf642ab20cdadfb96ec0f0bed',
  $flow$
-- lts-projection-v412: add derived future budget residuals once.
WITH baseline AS MATERIALIZED (
 SELECT * FROM lts_projection_private_v412.base_flow(p_user_id,p_from,p_to)
), projection AS MATERIALIZED (
 SELECT CASE WHEN p_to>current_date AND p_from<=lts_projection_private_v412.horizon_end(current_date)
  THEN lts_projection_private_v412.build(p_user_id,current_date)
  ELSE '{}'::jsonb END AS data
)
SELECT b.* FROM baseline b CROSS JOIN projection p
WHERE NOT(b.event_date>current_date AND coalesce(p.data->'replacement_refs','[]'::jsonb) ? b.source_ref)
UNION ALL
SELECT x.* FROM projection p
CROSS JOIN LATERAL jsonb_to_recordset(coalesce(p.data->'events','[]'::jsonb)) AS x(
 event_date date,account text,description text,signed_amount numeric,source text,
 source_ref text,confidence text,account_assignment text,legacy_index integer,
 original_date date,displaced boolean)
WHERE x.event_date BETWEEN p_from AND p_to;
$flow$),
 ('public.lts_recurring_maintenance_v366()',
  '64fe0a7ace2fb8a4d3b78e4ec7b5def9',
  $maintenance$
-- lts-projection-v412: reuse the existing daily schedule and fixed-plan engine.
DECLARE u uuid;results jsonb:='[]';reference_result jsonb;
BEGIN
 FOR u IN
  SELECT user_id FROM public.lts_recurring_plan_v366 WHERE active AND value_kind='fixed'
  UNION
  SELECT usuario_id FROM public.legacy_namespace WHERE chave='lts_owner_projection_policy_v412'
 LOOP
  reference_result:=lts_projection_private_v412.refresh_reference(u,current_date);
  results:=results||jsonb_build_array(public.lts_recurring_materialize_v366(u,current_date));
  IF EXISTS(SELECT 1 FROM public.legacy_namespace WHERE usuario_id=u AND chave='lts_owner_projection_policy_v412')
   THEN PERFORM lts_projection_private_v412.invalidate_reads(u);END IF;
 END LOOP;
 RETURN results;
END
$maintenance$)) AS versions(signature,old_md5,new_body)
 LOOP
  target:=to_regprocedure(signature);
  IF target IS NULL THEN RAISE EXCEPTION 'V412 predecessor missing: %',signature;END IF;
  SELECT prosrc,proacl,proowner,proconfig,prosecdef
  INTO current_body,prior_acl,prior_owner,prior_config,prior_security FROM pg_proc WHERE oid=target;
  before_definition:=pg_get_functiondef(target);
  IF md5(before_definition)<>old_md5 AND current_body IS DISTINCT FROM new_body
   THEN RAISE EXCEPTION 'V412 predecessor changed: %',signature;END IF;
  -- pg_get_functiondef supplies a canonical $function$ delimiter. Replacing its
  -- body alone avoids resetting installation-specific function properties.
  new_definition:=split_part(before_definition,'AS $function$',1)
   ||'AS $function$'||new_body||'$function$';
  EXECUTE new_definition;
  IF EXISTS(SELECT 1 FROM pg_proc WHERE oid=target AND
    (proacl IS DISTINCT FROM prior_acl OR proowner<>prior_owner
     OR proconfig IS DISTINCT FROM prior_config OR prosecdef<>prior_security))
   THEN RAISE EXCEPTION 'V412 changed protected function metadata: %',signature;END IF;
 END LOOP;
END $install$;

