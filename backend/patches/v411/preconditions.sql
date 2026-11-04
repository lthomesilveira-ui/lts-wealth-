-- Reject unknown definitions before changing anything. New helpers may be absent.
SET LOCAL lock_timeout='5s';
SET LOCAL statement_timeout='30s';
SET LOCAL search_path=public;
DO $v411_guard$
DECLARE spec jsonb; oid regprocedure; actual text;
BEGIN
 PERFORM set_config('lts.v411.changed','false',true);
 IF to_regclass('public.lts_future_liquidity_effective_v290') IS NULL THEN RAISE EXCEPTION 'V411 effective view is missing';END IF;
 SELECT md5(pg_get_viewdef('public.lts_future_liquidity_effective_v290'::regclass,true)) INTO actual;
 IF actual NOT IN ('58b622a70fdb6522ae0c9b9dde9342f5','ff2473ec216d45ff89a589314dd66966') THEN RAISE EXCEPTION 'V411 effective view drift';END IF;
 IF actual='58b622a70fdb6522ae0c9b9dde9342f5' THEN PERFORM set_config('lts.v411.changed','true',true);END IF;
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
  oid:=to_regprocedure(spec->>'signature');
  IF oid IS NULL THEN PERFORM set_config('lts.v411.changed','true',true);CONTINUE;END IF;
  actual:=md5(pg_get_functiondef(oid));
  IF actual=spec->>'after_md5' THEN CONTINUE;END IF;
  IF spec->>'before_md5' IS NULL OR actual<>spec->>'before_md5' THEN
   RAISE EXCEPTION 'V411 core definition drift: %',spec->>'signature';
  END IF;
  PERFORM set_config('lts.v411.changed','true',true);
 END LOOP;
END $v411_guard$;
