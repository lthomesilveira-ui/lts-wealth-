-- Existing owner-confirmed cycle rules also cover unresolved legacy card forecasts.
-- Only the date/displacement of the exact projected family can change. Original imports stay intact.
DO $patch$
DECLARE target regprocedure:='public.lts_corrected_cashflow_fix86_v5(uuid,date,date)'::regprocedure;
 definition text;attributes jsonb;part jsonb;restored text;
 patches jsonb:=$pairs$[{"name": "legacy-projected-due-date", "old": "case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date) else s.event_date end event_date,", "new": "case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date)\n         when due_rule.due_day is not null then date_trunc('month',s.event_date)::date+due_rule.due_day-1\n         else s.event_date end event_date,"}, {"name": "preserve-original-date-and-shift-state", "old": "case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date)<>s.event_date else s.displaced end displaced", "new": "case when s.source='card_invoice' then coalesce(nullif(ci.metadata->>'cash_effect_date','')::date,s.event_date)<>s.event_date\n         when due_rule.due_day is not null then date_trunc('month',s.event_date)::date+due_rule.due_day-1<>s.event_date\n         else s.displaced end displaced"}, {"name": "owner-effective-rule-for-exact-projected-card-family", "old": "   and s.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')\n)", "new": "   and s.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')\n  left join lateral (\n    select r.due_day from public.lts_card_due_rule_v290 r\n    where r.user_id=p_user_id and r.family='aeternum'\n      and r.effective_from<=date_trunc('month',s.event_date)::date\n      and s.source='legacy_fix86' and s.confidence='legacy_projection_adjusted'\n      and not coalesce(s.displaced,false) and s.signed_amount<0\n      and lower(trim(s.description))='visa aeternum' and s.account='Bradesco'\n    order by r.effective_from desc limit 1\n  ) due_rule on true\n)"}]$pairs$::jsonb;
BEGIN
 SELECT pg_get_functiondef(target),to_jsonb(p)-'prosrc' INTO definition,attributes FROM pg_proc p WHERE p.oid=target;
 IF strpos(definition,'owner-effective-rule-for-exact-projected-card-family')>0 THEN RAISE EXCEPTION 'V361_UNEXPECTED_MARKER';END IF;
 IF strpos(definition,'due_rule.due_day')>0 THEN
  restored:=definition;
  FOR part IN SELECT value FROM jsonb_array_elements(patches) WITH ORDINALITY p(value,n) ORDER BY n DESC LOOP
   restored:=replace(restored,part->>'new',part->>'old');
  END LOOP;
  IF md5(restored)<>'21e9a74eae386efd53486e261dac1101' THEN RAISE EXCEPTION 'V361_REPLAY_SOURCE_CHANGED';END IF;
  RETURN;
 END IF;
 IF md5(definition)<>'21e9a74eae386efd53486e261dac1101' THEN RAISE EXCEPTION 'V361_FLOW_SOURCE_CHANGED';END IF;
 FOR part IN SELECT value FROM jsonb_array_elements(patches) LOOP
  IF (length(definition)-length(replace(definition,part->>'old','')))/length(part->>'old')<>1
  THEN RAISE EXCEPTION 'V361_FLOW_ANCHOR_CHANGED: %',part->>'name';END IF;
  definition:=replace(definition,part->>'old',part->>'new');
 END LOOP;
 EXECUTE definition;
 IF attributes IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid=target)
 THEN RAISE EXCEPTION 'V361_FLOW_ATTRIBUTES_CHANGED';END IF;
END $patch$;
