// Only a private QA receipt persists; candidate DDL/source/cache fixtures roll back.
import fs from 'node:fs';
const mode=process.argv[2]||'year';
if(!['year','month','old','invalidation'].includes(mode))throw Error('choose year, month, old or invalidation');
const quote=v=>"'"+v.replaceAll("'","''")+"'";
const patch=fs.readFileSync('backend/patches/expense_reader_memo_v251.sql','utf8');
const fingerprint=`(SELECT md5(jsonb_agg(jsonb_build_array(p.oid::regprocedure::text,pg_get_functiondef(p.oid),p.proacl::text) ORDER BY p.oid::regprocedure::text)::text) FROM pg_proc p WHERE p.pronamespace='public'::regnamespace AND p.prokind='f')`;
const from=mode==='old'?"date '2019-01-01'":mode==='year'?"date_trunc('year',current_date)::date":"date_trunc('month',current_date)::date";
const to=mode==='old'?"date '2019-12-31'":"current_date";
const mutation=mode==='invalidation'?`
  SELECT epoch INTO e FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,decision_basis)
  VALUES(u,'v251_synthetic_qa','v251-synthetic-qa','QA classification','synthetic rollback invalidation fixture');
  IF (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)<=e OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id=u AND kind='expenses_v251') THEN RAISE EXCEPTION 'source did not invalidate memo';END IF;
  s:=clock_timestamp();after_change:=public.lts_browser_expenses_v229(lo,hi);rebuild_ms:=round(extract(epoch from(clock_timestamp()-s))*1000,1);
  IF after_change IS DISTINCT FROM baseline THEN RAISE EXCEPTION 'unrelated classification changed economic report';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id=u AND kind='expenses_v251' AND from_date=lo AND to_date=hi AND source_fingerprint='expenses-v251:'||(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)||':'||current_date::text) THEN RAISE EXCEPTION 'new epoch not in rebuilt cache';END IF;
`:'';
const query=`
SET LOCAL lock_timeout='1500ms';SET LOCAL statement_timeout='60s';SET LOCAL jit='off';SET LOCAL timezone='America/Sao_Paulo';
CREATE TABLE IF NOT EXISTS public.lts_v251_validation_report(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),created_at timestamptz NOT NULL DEFAULT clock_timestamp(),report jsonb NOT NULL);
ALTER TABLE public.lts_v251_validation_report ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_v251_validation_report FROM PUBLIC,anon,authenticated,service_role;
DO $qa$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();other_user uuid;old_hash text;after_hash text;report jsonb;started timestamptz:=clock_timestamp();lo date:=${from};hi date:=${to};
baseline jsonb;first jsonb;replay jsonb;after_change jsonb;claims text;old_claims text:=current_setting('request.jwt.claims',true);s timestamptz;baseline_ms numeric;first_ms numeric;replay_ms numeric;rebuild_ms numeric;e bigint;guard_pass boolean:=false;other_checked boolean:=false;
BEGIN
 old_hash:=${fingerprint};
 claims:=jsonb_build_object('sub',u,'role','authenticated','email',(SELECT email FROM auth.users WHERE id=u))::text;
 BEGIN
  PERFORM set_config('request.jwt.claims',claims,true);
  s:=clock_timestamp();baseline:=public.lts_browser_expenses_v229(lo,hi);baseline_ms:=round(extract(epoch from(clock_timestamp()-s))*1000,1);
  EXECUTE ${quote(patch)};
  IF has_function_privilege('anon','public.lts_browser_expenses_v229_engine_v251(date,date)','EXECUTE') OR has_function_privilege('authenticated','public.lts_browser_expenses_v229_engine_v251(date,date)','EXECUTE') OR has_function_privilege('service_role','public.lts_browser_expenses_v229_engine_v251(date,date)','EXECUTE') THEN RAISE EXCEPTION 'private engine exposed';END IF;
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(u,'expenses_v251',current_date,lo-1,hi,'{"wrong_period_marker":true}'::jsonb,clock_timestamp(),'expenses-v251:'||(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)||':'||current_date::text);
  SELECT id INTO other_user FROM auth.users WHERE id<>u ORDER BY id LIMIT 1;
  IF other_user IS NOT NULL THEN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
   VALUES(other_user,'expenses_v251',current_date,lo,hi,'{"foreign_owner_marker":true}'::jsonb,clock_timestamp(),'expenses-v251:'||(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton)||':'||current_date::text);
   other_checked:=true;
  END IF;
  s:=clock_timestamp();first:=public.lts_browser_expenses_v229(lo,hi);first_ms:=round(extract(epoch from(clock_timestamp()-s))*1000,1);
  s:=clock_timestamp();replay:=public.lts_browser_expenses_v229(lo,hi);replay_ms:=round(extract(epoch from(clock_timestamp()-s))*1000,1);
  IF first IS DISTINCT FROM baseline OR replay IS DISTINCT FROM baseline THEN RAISE EXCEPTION 'expense full JSON parity differs';END IF;
  IF NOT EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE user_id=u AND kind='expenses_v251' AND from_date=lo AND to_date=hi AND payload=baseline) THEN RAISE EXCEPTION 'exact-period memo missing';END IF;
  PERFORM set_config('request.jwt.claims','{}',true);
  BEGIN PERFORM public.lts_browser_expenses_v229(lo,hi);EXCEPTION WHEN insufficient_privilege THEN guard_pass:=true;END;
  IF NOT guard_pass THEN RAISE EXCEPTION 'anonymous cache hit bypassed auth';END IF;
  PERFORM set_config('request.jwt.claims',claims,true);guard_pass:=false;
  BEGIN PERFORM public.lts_browser_expenses_v229(NULL,hi);EXCEPTION WHEN SQLSTATE 'P0001' THEN guard_pass:=SQLERRM='invalid expense range';END;
  IF NOT guard_pass THEN RAISE EXCEPTION 'invalid period accepted';END IF;
  ${mutation}
  report:=jsonb_build_object('status','PASS','mode',${quote(mode)},'from',lo,'to',hi,'baseline_ms',baseline_ms,'candidate_first_ms',first_ms,'replay_ms',replay_ms,'full_json_exact',true,'period_isolation',true,'other_owner_cache_tested',other_checked,'auth_and_invalid_range_guards',true,'private_engine_acl',true,'source_invalidation_tested',${mode==='invalidation'},'rebuild_ms',rebuild_ms);
  RAISE EXCEPTION USING ERRCODE='P2510',MESSAGE='rollback candidate DDL and all fixtures';
 EXCEPTION WHEN SQLSTATE 'P2510' THEN NULL;
  WHEN query_canceled THEN report:=jsonb_build_object('status','FAIL','mode',${quote(mode)},'sqlstate',SQLSTATE,'error',SQLERRM);
  WHEN OTHERS THEN report:=jsonb_build_object('status','FAIL','mode',${quote(mode)},'sqlstate',SQLSTATE,'error',SQLERRM);
 END;
 after_hash:=${fingerprint};
 IF old_hash IS DISTINCT FROM after_hash OR to_regprocedure('public.lts_browser_expenses_v229_engine_v251(date,date)') IS NOT NULL THEN RAISE EXCEPTION 'DDL or ACL did not restore';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_v178_review_decision WHERE source_ref='v251-synthetic-qa') OR EXISTS(SELECT 1 FROM public.lts_v229_read_cache WHERE kind='expenses_v251') THEN RAISE EXCEPTION 'candidate fixture or memo persisted';END IF;
 PERFORM set_config('request.jwt.claims',coalesce(old_claims,''),true);
 INSERT INTO public.lts_v251_validation_report(report)VALUES(report||jsonb_build_object('candidate_ddl_and_cache_rolled_back',true,'definitions_and_acls_restored',true,'fixtures_absent',true,'duration_ms',round(extract(epoch from(clock_timestamp()-started))*1000,1)));
END $qa$;
`;
process.stdout.write(JSON.stringify({query}));

