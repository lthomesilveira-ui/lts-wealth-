-- Verify installed definitions and permissions before invalidating derived caches.
DO $v411_verify$
DECLARE spec jsonb; p record;
BEGIN
 IF md5(pg_get_viewdef('public.lts_future_liquidity_effective_v290'::regclass,true))<>'ff2473ec216d45ff89a589314dd66966' THEN
  RAISE EXCEPTION 'V411 installed view mismatch';END IF;
 IF NOT (SELECT reloptions @> ARRAY['security_invoker=true'] FROM pg_class WHERE oid='public.lts_future_liquidity_effective_v290'::regclass)
  OR has_table_privilege('anon','public.lts_future_liquidity_effective_v290','SELECT')
  OR has_table_privilege('authenticated','public.lts_future_liquidity_effective_v290','SELECT') THEN
  RAISE EXCEPTION 'V411 view access mismatch';END IF;
 FOR spec IN SELECT value FROM jsonb_array_elements($core_specs$[
  {
    "signature": "lts_award_private.considered_value_v411(uuid, text, numeric, numeric, numeric)",
    "before_md5": null,
    "after_md5": "8effcca086574d12dd8f4b5ac7db84b6",
    "security_definer": false,
    "configuration": [
      "search_path=\"\""
    ]
  },
  {
    "signature": "lts_award_private.grant_eligibility_v411(uuid, jsonb, text)",
    "before_md5": null,
    "after_md5": "8b545525230f2da1e6585155062ba5ed",
    "security_definer": false,
    "configuration": [
      "search_path=\"\""
    ]
  },
  {
    "signature": "lts_award_private.net_value_v411(uuid, text, numeric, numeric)",
    "before_md5": null,
    "after_md5": "2b67129cfd68ae98511c8bc272f01c0f",
    "security_definer": false,
    "configuration": [
      "search_path=\"\""
    ]
  },
  {
    "signature": "lts_award_private.owner_policy_v411(uuid)",
    "before_md5": null,
    "after_md5": "1edf02156a1017512e79be5a078543b6",
    "security_definer": false,
    "configuration": [
      "search_path=\"\""
    ]
  },
  {
    "signature": "public.lts_browser_rsu_policy_v411()",
    "before_md5": null,
    "after_md5": "948c3907830b7c211ad4e863e2f8b4ae",
    "security_definer": true,
    "configuration": [
      "search_path=\"\"",
      "TimeZone=America/Sao_Paulo"
    ]
  },
  {
    "signature": "public.lts_browser_vesting_scenario_v1(text[], date)",
    "before_md5": "a7d87ae050f7a9e59645ed56348056f2",
    "after_md5": "2db9c090c1a0d1fe931c9d074eb7bfe2",
    "security_definer": true,
    "configuration": [
      "search_path=\"\"",
      "TimeZone=America/Sao_Paulo"
    ]
  }
]$core_specs$::jsonb) LOOP
  SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure(spec->>'signature');
  IF NOT FOUND OR md5(pg_get_functiondef(p.oid))<>spec->>'after_md5'
   OR p.prosecdef IS DISTINCT FROM (spec->>'security_definer')::boolean
   OR to_jsonb(p.proconfig) IS DISTINCT FROM spec->'configuration'
   OR pg_get_userbyid(p.proowner)<>'postgres'
   OR has_function_privilege('anon',p.oid,'EXECUTE')
   OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')
   OR has_function_privilege('authenticated',p.oid,'EXECUTE') IS DISTINCT FROM (spec->>'security_definer')::boolean THEN
   RAISE EXCEPTION 'V411 installed core contract mismatch: %',spec->>'signature';
  END IF;
 END LOOP;
END $v411_verify$;

-- The seed may have advanced the epoch before this DDL. Invalidate after installing
-- definitions; unchanged replay performs neither deletion nor epoch advancement.
DO $v411_cache$
DECLARE changed_rows integer;
BEGIN
 IF current_setting('lts.v411.changed',true)='true' THEN
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
  GET DIAGNOSTICS changed_rows=ROW_COUNT;
  IF changed_rows<>1 THEN RAISE EXCEPTION 'V411 expected one cache epoch';END IF;
  DELETE FROM public.lts_v229_read_cache c WHERE EXISTS(SELECT 1 FROM public.legacy_namespace n WHERE n.usuario_id=c.user_id AND n.chave='lts_owner_rsu_policy_v411');
  DELETE FROM public.lts_flow_future_read_cache c WHERE EXISTS(SELECT 1 FROM public.legacy_namespace n WHERE n.usuario_id=c.user_id AND n.chave='lts_owner_rsu_policy_v411');
  DELETE FROM public.lts_flow_future_read_cache_v2 c WHERE EXISTS(SELECT 1 FROM public.legacy_namespace n WHERE n.usuario_id=c.user_id AND n.chave='lts_owner_rsu_policy_v411');
  DELETE FROM public.lts_dashboard_cockpit_cache c WHERE EXISTS(SELECT 1 FROM public.legacy_namespace n WHERE n.usuario_id=c.user_id AND n.chave='lts_owner_rsu_policy_v411');
  DELETE FROM public.lts_product_read_cache c WHERE EXISTS(SELECT 1 FROM public.legacy_namespace n WHERE n.usuario_id=c.user_id AND n.chave='lts_owner_rsu_policy_v411');
  PERFORM pg_notify('pgrst','reload schema');
 END IF;
END $v411_cache$;
