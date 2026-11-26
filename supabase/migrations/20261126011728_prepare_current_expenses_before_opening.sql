-- Prepare the default, private year-to-date report before the reader's
-- existing 30-minute validity expires. Source and revision checks stay intact.
CREATE OR REPLACE FUNCTION lts_product_refresh_private_v415.prepare_current_expenses_v498()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO '' SET timezone TO 'America/Sao_Paulo'
AS $prepare$
DECLARE
  owner_id uuid:=public.lts_open_finance_pilot_owner_v1();
  first_day date:=date_trunc('year',current_date)::date;
  initial_epoch bigint;
  final_epoch bigint;
  card_revision text;
  initial_time timestamptz:=clock_timestamp();
  fingerprint text;
  report jsonb;
BEGIN
  IF owner_id IS NULL OR NOT pg_try_advisory_xact_lock(hashtextextended('lts-current-expenses-v498',0)) THEN
    RETURN jsonb_build_object('prepared',false,'reason','unavailable_or_running');
  END IF;
  SELECT epoch INTO STRICT initial_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton;
  fingerprint:='expenses-v464:'||initial_epoch||':'||current_date::text;
  IF EXISTS(SELECT 1 FROM public.lts_v229_read_cache c WHERE c.user_id=owner_id
    AND c.kind='expenses_v251' AND c.as_of=current_date AND c.from_date=first_day AND c.to_date=current_date
    AND c.source_fingerprint=fingerprint AND c.refreshed_at>initial_time-interval '22 minutes') THEN
    RETURN jsonb_build_object('prepared',false,'reason','fresh');
  END IF;
  -- Keep time-driven preparation compatible with the existing worker and
  -- canonical authenticated reader. A changed contract falls back to that reader.
  IF md5(pg_get_functiondef('public.lts_browser_expenses_v229(date,date)'::regprocedure))
      <> 'f36b21764272fabd0fb8a08073d1aa3e'
     OR md5(pg_get_functiondef('public.lts_browser_expenses_v229_engine_v251(date,date)'::regprocedure))
      <> '579e0574f5ea7c0d702e591786d7f3f1' THEN
    RETURN jsonb_build_object('prepared',false,'reason','reader_changed');
  END IF;
  card_revision:=public.lts_c6_completeness_state_v269(owner_id)->>'source_revision';
  report:=lts_product_refresh_private_v415.expense_engine_v488(owner_id,first_day,current_date)
    ||jsonb_build_object('presentation',public.lts_expense_presentation_v353(owner_id,first_day,current_date,'{}'));

  IF report->>'version' IS DISTINCT FROM 'expense-executive-v229-consistent-comparisons'
     OR (report#>>'{period,from}')::date IS DISTINCT FROM first_day
     OR (report#>>'{period,to}')::date IS DISTINCT FROM current_date
     OR (report#>>'{summary,rows}')::bigint IS DISTINCT FROM (report#>>'{presentation,summary,rows}')::bigint
     OR (report#>>'{summary,selected_total}')::numeric IS DISTINCT FROM (report#>>'{presentation,summary,net}')::numeric THEN
    RETURN jsonb_build_object('prepared',false,'reason','incomplete');
  END IF;
  SELECT epoch INTO STRICT final_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton FOR SHARE;
  IF final_epoch<>initial_epoch OR card_revision IS NULL OR card_revision IS DISTINCT FROM
      (public.lts_c6_completeness_state_v269(owner_id)->>'source_revision') THEN
    RETURN jsonb_build_object('prepared',false,'reason','source_changed');
  END IF;
  PERFORM lts_product_refresh_private_v415.store_dashboard_year_v488(owner_id,initial_epoch,report);
  RETURN jsonb_build_object('prepared',EXISTS(SELECT 1 FROM public.lts_v229_read_cache c
    WHERE c.user_id=owner_id AND c.kind='expenses_v251' AND c.as_of=current_date
      AND c.from_date=first_day AND c.to_date=current_date AND c.source_fingerprint=fingerprint
      AND c.refreshed_at>=initial_time),'elapsed_ms',round(extract(epoch from clock_timestamp()-initial_time)*1000));
END
$prepare$;
REVOKE ALL ON FUNCTION lts_product_refresh_private_v415.prepare_current_expenses_v498() FROM PUBLIC,anon,authenticated,service_role;
-- Keep the existing schedule. Earlier bank and product work commit before
-- this report is calculated, and an already prepared report exits immediately.
DO $schedule$
DECLARE job cron.job%ROWTYPE;
BEGIN
  SELECT * INTO STRICT job FROM cron.job WHERE jobname='lts_product_refresh_pending_v415';
  IF strpos(job.command,'prepare_current_expenses_v498()')>0 THEN RETURN; END IF;
  IF md5(job.command)<>'31bf976cbb8682cb4b0da61f1bccbf33' THEN
    RAISE EXCEPTION 'Unexpected product preparation schedule';
  END IF;
  PERFORM cron.alter_job(job.jobid,command:=job.command||$command$
BEGIN;
SET LOCAL statement_timeout='18s';
SET LOCAL lock_timeout='400ms';
SELECT lts_product_refresh_private_v415.prepare_current_expenses_v498();
COMMIT;
$command$);
END
$schedule$;
