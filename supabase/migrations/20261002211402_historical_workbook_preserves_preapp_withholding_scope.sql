-- A future non-bank withholding policy must not reinterpret the protected
-- original workbook era. Keep all application-era movements and policies.
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v1(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
with payroll_matches as materialized (select projection_ref from public.lts_payroll_bank_matches_v231(p_user_id)), card_amounts as materialized (select * from public.lts_card_invoice_amounts_v230(p_user_id)), scenario_off as (
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
         coalesce(a.source_signed_amount,(eb.dados->>'valor')::numeric) amount_abs,eb.dados->>'efeito' efeito,
         lower(trim(coalesce(eb.dados->>'conta',''))) conta_norm,lower(trim(coalesce(eb.dados->>'desc',''))) desc_norm
  from public.evento_base eb
  left join public.lts_card_history_source_audit_v235 a on a.user_id=eb.usuario_id
    and a.source_table='evento_base' and a.source_ref=eb.idx::text
    and a.event_date=(eb.dados->>'dia')::date and a.source_description=eb.dados->>'desc'
    and a.ledger_amount=round((eb.dados->>'valor')::numeric,2) and a.source_signed_amount<0
    and eb.dados->>'efeito'='saida'
  where eb.usuario_id=p_user_id and (eb.dados->>'dia')::date<=p_to and extract(year from (eb.dados->>'dia')::date)>=2018
    and not exists(select 1 from scenario_off s where s.root=lower(trim(coalesce(eb.dados->>'desc',''))))
    and not (eb.dados->>'desc'='Pagamento Novo Coopharma' and (select onflag from coopharma_nonbank) and (eb.dados->>'dia')::date>=date '2026-07-08')
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
    and (eb.dados->>'dia')::date between p_from and p_to and (select onflag from coopharma_nonbank) and (eb.dados->>'dia')::date>=date '2026-07-08'
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
  select t.event_date,t.account,t.description,t.signed_amount,'legacy_fix86'::text src,'evento_base:'||t.idx::text src_ref,case when exists(select 1 from public.lts_card_history_source_audit_v235 a where a.user_id=p_user_id
 and a.source_table='evento_base' and a.source_ref=t.idx::text and a.event_date=t.original_date
 and a.source_signed_amount<0 and -a.source_signed_amount=round(t.signed_amount,2))
 then 'historical_workbook_signed_adjustment' else 'legacy_projection_adjusted' end::text conf,
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
from allrows a where not (a.src='legacy_fix86' and exists(select 1 from payroll_matches m where m.projection_ref=a.src_ref)) order by a.event_date,a.src,a.description;
$function$;

CREATE OR REPLACE FUNCTION public.lts_operational_source_key_v238(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
SELECT md5(jsonb_build_object(
 'historical_cash_reader_revision','signed-source-and-protected-workbook-boundary-v239',
 'financial_events',(SELECT md5(coalesce(string_agg(to_jsonb(f)::text,'|' ORDER BY f.id),'empty')) FROM public.financial_events f WHERE f.user_id=p_user_id),
 'accounts',(SELECT md5(coalesce(string_agg(to_jsonb(a)::text,'|' ORDER BY a.id),'empty')) FROM public.accounts a WHERE a.user_id=p_user_id),
 'semantic_rules',(SELECT md5(coalesce(string_agg(to_jsonb(r)::text,'|' ORDER BY r.id),'empty')) FROM public.lts_semantic_rule r WHERE r.user_id=p_user_id),
 'historical_rows',(SELECT md5(coalesce(string_agg(to_jsonb(h)::text,'|' ORDER BY to_jsonb(h)::text),'empty')) FROM public.historico_analitico h WHERE h.usuario_id=p_user_id),
 'legacy_rows',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY to_jsonb(e)::text),'empty')) FROM public.evento_base e WHERE e.usuario_id=p_user_id),
 'historical_cash_sign_evidence',(SELECT md5(coalesce(string_agg(to_jsonb(e)::text,'|' ORDER BY e.id),'empty')) FROM public.lts_reconciliation_evidence e WHERE e.user_id=p_user_id AND e.evidence_type='historical_workbook_cash_sign'),
 'source_signs',(SELECT md5(coalesce(string_agg(to_jsonb(s)::text,'|' ORDER BY to_jsonb(s)::text),'empty')) FROM public.lts_card_history_source_audit_v235 s WHERE s.user_id=p_user_id)
)::text)
$function$;
