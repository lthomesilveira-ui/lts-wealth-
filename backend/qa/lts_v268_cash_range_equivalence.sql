-- Prospective proof for bounded shared evaluation. No permanent mutation.
BEGIN;
SET LOCAL statement_timeout='55s';
SET LOCAL TimeZone='America/Sao_Paulo';
SET LOCAL jit=off;
DO $probe$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1(); wide jsonb; direct jsonb; sliced jsonb;
 w record; checks jsonb:='[]'; started timestamptz:=clock_timestamp();
BEGIN
 SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO wide
 FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(u,date '2013-10-10',date '2031-12-31')r;
 FOR w IN SELECT * FROM (VALUES
  (date '2013-10-10',date '2017-12-31'),
  (date '2019-01-01',date '2019-12-31'),
  (date '2026-01-01',date '2026-10-12'),
  (date '2026-07-07',date '2026-07-08'),
  (date '2026-10-01',date '2026-10-13'),
  (date '2026-10-13',date '2027-12-31'),
  (date '2027-01-01',date '2027-12-31'),
  (date '2030-01-01',date '2031-12-31')
 )ranges(from_day,to_day) LOOP
  SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text),'[]') INTO direct
  FROM public.lts_corrected_cashflow_fix86_v1_engine_v247(u,w.from_day,w.to_day)r;
  SELECT coalesce(jsonb_agg(j ORDER BY j::text),'[]') INTO sliced
  FROM jsonb_array_elements(wide)a(j)
  WHERE (j->>'event_date')::date BETWEEN w.from_day AND w.to_day
   -- The old engine filters original workbook dates before transformation.
   -- A covering read must not admit a backwards-moved later original row.
   AND (j->>'source'<>'legacy_fix86' OR (j->>'original_date')::date<=w.to_day);
  IF direct IS DISTINCT FROM sliced THEN
   RAISE EXCEPTION 'cash range contract differs: % to %',w.from_day,w.to_day;
  END IF;
  checks:=checks||jsonb_build_array(jsonb_build_object('from',w.from_day,'to',w.to_day,
   'rows',jsonb_array_length(direct),'all_fields_equal',true,'md5',md5(direct::text)));
 END LOOP;
 PERFORM set_config('lts.v268_range_proof',jsonb_build_object('pass',true,'checks',checks,
  'wide_rows',jsonb_array_length(wide),'elapsed_ms',round(extract(epoch FROM clock_timestamp()-started)*1000,1),
  'source_mutations','none','cache_mutations','rolled_back')::text,true);
END $probe$;
SELECT current_setting('lts.v268_range_proof')::jsonb receipt;
ROLLBACK;
