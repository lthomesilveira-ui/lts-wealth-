-- Execute with the project DBA tool only. Every write is rolled back.
begin;
do $$
declare u uuid; email text; before_facts text; after_facts text;
 before_schedule jsonb; after_schedule jsonb; p jsonb; before_statement jsonb;
 rejected boolean; checks integer:=0; target text;
begin
 select c.user_id,a.email into strict u,email
 from (select distinct user_id from lts_work_audit.cash_override_candidate_v1 limit 1)c
 join auth.users a on a.id=c.user_id;
 select md5(string_agg(to_jsonb(e)::text,',' order by e.id)) into before_facts from public.financial_events e where user_id=u;
 select jsonb_agg(to_jsonb(s) order by id) into before_statement from public.lts_brokerage_position_snapshots s where user_id=u;
 select jsonb_agg(jsonb_build_array(id,quantity,eligibility_date,settlement_days,active) order by id) into before_schedule from public.lts_future_liquidity_schedule where user_id=u;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'email',email,'role','authenticated')::text,true);
 execute 'set local role authenticated';
 p:=public.lts_browser_award_provenance_v183();
 if p->>'financial_effect'<>'none' or jsonb_array_length(p->'groups')=0 then raise exception 'empty or mutable provenance'; end if; checks:=checks+1;
 if exists(select 1 from jsonb_array_elements(p->'groups')g cross join lateral jsonb_array_elements(g->'components')c where c->>'market_quote_as_of' is not null) then raise exception 'invented live quote date'; end if; checks:=checks+1;
 target:=p#>>'{groups,0,group_key}';
 rejected:=false;
 begin perform public.lts_browser_save_all_award_assumptions_v1(0,5); exception when others then rejected:=true; end;
 if not rejected then raise exception 'invalid price accepted'; end if; checks:=checks+1;
 rejected:=false;
 begin perform public.lts_browser_save_all_award_assumptions_v1(2,101); exception when others then rejected:=true; end;
 if not rejected then raise exception 'invalid exchange accepted'; end if; checks:=checks+1;
 p:=public.lts_browser_save_all_award_assumptions_v1(2,5);
 if p->>'ok'<>'true' then raise exception 'global model write failed'; end if; checks:=checks+1;
 p:=public.lts_browser_award_provenance_v183();
 if exists(select 1 from jsonb_array_elements(p->'groups')g cross join lateral jsonb_array_elements(g->'components')c
   where (c->>'unit_price_usd')::numeric<>2 or (c->>'fx_rate')::numeric<>5
     or c->>'provenance'<>'manual' or c->>'assumption_recorded_at' is null
     or (c->>'gross_value_brl')::numeric<>round((c->>'quantity')::numeric*10,2)) then raise exception 'global assumption readback mismatch'; end if; checks:=checks+1;
 if exists(select 1 from jsonb_array_elements(p->'groups')g cross join lateral jsonb_array_elements(g->'components')c
   where (c->>'considered_value_brl')::numeric<>round((c->>'quantity')::numeric*10*case when g->>'asset_type'='cash_rsu' then .7 else 1 end,2)) then raise exception 'tax reserve contract mismatch'; end if; checks:=checks+1;
 p:=public.lts_browser_save_award_assumption_v1(target,3,5);
 if p->>'ok'<>'true' then raise exception 'individual model write failed'; end if;
 p:=public.lts_browser_award_provenance_v183();
 if exists(select 1 from jsonb_array_elements(p->'groups')g cross join lateral jsonb_array_elements(g->'components')c
   where (c->>'unit_price_usd')::numeric<>case when g->>'group_key'=target then 3 else 2 end) then raise exception 'individual edit leaked into sibling vesting'; end if; checks:=checks+1;
 perform set_config('request.jwt.claims','{}',true);rejected:=false;
 begin perform public.lts_browser_award_provenance_v183(); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'anonymous data access'; end if; checks:=checks+1;
 execute 'reset role';
 select md5(string_agg(to_jsonb(e)::text,',' order by e.id)) into after_facts from public.financial_events e where user_id=u;
 if before_facts is distinct from after_facts then raise exception 'model write changed bank facts'; end if; checks:=checks+1;
 if before_statement is distinct from (select jsonb_agg(to_jsonb(s) order by id) from public.lts_brokerage_position_snapshots s where user_id=u) then raise exception 'model write changed statement'; end if; checks:=checks+1;
 select jsonb_agg(jsonb_build_array(id,quantity,eligibility_date,settlement_days,active) order by id) into after_schedule from public.lts_future_liquidity_schedule where user_id=u;
 if before_schedule is distinct from after_schedule then raise exception 'quantities or original dates changed'; end if; checks:=checks+1;
 if has_function_privilege('anon','public.lts_browser_award_provenance_v183()','execute') then raise exception 'anonymous endpoint'; end if; checks:=checks+1;
 if checks<>13 then raise exception 'incomplete checks: %',checks; end if;
end $$;
rollback;
