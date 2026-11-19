-- Refresh the pinned calculation graph for the reviewed card and recurring-commitment changes.
-- Source checks and definition hashes are evaluated with fully qualified names.
DO $migration$
DECLARE
 profile jsonb; updated jsonb; pins jsonb := $pins$[
  {
    "signature": "lts_projection_private_v412.build(uuid,date)",
    "md5": "cc96f70a4a71906be9c78b73b749ad53"
  },
  {
    "signature": "lts_recurring_private_v469.append_result(uuid,date,jsonb,jsonb,jsonb)",
    "md5": "c4b97f6845a10b874012724487b1810f"
  },
  {
    "signature": "lts_recurring_private_v469.bank_commitments_v479(jsonb,jsonb,jsonb,date,jsonb)",
    "md5": "0d7ab33cac602e953a92e7295024a900"
  },
  {
    "signature": "lts_recurring_private_v469.calculate(jsonb,jsonb,jsonb,jsonb,date)",
    "md5": "0afabe35c1005c5f4849c8d50675b2b5"
  },
  {
    "signature": "lts_recurring_private_v469.card_commitments_v479(jsonb,jsonb,date,jsonb)",
    "md5": "7f3a8b972c380b42d1fb70c36d21bf0d"
  },
  {
    "signature": "lts_recurring_private_v469.open_card_cycle_v478(jsonb,jsonb,date)",
    "md5": "16da5f87bdf68b85274151f38297c6fa"
  },
  {
    "signature": "lts_recurring_private_v469.open_cash_end_v479(jsonb,date)",
    "md5": "1a10c1715f97d43598691d87375b2f77"
  },
  {
    "signature": "lts_recurring_private_v469.posted_bank_v479(uuid,date,jsonb)",
    "md5": "c54f686f9a30a7ca98aa3c3d688bc7d3"
  },
  {
    "signature": "lts_recurring_private_v469.skip_current_estimate_v479(jsonb,jsonb,date,date)",
    "md5": "b402772008fb4e1769d1ae2b91aa8abf"
  },
  {
    "signature": "public.lts_aeternum_forecast_cycles_v311(uuid)",
    "md5": "d5400d9eaac9e5b040b2088afc1aaace"
  }
]$pins$;
 item jsonb; rewritten text; original text;
BEGIN
 PERFORM set_config('search_path','',true);
 SELECT lts_product_refresh_private_v415.review_profile_v450() INTO profile;
 IF md5(profile::text) IS DISTINCT FROM '3a941712276413c8dc88ef621e7d0f66'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.review_profile_v450()'::regprocedure)) IS DISTINCT FROM '78a07ebc6f58b8fae2e3d2b4c257199a'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.review_guard_v450(uuid)'::regprocedure)) IS DISTINCT FROM 'cd1353fdd869841803cdb3007e7c3db1'
  OR md5(pg_get_functiondef('lts_product_refresh_private_v415.long_flow_guard_v450(uuid)'::regprocedure)) IS DISTINCT FROM '11b67db251b1a4c9c06fa8a959cf220c'
 THEN RAISE EXCEPTION 'Original read guards changed'; END IF;
 SELECT jsonb_set(profile,'{producers}',
  (SELECT jsonb_agg(coalesce(n.value,o.value) ORDER BY o.ord)
   FROM jsonb_array_elements(profile->'producers') WITH ORDINALITY o(value,ord)
   LEFT JOIN jsonb_array_elements(pins)n ON n.value->>'signature'=o.value->>'signature')
  || (SELECT jsonb_agg(n.value ORDER BY n.ord) FROM jsonb_array_elements(pins) WITH ORDINALITY n(value,ord)
     WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(profile->'producers')o WHERE o->>'signature'=n.value->>'signature'))
 ) INTO updated;
 IF md5(updated::text) IS DISTINCT FROM 'c4e51592379f1caca088b740531ce940' OR (updated-'producers') IS DISTINCT FROM (profile-'producers')
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
 rewritten:=replace(original,'3a941712276413c8dc88ef621e7d0f66','c4e51592379f1caca088b740531ce940');
 IF rewritten=original THEN RAISE EXCEPTION 'Review guard marker missing';END IF;
 EXECUTE rewritten;
END $migration$;
