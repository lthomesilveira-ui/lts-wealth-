-- Correct the aggregate aliases used by the V171 coverage disclosure.
do $migration$
declare
  v_definition text;
  v_before text;
begin
  select pg_get_functiondef('public.lts_browser_expense_executive_v6(date,date)'::regprocedure)
    into v_definition;
  v_before:=v_definition;
  v_definition:=replace(v_definition,
    '''total'',round(coalesce(sum(amount),0),2),',
    '''total'',round(coalesce(sum(total),0),2),');
  v_definition:=replace(v_definition,
    '''rows'',count(*),',
    '''rows'',coalesce(sum(rows),0),');
  if v_definition=v_before then
    raise exception 'V171 coverage aggregation patch point not found';
  end if;
  execute v_definition;
end
$migration$;
