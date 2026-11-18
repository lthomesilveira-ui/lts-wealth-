-- Refresh the pinned calculation graph after adding approved-budget sources.
-- Source checks and definition hashes are evaluated with fully qualified names.
DO $migration$
DECLARE
 profile jsonb; updated jsonb; pins jsonb := $pins$[
  {
    "signature": "public.lts_flow_classification_decision_v1(uuid,jsonb)",
    "md5": "9ccfe7ffb6974f7dfc61333da8b1c535"
  },
  {
    "signature": "lts_projection_private_v412.build(uuid,date)",
    "md5": "c73dc489c3771e5b8861569a2001f5b6"
  },
  {
    "signature": "lts_budget_private_v470.append_result(uuid,date,jsonb,jsonb,jsonb)",
    "md5": "6aa53b90af99e1069b45b6d9b47e6f4c"
  },
  {
    "signature": "lts_budget_private_v470.calculate(jsonb,jsonb,jsonb,date)",
    "md5": "ed595a29a697b579d23de04e0f838ab9"
  },
  {
    "signature": "lts_budget_private_v470.classification(uuid,jsonb)",
    "md5": "870a9b9d8913ad423348dd32617441ac"
  },
  {
    "signature": "lts_budget_private_v470.matches(jsonb,jsonb)",
    "md5": "13c8a1b68439839188997a11dccf8a3f"
  },
  {
    "signature": "lts_budget_private_v470.owner_plan(uuid)",
    "md5": "985bae77ffdd9a0e874a310c7cded855"
  },
  {
    "signature": "lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)",
    "md5": "cdb4c1b3eb4910ec0c2ac98b5656dcba"
  },
  {
    "signature": "lts_recurring_private_v469.calculate(jsonb,jsonb,jsonb,jsonb,date)",
    "md5": "a0d45646467712aed1ff4a9284f2b025"
  },
  {
    "signature": "lts_recurring_private_v469.classification(uuid,jsonb)",
    "md5": "10818696330108bab1055da3dc3de54d"
  },
  {
    "signature": "lts_recurring_private_v469.forecast(text,text,text,numeric,date)",
    "md5": "f576e5227b12f1ab9cbb7eeddd10f356"
  },
  {
    "signature": "lts_recurring_private_v469.owner_plan(uuid)",
    "md5": "08e7f4d4ca441fdfff72a34053c89acf"
  },
  {
    "signature": "lts_recurring_private_v469.third_business_day(date)",
    "md5": "dc44372f23e7e4e4941e82caf7f19b61"
  },
  {
    "signature": "lts_subscription_private_v468.append_result(uuid,date,jsonb,jsonb,jsonb)",
    "md5": "a1684410d4603439ac17f8d9cd87d856"
  },
  {
    "signature": "lts_subscription_private_v468.calculate(jsonb,jsonb,date,date)",
    "md5": "9b86aaf493e379e13e5ca2d1c6bf6753"
  },
  {
    "signature": "lts_subscription_private_v468.owner_plan(uuid)",
    "md5": "d1f4e4fb3c34e2e05567bc18335a322e"
  },
  {
    "signature": "lts_subscription_private_v468.validate_plan(jsonb)",
    "md5": "eed1f45e8fe38e929c58f03a871557a5"
  }
]$pins$;
 item jsonb; rewritten text; original text;
BEGIN
 PERFORM set_config('search_path','',true);
 SELECT lts_product_refresh_private_v415.review_profile_v450() INTO profile;
 IF md5(profile::text) IS DISTINCT FROM '3344fae485b34b6cf29a939801ab492e'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.review_profile_v450()'::regprocedure)) IS DISTINCT FROM '21e3ec09d2322aeb876d1136f9bbe2e2'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.review_guard_v450(uuid)'::regprocedure)) IS DISTINCT FROM '02d895675e35f70ae4fb11c6a1b2176f'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.long_flow_guard_v450(uuid)'::regprocedure)) IS DISTINCT FROM '62ee97b13bcaa0632612ecb7953cb17c'
 THEN RAISE EXCEPTION 'Original read guards changed'; END IF;
 SELECT jsonb_set(profile,'{producers}',
  (SELECT jsonb_agg(coalesce(n.value,o.value) ORDER BY o.ord)
   FROM jsonb_array_elements(profile->'producers') WITH ORDINALITY o(value,ord)
   LEFT JOIN jsonb_array_elements(pins)n ON n.value->>'signature'=o.value->>'signature')
  || (SELECT jsonb_agg(n.value ORDER BY n.ord) FROM jsonb_array_elements(pins) WITH ORDINALITY n(value,ord)
     WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(profile->'producers')o WHERE o->>'signature'=n.value->>'signature'))
 ) INTO updated;
 IF md5(updated::text) IS DISTINCT FROM '3a941712276413c8dc88ef621e7d0f66' OR (updated-'producers') IS DISTINCT FROM (profile-'producers')
  OR NOT lts_product_refresh_private_v415.review_input_contract_ok_v465(updated)
 THEN RAISE EXCEPTION 'Guarded source manifest mismatch';END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(updated->'producers') LOOP
  IF md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) IS DISTINCT FROM item->>'md5' THEN
   RAISE EXCEPTION 'Unexpected projection producer: %', item->>'signature';
  END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(updated->'views') LOOP
  IF md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) IS DISTINCT FROM item->>'md5' THEN
   RAISE EXCEPTION 'Unexpected view definition: %', item->>'signature';
  END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(updated->'epoch_tables') LOOP
  IF (SELECT md5(string_agg(tgname::text||tgenabled::text||pg_get_triggerdef(oid),'|' ORDER BY tgname))
   FROM pg_trigger WHERE tgrelid=to_regclass(item->>'signature') AND NOT tgisinternal) IS DISTINCT FROM item->>'md5' THEN
   RAISE EXCEPTION 'Unexpected source invalidation: %', item->>'signature';
  END IF;
 END LOOP;
 EXECUTE format('CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.review_profile_v450() RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path TO '''' AS %L',format(' SELECT %L::jsonb ',updated::text));
 original:=pg_get_functiondef('lts_product_refresh_private_v415.review_guard_v450(uuid)'::regprocedure);
 rewritten:=replace(original,'3344fae485b34b6cf29a939801ab492e','3a941712276413c8dc88ef621e7d0f66');
 IF rewritten=original THEN RAISE EXCEPTION 'Review guard marker missing';END IF;
 EXECUTE rewritten;
END $migration$;
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.long_flow_guard_v450(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE profile jsonb; item jsonb; actual text; source_epoch bigint; key_value text; program_key text; budget_sources text;
BEGIN
 profile:=lts_product_refresh_private_v415.review_profile_v450();
 IF jsonb_typeof(profile->'producers') IS DISTINCT FROM 'array'
  OR jsonb_typeof(profile->'views') IS DISTINCT FROM 'array'
  OR jsonb_typeof(profile->'epoch_tables') IS DISTINCT FROM 'array' THEN RETURN NULL; END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'producers') LOOP
  SELECT md5(pg_get_functiondef(to_regprocedure(item->>'signature'))) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'views') LOOP
  SELECT md5(pg_get_viewdef(to_regclass(item->>'signature'),true)) INTO actual;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 FOR item IN SELECT value FROM jsonb_array_elements(profile->'epoch_tables') LOOP
  SELECT md5(string_agg(tgname::text||tgenabled::text||pg_get_triggerdef(oid),'|' ORDER BY tgname)) INTO actual
   FROM pg_trigger WHERE tgrelid=to_regclass(item->>'signature') AND NOT tgisinternal;
  IF actual IS DISTINCT FROM item->>'md5' THEN RETURN NULL; END IF;
 END LOOP;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 key_value:=public.lts_flow_read_source_key_v247(p_user_id);
 -- Include all LTS program definitions, including the long-flow engine's
 -- transitive callees. A code change never reuses a previous engine result.
 SELECT md5(string_agg(p.oid::regprocedure::text||md5(pg_get_functiondef(p.oid)),'|' ORDER BY p.oid::regprocedure::text))
  INTO program_key FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE p.prokind IN('f','p') AND ((n.nspname='public' AND p.proname LIKE 'lts_%') OR n.nspname LIKE 'lts_%');
 SELECT md5(jsonb_build_array(
  public.lts_card_cycles_v226(p_user_id)-'computed_at',
  (SELECT jsonb_agg(to_jsonb(d) ORDER BY to_jsonb(d)::text) FROM public.lts_card_due_rule_v290 d WHERE d.user_id=p_user_id),
  (SELECT jsonb_agg(to_jsonb(d) ORDER BY to_jsonb(d)::text) FROM public.lts_card_due_transition_v370 d WHERE d.user_id=p_user_id),
  (SELECT jsonb_agg(jsonb_build_array(chave,sha256,md5(valor_bruto)) ORDER BY chave)
   FROM public.legacy_namespace WHERE usuario_id=p_user_id AND chave IN
    ('lts_owner_card_subscriptions_v468','lts_owner_recurring_plan_v469','lts_owner_budgets_v470'))
 )::text) INTO budget_sources;
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Long flow sources changed during read';
 END IF;
 RETURN 'long-flow-v450:'||source_epoch||':'||key_value||':'||program_key||':'||budget_sources||':'||md5(profile::text);
END
$function$;
