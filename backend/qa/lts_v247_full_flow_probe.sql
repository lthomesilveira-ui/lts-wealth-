-- Run only inside the transactional candidate probe. No source data persists.
DO $flow$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); first_payload jsonb; replay jsonb;
 year_payload jsonb; full_days jsonb; year_days jsonb; expected_year jsonb;
 started timestamptz; first_ms numeric; replay_ms numeric; year_ms numeric; coverage jsonb;
BEGIN
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',u,'role','authenticated','email',(SELECT email FROM auth.users WHERE id=u))::text,true);
 started:=clock_timestamp();
 first_payload:=public.lts_browser_flow_v242(date '2026-01-01',date '2027-12-31');
 first_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
 started:=clock_timestamp();
 replay:=public.lts_browser_flow_v242(date '2026-01-01',date '2027-12-31');
 replay_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
 IF first_payload<>replay THEN RAISE EXCEPTION 'full Flow cached replay changed response';END IF;
 SELECT coalesce(jsonb_agg(d ORDER BY d->>'date'),'[]') INTO full_days FROM (
  SELECT d FROM jsonb_array_elements(coalesce(first_payload#>'{flow,historical,days}','[]')) d
  UNION ALL SELECT d FROM jsonb_array_elements(coalesce(first_payload#>'{flow,current_future,days}','[]')) d
 ) all_days;
 IF jsonb_array_length(full_days)<>730 OR (SELECT count(DISTINCT d->>'date') FROM jsonb_array_elements(full_days)d)<>730
 OR full_days->0->>'date'<>'2026-01-01' OR full_days->729->>'date'<>'2027-12-31' THEN
  RAISE EXCEPTION '2026 and 2027 coverage incomplete';
 END IF;
 started:=clock_timestamp();
 year_payload:=public.lts_browser_flow_v242(date '2027-01-01',date '2027-12-31');
 year_ms:=round(extract(epoch FROM(clock_timestamp()-started))*1000,1);
 SELECT coalesce(jsonb_agg(d ORDER BY d->>'date'),'[]') INTO year_days FROM (
  SELECT d FROM jsonb_array_elements(coalesce(year_payload#>'{flow,historical,days}','[]')) d
  UNION ALL SELECT d FROM jsonb_array_elements(coalesce(year_payload#>'{flow,current_future,days}','[]')) d
 ) all_days;
 SELECT jsonb_agg(d ORDER BY d->>'date') INTO expected_year FROM jsonb_array_elements(full_days)d WHERE d->>'date'>='2027-01-01';
 IF year_days<>expected_year THEN RAISE EXCEPTION '2027 slice differs from full 2026-2027 view';END IF;
 SELECT jsonb_object_agg(year_number,summary) INTO coverage FROM (
  SELECT left(d->>'date',4) AS year_number,jsonb_build_object('days',count(*),
   'missing_d0_d1',count(*) FILTER(WHERE d#>>'{fix86_columns,liq_d0_1}' IS NULL),
   'missing_rsu',count(*) FILTER(WHERE d#>>'{fix86_columns,rsus_vested}' IS NULL),
   'missing_fgts',count(*) FILTER(WHERE d#>>'{fix86_columns,fgts}' IS NULL)) summary
  FROM jsonb_array_elements(full_days)d GROUP BY 1
 ) years;
 PERFORM set_config('lts.qa_full_flow_v247',jsonb_build_object('status','PASS','first_ms',first_ms,
  'replay_ms',replay_ms,'year_slice_ms',year_ms,'replay_exact',true,'year_slice_exact',true,'coverage',coverage)::text,true);
END $flow$;
