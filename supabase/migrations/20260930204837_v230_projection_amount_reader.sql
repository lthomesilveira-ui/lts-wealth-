-- Operational hotfix for V229. No customer records or new financial rules.
-- Keep the complete classified purchase reader for Despesas / card drilldowns.
CREATE FUNCTION public.lts_card_invoice_amounts_v230(p_user_id uuid)
RETURNS TABLE(user_id uuid,card_name text,reference_month date,due_date date,status text,amount numeric,source text)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $function$
WITH src AS MATERIALIZED (
 SELECT s.user_id,s.institution_code,s.signed_amount,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 CASE WHEN s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 THEN (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date END forecast
 FROM public.lts_open_finance_staging s
 WHERE s.user_id=p_user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND s.normalized_payload->>'status'='PENDING'
 AND NOT (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 OR coalesce(s.raw_payload->>'category','')='Credit card payment'
 OR public.lts_v178_norm(s.description_raw) ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)')
), open_cards AS MATERIALIZED (
 SELECT DISTINCT ON (family) family,reference_month,due_date FROM (
 SELECT public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
 WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END) family,
 i.reference_month,i.due_date FROM public.card_invoices i
 WHERE i.user_id=p_user_id AND i.status='open' AND i.due_date>=current_date
 ) q ORDER BY family,due_date
), dated AS MATERIALIZED (
 SELECT s.family,-s.signed_amount amount,
 CASE WHEN b.id IS NOT NULL THEN date_trunc('month',b.posting_date)::date
 WHEN s.institution_code='336' AND s.forecast<=date_trunc('month',current_date)::date
 THEN coalesce(c.reference_month,s.forecast) ELSE s.forecast END reference_month
 FROM src s LEFT JOIN public.lts_open_finance_staging b ON b.user_id=s.user_id
 AND b.institution_code=s.institution_code AND b.resource_type='invoice'
 AND b.normalized_payload->>'provider_id'=s.raw_bill_id
 LEFT JOIN open_cards c ON c.family=s.family
), composition AS MATERIALIZED (
 SELECT family,reference_month,round(sum(amount),2) amount
 FROM dated WHERE reference_month>=date_trunc('month',current_date)::date
 GROUP BY family,reference_month
)
SELECT i.user_id,i.card_name,i.reference_month,i.due_date,i.status,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN c.amount ELSE i.amount END,
CASE WHEN c.family IS NOT NULL AND i.status='open' AND i.due_date>=current_date THEN 'open_finance_composition_v226' ELSE i.source END
FROM public.card_invoices i LEFT JOIN composition c ON c.reference_month=i.reference_month
AND c.family=public.lts_card_family_v226(i.card_name,CASE WHEN i.card_name ~* 'c6' THEN 'C6'
WHEN i.card_name ~* 'aeternum|bradesco|prime' THEN 'Bradesco' ELSE 'Itaú' END)
WHERE i.user_id=p_user_id
$function$;
REVOKE ALL ON FUNCTION public.lts_card_invoice_amounts_v230(uuid) FROM public,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_invoice_amounts_v230(uuid) TO service_role;

-- Abort deployment if any current invoice differs from the full item reader.
DO $verify$ DECLARE u uuid; BEGIN
 FOR u IN SELECT DISTINCT user_id FROM public.card_invoices LOOP
  IF EXISTS (
   (SELECT user_id,card_name,reference_month,due_date,status,amount,source FROM public.lts_card_invoice_amounts_v230(u)
    EXCEPT ALL SELECT user_id,card_name,reference_month,due_date,status,amount,source FROM public.lts_card_invoices_effective_v226(u))
   UNION ALL
   (SELECT user_id,card_name,reference_month,due_date,status,amount,source FROM public.lts_card_invoices_effective_v226(u)
    EXCEPT ALL SELECT user_id,card_name,reference_month,due_date,status,amount,source FROM public.lts_card_invoice_amounts_v230(u))
  ) THEN RAISE EXCEPTION 'Invoice amount reader parity failed'; END IF;
 END LOOP;
END $verify$;

CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with card_amounts as materialized (select * from public.lts_card_invoice_amounts_v230(p_user_id)), scenario_off as (
  select lower(k) as root from public.legacy_namespace l,lateral jsonb_each_text(l.valor_bruto::jsonb) x(k,v)
  where l.usuario_id=p_user_id and l.chave='lts_cen_off_v2' and lower(v)='true'
), explicit_reconc as (
  select distinct nullif(dados->>'previsaoIdx','')::int idx from public.reconciliacao
  where usuario_id=p_user_id and dados->>'status' in ('reconciliada','ciclo-realizado') and nullif(dados->>'previsaoIdx','') is not null
), coopharma_nonbank as (
  select exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.id='suppress_coopharma_nonbank_future') onflag
), ops as (
  select dados,lower(trim(coalesce(dados->>'conta',''))) conta,lower(trim(coalesce(dados->>'desc',''))) descr,
         nullif(dados->>'dia','')::date dia,coalesce((dados->>'ts')::bigint,0) ts
  from public.projecao_op where usuario_id=p_user_id and coalesce(dados->>'status','ativa')='ativa' and nullif(dados->>'revertidaEm','') is null
), base0 as (
  select eb.idx,(eb.dados->>'dia')::date original_date,eb.dados->>'conta' account,eb.dados->>'desc' description,
         (eb.dados->>'valor')::numeric amount_abs,eb.dados->>'efeito' efeito,
         lower(trim(coalesce(eb.dados->>'conta',''))) conta_norm,lower(trim(coalesce(eb.dados->>'desc',''))) desc_norm
  from public.evento_base eb
  where eb.usuario_id=p_user_id and (eb.dados->>'dia')::date<=p_to and extract(year from (eb.dados->>'dia')::date)>=2018
    and not exists(select 1 from scenario_off s where s.root=lower(trim(coalesce(eb.dados->>'desc',''))))
    and not (eb.dados->>'desc'='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank))
    and not exists(select 1 from explicit_reconc r where r.idx=eb.idx)
    and not exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.source_table='evento_base'
      and (r.description_exact is null or r.description_exact=eb.dados->>'desc') and (r.account_exact is null or r.account_exact=eb.dados->>'conta')
      and (r.date_from is null or (eb.dados->>'dia')::date>=r.date_from) and (r.date_to is null or (eb.dados->>'dia')::date<=r.date_to))
), base_with_ops as (
  select b.*,
    exists(select 1 from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='cancelamento') cancelled,
    coalesce((select (o.dados#>>'{depois,valor}')::numeric from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='valor' order by o.ts desc limit 1),b.amount_abs) adjusted_amount,
    coalesce((select (o.dados#>>'{depois,dia}')::date from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='data' order by o.ts desc limit 1),b.original_date) adjusted_date,
    (select o.dados->'partes' from ops o where o.conta=b.conta_norm and o.descr=b.desc_norm and o.dia=b.original_date and o.dados->>'tipo'='divisao' order by o.ts desc limit 1) split_parts
  from base0 b
), transformed_base as (
  select b.idx,coalesce(disp.para,b.adjusted_date) event_date,b.account,b.description,
         case when b.efeito='entrada' then b.adjusted_amount else -b.adjusted_amount end signed_amount,b.original_date,(disp.para is not null) displaced
  from base_with_ops b
  left join lateral (
    select (d.dados->>'para')::date para from public.deslocamento d
    where d.usuario_id=p_user_id and coalesce(d.dados->>'status','ativo')='ativo'
      and lower(trim(coalesce(d.dados->>'conta','')))=b.conta_norm and lower(trim(coalesce(d.dados->>'identidade','')))=b.desc_norm
      and (d.dados->>'de')::date=b.original_date order by coalesce((d.dados->>'ts')::bigint,0) desc limit 1
  ) disp on true where not b.cancelled and b.split_parts is null
  union all
  select b.idx,coalesce(disp.para,(p->>'dia')::date),b.account,b.description,
         case when b.efeito='entrada' then (p->>'valor')::numeric else -(p->>'valor')::numeric end,b.original_date,(disp.para is not null)
  from base_with_ops b cross join lateral jsonb_array_elements(b.split_parts) p
  left join lateral (
    select (d.dados->>'para')::date para from public.deslocamento d
    where d.usuario_id=p_user_id and coalesce(d.dados->>'status','ativo')='ativo'
      and lower(trim(coalesce(d.dados->>'conta','')))=b.conta_norm and lower(trim(coalesce(d.dados->>'identidade','')))=b.desc_norm
      and (d.dados->>'de')::date=b.original_date order by coalesce((d.dados->>'ts')::bigint,0) desc limit 1
  ) disp on true where not b.cancelled and b.split_parts is not null
), economic_withholding as (
  select (eb.dados->>'dia')::date event_date,'Folha'::text account,eb.dados->>'desc' description,-abs((eb.dados->>'valor')::numeric) signed_amount,
         'economic_withholding'::text src,'contrato:ct_ms9rzp71rpi9|evento_base:'||eb.idx::text src_ref,'validated_contract'::text conf,'nonbank'::text acct_assign,
         eb.idx legacy_idx,(eb.dados->>'dia')::date orig_date,false is_displaced
  from public.evento_base eb where eb.usuario_id=p_user_id and eb.dados->>'desc'='Pagamento Novo Coopharma'
    and (eb.dados->>'dia')::date between p_from and p_to and (select onflag from coopharma_nonbank)
), normalized as (
  select fe.event_date,coalesce(a.institution,'Não atribuída'),coalesce(fe.description_normalized,fe.description_raw,'(sem descrição)'),fe.amount,
         'current_event'::text,coalesce(fe.legacy_id,fe.id::text),
         case when fe.source='validated_contract_qa' then 'validated' when fe.status='scheduled' then 'documented_scheduled' when fe.status='expected' then 'documented_expected' else 'current_evidence' end,
         case when fe.account_id is null then 'pending' else 'assigned' end,fe.legacy_index,fe.event_date,false
  from public.financial_events fe left join public.accounts a on a.id=fe.account_id
  where fe.user_id=p_user_id and fe.event_date between p_from and p_to and coalesce(fe.is_suppressed,false)=false
    and coalesce(fe.is_internal_transfer,false)=false and coalesce(fe.nature,'')<>'transfer' and fe.status in ('scheduled','expected','active','needs_reconciliation')
    and not exists(select 1 from scenario_off s where s.root=lower(trim(coalesce(fe.description_normalized,fe.description_raw,''))))
    and not (coalesce(fe.description_normalized,fe.description_raw,'')='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank))
), cards as (
  select ci.due_date,coalesce((select r.account_exact from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.replacement_source='card_invoices' and r.date_from<=ci.due_date and r.date_to>=ci.due_date order by r.updated_at desc limit 1),public.lts_card_invoice_account_v181(ci.card_name),'Não atribuída'),
         'Fatura '||ci.card_name,-abs(ci.amount),'card_invoice'::text,ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM'),
         case when ci.status='closed' then 'documented_closed' when ci.status='open' then 'documented_open' else 'documented_projected_snapshot' end,
         case when public.lts_card_invoice_account_v181(ci.card_name) is not null or exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.replacement_source='card_invoices' and r.date_from<=ci.due_date and r.date_to>=ci.due_date) then 'assigned' else 'pending' end,
         null::int,ci.due_date,false
  from card_amounts ci where ci.user_id=p_user_id and ci.due_date between p_from and p_to and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
), allrows as (
  select t.event_date,t.account,t.description,t.signed_amount,'legacy_fix86'::text src,'evento_base:'||t.idx::text src_ref,'legacy_projection_adjusted'::text conf,
         'assigned'::text acct_assign,t.idx legacy_idx,t.original_date orig_date,t.displaced is_displaced
  from transformed_base t
  where t.event_date between p_from and p_to
    and not exists (
      select 1
      from card_amounts ci
      where ci.user_id=p_user_id
        and ci.reference_month=date_trunc('month',t.event_date)::date
        and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
        and public.lts_card_family_key_v181(ci.card_name,null) is not null
        and public.lts_card_family_key_v181(ci.card_name,null)=public.lts_card_family_key_v181(t.description,t.account)
    )
  union all select * from economic_withholding union all select * from normalized union all select * from cards
)
select a.event_date,a.account,a.description,a.signed_amount,a.src,a.src_ref,a.conf,a.acct_assign,a.legacy_idx,a.orig_date,a.is_displaced
from allrows a order by a.event_date,a.src,a.description;
$function$
;

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
  c.payload:=public.lts_flow_invoice_amount_overlay_v226(c.payload,(select coalesce(jsonb_agg(to_jsonb(i)),'[]'::jsonb) from public.lts_card_invoice_amounts_v230(p_user_id)i where i.status='open' and i.due_date>=current_date));
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
