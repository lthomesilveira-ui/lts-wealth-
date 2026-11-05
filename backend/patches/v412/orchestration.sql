-- Read-only construction of future slots. No financial event is inserted here.
CREATE OR REPLACE FUNCTION lts_projection_private_v412.build(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE policy jsonb:=lts_projection_private_v412.owner_policy(p_user_id); horizon date;
 wf date;wt date;nr date;history jsonb;templates jsonb;baseline jsonb;cycles jsonb;slots jsonb:='[]';
 r jsonb;t jsonb;period record;key text;method text;d date;nominal date;day_number int;
 base_amount numeric;known numeric;replace_amount numeric;replace_refs jsonb;refs jsonb;authoritative boolean;
 known_complete boolean;cancelled boolean;withholding numeric;withholding_known boolean;calendar_days jsonb;canonical_due date;
 seen_dates date[];replacement_seen text[]:='{}';withholding_rows int;invoice_amount numeric;invoice_count int;
BEGIN
 IF policy IS NULL THEN RETURN jsonb_build_object('version','projection-policy-v412','enabled',false); END IF;
 policy:=policy||jsonb_build_object('_history_reference',lts_projection_private_v412.reference_state(p_user_id));
 horizon:=lts_projection_private_v412.horizon_end(p_as_of);
 SELECT * INTO wf,wt,nr FROM lts_projection_private_v412.review_window(policy,p_as_of);
 SELECT coalesce(jsonb_agg(to_jsonb(f)ORDER BY series_key,month),'[]') INTO history
 FROM lts_projection_private_v412.monthly_source_facts_v412(p_user_id,wf,wt,policy)f;
 SELECT coalesce(jsonb_agg(to_jsonb(template_row)ORDER BY series_key,event_month,event_day,source_ref),'[]') INTO templates
 FROM lts_projection_private_v412.calendar_templates_v412(p_user_id,policy)template_row;
 SELECT coalesce(jsonb_agg(to_jsonb(b)ORDER BY event_date,source_ref),'[]') INTO baseline
 FROM lts_projection_private_v412.base_flow(p_user_id,p_as_of+1,horizon)b;
 SELECT coalesce(jsonb_agg(to_jsonb(c)ORDER BY series_key,due_date),'[]') INTO cycles
 FROM lts_projection_private_v412.known_card_periods_v412(p_user_id)c;

 FOR r IN SELECT value FROM jsonb_array_elements(policy->'rules')
  WHERE coalesce(value->>'active','true')='true' ORDER BY value->>'series_key' LOOP
  key:=r->>'series_key';method:=r->>'method';seen_dates:='{}';calendar_days:='[]';
  IF method IN('inflated_calendar','repeat_calendar') AND coalesce(r->>'template_source','calendar')<>'history_mean' THEN
   -- Templates may include several installments and a separate license in a year.
   -- Equal calendar dates aggregate once, retaining all original references.
   SELECT coalesce(jsonb_agg(to_jsonb(a)ORDER BY event_month,event_day),'[]') INTO calendar_days
   FROM(SELECT (v->>'event_month')::int event_month,(v->>'event_day')::int event_day,
    sum((v->>'amount_brl')::numeric) amount_brl,jsonb_agg(v->>'source_ref') source_refs
    FROM jsonb_array_elements(templates)v WHERE v->>'series_key'=key
    GROUP BY 1,2)a;
  ELSE
   day_number:=nullif(r->>'due_day','')::int;
   IF day_number IS NULL THEN
    -- Modal observed day; ties use the earlier day and remain explicitly estimated.
    SELECT value::int INTO day_number FROM jsonb_array_elements(history)f
    CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(f->'observed_days','[]'))x(value)
    WHERE f->>'series_key'=key AND value~'^[0-9]{1,2}$' AND value::int BETWEEN 1 AND 31
    GROUP BY value ORDER BY count(*) DESC,value::int LIMIT 1;
   END IF;
   IF day_number BETWEEN 1 AND 31 THEN
    SELECT jsonb_agg(jsonb_build_object('event_month',n,'event_day',day_number,
     'amount_brl',r->'amount_brl','source_refs','[]'::jsonb)ORDER BY n) INTO calendar_days
    FROM generate_series(1,12)n;
   END IF;
  END IF;
  FOR period IN SELECT generate_series(extract(year FROM p_as_of)::int,extract(year FROM horizon)::int) AS calendar_year LOOP
   FOR t IN SELECT value FROM jsonb_array_elements(calendar_days) ORDER BY (value->>'event_month')::int,(value->>'event_day')::int LOOP
    nominal:=make_date(period.calendar_year,(t->>'event_month')::int,1);
    d:=nominal+least((t->>'event_day')::int,extract(day FROM nominal+interval '1 month -1 day')::int)-1;
    IF r->>'card_family' IS NOT NULL THEN
     -- Current owner calendar and an explicit transition outrank a historical mode.
     SELECT min((v->>'due_date')::date) INTO canonical_due FROM jsonb_array_elements(cycles)v
     WHERE v->>'series_key'=key AND date_trunc('month',(v->>'due_date')::date)=nominal;
     -- A cycle's cash date already includes the V370 transition. Apply that
     -- transition only to a new nominal date, never a second time to a cycle.
     d:=CASE WHEN canonical_due IS NOT NULL THEN canonical_due
      ELSE public.lts_card_transition_cash_date_v370(p_user_id,r->>'card_family',d) END;
    END IF;
    IF d<=p_as_of OR d>horizon OR d<(r->>'starts_on')::date OR d=ANY(seen_dates)
     OR(r->>'ends_on' IS NOT NULL AND d>(r->>'ends_on')::date) THEN CONTINUE; END IF;
    seen_dates:=array_append(seen_dates,d);base_amount:=nullif(t->>'amount_brl','')::numeric;
    SELECT coalesce(sum(abs((v->>'signed_amount')::numeric)),0),
     coalesce(jsonb_agg(v->>'source_ref' ORDER BY v->>'source_ref'),'[]')
    INTO known,refs FROM jsonb_array_elements(baseline)v
    WHERE public.lts_forecast_series_key_v1(v->>'description')=key
     AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
     AND date_trunc('month',(v->>'event_date')::date)=date_trunc('month',d);
    authoritative:=false;known_complete:=true;replace_amount:=0;replace_refs:='[]';
    IF r->>'card_family' IS NOT NULL THEN
     SELECT count(*)::int,coalesce(bool_or(coalesce((v->>'closed')::boolean,false) OR coalesce((v->>'paid')::boolean,false)),false),
      coalesce(bool_and(coalesce((v->>'complete')::boolean,false)),true),sum((v->>'amount_brl')::numeric)
     INTO invoice_count,authoritative,known_complete,invoice_amount
     FROM jsonb_array_elements(cycles)v WHERE v->>'series_key'=key
      AND date_trunc('month',(v->>'due_date')::date)=date_trunc('month',d);
     -- If a canonical cycle is missing from this reader, do not hide the mismatch
     -- by estimating a smaller residual against a different amount.
     IF invoice_count>0 AND invoice_amount IS NOT NULL AND NOT authoritative
      AND abs(invoice_amount-known)>0.005 THEN known_complete:=false;END IF;
    END IF;
    cancelled:=EXISTS(SELECT 1 FROM public.lts_projection_replacement_rule c
     WHERE c.user_id=p_user_id AND c.active AND c.action='suppress_legacy'
      AND c.replacement_source='owner_confirmation' AND coalesce(c.evidence->>'policy_action','')<>'revise'
      AND public.lts_forecast_series_key_v1(c.description_exact)=key AND d BETWEEN c.date_from AND c.date_to)
     OR EXISTS(SELECT 1 FROM public.lts_recurring_plan_v366 p
      WHERE p.user_id=p_user_id AND p.series_key=key
       AND (p.direction='entrada')=(r->>'direction'='income')
       AND p.confirmed_at >= (policy->>'_activated_at')::timestamptz
       AND ((NOT p.active AND d>=p.starts_on) OR (p.ends_on IS NOT NULL AND d>p.ends_on)));
    IF method='inflated_calendar' THEN
     -- The new annual template may split an old lump-sum estimate. Suppress all
     -- identified estimates for the same future year once, on its first slot.
     SELECT coalesce(jsonb_agg(v->>'source_ref' ORDER BY v->>'source_ref'),'[]'),
      coalesce(sum(abs((v->>'signed_amount')::numeric)),0)
     INTO replace_refs,replace_amount FROM jsonb_array_elements(baseline)v
     WHERE public.lts_forecast_series_key_v1(v->>'description')=key
      AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
      AND extract(year FROM(v->>'event_date')::date)=period.calendar_year
      AND v->>'source'='legacy_fix86' AND v->>'confidence'='legacy_projection_adjusted'
      AND NOT (v->>'source_ref'=ANY(replacement_seen));
     -- Documentary amounts in a month replace that month's estimate, preserving
     -- their identity/date and preventing a budget from adding a second payment.
     authoritative:=EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)v
      WHERE public.lts_forecast_series_key_v1(v->>'description')=key
       AND ((v->>'signed_amount')::numeric>0)=(r->>'direction'='income')
       AND date_trunc('month',(v->>'event_date')::date)=date_trunc('month',d)
       AND NOT(v->>'source'='legacy_fix86' AND v->>'confidence'='legacy_projection_adjusted'));
     IF NOT authoritative AND NOT cancelled THEN
      SELECT coalesce(array_agg(value),'{}')||replacement_seen INTO replacement_seen
      FROM jsonb_array_elements_text(replace_refs);
      known:=replace_amount;
     ELSE replace_refs:='[]';replace_amount:=0; END IF;
    END IF;
    withholding:=NULL;withholding_known:=false;
    IF method='salary_net' THEN
     SELECT count(*)::int,sum(abs(amount_total)) INTO withholding_rows,withholding
     FROM public.lts_commitment_documentary_schedule c WHERE c.user_id=p_user_id
      AND c.commitment_id=r->>'withholding_commitment'
      AND date_trunc('month',c.due_date)=date_trunc('month',d);
     withholding_known:=withholding_rows>0;
     IF withholding_rows=0 AND pg_catalog.pg_input_is_valid(r->>'withholding_ends_on','date')
      AND nullif(btrim(r->>'withholding_end_source_ref'),'') IS NOT NULL
      AND d>(r->>'withholding_ends_on')::date
      THEN withholding:=0;withholding_known:=true;END IF;
    END IF;
    slots:=slots||jsonb_build_array(jsonb_build_object('series_key',key,'event_date',d,
     'base_amount_brl',base_amount,'known_amount_brl',known,'known_complete',known_complete,
     'authoritative',authoritative,'cancelled',cancelled,
     'replacement_amount_brl',replace_amount,'replacement_refs',replace_refs,
     'withholding_brl',withholding,'withholding_known',withholding_known,
     'source_refs',refs||coalesce(t->'source_refs','[]')));
   END LOOP;
  END LOOP;
 END LOOP;
 RETURN lts_projection_private_v412.calculate(policy,history,slots,p_as_of);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.build(uuid,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.build(uuid,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.read_policy()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 result:=lts_projection_private_v412.build(u,current_date);
 RETURN (result-'events'-'replacement_refs')||jsonb_build_object('read_at',clock_timestamp());
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.read_policy() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.read_policy() TO authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_projection_policy_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT lts_projection_private_v412.read_policy()
$f$;
REVOKE ALL ON FUNCTION public.lts_browser_projection_policy_v412() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_projection_policy_v412() TO authenticated;

CREATE OR REPLACE FUNCTION lts_projection_private_v412.refresh()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
BEGIN
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text,166));
 PERFORM lts_projection_private_v412.refresh_reference(u,current_date);
 -- Reuse the installed V366/V376 materializer for its existing fixed plans.
 PERFORM public.lts_recurring_materialize_v366(u,current_date);
 PERFORM lts_projection_private_v412.invalidate_reads(u);
 result:=lts_projection_private_v412.read_policy();
 RETURN result||jsonb_build_object('refreshed',true);
END $f$;
REVOKE ALL ON FUNCTION lts_projection_private_v412.refresh() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_projection_private_v412.refresh() TO authenticated;
CREATE OR REPLACE FUNCTION public.lts_browser_projection_refresh_v412()
RETURNS jsonb LANGUAGE sql SECURITY INVOKER SET search_path='' AS $f$
 SELECT lts_projection_private_v412.refresh()
$f$;
REVOKE ALL ON FUNCTION public.lts_browser_projection_refresh_v412() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_projection_refresh_v412() TO authenticated;
