DO $guard$ BEGIN
 IF md5(pg_get_functiondef('lts_budget_private_v470.append_result(uuid,date,jsonb,jsonb,jsonb)'::regprocedure)) <> 'b3013c883c860383431e74b9bf14ed72' OR md5(pg_get_functiondef('lts_budget_private_v470.calculate(jsonb,jsonb,jsonb,date)'::regprocedure)) <> 'd09292717aa42458d768100274698f2a' THEN
  RAISE EXCEPTION 'Budget calculation contract changed';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.calculate(p jsonb, base jsonb, calendar jsonb, asof date)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO ''
AS $function$
DECLARE ev jsonb:=base->'events';rr jsonb:=base->'replacement_refs';series jsonb:=base->'series';warnings jsonb:=base->'warnings';
 r jsonb;c jsonb;s jsonb;m date;d date;h date:=(base->>'horizon_end')::date;target numeric;known numeric;extra numeric;periods jsonb;annual jsonb;bad int; month_rows jsonb; rule_events jsonb;
BEGIN
 IF p IS NULL THEN RETURN base;END IF;
 IF p->>'schema' IS DISTINCT FROM 'owner-budgets-v470' OR base->>'as_of' IS DISTINCT FROM asof::text
 OR jsonb_typeof(calendar) IS DISTINCT FROM 'array' OR jsonb_array_length(p->'budgets')<1
 OR (SELECT count(DISTINCT x->>'id')FROM jsonb_array_elements(p->'budgets')x)<>jsonb_array_length(p->'budgets')
 THEN RAISE EXCEPTION 'Confira o orçamento das despesas.';END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(coalesce(p->'suppressions','[]')) LOOP
  IF (s->>'event_date')::date>asof THEN rr:=rr||jsonb_build_array(s->>'source_ref');END IF;
 END LOOP;
 FOR r IN SELECT value FROM jsonb_array_elements(p->'budgets') ORDER BY value->>'id' LOOP
  target:=(r->>'amount_brl')::numeric;periods:='[]';bad:=0;rule_events:='[]';
  IF r->>'id' !~ '^owner_[a-z_]+$' OR target IS NULL OR target<=0 OR target>100000 OR nullif(r->>'category','') IS NULL
  OR nullif(r->>'description','') IS NULL THEN RAISE EXCEPTION 'Confira o valor da despesa.';END IF;
  SELECT jsonb_object_agg(month_key,entries) INTO month_rows FROM (
   SELECT x->>'cash_month' month_key,jsonb_agg(x) entries FROM jsonb_array_elements(calendar)x
   WHERE x->>'id'=r->>'id' AND x->>'cash_month' IS NOT NULL GROUP BY 1
  ) indexed;
  FOR m IN SELECT d0::date FROM generate_series((p->>'starts_on')::date,date_trunc('month',h),interval '1 month')d0 LOOP
   d:=m+2;IF d<=asof OR d>h THEN CONTINUE;END IF;
   IF jsonb_array_length(month_rows->m::text) IS DISTINCT FROM 1 THEN RAISE EXCEPTION 'Confira os compromissos do mês.';END IF;
   c:=month_rows->m::text->0;
   IF c->>'trusted' IS DISTINCT FROM 'true' THEN known:=NULL;extra:=NULL;bad:=bad+1;
   ELSE
    known:=greatest((c->>'known_brl')::numeric,0);extra:=greatest(target-known,0);
    IF extra>0 THEN rule_events:=rule_events||jsonb_build_array(lts_recurring_private_v469.forecast(r->>'id',r->>'description','Bradesco',extra,d));END IF;
   END IF;
   periods:=periods||jsonb_build_array(jsonb_build_object('event_date',d,'budget_total_brl',target,'known_brl',known,'additional_brl',extra,'trusted',c->'trusted'));
  END LOOP;
  ev:=ev||rule_events;
  SELECT coalesce(jsonb_agg(jsonb_build_object('year',y,'partial_year',y=extract(year FROM asof)::int,'budget_total_brl',CASE WHEN ok THEN total ELSE NULL END,'additional_brl',CASE WHEN ok THEN more ELSE NULL END)ORDER BY y),'[]') INTO annual
  FROM(SELECT extract(year FROM(x->>'event_date')::date)::int y,bool_and((x->>'trusted')::boolean)ok,
   sum(greatest((x->>'budget_total_brl')::numeric,(x->>'known_brl')::numeric))total,sum((x->>'additional_brl')::numeric)more FROM jsonb_array_elements(periods)x GROUP BY 1)a;
  series:=series||jsonb_build_array(jsonb_build_object('series_key',r->>'id','description',r->>'description','account','Bradesco','direction','expense','method','fixed',
   'reference_amount_brl',target,'reference_window',r->'reference_window','uses_history',coalesce((r->>'uses_history')::boolean,false),'reference_stale',false,
   'expected_months',12,'coverage_months',r->'coverage_months','coverage',periods,'annual_totals',annual,'warnings',CASE WHEN bad>0 THEN '["unreconciled_periods"]'::jsonb ELSE '[]'::jsonb END));
  IF bad>0 THEN warnings:=warnings||jsonb_build_array(jsonb_build_object('series_key',r->>'id','codes',jsonb_build_array('unreconciled_periods')));END IF;
 END LOOP;
 RETURN base||jsonb_build_object('events',ev,'replacement_refs',rr,'series',series,'warnings',warnings);
END $function$;
CREATE OR REPLACE FUNCTION lts_budget_private_v470.append_result(u uuid, asof date, base jsonb, cards jsonb, baseline jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO ''
AS $function$
DECLARE p jsonb:=lts_budget_private_v470.owner_plan(u);calendar jsonb;s jsonb;
BEGIN
 IF p IS NULL THEN RETURN base;END IF;
 FOR s IN SELECT value FROM jsonb_array_elements(coalesce(p->'suppressions','[]')) WHERE (value->>'event_date')::date>asof LOOP
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(baseline)b WHERE b->>'source_ref'=s->>'source_ref' AND b->>'event_date'=s->>'event_date'
   AND b->>'description'=s->>'description' AND b->>'account'=s->>'account' AND b->>'signed_amount'=s->>'signed_amount')
  THEN RAISE EXCEPTION 'Uma despesa prevista mudou. Confira o lançamento.';END IF;
 END LOOP;
 WITH bank_rows AS MATERIALIZED (
  SELECT b, (b->>'signed_amount')::numeric signed_amount, (b->>'event_date')::date due,
    public.lts_card_family_v226(b->>'description', b->>'account') family
  FROM jsonb_array_elements(baseline) b WHERE (b->>'signed_amount')::numeric < 0
 ), invoices AS MATERIALIZED (
  SELECT family, date_trunc('month',due)::date cash_month, sum(-signed_amount) base_amount
  FROM bank_rows WHERE family IS NOT NULL GROUP BY 1,2
 ), items AS MATERIALIZED (
  SELECT date_trunc('month',(cy->>'due_date')::date)::date cash_month, i,
    inv.base_amount IS NOT NULL AND nullif(cy->>'amount','') IS NOT NULL
    AND abs(inv.base_amount-(cy->>'amount')::numeric) <= 0.005
    AND nullif(i->>'source_id','') IS NOT NULL trusted
  FROM jsonb_array_elements(cards->'cards') ca
  CROSS JOIN LATERAL jsonb_array_elements(ca->'cycles') cy
  CROSS JOIN LATERAL jsonb_array_elements(cy->'items') i
  LEFT JOIN invoices inv ON inv.family=ca->>'family'
    AND inv.cash_month=date_trunc('month',(cy->>'due_date')::date)::date
  WHERE (cy->>'due_date')::date > asof AND coalesce(i->>'is_payment','false') <> 'true'
    AND (i->>'amount')::numeric > 0
 ), direct AS MATERIALIZED (
  SELECT b, due, signed_amount, family FROM bank_rows
  WHERE due > asof AND NOT coalesce(base->'replacement_refs','[]') ? (b->>'source_ref')
  UNION ALL
  SELECT e, (e->>'event_date')::date, (e->>'signed_amount')::numeric,
    public.lts_card_family_v226(e->>'description', e->>'account')
  FROM jsonb_array_elements(base->'events') e WHERE (e->>'signed_amount')::numeric < 0
 ), classified AS MATERIALIZED (
  SELECT b->>'source_ref' source_ref, date_trunc('month',due)::date cash_month, -signed_amount amount,
    CASE WHEN family IS NULL THEN public.lts_flow_classification_decision_v1(u,b) END event
  FROM direct
 ), rules AS MATERIALIZED (
  SELECT r AS rule, r->>'id' id FROM jsonb_array_elements(p->'budgets') r
 ), matched AS (
  SELECT r.id, i.cash_month, (i.i->>'amount')::numeric known, i.trusted
  FROM rules r JOIN items i ON lts_budget_private_v470.matches(r.rule,i.i)
  UNION ALL
  SELECT r.id, d.cash_month, d.amount, true
  FROM rules r JOIN classified d ON
    (d.event IS NOT NULL AND lts_budget_private_v470.matches(r.rule,d.event))
    OR coalesce(r.rule->'source_refs','[]') ? d.source_ref
 ), month_totals AS (
  SELECT id, cash_month, sum(known) known, bool_and(trusted) trusted FROM matched GROUP BY 1,2
 ), slots AS (
  SELECT r.id, d::date cash_month FROM rules r
  CROSS JOIN generate_series((p->>'starts_on')::date,date_trunc('month',(base->>'horizon_end')::date),interval '1 month') d
 )
 SELECT jsonb_agg(jsonb_build_object('id',s.id,'cash_month',s.cash_month,'known_brl',coalesce(t.known,0),
  'trusted',coalesce(cards->>'complete','false')='true' AND coalesce(t.trusted,true)) ORDER BY s.id,s.cash_month)
 INTO calendar FROM slots s LEFT JOIN month_totals t USING(id,cash_month);
 RETURN lts_budget_private_v470.calculate(p,base,calendar,asof);
END $function$;
