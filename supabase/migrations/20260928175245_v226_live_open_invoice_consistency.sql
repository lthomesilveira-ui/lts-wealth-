-- Current open invoices use the received composition; historical documents are unchanged.
CREATE OR REPLACE FUNCTION public.lts_card_invoices_effective_v226(p_user_id uuid)
RETURNS SETOF public.card_invoices LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
with rows as materialized (
 select * from public.lts_card_source_rows_v226(p_user_id) where not is_payment and provider_status='PENDING' and reference_month>=date_trunc('month',current_date)::date
), composition as materialized (
 select family,reference_month,round(sum(amount),2) amount,max(observed_at) observed_at,
 jsonb_agg(to_jsonb(r)||jsonb_build_object('source_line',source_id,'card_final',last4) order by posting_date,description,source_id) items
 from rows r group by family,reference_month
), effective as materialized (
 select to_jsonb(i)||case when c.items is not null and i.status='open' and i.due_date>=current_date then
 jsonb_build_object('amount',c.amount,'source','open_finance_composition_v226','metadata',coalesce(i.metadata,'{}'::jsonb)||jsonb_build_object(
 'items',c.items,'open_finance_observed_at',c.observed_at,'documentary_snapshot',jsonb_build_object('amount',i.amount,'source',i.source,'as_of',i.metadata->'as_of')))
 else '{}'::jsonb end value
 from public.card_invoices i left join composition c on c.reference_month=i.reference_month
 and c.family=public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end)
 where i.user_id=p_user_id
)
select r.* from effective e cross join lateral jsonb_populate_record(null::public.card_invoices,e.value)r
$f$;
REVOKE ALL ON FUNCTION public.lts_card_invoices_effective_v226(uuid) FROM public,anon;
GRANT EXECUTE ON FUNCTION public.lts_card_invoices_effective_v226(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_operating_view_v2(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with inv as (
  select ci.id,ci.card_name,ci.reference_month,ci.due_date,ci.status,ci.amount,ci.source,ci.metadata,
         exists(
           select 1 from public.lts_fact_confirmation fc
           where fc.user_id=p_user_id
             and fc.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
             and fc.event_date=ci.due_date
             and (fc.signed_amount is null or abs(fc.signed_amount+abs(ci.amount))<=0.02)
         ) confirmed_payment,
         case
           when lower(coalesce(ci.status,''))='paid' then 'paid'
           when lower(coalesce(ci.status,''))='closed' and exists(
             select 1 from public.lts_fact_confirmation fc
             where fc.user_id=p_user_id
               and fc.source_ref=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
               and fc.event_date=ci.due_date
               and (fc.signed_amount is null or abs(fc.signed_amount+abs(ci.amount))<=0.02)
           ) then 'paid'
           when lower(coalesce(ci.status,''))='closed' and ci.due_date>=p_as_of then 'closed_unpaid'
           when lower(coalesce(ci.status,''))='closed' and ci.due_date<p_as_of then 'payment_evidence_needed'
           when lower(coalesce(ci.status,''))='open' then 'open_cycle'
           when ci.source='derived_installments' then 'contracted_installment_floor'
           else 'other_projection'
         end human_state
  from public.lts_card_invoices_effective_v226(p_user_id) ci
  where ci.user_id=p_user_id
), closed as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state',human_state,'label',case when human_state='closed_unpaid' then 'Fatura fechada · a pagar' else 'Fatura vencida · confirmar pagamento' end,
    'detail_available',exists(select 1 from public.lts_card_invoice_detail_reconciliation r where r.user_id=p_user_id and r.reconciled=true and r.due_date=inv.due_date and trim(r.card_name)=trim(inv.card_name))
  ) order by due_date,card_name),'[]'::jsonb) j,
  coalesce(sum(amount),0) total
  from inv where human_state in ('closed_unpaid','payment_evidence_needed')
), paid_recent as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state','paid','label',case when confirmed_payment then 'Pagamento confirmado' else 'Fatura paga' end,'confirmed',confirmed_payment
  ) order by due_date desc,card_name),'[]'::jsonb) j
  from inv
  where human_state='paid' and due_date>=p_as_of-90
), open_cycles as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'invoice_id',id,'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'amount',amount,
    'state','open_cycle','label','Fatura aberta','source_evidence',case when source in ('app_screenshot','app_statement_open') then 'valor observado no app/extrato' else 'valor registrado' end,
    'detail_preview',coalesce(metadata->'items','[]'::jsonb),
    'detail_preview_count',jsonb_array_length(coalesce(metadata->'items','[]'::jsonb)),
    'detail_preview_total',coalesce((select round(sum((x->>'amount')::numeric),2) from jsonb_array_elements(coalesce(metadata->'items','[]'::jsonb)) x where nullif(x->>'amount','') is not null),0),
    'detail_preview_basis',case when jsonb_array_length(coalesce(metadata->'items','[]'::jsonb))>0 then 'itens documentados da fatura aberta' else null end
  ) order by due_date,card_name),'[]'::jsonb) j,
  coalesce(sum(amount),0) total
  from inv where human_state='open_cycle'
), floors as (
  select reference_month,round(sum(amount)::numeric,2) amount,count(*) cards,
         jsonb_agg(jsonb_build_object('card_name',card_name,'amount',amount,'due_date',due_date) order by due_date,card_name) detail
  from inv where human_state='contracted_installment_floor'
  group by reference_month
), floor_summary as (
  select coalesce(jsonb_agg(jsonb_build_object('reference_month',to_char(reference_month,'YYYY-MM'),'amount',amount,'cards',cards,'detail',detail) order by reference_month),'[]'::jsonb) months,
         coalesce(sum(amount),0) total,min(reference_month) first_month,max(reference_month) last_month
  from floors
), rec as (
  select count(*) reconciled_invoices,coalesce(sum(detail_lines),0) detail_lines,round(coalesce(sum(detail_net),0)::numeric,2) detail_net,
         min(due_date) first_due,max(due_date) last_due,count(*) filter(where abs(delta)<=0.02) zero_delta_invoices
  from public.lts_card_invoice_detail_reconciliation
  where user_id=p_user_id and reconciled=true
), review as (select public.lts_card_classification_review_v1(p_user_id,100) j),
next_due as (
  select card_name,due_date,amount,human_state
  from inv where human_state in ('closed_unpaid','payment_evidence_needed','open_cycle')
  order by due_date,case human_state when 'closed_unpaid' then 0 when 'payment_evidence_needed' then 1 else 2 end
  limit 1
)
select jsonb_build_object(
  'version','card-operating-v2-open-detail-preview','as_of',p_as_of,
  'closed_or_due',(select j from closed),'closed_or_due_total',(select total from closed),
  'paid_recent',(select j from paid_recent),
  'open_cycles',(select j from open_cycles),'open_cycles_total',(select total from open_cycles),
  'contracted_installment_floor_months',(select months from floor_summary),'contracted_installment_floor_total',(select total from floor_summary),
  'contracted_installment_floor_first_month',(select first_month from floor_summary),'contracted_installment_floor_last_month',(select last_month from floor_summary),
  'next_due',coalesce((select jsonb_build_object('card_name',card_name,'due_date',due_date,'amount',amount,'state',human_state) from next_due),'{}'::jsonb),
  'detail_coverage',(select to_jsonb(rec) from rec),
  'classification_review',jsonb_build_object(
    'pending_groups',(select (j->>'pending_groups')::int from review),
    'pending_lines',(select (j->>'pending_lines')::int from review),
    'pending_value',(select (j->>'pending_value')::numeric from review),
    'safe_suggestion_groups',(select (j->>'safe_suggestion_groups')::int from review)
  ),
  'guardrails',jsonb_build_array(
    'Fatura fechada é obrigação de caixa até existir evidência de pagamento.',
    'Confirmação de pagamento muda o estado da obrigação e preserva a saída de caixa uma única vez.',
    'Fatura aberta é valor observado até a data da evidência e pode crescer até o fechamento.',
    'Detalhe de fatura aberta só é exibido quando existem itens documentados; ausência de detalhe não é preenchida por inferência.',
    'Parcelas futuras já contratadas são piso conhecido da fatura futura, não previsão do valor final.',
    'Pagamento da fatura é liquidação de caixa; consumo econômico vem das compras detalhadas quando disponíveis.'
  )
);
$function$;

CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with scenario_off as (
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
  from public.lts_card_invoices_effective_v226(p_user_id) ci where ci.user_id=p_user_id and ci.due_date between p_from and p_to and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
), allrows as (
  select t.event_date,t.account,t.description,t.signed_amount,'legacy_fix86'::text src,'evento_base:'||t.idx::text src_ref,'legacy_projection_adjusted'::text conf,
         'assigned'::text acct_assign,t.idx legacy_idx,t.original_date orig_date,t.displaced is_displaced
  from transformed_base t
  where t.event_date between p_from and p_to
    and not exists (
      select 1
      from public.lts_card_invoices_effective_v226(p_user_id) ci
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
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_invoice_flow_reconciliation_v183(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to
     or p_from<date '2013-10-10' or p_to>current_date+interval '730 days'
     or p_to-p_from>1095 then
    raise exception 'invalid invoice reconciliation range';
  end if;

  with invoices as materialized (
    select ci.*,
      ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM') expected_ref,
      public.lts_card_family_key_v181(ci.card_name,null) family_key
    from public.lts_card_invoices_effective_v226(v_uid) ci
    where ci.user_id=v_uid
      and ci.due_date between p_from and p_to
      and (ci.status in ('closed','open') or (ci.status='projected' and ci.source<>'derived_installments'))
  ), flow as materialized (
    select * from public.lts_corrected_cashflow_fix86_v5(v_uid,p_from,p_to)
  ), reconciled as (
    select i.id,i.card_name,i.reference_month,i.due_date,i.status,i.amount,i.source,
      i.expected_ref,i.family_key,
      count(*) filter(where f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key) invoice_event_count,
      coalesce(sum(abs(f.signed_amount)) filter(where f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key),0) flow_amount,
      count(*) filter(where f.source='legacy_fix86'
        and date_trunc('month',f.event_date)::date=i.reference_month
        and i.family_key is not null
        and public.lts_card_family_key_v181(f.description,f.account)=i.family_key) legacy_conflict_count
    from invoices i
    left join flow f on (f.source in ('card_invoice','confirmed_fact') and f.source_ref=i.expected_ref and f.event_date=i.due_date and f.signed_amount<0 and public.lts_card_family_key_v181(f.description,f.account)=i.family_key)
      or (f.source='legacy_fix86' and date_trunc('month',f.event_date)::date=i.reference_month
        and i.family_key is not null
        and public.lts_card_family_key_v181(f.description,f.account)=i.family_key)
    group by i.id,i.card_name,i.reference_month,i.due_date,i.status,i.amount,i.source,
      i.expected_ref,i.family_key
  ), classified as (
    select r.*,
      round(r.flow_amount-r.amount,2) difference,
      case
        when r.family_key is null then 'card_identity_pending'
        when r.invoice_event_count<>1 then 'invoice_event_count_mismatch'
        when r.legacy_conflict_count<>0 then 'legacy_projection_conflict'
        when abs(r.flow_amount-r.amount)>0.02 then 'amount_mismatch'
        else 'reconciled'
      end reconciliation_status
    from reconciled r
  )
  select jsonb_build_object(
    'version','invoice-flow-reconciliation-v182-confirmed-fact',
    'from',p_from,'to',p_to,
    'row_count',(select count(*) from classified),
    'reconciled_count',(select count(*) from classified where reconciliation_status='reconciled'),
    'issue_count',(select count(*) from classified where reconciliation_status<>'reconciled'),
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'id',id,'card_name',card_name,'reference_month',reference_month,'due_date',due_date,
      'invoice_status',status,'documented_amount',amount,'flow_amount',flow_amount,
      'difference',difference,'reconciliation_status',reconciliation_status,
      'invoice_event_count',invoice_event_count,'legacy_conflict_count',legacy_conflict_count,
      'source_ref',expected_ref,'detail_available',true
    ) order by due_date,card_name) from classified),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_card_obligations_fix86plus_v2(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with inv as (
 select card_name,reference_month,due_date,status,amount,source,metadata,
   case when lower(coalesce(status,''))='paid' then 'paid' when due_date<p_as_of then 'needs_payment_evidence' when lower(coalesce(status,'')) in ('open','closed') then 'open' else 'projected' end obligation_state,
   (reference_month>date_trunc('month',p_as_of)::date) reference_month_is_future,
   (due_date>p_as_of) due_in_future
 from public.lts_card_invoices_effective_v226(p_user_id) where user_id=p_user_id
), rows as (
 select jsonb_build_object(
   'card_name',card_name,'reference_month',to_char(reference_month,'YYYY-MM'),'due_date',due_date,'source_status',status,'obligation_state',obligation_state,'amount',amount,'source_winner',source,
   'is_future',reference_month_is_future,'reference_month_is_future',reference_month_is_future,'due_in_future',due_in_future,
   'future_installments_total',nullif(metadata->>'future_installments','')::numeric,'future_oct',nullif(metadata->>'future_oct','')::numeric,'future_nov',nullif(metadata->>'future_nov','')::numeric,'evidence_sha256',metadata->>'evidence_sha256',
   'cycle_closed_not_paid',(lower(coalesce(status,''))='closed' and obligation_state='open')
 ) j from inv order by due_date,card_name
)
select jsonb_build_object('version','card-obligations-fix86plus-v2','as_of',p_as_of,'items',coalesce((select jsonb_agg(j) from rows),'[]'::jsonb),'open_amount',coalesce((select sum(amount) from inv where obligation_state in ('open','needs_payment_evidence')),0),'paid_amount',coalesce((select sum(amount) from inv where obligation_state='paid'),0),'projected_amount',coalesce((select sum(amount) from inv where obligation_state='projected'),0),'guardrail','Reference-month timing and payment due-date timing are distinct. Closed cycle is not paid without payment evidence; purchase consumption remains separate from invoice cash settlement.');
$function$;

