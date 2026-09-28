-- Reconcile cached future invoice amounts at read time. No source or cache writes.
CREATE OR REPLACE FUNCTION public.lts_flow_invoice_amount_overlay_v226(p_flow jsonb,p_invoices jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
declare changes jsonb; new_events jsonb; new_days jsonb;
begin
 with invoices as (
  select i->>'card_name' card_name,(i->>'reference_month')::date AS month,(i->>'due_date')::date due_date,(i->>'amount')::numeric amount
  from jsonb_array_elements(coalesce(p_invoices,'[]'::jsonb)) i
 ), updates as (
  select e->>'source_ref' ref,e->>'account' account,(e->>'event_date')::date AS day,
   (e->>'signed_amount')::numeric old_amount,-i.amount new_amount
  from jsonb_array_elements(coalesce(p_flow->'events','[]'::jsonb))e
  join invoices i on e->>'source_ref'=i.card_name||'|'||to_char(i.month,'YYYY-MM')
    and (e->>'event_date')::date=i.due_date
  where e->>'source'='card_invoice' and (e->>'event_date')::date>=current_date
   and e->>'account' in ('Itaú','Bradesco','C6') and (e->>'signed_amount')::numeric<>-i.amount
 )select jsonb_agg(to_jsonb(u)) into changes from updates u;
 if changes is null then return p_flow;end if;
 if exists(select 1 from jsonb_array_elements(changes)c group by c->>'ref' having count(*)>1)then
  raise exception 'Ambiguous invoice composition';end if;
 select jsonb_agg(e||case when c is null then '{}'::jsonb else jsonb_build_object('signed_amount',(c->>'new_amount')::numeric)end order by n)
 into new_events from jsonb_array_elements(p_flow->'events')with ordinality src(e,n)
 left join lateral(select x from jsonb_array_elements(changes)x where x->>'ref'=e->>'source_ref' and e->>'source'='card_invoice')a(c)on true;
 with deltas as materialized (
  select (c->>'day')::date AS day,c->>'account' bank,(c->>'new_amount')::numeric-(c->>'old_amount')::numeric net,
   greatest((c->>'new_amount')::numeric,0)-greatest((c->>'old_amount')::numeric,0) entries,
   greatest(-(c->>'new_amount')::numeric,0)-greatest(-(c->>'old_amount')::numeric,0) exits
  from jsonb_array_elements(changes)c
 ), adjusted as (
  select d,n,(d->>'date')::date AS day,
   coalesce(sum(net)filter(where bank='Itaú'),0) ci,coalesce(sum(net)filter(where bank='Bradesco'),0) cb,coalesce(sum(net)filter(where bank='C6'),0) cc,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='Itaú'),0) ni,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='Bradesco'),0) nb,
   coalesce(sum(net)filter(where x.day=(d->>'date')::date and bank='C6'),0) nc,
   coalesce(sum(entries)filter(where x.day=(d->>'date')::date),0) en,
   coalesce(sum(exits)filter(where x.day=(d->>'date')::date),0) ex
  from jsonb_array_elements(p_flow->'days')with ordinality src(d,n)
  left join deltas x on x.day<=(d->>'date')::date group by d,n
 ), composed as (
  select n,d||jsonb_build_object(
   'Itaú',(d->'Itaú')||jsonb_build_object('balance',(d#>>'{Itaú,balance}')::numeric+ci,'net',(d#>>'{Itaú,net}')::numeric+ni),
   'Bradesco',(d->'Bradesco')||jsonb_build_object('balance',(d#>>'{Bradesco,balance}')::numeric+cb,'net',(d#>>'{Bradesco,net}')::numeric+nb),
   'C6',(d->'C6')||jsonb_build_object('balance',(d#>>'{C6,balance}')::numeric+cc,'net',(d#>>'{C6,net}')::numeric+nc),
   'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',(d#>>'{Consolidado,bank_balance}')::numeric+ci+cb+cc,'economic_net',(d#>>'{Consolidado,economic_net}')::numeric+ni+nb+nc),
   'summary',(d->'summary')||jsonb_build_object('Consolidado',(d#>'{summary,Consolidado}')||jsonb_build_object('entries',(d#>>'{summary,Consolidado,entries}')::numeric+en,'exits',(d#>>'{summary,Consolidado,exits}')::numeric+ex)),
   'fix86_columns',(d->'fix86_columns')||(select jsonb_object_agg(k,to_jsonb(v::numeric+case
     when k='entradas' then en when k='saidas' then ex when k='saldo_anterior' then ci+cb+cc-ni-nb-nc else ci+cb+cc end))
    from jsonb_each_text(d->'fix86_columns')z(k,v)where k in ('entradas','saidas','saldo_anterior','saldo_final','liq_d0_1','liq_d30','saldo_apos_d0_1','saldo_apos_rsu','saldo_apos_fgts','disponivel_total','posicao_antes_rsus','posicao_curto_prazo','posicao_economica_total'))
  )value from adjusted
 )select jsonb_agg(value order by n)into new_days from composed;
 return p_flow||jsonb_build_object('days',new_days,'events',new_events);
end $f$;
REVOKE ALL ON FUNCTION public.lts_flow_invoice_amount_overlay_v226(jsonb,jsonb) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_flow_invoice_amount_overlay_v226(jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_flow_future_read_slice_v9(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare c record; d jsonb; e jsonb; base jsonb; requested_horizon integer;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<current_date then raise exception 'invalid future range'; end if;
  if p_to+30>current_date+1800 then raise exception 'future range exceeds supported horizon'; end if;
  select * into c from public.lts_flow_future_read_cache_v2
   where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
     and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
   order by refreshed_at desc limit 1;
  if not found then
    requested_horizon:=greatest(60,(p_to-current_date)+31);
    perform public.lts_flow_future_read_cache_refresh_v9(p_user_id,requested_horizon);
    select * into c from public.lts_flow_future_read_cache_v2
     where user_id=p_user_id and as_of=current_date and from_date<=p_from and to_date>=p_to+30
       and engine_version='daily-flow-fix86-v20-award-milestones-invoice-precedence-v181'
     order by refreshed_at desc limit 1;
  end if;
  if not found then raise exception 'future Flow cache could not cover requested range'; end if;
  c.payload:=public.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.lts_card_invoices_effective_v226(p_user_id)i where i.status='open' and i.due_date>=current_date));
  with all_src as (
    select x,(x->>'date')::date dt from jsonb_array_elements(coalesce(c.payload->'days','[]'::jsonb)) x
     where (x->>'date')::date between p_from and p_to+30
  ), src as (select * from all_src where dt<=p_to), adj as (
    select s.dt,jsonb_set(s.x,'{fix86_columns,liq_d30}',to_jsonb(
      coalesce(nullif(s.x#>>'{fix86_columns,liq_d0_1}','')::numeric,0)+coalesce((
        select sum(nullif(y.x#>>'{Consolidado,economic_net}','')::numeric) from all_src y
         where y.dt>s.dt and y.dt<=s.dt+30),0)),true) x from src s
  ) select coalesce(jsonb_agg(x order by dt),'[]'::jsonb) into d from adj;
  select coalesce(jsonb_agg(x order by x->>'event_date',x->>'source_ref'),'[]'::jsonb) into e
    from jsonb_array_elements(coalesce(c.payload->'events','[]'::jsonb)) x
   where (x->>'event_date')::date between p_from and p_to;
  base:=(c.payload-'days'-'events')||jsonb_build_object('from',p_from,'to',p_to,'days',d,'events',e,
    'version','daily-flow-fix86-v20-award-milestones-invoice-precedence-v181-cache-slice','horizon_contract','requested-period-plus-30-days-v3',
    'cold_refresh_horizon_days',requested_horizon);
  return base;
end
$function$
;

