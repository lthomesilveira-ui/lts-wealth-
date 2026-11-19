-- Prepare the same year-to-date report while the existing worker owns a
-- validated claim. Leave the normal reader's TTL, epoch and card guards intact.
DO $migration$
DECLARE
  engine regprocedure := 'public.lts_browser_expenses_v229_engine_v251(date,date)'::regprocedure;
  reader regprocedure := 'public.lts_browser_expenses_v229(date,date)'::regprocedure;
  runner regprocedure := 'lts_product_refresh_private_v415.run_claimed()'::regprocedure;
  definition text; original_body text;
  decl text := 'declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;';
  before_publish text := '  -- Protect publication, briefly, against a concurrent committed source epoch.';
  after_guard text := '  -- Persist the summary already produced during this guarded refresh.';
BEGIN
  PERFORM set_config('search_path','',true);
  IF md5(pg_get_functiondef(engine)) <> '7ffca84a1e548a64e845e9421ae06133'
     OR md5(pg_get_functiondef(reader)) <> 'f36b21764272fabd0fb8a08073d1aa3e'
     OR md5(pg_get_functiondef(runner)) <> '71fd4b4ec3ec34a33df0a605c0e1a76b' THEN
    RAISE EXCEPTION 'Unexpected source for year-to-date dashboard calculation';
  END IF;
  SELECT prosrc INTO STRICT original_body FROM pg_proc WHERE oid=engine;
  IF array_length(string_to_array(original_body,decl),1) IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Unexpected expense engine declaration';
  END IF;
  -- Move the existing financial calculation unchanged into one invoker-only
  -- helper. The public engine still resolves its owner through the same gate.
  EXECUTE format('CREATE FUNCTION lts_product_refresh_private_v415.expense_engine_v488(u uuid,p_from date,p_to date)
    RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO %L SET timezone TO %L AS %L',
    '', 'America/Sao_Paulo', replace(original_body,decl,'declare result jsonb;'));
  REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.expense_engine_v488(uuid,date,date)
    FROM PUBLIC,anon,authenticated,service_role;
  definition := pg_get_functiondef(engine);
  EXECUTE replace(definition,original_body,$wrapper$
BEGIN
  RETURN lts_product_refresh_private_v415.expense_engine_v488(public.lts_browser_assert_user_v1(),p_from,p_to);
END $wrapper$);
  definition:=pg_get_functiondef(runner);
  IF array_length(string_to_array(definition,before_publish),1) IS DISTINCT FROM 2
     OR array_length(string_to_array(definition,after_guard),1) IS DISTINCT FROM 2
     OR array_length(string_to_array(definition,'DECLARE audit_v442 jsonb;'),1) IS DISTINCT FROM 2 THEN
    RAISE EXCEPTION 'Unexpected worker publication anchors';
  END IF;
  definition:=replace(definition,'DECLARE audit_v442 jsonb;','DECLARE dashboard_year_v488 jsonb; audit_v442 jsonb;');
  definition:=replace(definition,before_publish,$build$  -- Compute before taking the publication locks. A future change to the
  -- canonical reader disables this optional optimization until reviewed.
  IF md5(pg_get_functiondef('public.lts_browser_expenses_v229(date,date)'::regprocedure))='f36b21764272fabd0fb8a08073d1aa3e'
    AND md5(pg_get_functiondef('public.lts_browser_expenses_v229_engine_v251(date,date)'::regprocedure))='579e0574f5ea7c0d702e591786d7f3f1'
    AND NOT EXISTS(SELECT 1 FROM public.lts_v229_read_cache c WHERE c.user_id=u
      AND c.kind='expenses_v251' AND c.as_of=current_date AND c.from_date=date_trunc('year',current_date)::date
      AND c.to_date=current_date AND c.source_fingerprint='expenses-v464:'||expected_epoch||':'||current_date::text
      AND c.refreshed_at>clock_timestamp()-interval '30 minutes') THEN
    BEGIN
      dashboard_year_v488:=lts_product_refresh_private_v415.expense_engine_v488(u,date_trunc('year',current_date)::date,current_date)
        ||jsonb_build_object('presentation',public.lts_expense_presentation_v353(u,date_trunc('year',current_date)::date,current_date,'{}'));
    EXCEPTION WHEN OTHERS THEN
      -- A failed optional calculation leaves the authenticated reader in charge.
      RAISE LOG 'Dashboard year warm skipped (%)',SQLSTATE;
    END;
  END IF;
$build$||before_publish);
  definition:=replace(definition,after_guard,$publish$  IF dashboard_year_v488 IS NOT NULL THEN
    PERFORM lts_product_refresh_private_v415.store_dashboard_year_v488(u,expected_epoch,dashboard_year_v488);
  END IF;
$publish$||after_guard);
  EXECUTE definition;
END $migration$;

CREATE FUNCTION lts_product_refresh_private_v415.store_dashboard_year_v488(u uuid, source_epoch bigint, result jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path TO '' SET timezone TO 'America/Sao_Paulo' SET lock_timeout TO '100ms'
AS $store$
BEGIN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(u,'expenses_v251',current_date,date_trunc('year',current_date)::date,current_date,result,clock_timestamp(),
         'expenses-v464:'||source_epoch||':'||current_date::text)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE
    SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
EXCEPTION WHEN lock_not_available THEN
  RAISE LOG 'Dashboard year warm skipped (concurrent writer)';
END $store$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.store_dashboard_year_v488(uuid,bigint,jsonb)
  FROM PUBLIC,anon,authenticated,service_role;
