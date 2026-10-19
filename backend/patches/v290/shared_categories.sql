-- V290: one owner-scoped classification catalog; raw source labels and decisions stay intact.
CREATE TABLE public.lts_category_binding_v290 (
 user_id uuid NOT NULL, source_table text NOT NULL, source_ref text NOT NULL,
 raw_category text NOT NULL, category_key text NOT NULL,
 source_beneficiary text GENERATED ALWAYS AS (substring(raw_category from '^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–]')) STORED,
 first_seen_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,source_table,source_ref,raw_category),
 FOREIGN KEY(user_id,category_key) REFERENCES public.lts_category_catalog(user_id,category_key)
);
ALTER TABLE public.lts_category_binding_v290 ENABLE ROW LEVEL SECURITY;
CREATE POLICY own_bindings ON public.lts_category_binding_v290 FOR SELECT TO authenticated USING(user_id=(SELECT auth.uid()));
REVOKE ALL ON public.lts_category_binding_v290 FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.lts_category_binding_v290 TO authenticated;
GRANT ALL ON public.lts_category_binding_v290 TO service_role;

CREATE OR REPLACE FUNCTION public.lts_category_name_v290(p_user_id uuid,p_category text)
RETURNS text LANGUAGE sql STABLE SET search_path='' AS $f$
 WITH clean AS (SELECT nullif(regexp_replace(trim(p_category),'[[:space:]]+',' ','g'),'') raw),
 nature AS (SELECT CASE WHEN raw ~ '^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–][[:space:]]*'
 AND raw !~* '[-—–][[:space:]]*despesas$'
 THEN regexp_replace(regexp_replace(raw,'^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–][[:space:]]*',''),
 '^(Lucas|Larissa|Benjamin|Rafiki)[[:space:]]*[-—–][[:space:]]*','') ELSE raw END v FROM clean),
 aliased AS (SELECT coalesce((SELECT a.canonical_category FROM public.lts_category_alias a,clean
 WHERE a.user_id=p_user_id AND a.active AND public.lts_v178_norm(a.alias)=public.lts_v178_norm(clean.raw)
 ORDER BY a.alias LIMIT 1),v) v FROM nature)
 SELECT coalesce((SELECT c.category FROM public.lts_category_catalog c,aliased a
 WHERE c.user_id=p_user_id AND public.lts_v178_norm(c.category)=public.lts_v178_norm(a.v)
 ORDER BY c.active DESC,c.created_at,c.category_key LIMIT 1),v) FROM aliased
$f$;
REVOKE ALL ON FUNCTION public.lts_category_name_v290(uuid,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_category_name_v290(uuid,text) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_category_register_v290(p_user_id uuid,p_category text,p_source_table text,p_source_ref text)
RETURNS text LANGUAGE plpgsql SET search_path='' AS $f$
DECLARE c text:=public.lts_category_name_v290(p_user_id,p_category); k text;
BEGIN
 IF c IS NULL OR length(c)>120 THEN RETURN NULL; END IF;
 k:=public.lts_v178_norm(c);
 -- A single normalized key owns spelling/case variants. Existing retirement decisions remain effective.
 SELECT category_key,category INTO k,c FROM public.lts_category_catalog
 WHERE user_id=p_user_id AND public.lts_v178_norm(category)=k
 ORDER BY active DESC,created_at,category_key LIMIT 1;
 IF NOT FOUND THEN
  c:=public.lts_category_name_v290(p_user_id,p_category); k:=public.lts_v178_norm(c);
  INSERT INTO public.lts_category_catalog(user_id,category_key,category,active)
  VALUES(p_user_id,k,c,public.lts_v178_norm(c) NOT IN
   ('a classificar','nao identificado','sem categoria','cartao — detalhe historico nao recuperado',
    'ajustes de fatura conforme planilha','creditos / estornos','cartao - credito/estorno provisorio',
    'cartao - despesa provisoria','pagamento de fatura','pagamento de cartao','movimentacao interna',
    'transferencia interna','movimentacao de liquidez'))
  ON CONFLICT(user_id,category_key) DO NOTHING;
  SELECT category INTO c FROM public.lts_category_catalog WHERE user_id=p_user_id AND category_key=k;
 END IF;
 IF p_source_ref IS NOT NULL THEN
  INSERT INTO public.lts_category_binding_v290(user_id,source_table,source_ref,raw_category,category_key)
  VALUES(p_user_id,p_source_table,p_source_ref,p_category,k) ON CONFLICT DO NOTHING;
 END IF;
 RETURN c;
END $f$;
REVOKE ALL ON FUNCTION public.lts_category_register_v290(uuid,text,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_category_register_v290(uuid,text,text,text) TO service_role;

-- Snapshot the actual reconciled expense readers, including all historical card allocations.
-- No financial amount, date, beneficiary or source text is overwritten by this migration.
CREATE TEMP TABLE category_sources_v290 ON COMMIT DROP AS
 SELECT pc.user_id,r.source_table,r.source_ref,r.category raw_category
 FROM public.lts_product_read_cache pc
 CROSS JOIN LATERAL public.lts_v229_expense_rows(pc.user_id,date '2013-10-10',current_date) r
 WHERE nullif(trim(r.category),'') IS NOT NULL
 UNION SELECT user_id,'lts_v178_review_decision',source_table||':'||source_ref,category_label
 FROM public.lts_v178_review_decision WHERE category_label IS NOT NULL
 UNION SELECT user_id,'financial_events',id::text,category FROM public.financial_events
 WHERE category IS NOT NULL AND amount<0 AND NOT is_internal_transfer
 UNION SELECT user_id,'card_purchase_detail',line_key,category FROM public.lts_card_purchase_detail WHERE category IS NOT NULL
 UNION SELECT user_id,'lts_card_document_supplement_v234',id::text,category FROM public.lts_card_document_supplement_v234 WHERE category IS NOT NULL
 UNION SELECT pc.user_id,'legacy_options',x,x FROM public.lts_product_read_cache pc
 CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(pc.payload#>'{card_classification_review,category_options}','[]'))x;
CREATE TEMP TABLE category_names_v290 ON COMMIT DROP AS
 SELECT u.user_id,u.raw_category,public.lts_category_name_v290(u.user_id,u.raw_category) category
 FROM (SELECT DISTINCT user_id,raw_category FROM category_sources_v290)u;
INSERT INTO public.lts_category_catalog(user_id,category_key,category,active)
 SELECT DISTINCT ON (user_id,public.lts_v178_norm(category)) user_id,public.lts_v178_norm(category),category,
 public.lts_v178_norm(category) NOT IN ('a classificar','nao identificado','sem categoria',
 'cartao — detalhe historico nao recuperado','ajustes de fatura conforme planilha','creditos / estornos',
 'cartao - credito/estorno provisorio','cartao - despesa provisoria','pagamento de fatura','pagamento de cartao',
 'movimentacao interna','transferencia interna','movimentacao de liquidez')
 FROM category_names_v290 n
 WHERE category IS NOT NULL AND NOT EXISTS(SELECT 1 FROM public.lts_category_catalog c
 WHERE c.user_id=n.user_id AND public.lts_v178_norm(c.category)=public.lts_v178_norm(n.category))
 ORDER BY user_id,public.lts_v178_norm(category),category COLLATE "C"
 ON CONFLICT(user_id,category_key) DO NOTHING;
ALTER TABLE category_names_v290 ADD COLUMN category_key text;
UPDATE category_names_v290 n SET category_key=(SELECT c.category_key FROM public.lts_category_catalog c
 WHERE c.user_id=n.user_id AND public.lts_v178_norm(c.category)=public.lts_v178_norm(n.category)
 ORDER BY c.active DESC,c.created_at,c.category_key LIMIT 1);
INSERT INTO public.lts_category_binding_v290(user_id,source_table,source_ref,raw_category,category_key)
 SELECT s.user_id,s.source_table,s.source_ref,s.raw_category,n.category_key
 FROM category_sources_v290 s JOIN category_names_v290 n USING(user_id,raw_category)
 WHERE s.source_ref IS NOT NULL AND n.category_key IS NOT NULL ON CONFLICT DO NOTHING;

-- Alias catalog rows remain as inactive history; all bindings now point at their canonical entry.
UPDATE public.lts_category_catalog c SET active=false,updated_at=now()
WHERE EXISTS(SELECT 1 FROM public.lts_category_alias a WHERE a.user_id=c.user_id AND a.active
 AND public.lts_v178_norm(a.alias)=public.lts_v178_norm(c.category)
 AND public.lts_v178_norm(a.canonical_category)<>public.lts_v178_norm(c.category));

CREATE OR REPLACE FUNCTION public.lts_category_source_trigger_v290()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE j jsonb:=to_jsonb(NEW); u uuid; c text; ref text;
BEGIN
 u:=nullif(j->>'user_id','')::uuid;
 c:=coalesce(j->>'category_label',j->>'category');
 ref:=coalesce(j->>'source_ref',j->>'id',j->>'line_key');
 IF u IS NOT NULL AND c IS NOT NULL THEN
  PERFORM public.lts_category_register_v290(u,c,TG_TABLE_NAME,ref);
 END IF;
 RETURN NEW;
END $f$;
REVOKE ALL ON FUNCTION public.lts_category_source_trigger_v290() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_category_source_trigger_v290() TO service_role;
CREATE TRIGGER category_registry_v290 AFTER INSERT OR UPDATE OF category_label ON public.lts_v178_review_decision
 FOR EACH ROW EXECUTE FUNCTION public.lts_category_source_trigger_v290();
CREATE TRIGGER category_registry_v290 AFTER INSERT OR UPDATE OF category ON public.financial_events
 FOR EACH ROW EXECUTE FUNCTION public.lts_category_source_trigger_v290();
CREATE TRIGGER category_registry_v290 AFTER INSERT OR UPDATE OF category ON public.lts_card_document_supplement_v234
 FOR EACH ROW EXECUTE FUNCTION public.lts_category_source_trigger_v290();

CREATE OR REPLACE FUNCTION public.lts_browser_card_category_options_v226()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb; entries jsonb; aliases jsonb;
BEGIN
 SELECT coalesce(jsonb_agg(category ORDER BY category),'[]'),coalesce(jsonb_agg(jsonb_build_object(
 'key',category_key,'label',category) ORDER BY category),'[]') INTO result,entries
 FROM public.lts_category_catalog c WHERE c.user_id=u AND c.active;
 SELECT coalesce(jsonb_object_agg(b.raw_category,c.category),'{}') INTO aliases
 FROM public.lts_category_binding_v290 b JOIN public.lts_category_catalog c USING(user_id,category_key)
 WHERE b.user_id=u;
 RETURN jsonb_build_object('categories',result,'entries',entries,'aliases',aliases,'registry','shared-v290','revision',md5(result::text));
END $f$;

CREATE OR REPLACE FUNCTION public.lts_browser_category_create_v1(p_category text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); c text:=regexp_replace(trim(coalesce(p_category,'')),'[[:space:]]+',' ','g'); opts jsonb;
BEGIN
 IF length(c)<2 OR length(c)>80 THEN RAISE EXCEPTION 'A classificação deve ter entre 2 e 80 caracteres.'; END IF;
 IF public.lts_v178_norm(c) IN ('a classificar','nao identificado','sem categoria','cartao de credito','cartoes','—','creditos / estornos')
 THEN RAISE EXCEPTION 'Escolha um nome para o tipo de despesa.'; END IF;
 c:=public.lts_category_register_v290(u,c,'user_created',NULL);
 IF NOT EXISTS(SELECT 1 FROM public.lts_category_catalog WHERE user_id=u AND category=c AND active)
 THEN RAISE EXCEPTION 'Esta classificação foi desativada. Escolha uma classificação atual.'; END IF;
 opts:=public.lts_browser_card_category_options_v226();
 UPDATE public.lts_product_read_cache SET payload=jsonb_set(payload,'{card_classification_review,category_options}',opts->'categories',true)
 WHERE user_id=u;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),
 'category_create_v290',jsonb_build_object('category',c,'registry','shared','financial_effect','none'));
 RETURN jsonb_build_object('ok',true,'category',c,'categories',opts->'categories','revision',opts->'revision');
END $f$;

DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_card_classify_v226(uuid,text,text)'::regprocedure))<>'543c474f35cc5f2bb1e6bfd9a26b9e6a' THEN RAISE EXCEPTION 'V290 classification source changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_classify_v226(p_source_id uuid, p_category text, p_beneficiary text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); before_row jsonb; cat text:=public.lts_category_name_v290(u,nullif(trim(p_category),'')); person text:=nullif(trim(p_beneficiary),''); target record; v_st text:='lts_open_finance_staging';
begin
 if cat is null or length(cat)>120 or public.lts_v178_norm(cat) in ('a classificar','nao identificado','sem categoria') then raise exception 'Escolha uma categoria.'; end if;
 if person is not null and person not in ('Lucas','Larissa','Benjamin','Rafiki') then raise exception 'Beneficiário inválido.'; end if;
 select * into target from public.lts_open_finance_staging s where s.id=p_source_id and s.user_id=u and s.resource_type='card_transaction' and s.provider_deleted_at is null;
 if not found then
  IF NOT EXISTS(SELECT 1 FROM public.lts_card_document_supplement_v234 p WHERE p.user_id=u AND p.id=p_source_id)
  THEN raise exception 'Compra não encontrada.'; END IF;
  v_st:='lts_card_document_supplement_v234';
 end if;
 if not exists(select 1 from public.lts_category_catalog c where c.user_id=u and c.active and c.category=cat) then raise exception 'Categoria não disponível.'; end if;
 select to_jsonb(d) into before_row from public.lts_v178_review_decision d where d.user_id=u and d.source_table=v_st and d.source_ref=p_source_id::text;
 insert into public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 values(u,v_st,p_source_id::text,cat,person,'authenticated_user_v226')
 on conflict(user_id,source_table,source_ref) do update set category_label=excluded.category_label,beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),decision_basis=excluded.decision_basis,decided_at=now();
 insert into public.lts_access_audit(user_id,email,action,meta) values(u,lower(coalesce(auth.jwt()->>'email','')),'browser_card_classify_v226',jsonb_build_object('source_id',p_source_id,'before',before_row,'after',jsonb_build_object('category',cat,'beneficiary',person),'financial_effect','none'));
 return jsonb_build_object('ok',true,'source_id',p_source_id,'category',cat,'beneficiary',person);
end $function$;


DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_expense_review_decision_v229(text,text,text,text,text)'::regprocedure))<>'fd499bb2afcea8e3e06f99a03146e3ad' THEN RAISE EXCEPTION 'V290 classification source changed'; END IF; END $guard$;
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
  v_category text:=public.lts_category_name_v290(v_uid,nullif(trim(coalesce(p_category_label,'')),''));
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


DO $guard$ BEGIN IF md5(pg_get_functiondef('public.lts_browser_expense_classification_v232(date,date,text,text,text,text)'::regprocedure))<>'59b8da83c452685b8a5acdb86b56c0ea' THEN RAISE EXCEPTION 'V290 classification source changed'; END IF; END $guard$;
CREATE OR REPLACE FUNCTION public.lts_browser_expense_classification_v232(p_from date, p_to date, p_row_key text, p_category text DEFAULT NULL::text, p_beneficiary text DEFAULT NULL::text, p_property_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); r record; before_value jsonb;
 cat text:=public.lts_category_name_v290(u,nullif(trim(p_category),'')); person text:=nullif(trim(p_beneficiary),''); prop text:=nullif(trim(p_property_code),'');
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid range'; END IF;
 IF cat IS NULL AND person IS NULL AND prop IS NULL THEN RAISE EXCEPTION 'classification required'; END IF;
 IF person IS NOT NULL AND person NOT IN ('Lucas','Larissa','Benjamin','Rafiki') THEN RAISE EXCEPTION 'invalid beneficiary'; END IF;
 IF prop IS NOT NULL AND prop NOT IN ('cipo396','other_property','not_property') THEN RAISE EXCEPTION 'invalid property'; END IF;
 SELECT * INTO r FROM public.lts_v229_expense_rows(u,p_from,p_to) WHERE row_key=p_row_key;
 IF NOT FOUND THEN RAISE EXCEPTION 'expense not found in selected period'; END IF;
 IF r.coverage_mode='card_invoice_aggregate_fallback' THEN RAISE EXCEPTION 'Identifique as compras da fatura, não o pagamento total.'; END IF;
 IF cat IS NOT NULL AND (length(cat)>120 OR public.lts_v178_norm(cat) IN ('a classificar','sem categoria','nao identificado')) THEN RAISE EXCEPTION 'invalid category'; END IF;
 IF cat IS NOT NULL AND cat<>r.category AND NOT EXISTS(SELECT 1 FROM public.lts_category_catalog shared WHERE shared.user_id=u AND shared.active AND shared.category=cat) AND NOT EXISTS(
  SELECT 1 FROM public.lts_product_read_cache c CROSS JOIN LATERAL jsonb_array_elements_text(coalesce(c.payload#>'{card_classification_review,category_options}','[]')) a(value)
  WHERE c.user_id=u AND a.value=cat
 ) AND NOT EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,p_from,p_to) x WHERE cat IN (x.category,x.management_subgroup)) THEN RAISE EXCEPTION 'unknown category'; END IF;
 SELECT to_jsonb(d) INTO before_value FROM public.lts_v178_review_decision d WHERE d.user_id=u AND d.source_table=r.source_table AND d.source_ref=r.source_ref;
 INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,beneficiary,property_code,category_label,decision_basis,decided_at)
 VALUES(u,r.source_table,r.source_ref,person,prop,cat,'authenticated_detail_v232',now())
 ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET
  beneficiary=coalesce(excluded.beneficiary,lts_v178_review_decision.beneficiary),
  property_code=coalesce(excluded.property_code,lts_v178_review_decision.property_code),
  category_label=coalesce(excluded.category_label,lts_v178_review_decision.category_label),decision_basis=excluded.decision_basis,decided_at=excluded.decided_at;
 IF NOT EXISTS(SELECT 1 FROM public.lts_v229_expense_rows(u,r.event_date,r.event_date) x
   WHERE x.source_table=r.source_table AND x.source_ref=r.source_ref
    AND (cat IS NULL OR public.lts_category_name_v290(u,x.category)=cat) AND (person IS NULL OR x.beneficiary=person)
    AND (prop IS NULL OR x.property_code=prop)) THEN RAISE EXCEPTION 'classification did not propagate'; END IF;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),'expense_detail_classification_v232',
  jsonb_build_object('source_table',r.source_table,'source_ref',r.source_ref,'before',before_value,'after',jsonb_build_object('category',cat,'beneficiary',person,'property_code',prop),'original',to_jsonb(r)));
 RETURN jsonb_build_object('ok',true,'source_table',r.source_table,'source_ref',r.source_ref);
END $function$;


