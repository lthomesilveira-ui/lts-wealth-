-- The monthly table and its result use the same newly observed expenses as
-- the executive report. Card payments and own-account transfers remain excluded.
DO $$ DECLARE definition text; BEGIN
 definition:=pg_get_functiondef('public.lts_browser_monthly_v229(date,date)'::regprocedure);
 definition:=replace(definition,'computed numeric;','computed numeric; additions jsonb; delta numeric;');
 definition:=replace(definition,'b:=public.lts_browser_monthly_balance_v6(p_from,p_to);',
 $patch$b:=public.lts_browser_monthly_balance_v6(p_from,p_to);
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]'),coalesce(sum(x.amount),0) INTO additions,delta FROM (
  SELECT date_trunc('month',event_date)::date AS month,sum(-signed_amount) amount FROM public.lts_v229_new_bank_rows(u,p_from,p_to) GROUP BY 1
 ) x;
 b:=b||jsonb_build_object('monthly_totals',coalesce((SELECT jsonb_agg(m||jsonb_build_object(
  'expenses',(m->>'expenses')::numeric+coalesce((a->>'amount')::numeric,0),
  'operating_balance',(m->>'operating_balance')::numeric-coalesce((a->>'amount')::numeric,0),
  'cash_after_extraordinary',(m->>'cash_after_extraordinary')::numeric-coalesce((a->>'amount')::numeric,0)) ORDER BY m->>'month')
  FROM jsonb_array_elements(b->'monthly_totals') m LEFT JOIN jsonb_array_elements(additions) a ON a->>'month'=m->>'month'),'[]'),
  'totals',(b->'totals')||jsonb_build_object('expenses',(b#>>'{totals,expenses}')::numeric+delta,
   'operating_balance',(b#>>'{totals,operating_balance}')::numeric-delta,
   'cash_after_extraordinary',(b#>>'{totals,cash_after_extraordinary}')::numeric-delta));$patch$);
 EXECUTE definition;
END $$;
