-- Set request.jwt.claims for the authorized owner before running.
BEGIN;
SET LOCAL timezone='America/Sao_Paulo';
do $$ declare u uuid:=public.lts_browser_assert_user_v1(); ranges jsonb:=jsonb_build_array(
 jsonb_build_object('from',date_trunc('month',current_date)::date,'to',current_date),
 jsonb_build_object('from',date_trunc('year',current_date)::date,'to',current_date),
 jsonb_build_object('from',(date_trunc('month',current_date)-interval '11 months')::date,'to',current_date));
 r jsonb; report jsonb; monthly jsonb; detail jsonb; expected numeric; results jsonb:='[]'; begin
 for r in select value from jsonb_array_elements(ranges) loop
 report:=public.lts_browser_expenses_v229((r->>'from')::date,(r->>'to')::date);
 monthly:=public.lts_browser_monthly_v229((r->>'from')::date,(r->>'to')::date);
 detail:=public.lts_browser_expense_detail_v229((r->>'from')::date,(r->>'to')::date,null,null,0,1,null);
 select sum(amount) into expected from public.lts_v229_expense_rows(u,(r->>'from')::date,(r->>'to')::date);
 if abs((report#>>'{summary,selected_total}')::numeric-expected)>.005
 or abs((monthly#>>'{totals,expenses}')::numeric-expected)>.005
 or abs((detail->>'total')::numeric-expected)>.005
 then raise exception 'Report, monthly, detail or source total differs';end if;
 results:=results||jsonb_build_array(r||jsonb_build_object('source_total',expected,'report',report#>'{summary,selected_total}','monthly',monthly#>'{totals,expenses}','detail',detail->'total','last_12m',report#>'{summary,last_12m}','comparison',report->'comparison','period',report->'period'));
 end loop;
 perform set_config('lts.v231.qa.reports',results::text,true);end $$;
 select current_setting('lts.v231.qa.reports')::jsonb result;rollback;
