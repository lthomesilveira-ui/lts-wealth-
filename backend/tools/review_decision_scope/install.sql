-- Guarded function-only correction. No financial source or release-pointer writes.
BEGIN;
DO $guard$
DECLARE actual text:=md5(pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure));
BEGIN
 IF actual NOT IN ('2dafdd9285b9e5ed7252c2ec3e3d9cc3','2f072b68540498cf5828f5481c8eba6a') THEN
  RAISE EXCEPTION 'Review decision changed concurrently; installation stopped';
 END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_decision_v229(p_source_table text, p_source_ref text, p_beneficiary text DEFAULT NULL::text, p_property_code text DEFAULT NULL::text, p_category_label text DEFAULT NULL::text)
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
  v_category text:=public.lts_category_name_v290(v_uid,nullif(trim(coalesce(p_category_label,'')),''));
  v_before jsonb;
  v_target record;
  v_resolved boolean;
  v_scope_from date:=date '2013-10-10'; v_scope_to date:=current_date; v_source_date date; v_posted_bank boolean:=false;
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
    ,s.resource_type='transaction' AND s.provider_deleted_at IS NULL
      AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
      AND s.normalized_payload->>'status'='POSTED'
    INTO v_source_date,v_posted_bank FROM public.lts_open_finance_staging s WHERE s.user_id=v_uid AND s.id::text=v_source_ref;
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
  -- A posted bank occurrence has an exact civil date. Validate both the pending
  -- occurrence and its resolution in that same day; retain the original month
  -- scope for card, monthly, legacy and incomplete provider observations.
  IF coalesce(v_posted_bank,false) AND v_source_date IS NOT NULL THEN
    v_scope_from:=greatest(date '2013-10-10',v_source_date);
    v_scope_to:=least(current_date,v_source_date);
  END IF;

  -- Posted checking-account facts cannot originate in the future-card union.
  -- Read the same expense component directly so a decision's cache invalidation
  -- does not rebuild unrelated card history during the atomic resolution check.
  IF coalesce(v_posted_bank,false) THEN
    select * into v_target
    from public.lts_v229_expense_rows(v_uid,v_scope_from,v_scope_to) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
    order by r.event_date desc limit 1;
  ELSE
  select * into v_target
  from public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to) r
  where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  order by r.event_date desc
  limit 1;
  END IF;
  if not found then raise exception 'pending review item not found'; end if;

  if v_category is not null and not exists (
    select 1 from public.lts_category_catalog allowed_category
    where allowed_category.user_id=v_uid and allowed_category.active and allowed_category.category=v_category
  ) and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from jsonb_array_elements_text(coalesce(public.lts_browser_card_category_options_v226()->'categories','[]'::jsonb)) option_category(value)
    where option_category.value=v_category
  ) and not exists (
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to) r
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

  IF coalesce(v_posted_bank,false) THEN
    select not exists(
      select 1 from public.lts_v229_expense_rows(v_uid,v_scope_from,v_scope_to) r
      where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
    ) into v_resolved;
  ELSE
  select not exists(
    select 1 from public.lts_v229_review_rows(v_uid,v_scope_from,v_scope_to) r
    where r.source_table=v_source_table and r.source_ref=v_source_ref and r.identity_status='pending'
  ) into v_resolved;
  END IF;
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
$function$
$definition$;
END $guard$;
COMMIT;
