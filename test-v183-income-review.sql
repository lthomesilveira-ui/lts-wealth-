-- DBA integration test: synthetic rows only, all changes rolled back.
begin;
do $$
declare
 u uuid; email text; a uuid; f1 uuid; f2 uuid; p jsonb; before_row jsonb;
 token text; rejected boolean; checks integer:=0; monthly_before jsonb; monthly_after jsonb;
 family_before numeric; family_after numeric; flow_after jsonb;
begin
 select c.user_id,au.email into strict u,email
 from (select distinct user_id from lts_work_audit.cash_override_candidate_v1 limit 1)c
 join auth.users au on au.id=c.user_id;
 select ac.id into strict a from public.accounts ac where ac.user_id=u and ac.institution='Itaú' limit 1;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',u,'email',email,'role','authenticated')::text,true);
 insert into public.financial_events(user_id,account_id,event_date,description_raw,description_normalized,amount,nature,source,status,is_internal_transfer,is_projection,is_suppressed,category)
 values(u,a,current_date-3,'V183 isolated income fixture','V183 isolated income fixture',12.34,'income','itau_statement','active',false,false,false,'A classificar') returning id into f1;
 insert into public.financial_events(user_id,account_id,event_date,description_raw,description_normalized,amount,nature,source,status,is_internal_transfer,is_projection,is_suppressed,category)
 values(u,a,current_date-3,'V183 isolated income fixture','V183 isolated income fixture',23.45,'income','itau_statement','active',false,false,false,'A classificar') returning id into f2;
 select to_jsonb(e) into before_row from public.financial_events e where e.id=f1;
 -- Execute the public RPC with the actual API role, not postgres privileges.
 execute 'set local role authenticated';
 p:=public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34);
 if not coalesce((p->>'editable')::boolean,false) then raise exception 'preview failed: %',p; end if; checks:=checks+1;
 token:=p->>'token';
 monthly_before:=public.lts_browser_monthly_balance_v5(current_date-3,current_date-3);
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34,'Família','stale'); exception when others then rejected:=true; end;
 if not rejected then raise exception 'stale token accepted'; end if; checks:=checks+1;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34,'Despesa',token); exception when others then rejected:=true; end;
 if not rejected then raise exception 'expense category accepted'; end if; checks:=checks+1;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.35); exception when others then rejected:=true; end;
 if not rejected then raise exception 'wrong amount accepted'; end if; checks:=checks+1;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-2,'Itaú',12.34); exception when others then rejected:=true; end;
 if not rejected then raise exception 'wrong date accepted'; end if; checks:=checks+1;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'C6',12.34); exception when others then rejected:=true; end;
 if not rejected then raise exception 'wrong account accepted'; end if; checks:=checks+1;
 p:=public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34,'Família',token);
 if not coalesce((p->>'saved')::boolean,false) then raise exception 'save failed: %',p; end if; checks:=checks+1;
 monthly_after:=public.lts_browser_monthly_balance_v5(current_date-3,current_date-3);
 select coalesce(sum((x->>'total')::numeric),0) into family_before from jsonb_array_elements(monthly_before->'revenue_groups')x where x->>'label' ~* 'fam';
 select coalesce(sum((x->>'total')::numeric),0) into family_after from jsonb_array_elements(monthly_after->'revenue_groups')x where x->>'label' ~* 'fam';
 if family_after-family_before<>12.34 then raise exception 'monthly family group not updated: %',monthly_after->'revenue_groups'; end if; checks:=checks+1;
 if monthly_after->'totals' is distinct from monthly_before->'totals' then raise exception 'monthly financial totals changed'; end if; checks:=checks+1;
 flow_after:=public.lts_browser_flow_v11(current_date-3,current_date-3);
 if not exists(select 1 from jsonb_array_elements(coalesce(flow_after#>'{flow,historical,events}','[]'::jsonb)||coalesce(flow_after#>'{flow,current_future,events}','[]'::jsonb))x where x->>'source_ref'=f1::text and x->>'category'='Família') then raise exception 'flow category not updated'; end if; checks:=checks+1;
 if (select to_jsonb(e)-'category' from public.financial_events e where e.id=f1) is distinct from (before_row-'category') then raise exception 'non-category field changed'; end if; checks:=checks+1;
 if (select category from public.financial_events where id=f2) <> 'A classificar' then raise exception 'same-description sibling changed'; end if; checks:=checks+1;
 p:=public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34);
 if coalesce((p->>'editable')::boolean,true) then raise exception 'classified receipt editable'; end if; checks:=checks+1;
 update public.financial_events set is_internal_transfer=true where id=f2;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f2::text,current_date-3,'Itaú',23.45); exception when others then rejected:=true; end;
 if not rejected then raise exception 'transfer accepted'; end if; checks:=checks+1;
 update public.financial_events set is_internal_transfer=false,is_projection=true where id=f2;
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f2::text,current_date-3,'Itaú',23.45); exception when others then rejected:=true; end;
 if not rejected then raise exception 'projection accepted'; end if; checks:=checks+1;
 perform set_config('request.jwt.claims','{}',true);
 rejected:=false;
 begin perform public.lts_browser_income_category_v183('current_event',f1::text,current_date-3,'Itaú',12.34); exception when insufficient_privilege then rejected:=true; end;
 if not rejected then raise exception 'unauthenticated request accepted'; end if; checks:=checks+1;
 execute 'reset role';
 if has_function_privilege('anon','public.lts_browser_income_category_v183(text,text,date,text,numeric,text,text)','execute') then raise exception 'anonymous endpoint privilege'; end if; checks:=checks+1;
 if has_schema_privilege('anon','lts_income_private','usage') then raise exception 'anonymous private schema privilege'; end if; checks:=checks+1;
 if checks<>18 then raise exception 'incomplete tests'; end if;
end $$;
rollback;
select '18 integration checks passed; synthetic inserts, updates and audit rolled back' as result;
