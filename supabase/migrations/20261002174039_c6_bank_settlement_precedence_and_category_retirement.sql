-- Source-backed C6 settlement precedence and retired category options.
-- Raw workbook and individual purchase amounts are preserved.
CREATE OR REPLACE FUNCTION public.lts_corrected_cashflow_fix86_v4(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with base_pre as (
 select f.event_date,f.account,f.description,coalesce(bo.amount,f.signed_amount) signed_amount,
        case when c.id is not null then 'confirmed_fact' else f.source end source,
        f.source_ref,
        case when bo.amount is not null then 'bank_documented_settlement_precedence'
             when c.id is not null then 'user_confirmed_fact'
             when f.source='current_event' and exists(
               select 1 from public.financial_events fe
               where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=f.source_ref
                 and fe.event_date>=current_date
                 and coalesce(fe.status,'') in ('scheduled','expected')
                 and coalesce(fe.is_suppressed,false)=false
                 and coalesce(fe.is_internal_transfer,false)=false
                 and not exists(select 1 from public.lts_fact_confirmation fc where fc.user_id=p_user_id and fc.source_ref=coalesce(fe.legacy_id,fe.id::text))
             ) then 'user_flow_editable'
             else f.confidence end confidence,
        f.account_assignment,f.legacy_index,f.original_date,f.displaced
 from public.lts_corrected_cashflow_fix86_v3(p_user_id,p_from,p_to) f
 left join lateral (
   select min(ev.amount) amount
   from public.lts_reconciliation_evidence ev
   join public.lts_open_finance_staging st
     on st.user_id=ev.user_id and st.id::text=ev.metadata->>'bank_staging_id'
    and st.raw_hash=ev.metadata->>'bank_raw_hash' and st.provider_deleted_at is null
    and st.institution_code='336' and f.account='C6' and ev.account='C6'
   where ev.user_id=p_user_id and ev.status='documented'
     and ev.evidence_type='card_invoice_payment'
     and ev.metadata->>'cash_effect'='replace_existing_payment_amount'
     and ev.metadata->>'target_flow_source_ref'=f.source_ref
     and (ev.metadata->>'original_signed_amount')::numeric=f.signed_amount
     and ev.evidence_date=f.event_date and ev.account=f.account
     and ev.amount<0 and st.normalized_payload->>'layer'='card_invoice_obligation'
     and st.normalized_payload->>'currency'='BRL'
     and (st.normalized_payload->>'amount')::numeric=-ev.amount
     and exists (
       select 1 from jsonb_array_elements(coalesce(st.normalized_payload->'payments','[]'::jsonb)) pay
       where pay->>'id'=ev.metadata->>'bank_payment_id'
         and (pay->>'amount')::numeric=-ev.amount
         and left(pay->>'paymentDate',10)::date=f.event_date
         and pay->>'currencyCode'='BRL'
     )
   having count(*)=1
 ) bo on true
 left join public.lts_fact_confirmation c
   on c.user_id=p_user_id and c.source_ref=f.source_ref
  and c.event_date=f.event_date
  and (c.signed_amount is null or c.signed_amount=f.signed_amount)
), base as (
 select b.* from base_pre b
 where not (
   b.source='current_event'
   and exists (
     select 1 from public.financial_events fe
     join public.lts_flow_event_operation o on o.user_id=p_user_id and o.target_event_id=fe.id and o.active
     where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=b.source_ref
   )
 )
), operated_current as (
 select e.event_date,e.account,e.description,e.signed_amount,'current_event'::text source,e.source_ref,'user_flow_editable'::text confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced
 from public.lts_flow_current_effective_v1(p_user_id,p_from,p_to) e
 where exists (
   select 1 from public.financial_events fe
   join public.lts_flow_event_operation o on o.user_id=p_user_id and o.target_event_id=fe.id and o.active
   where fe.user_id=p_user_id and coalesce(fe.legacy_id,fe.id::text)=e.source_ref
 )
)
select * from base
union all
select * from operated_current;
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_card_category_options_v226()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 select coalesce(jsonb_agg(category order by category),'[]'::jsonb) into result from (
 select distinct x category from public.lts_product_read_cache c
 cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x
 where c.user_id=u and not exists(select 1 from public.lts_category_catalog retired where retired.user_id=u and not retired.active and public.lts_v178_norm(retired.category)=public.lts_v178_norm(x)) and public.lts_v178_norm(x) not in ('a classificar','nao identificado','sem categoria')
 )q;
 return jsonb_build_object('categories',result);
end $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_queue_v229(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10'
     or p_to>current_date or p_offset<0 or p_limit not between 1 and 100 then
    raise exception 'invalid review queue range';
  end if;

  with pending as materialized (
    select r.*,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'person'
        when r.management_group='Moradia — imóvel a confirmar' then 'property'
        when r.property_component='A revisar' then 'property_purpose'
        else 'classification'
      end question_kind,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'De quem é esta despesa?'
        when r.management_group='Moradia — imóvel a confirmar' then 'A que imóvel se refere?'
        when r.property_component='A revisar' then 'Qual é a finalidade deste gasto no imóvel?'
        else 'Qual é a pessoa ou classificação correta?'
      end review_question
    from public.lts_v229_review_rows(v_uid,p_from,p_to) r
    where r.identity_status='pending'
  ), filtered as materialized (
    select * from pending
    where nullif(trim(p_query),'') is null
       or strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,category,management_group,raw_reference)),public.lts_v178_norm(trim(p_query)))>0
  ), page as materialized (
    select * from filtered
    order by event_date desc,amount desc,row_key
    offset p_offset limit p_limit
  ), suggestions AS MATERIALIZED (
    SELECT * FROM public.lts_review_suggestions_v231(v_uid,coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM page),'[]'))
  ), options as (
    select public.lts_browser_card_category_options_v226()->'categories' categories
  )
  select jsonb_build_object(
    'version','expense-review-queue-v229',
    'from',p_from,'to',p_to,
    'row_count',(select count(*) from pending),
    'pending_projections',public.lts_pending_projections_v233(v_uid),
    'queue_breakdown',jsonb_build_object(
     'historical_context',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) NOT IN ('a classificar','sem categoria','nao identificado')),
     'classification_needed',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) IN ('a classificar','sem categoria','nao identificado')),
     'classification',(SELECT count(*) FROM pending WHERE question_kind='classification'),
     'person',(SELECT count(*) FROM pending WHERE question_kind='person'),
     'property',(SELECT count(*) FROM pending WHERE question_kind IN ('property','property_purpose'))),
    'matched_count',(select count(*) from filtered),
    'offset',p_offset,
    'next_offset',case when p_offset+p_limit<(select count(*) from filtered) then p_offset+p_limit end,
    'category_options',coalesce((select categories from options),'[]'::jsonb),
    'beneficiary_options',jsonb_build_array(
      jsonb_build_object('value','Lucas','label','Minha / sem prefixo'),
      jsonb_build_object('value','Benjamin','label','Benjamin'),
      jsonb_build_object('value','Larissa','label','Larissa'),
      jsonb_build_object('value','Rafiki','label','Rafiki')
    ),
    'property_options',jsonb_build_array(
      jsonb_build_object('value','cipo396','label','Apartamento · CIPÓ 396'),
      jsonb_build_object('value','other_property','label','Outro imóvel'),
      jsonb_build_object('value','not_property','label','Não é gasto de imóvel')
    ),
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'key',row_key,'source_table',source_table,'source_ref',source_ref,
      'date',event_date,'period',competence_month,'description',description,
      'account_source',account_source,'amount',amount,'category',category,
      'beneficiary',beneficiary,'management_group',management_group,
      'question_kind',question_kind,'review_question',review_question,
      'suggestion',(SELECT s.suggestion FROM suggestions s WHERE s.source_table=page.source_table AND s.source_ref=page.source_ref)
    ) order by event_date desc,amount desc,row_key) from page),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$;

CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_decision_v229(p_source_table text, p_source_ref text, p_beneficiary text DEFAULT NULL::text, p_property_code text DEFAULT NULL::text, p_category_label text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_source_table text:=nullif(trim(coalesce(p_source_table,'')),'');
  v_source_ref text:=nullif(trim(coalesce(p_source_ref,'')),'');
  v_beneficiary text:=nullif(trim(coalesce(p_beneficiary,'')),'');
  v_property text:=nullif(trim(coalesce(p_property_code,'')),'');
  v_category text:=nullif(trim(coalesce(p_category_label,'')),'');
  v_before jsonb;
  v_target record;
  v_resolved boolean;
  v_scope_from date:=date '2013-10-10'; v_source_date date;
begin
  if v_source_table is null or v_source_ref is null then raise exception 'source required'; end if;
  if v_beneficiary is null and v_property is null and v_category is null then raise exception 'decision required'; end if;
  if v_beneficiary is not null and v_beneficiary not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'invalid beneficiary'; end if;
  if v_property is not null and v_property not in ('cipo396','other_property','not_property') then raise exception 'invalid property'; end if;
  if v_category is not null and length(v_category)>120 then raise exception 'invalid category'; end if;

  if v_category is not null and exists(select 1 from public.lts_category_catalog t where t.user_id=v_uid and not t.active and public.lts_v178_norm(t.category)=public.lts_v178_norm(v_category)) then raise exception 'Categoria desativada; selecione uma categoria atual.'; end if;

  -- Resolve the requested occurrence in its own dated scope. The authorization,
  -- category allowlist, audit and post-write resolution checks are unchanged.
  IF v_source_table='lts_open_finance_staging' THEN
    SELECT least(s.posting_date,CASE WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
      THEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date ELSE s.posting_date END)
    INTO v_source_date FROM public.lts_open_finance_staging s WHERE s.user_id=v_uid AND s.id::text=v_source_ref;
  ELSIF v_source_table='lts_card_document_supplement_v234' THEN
    SELECT d.purchase_date INTO v_source_date FROM public.lts_card_document_supplement_v234 d
    WHERE d.user_id=v_uid AND d.id::text=v_source_ref;
  ELSIF v_source_table='evento_base' THEN
    SELECT (e.dados->>'dia')::date INTO v_source_date FROM public.evento_base e WHERE e.usuario_id=v_uid AND e.idx::text=v_source_ref;
  ELSIF v_source_table='historico_analitico' THEN
    SELECT (e.dados->>'dia')::date INTO v_source_date FROM public.historico_analitico e WHERE e.usuario_id=v_uid AND e.idx::text=v_source_ref;
  ELSIF v_source_table='card_purchase_detail' THEN
    SELECT e.invoice_due_date INTO v_source_date FROM public.lts_card_purchase_detail e WHERE e.user_id=v_uid AND (e.line_key=v_source_ref OR e.purchase_key=v_source_ref) LIMIT 1;
  END IF;
  IF v_source_date IS NOT NULL THEN v_scope_from:=greatest(date '2013-10-10',date_trunc('month',v_source_date)::date); END IF;

  select * into v_target
  from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
  where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  order by r.event_date desc
  limit 1;
  if not found then raise exception 'pending review item not found'; end if;

  if v_category is not null and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
    where r.category=v_category or r.management_group=v_category or r.management_subgroup=v_category
  ) then raise exception 'unknown category'; end if;

  select to_jsonb(d) into v_before
  from public.lts_v178_review_decision d
  where d.user_id=v_uid and d.source_table=v_source_table and d.source_ref=v_source_ref;

  insert into public.lts_v178_review_decision(
    user_id,source_table,source_ref,beneficiary,property_code,category_label,decision_basis,decided_at
  ) values (
    v_uid,v_source_table,v_source_ref,v_beneficiary,v_property,v_category,'authenticated_user_v229',now()
  )
  on conflict(user_id,source_table,source_ref) do update set
    beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),
    property_code=coalesce(excluded.property_code,lts_v178_review_decision.property_code),
    category_label=coalesce(excluded.category_label,lts_v178_review_decision.category_label),
    decision_basis=excluded.decision_basis,
    decided_at=excluded.decided_at;

  select not exists(
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,current_date) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  ) into v_resolved;
  if not v_resolved then raise exception 'A decisão não resolveu a pendência; nenhuma alteração foi mantida.'; end if;

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(v_uid,v_email,'browser_expense_review_decision_v181',jsonb_build_object(
    'source_table',v_source_table,'source_ref',v_source_ref,
    'before',v_before,
    'after',jsonb_build_object('beneficiary',v_beneficiary,'property_code',v_property,'category_label',v_category),
    'resolved',v_resolved
  ));

  return jsonb_build_object(
    'ok',true,'resolved',v_resolved,'source_table',v_source_table,'source_ref',v_source_ref,
    'display_contract',case when v_beneficiary='Lucas' then 'owner_category_without_prefix' else 'named_person_when_explicit' end
  );
end
$function$;