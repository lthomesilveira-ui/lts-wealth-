-- Match the Dashboard RSU alert to the dated scheduled-availability series already shown by Flow.
CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
declare j jsonb:=public.lts_browser_planning_executive_v2(); d01 text; rsu text; fg text;
begin
 if j->>'version'<>'planning-executive-v2-current-anchors' then raise exception 'planning v2 not ready'; end if;
 select x->>'first_need_next_layer' into d01 from jsonb_array_elements(j->'layers') x where x->>'id'='d01';
 select x->>'first_need_next_layer' into rsu from jsonb_array_elements(j->'layers') x where x->>'id'='future_vestings';
 fg:=j#>>'{summary,first_negative_even_with_fgts}';
 return jsonb_build_object('version','planning-ui-contract-v2','period_to',j#>>'{period,to}','d01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',(j#>>'{summary,fgts_covers_horizon}')::boolean,'fgts_request_by',j#>>'{summary,fgts_request_by}',
 'labels',jsonb_build_object('d01',case when d01 is null then 'Caixa consolidado após D0/D1 preservado até 31/12/2027' else 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') end,
 'rsu',case when rsu is null then 'Com RSUs disponíveis, sem ruptura até 31/12/2027' else 'Com RSUs disponíveis, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') end,
 'fgts',case when fg is null then 'Com FGTS, sem ruptura até 31/12/2027' else 'Mesmo com FGTS, a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') end));
end $function$
;
