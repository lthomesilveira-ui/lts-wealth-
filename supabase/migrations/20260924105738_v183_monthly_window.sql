-- Inclusive report boundaries must match the canonical expense detail.
-- This changes one read predicate; no source facts, permissions or categories change.
DO $repair$
DECLARE
  definition text;
  expected_fragment text := $old$  from params p cross join lateral public.lts_expense_total_rows_v5(p_user_id,p.from_date,p.to_date) e
$old$;
  replacement_fragment text := $new$  from params p cross join lateral public.lts_expense_total_rows_v5(p_user_id,p.from_date,p.to_date) e
  where e.event_date between p.from_date and p.to_date
$new$;
  before_reports jsonb;
  after_reports jsonb;
  u uuid;
  bounds record;
  report jsonb;
  expected_total numeric;
BEGIN
  SELECT pg_get_functiondef('public.lts_monthly_balance_v1(uuid,date,date)'::regprocedure) INTO definition;
  IF strpos(definition,expected_fragment)=0 OR strpos(definition,replacement_fragment)>0
     OR (length(definition)-length(replace(definition,expected_fragment,'')))/length(expected_fragment)<>1 THEN
    RAISE EXCEPTION 'Monthly reader changed; review migration before applying';
  END IF;

  -- Entire closed months and the current-year report must remain byte-equivalent.
  SELECT jsonb_agg(jsonb_build_object('user',c.user_id,'from',p.a,'to',p.b,
    'report',public.lts_monthly_balance_v1(c.user_id,p.a,p.b)) ORDER BY c.user_id,p.a,p.b)
  INTO before_reports
  FROM (SELECT DISTINCT user_id FROM public.lts_expense_effective_read_cache) c
  CROSS JOIN (VALUES
    (date '2026-01-01',date '2026-02-28'),
    (date_trunc('year',current_date)::date,current_date)
  ) p(a,b);

  EXECUTE replace(definition,expected_fragment,replacement_fragment);

  SELECT jsonb_agg(jsonb_build_object('user',c.user_id,'from',p.a,'to',p.b,
    'report',public.lts_monthly_balance_v1(c.user_id,p.a,p.b)) ORDER BY c.user_id,p.a,p.b)
  INTO after_reports
  FROM (SELECT DISTINCT user_id FROM public.lts_expense_effective_read_cache) c
  CROSS JOIN (VALUES
    (date '2026-01-01',date '2026-02-28'),
    (date_trunc('year',current_date)::date,current_date)
  ) p(a,b);
  IF before_reports IS DISTINCT FROM after_reports THEN
    RAISE EXCEPTION 'Full-period reports changed; reverting monthly reader';
  END IF;

  -- Real-source checks run under the administrator applying this migration.
  -- No JWT claims, browser identity or authentication guards are changed.
  FOR u IN SELECT DISTINCT user_id FROM public.lts_expense_effective_read_cache LOOP
    FOR bounds IN SELECT * FROM (VALUES
      (date '2026-01-17',date '2026-02-12'),
      (date '2026-01-17',date '2026-01-31'),
      (date '2026-02-01',date '2026-02-12'),
      (date '2026-01-05',date '2026-01-05')
    ) p(a,b) LOOP
      report:=public.lts_monthly_balance_v1(u,bounds.a,bounds.b);
      SELECT coalesce(sum(amount),0) INTO expected_total
      FROM public.lts_v178_expense_rows(u,bounds.a,bounds.b);
      IF abs((report#>>'{totals,expenses}')::numeric-expected_total)>0.01 THEN
        RAISE EXCEPTION 'Partial-period source total differs from expense detail';
      END IF;
    END LOOP;
  END LOOP;
END
$repair$;
