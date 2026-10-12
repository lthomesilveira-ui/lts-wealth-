-- V261: expose already-approved categories; preserve authorization, audit and inactive labels.
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_card_category_options_v226()'::regprocedure))<>'c665dd20f40335828582ea70e5a95d78' THEN RAISE EXCEPTION 'V261 reviewed definition changed'; END IF; END $guard$;
DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure))<>'6c7a6e9e0f2c077bfde3addc92f38c53' THEN RAISE EXCEPTION 'V261 reviewed definition changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_category_options_v226()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb;
begin
 select coalesce(jsonb_agg(category order by category),'[]'::jsonb) into result from (
 select distinct case when public.lts_v178_norm(x) in ('organon','organon despesas','despesas organon') then public.lts_canonical_category_v1(u,x) else x end category from public.lts_product_read_cache c
 cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x
 where c.user_id=u and not exists(select 1 from public.lts_category_catalog retired where retired.user_id=u and not retired.active and public.lts_v178_norm(retired.category)=public.lts_v178_norm(x)) and public.lts_v178_norm(x) not in ('a classificar','nao identificado','sem categoria')
 UNION
 SELECT DISTINCT CASE WHEN public.lts_v178_norm(t.category) IN ('organon','organon despesas','despesas organon') THEN public.lts_canonical_category_v1(u,t.category) ELSE t.category END FROM public.lts_category_catalog t
 WHERE t.user_id=u AND t.active AND public.lts_v178_norm(t.category) NOT IN ('a classificar','nao identificado','sem categoria')

 UNION
 SELECT DISTINCT CASE WHEN public.lts_v178_norm(d.category_label) IN ('organon','organon despesas','despesas organon') THEN public.lts_canonical_category_v1(u,d.category_label) ELSE d.category_label END
 FROM public.lts_v178_review_decision d
 WHERE d.user_id=u AND nullif(trim(d.category_label),'') IS NOT NULL
 AND public.lts_v178_norm(d.category_label) NOT IN ('a classificar','nao identificado','sem categoria')
 AND NOT EXISTS(SELECT 1 FROM public.lts_category_catalog retired
 WHERE retired.user_id=u AND NOT retired.active
 AND public.lts_v178_norm(retired.category)=public.lts_v178_norm(d.category_label))
 )q;
 return jsonb_build_object('categories',result);
end $function$;

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
    select 1 from jsonb_array_elements_text(coalesce(public.lts_browser_card_category_options_v226()->'categories','[]'::jsonb)) option_category(value)
    where option_category.value=v_category
  ) and not exists (
    select 1 from public.lts_product_read_cache c
    cross join lateral jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]'::jsonb)) x(value)
    where c.user_id=v_uid and x.value=v_category
  ) and not exists (
    select 1 from public.lts_category_catalog allowed_category
    where allowed_category.user_id=v_uid and allowed_category.active and allowed_category.category=v_category
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
