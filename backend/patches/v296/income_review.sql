-- Canonical incoming categories, a complete review list, and category-only edits.
-- No financial source amount/date/status is updated by this migration.
DO $baseline$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();v text;
BEGIN
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO v
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 PERFORM set_config('lts.v296.expenses_before',v,true);
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r)-'category' ORDER BY(to_jsonb(r)-'category')::text)::text,'[]')) INTO v
 FROM public.lts_historical_effective_cash_v5(u,'2013-10-10',current_date)r;
 PERFORM set_config('lts.v296.cash_before',v,true);
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id)::text,'[]')) INTO v
 FROM public.lts_open_finance_staging r WHERE r.user_id=u;
 PERFORM set_config('lts.v296.bank_before',v,true);
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id)::text,'[]')) INTO v
 FROM public.financial_events r WHERE r.user_id=u;
 PERFORM set_config('lts.v296.events_before',v,true);
END $baseline$;
CREATE OR REPLACE FUNCTION lts_income_private.category_v296(p_user_id uuid,p_description text,p_current text)
RETURNS text LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH candidates AS (
 SELECT c.category,0 priority FROM public.lts_category_catalog c
 WHERE c.user_id=p_user_id AND c.active
 AND public.lts_v178_norm(c.category)=public.lts_v178_norm(p_description)
 AND public.lts_v178_norm(c.category) NOT IN('','a classificar','sem categoria','nao identificado','—')
 UNION ALL
 SELECT coalesce(named.category,canonical.category),CASE WHEN r.confidence='user_confirmed' THEN 1 ELSE 2 END
 FROM public.lts_semantic_rule r
 LEFT JOIN public.lts_category_catalog named ON named.user_id=r.user_id AND named.active
  AND public.lts_v178_norm(named.category)=public.lts_v178_norm(r.counterparty)
 LEFT JOIN public.lts_category_catalog canonical ON canonical.user_id=r.user_id AND canonical.active
  AND public.lts_v178_norm(canonical.category)=public.lts_v178_norm(r.category)
 WHERE r.user_id=p_user_id AND r.active AND r.confidence IN('user_confirmed','high','alta','system_high')
 AND public.lts_v178_norm(r.semantic_nature) IN('income','receita','entrada')
 AND NOT r.is_internal_transfer AND NOT r.is_asset_movement
 AND ((r.match_type='exact' AND public.lts_v178_norm(r.match_value)=public.lts_v178_norm(p_description))
  OR(r.match_type='prefix' AND starts_with(public.lts_v178_norm(p_description),public.lts_v178_norm(r.match_value))))
), ranked AS(SELECT *,min(priority) OVER() best FROM candidates WHERE category IS NOT NULL)
SELECT CASE WHEN public.lts_v178_norm(coalesce(p_current,''))
 NOT IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—') THEN p_current
 ELSE coalesce((SELECT min(category) FROM ranked WHERE priority=best HAVING count(DISTINCT category)=1),p_current,'A classificar') END;
$fn$;
REVOKE ALL ON FUNCTION lts_income_private.category_v296(uuid,text,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.category_v296(uuid,text,text) TO service_role;

-- Metadata only: preserve the existing reader's identity, OID, ACL and every cash field.
DO $patch$
DECLARE d text;acl aclitem[];own oid;
BEGIN
 SELECT pg_get_functiondef(oid),proacl,proowner INTO d,acl,own FROM pg_proc
 WHERE oid='public.lts_historical_effective_cash_v5(uuid,date,date)'::regprocedure;
 IF md5(d)<>'e61f033c64c898917d7a250a25bf6cb5' THEN RAISE EXCEPTION 'Historical income reader lease changed';END IF;
 d:=replace(d,$old$SELECT * FROM kept UNION ALL SELECT * FROM source_totals WHERE amount<>0;$old$,$new$
, original_rows AS(SELECT * FROM kept UNION ALL SELECT * FROM source_totals WHERE amount<>0)
SELECT r.event_date,r.account,r.description,r.signed_amount,r.source,r.source_ref,r.confidence,
 r.account_assignment,r.legacy_index,r.original_date,r.displaced,r.internal_transfer,
 CASE WHEN r.signed_amount>0 THEN
  lts_income_private.category_v296(p_user_id,r.description,
   public.lts_flow_classification_decision_v1(p_user_id,to_jsonb(r))->>'category')
 ELSE r.category END,r.counterparty,r.center_cost,r.excluded_from_spend FROM original_rows r;
$new$);
 IF d NOT LIKE '%original_rows AS%' THEN RAISE EXCEPTION 'Historical income patch anchor missing';END IF;
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.lts_historical_effective_cash_v5(uuid,date,date)'::regprocedure
  AND(proacl IS DISTINCT FROM acl OR proowner<>own)) THEN RAISE EXCEPTION 'Historical income privileges changed';END IF;
END $patch$;

-- Income rules must never classify a debit to the same counterparty as a reimbursement.
DO $patch$
DECLARE d text;acl aclitem[];own oid;
BEGIN
 SELECT pg_get_functiondef(oid),proacl,proowner INTO d,acl,own FROM pg_proc
 WHERE oid='public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure;
 IF md5(d)<>'da50512a2b30f953bce63ac3fb0465ae' THEN RAISE EXCEPTION 'Bank classification lease changed';END IF;
 d:=replace(d,$old$AND r.confidence IN ('user_confirmed','high','alta','system_high')$old$,$new$AND r.confidence IN ('user_confirmed','high','alta','system_high')
   AND (public.lts_v178_norm(coalesce(r.semantic_nature,'')) NOT IN('income','receita','entrada') OR t.signed_amount>0)$new$);
 IF d NOT LIKE '%OR t.signed_amount>0)%' THEN RAISE EXCEPTION 'Bank direction patch anchor missing';END IF;
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc WHERE oid='public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure
  AND(proacl IS DISTINCT FROM acl OR proowner<>own)) THEN RAISE EXCEPTION 'Bank classification privileges changed';END IF;
END $patch$;

CREATE OR REPLACE FUNCTION lts_income_private.rows_v296(p_user_id uuid,p_from date,p_to date)
RETURNS SETOF jsonb LANGUAGE plpgsql SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
DECLARE cutover date;finish_history date;payload jsonb;events jsonb:='[]';
BEGIN
 IF p_user_id IS DISTINCT FROM public.lts_browser_assert_user_v1() THEN RAISE EXCEPTION 'Acesso não autorizado.';END IF;
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date
 THEN RAISE EXCEPTION 'Período inválido.';END IF;
 -- Same documentary cutover as canonical Flow, not an arbitrary recent-day filter.
 SELECT min((metadata->>'balance_as_of')::date) INTO cutover FROM public.accounts
 WHERE user_id=p_user_id AND is_active AND metadata->>'evidence_sha256' IS NOT NULL
 AND institution IN('Itaú','Bradesco','C6') AND(metadata->>'balance_as_of')::date<current_date;
 finish_history:=least(p_to,coalesce(cutover,p_to));
 IF p_from<=finish_history THEN
  SELECT coalesce(jsonb_agg(to_jsonb(r)),'[]') INTO events
  FROM public.lts_historical_effective_cash_v5(p_user_id,p_from,finish_history) r WHERE r.signed_amount>0;
 END IF;
 IF cutover IS NOT NULL AND p_to>cutover THEN
  -- The canonical posted-cash layer excludes card forecast/composition work.
  payload:=public.lts_browser_flow_pre_v238(greatest(p_from,cutover+1),p_to);
  IF payload->>'ok' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Não foi possível conferir as entradas.';END IF;
  events:=events||coalesce(payload#>'{flow,historical,events}','[]')||coalesce(payload#>'{flow,current_future,events}','[]');
 END IF;
 RETURN QUERY WITH original AS MATERIALIZED(
  SELECT public.lts_flow_classification_decision_v1(p_user_id,x) x FROM jsonb_array_elements(events)x
  WHERE(x->>'signed_amount')::numeric>0 AND(x->>'event_date')::date BETWEEN p_from AND p_to
  AND NOT coalesce((x->>'internal_transfer')::boolean,false)
  AND NOT coalesce((x->>'asset_movement')::boolean,false)
  AND NOT coalesce((x->>'excluded_from_spend')::boolean,false)
  AND NOT coalesce((x->>'unposted_past_projection')::boolean,false)
  AND NOT coalesce((x->>'unposted_current_projection')::boolean,false)
  AND NOT coalesce((x->>'is_projection')::boolean,false)
 ), mapped AS MATERIALIZED(
  SELECT x,lts_income_private.category_v296(p_user_id,x->>'description',x->>'category') category,
   CASE WHEN x->>'source'='open_finance' OR x->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
    WHEN x->>'source'='legacy_fix86' AND x->>'source_ref' ~ '^evento_base:[0-9]+$' THEN 'evento_base'
    WHEN x->>'source'='current_event' THEN 'daily_flow_documentary_bridge' ELSE x->>'source' END source_table,
   CASE WHEN x->>'open_finance_id' IS NOT NULL THEN x->>'open_finance_id'
    WHEN x->>'source'='legacy_fix86' AND x->>'source_ref' ~ '^evento_base:[0-9]+$' THEN split_part(x->>'source_ref',':',2)
    ELSE x->>'source_ref' END source_ref
  FROM original
 ), identified AS MATERIALIZED(
  SELECT m.*,coalesce(
   (SELECT s.raw_hash FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.id::text=m.source_ref
    AND m.source_table='lts_open_finance_staging' AND s.normalized_payload->>'status'='POSTED' AND s.provider_deleted_at IS NULL),
   (SELECT md5(to_jsonb(f)::text) FROM public.financial_events f WHERE f.user_id=p_user_id
    AND m.source_table IN('daily_flow_documentary_bridge','financial_events','confirmed_fact')
    AND m.source_ref IN(f.id::text,f.legacy_id,'financial_events:'||f.id::text)
    AND NOT f.is_projection AND NOT f.is_suppressed AND NOT f.is_internal_transfer AND f.nature='income'
    AND f.status IN('active','confirmed') LIMIT 1),
   (SELECT md5(to_jsonb(b)::text) FROM public.evento_base b WHERE b.usuario_id=p_user_id
    AND m.source_table='evento_base' AND b.idx::text=m.source_ref AND b.dados->>'efeito'='entrada')
   ) source_hash,
   (SELECT to_jsonb(d) FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id AND d.source_table=m.source_table AND d.source_ref=m.source_ref) decision
  FROM mapped m
 ), unique_rows AS(
  SELECT DISTINCT ON(source_table,source_ref,x->>'event_date',x->>'account') * FROM identified
  ORDER BY source_table,source_ref,x->>'event_date',x->>'account',x::text
 ) SELECT x||jsonb_build_object('category',category,'source_table',source_table,'decision_ref',source_ref,
  'review_key',source_table||':'||source_ref||':'||(x->>'event_date'),
  'editable',source_hash IS NOT NULL,'token',md5(jsonb_build_object(
   'source',source_table,'ref',source_ref,'date',x->>'event_date','account',x->>'account',
   'amount',x->>'signed_amount','category',category,'source_hash',source_hash,'decision',decision)::text))
 FROM unique_rows;
END $fn$;
REVOKE ALL ON FUNCTION lts_income_private.rows_v296(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.rows_v296(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_income_review_queue_v296(p_from date,p_to date,
 p_offset integer DEFAULT 0,p_limit integer DEFAULT 25,p_query text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();result jsonb;
BEGIN
 IF p_offset IS NULL OR p_limit IS NULL OR p_offset<0 OR p_limit NOT BETWEEN 1 AND 100 OR length(coalesce(p_query,''))>300 THEN RAISE EXCEPTION 'Filtro inválido.';END IF;
 WITH pending AS MATERIALIZED(
  SELECT x FROM lts_income_private.rows_v296(u,p_from,p_to)x
  WHERE public.lts_v178_norm(x->>'category') IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—')
 ),filtered AS MATERIALIZED(
  SELECT x FROM pending WHERE nullif(trim(p_query),'') IS NULL
  OR strpos(public.lts_v178_norm(concat_ws(' ',x->>'description',x->>'account',x->>'category')),public.lts_v178_norm(p_query))>0
 ),page AS(
  SELECT x FROM filtered ORDER BY x->>'event_date' DESC,(x->>'signed_amount')::numeric DESC,x->>'review_key' OFFSET p_offset LIMIT p_limit
 ) SELECT jsonb_build_object('ok',true,'from',p_from,'to',p_to,'row_count',(SELECT count(*) FROM pending),
  'matched_count',(SELECT count(*) FROM filtered),'offset',p_offset,
  'next_offset',CASE WHEN p_offset+p_limit<(SELECT count(*) FROM filtered) THEN p_offset+p_limit END,
  'rows',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date' DESC,(x->>'signed_amount')::numeric DESC,x->>'review_key') FROM page),'[]')) INTO result;
 RETURN result;
END $fn$;
REVOKE ALL ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text) TO authenticated,service_role;

-- Preserve the public V183 signature; add posted bank/historical source support.
DO $lease$ BEGIN
 IF md5(pg_get_functiondef('lts_income_private.review_v183(text,text,date,text,numeric,text,text)'::regprocedure))<>'5dcffd1558d075d350dcb5934d10bf11'
 THEN RAISE EXCEPTION 'Income writer lease changed';END IF;
END $lease$;
CREATE OR REPLACE FUNCTION lts_income_private.review_v183(p_source text,p_source_ref text,p_event_date date,
 p_account text,p_amount numeric,p_category text,p_expected text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
DECLARE u uuid:=public.lts_browser_assert_user_v1();r jsonb;cat text;options jsonb;before_value jsonb;n integer;
BEGIN
 IF p_source IS NULL OR nullif(p_source_ref,'') IS NULL OR length(p_source_ref)>180 OR p_event_date IS NULL
 OR p_event_date>current_date OR p_event_date<date '2013-10-10' OR p_amount IS NULL OR p_amount<=0
 OR p_account NOT IN('Itaú','Bradesco','C6') THEN RAISE EXCEPTION 'Recebimento inválido. Atualize a lista.';END IF;
 SELECT count(*),jsonb_agg(x)->0 INTO n,r FROM lts_income_private.rows_v296(u,p_event_date,p_event_date)x
 WHERE x->>'source'=p_source AND x->>'source_ref'=p_source_ref AND x->>'account'=p_account
 AND(x->>'signed_amount')::numeric=p_amount;
 IF n<>1 OR r->>'editable' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'Não foi possível conferir este recebimento. Atualize a lista.';END IF;
 -- Serialize edits on the exact source and recheck after acquiring its lock.
 PERFORM pg_advisory_xact_lock(hashtextextended(u::text||':'||(r->>'source_table')||':'||(r->>'decision_ref'),296));
 IF r->>'source_table'='lts_open_finance_staging' THEN
  PERFORM 1 FROM public.lts_open_finance_staging WHERE user_id=u AND id::text=r->>'decision_ref' FOR SHARE;
 ELSIF r->>'source_table'='evento_base' THEN
  PERFORM 1 FROM public.evento_base WHERE usuario_id=u AND idx::text=r->>'decision_ref' FOR SHARE;
 ELSE
  PERFORM 1 FROM public.financial_events f WHERE f.user_id=u
   AND(r->>'decision_ref') IN(f.id::text,f.legacy_id,'financial_events:'||f.id::text) FOR SHARE;
 END IF;
 SELECT x INTO STRICT r FROM lts_income_private.rows_v296(u,p_event_date,p_event_date)x
 WHERE x->>'source'=p_source AND x->>'source_ref'=p_source_ref AND x->>'account'=p_account
 AND(x->>'signed_amount')::numeric=p_amount;
 SELECT categories INTO options FROM jsonb_to_record(public.lts_browser_card_category_options_v226()) AS c(categories jsonb);
 IF p_category IS NULL THEN
  RETURN jsonb_build_object('ok',true,'editable',public.lts_v178_norm(r->>'category') IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—'),
   'saved',false,'category',r->>'category','token',r->>'token','options',options,'event',r);
 END IF;
 IF p_expected IS NULL OR p_expected IS DISTINCT FROM r->>'token' THEN RAISE EXCEPTION 'O recebimento mudou. Atualize a lista antes de classificar.';END IF;
 IF public.lts_v178_norm(r->>'category') NOT IN('','a classificar','classificacao pendente','sem categoria','nao identificado','—')
 THEN RETURN jsonb_build_object('ok',true,'saved',false,'editable',false,'category',r->>'category');END IF;
 cat:=public.lts_category_name_v290(u,p_category);
 IF cat IS NULL OR NOT(options ? cat) OR public.lts_v178_norm(cat) IN('','a classificar','—') THEN RAISE EXCEPTION 'Escolha uma classificação do cadastro.';END IF;
 SELECT to_jsonb(d) INTO before_value FROM public.lts_v178_review_decision d
 WHERE d.user_id=u AND d.source_table=r->>'source_table' AND d.source_ref=r->>'decision_ref';
 INSERT INTO public.lts_v178_review_decision(user_id,source_table,source_ref,category_label,beneficiary,decision_basis)
 VALUES(u,r->>'source_table',r->>'decision_ref',cat,NULL,'authenticated_income_v296')
 ON CONFLICT(user_id,source_table,source_ref) DO UPDATE SET category_label=excluded.category_label,
 decision_basis=excluded.decision_basis,decided_at=now();
 IF NOT EXISTS(SELECT 1 FROM lts_income_private.rows_v296(u,p_event_date,p_event_date)x
  WHERE x->>'source'=p_source AND x->>'source_ref'=p_source_ref AND x->>'category'=cat)
 THEN RAISE EXCEPTION 'A classificação não foi refletida. Nenhuma alteração foi salva.';END IF;
 INSERT INTO public.lts_access_audit(user_id,email,action,meta) VALUES(u,lower(coalesce(auth.jwt()->>'email','')),
 'income_category_v296',jsonb_build_object('source_table',r->>'source_table','source_ref',r->>'decision_ref',
 'before',before_value,'category',cat,'date',p_event_date,'amount',p_amount,'cash_changed',false,'person_inferred',false));
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
 RETURN jsonb_build_object('ok',true,'saved',true,'category',cat,'cash_changed',false);
END $fn$;

UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;

DO $verify$
DECLARE u uuid:=public.lts_open_finance_pilot_owner_v1();v text;
BEGIN
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY to_jsonb(r)::text)::text,'[]')) INTO v
 FROM public.lts_v229_expense_rows(u,'2013-10-10',current_date)r;
 IF v IS DISTINCT FROM current_setting('lts.v296.expenses_before') THEN RAISE EXCEPTION 'Unrelated canonical expenses changed';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r)-'category' ORDER BY(to_jsonb(r)-'category')::text)::text,'[]')) INTO v
 FROM public.lts_historical_effective_cash_v5(u,'2013-10-10',current_date)r;
 IF v IS DISTINCT FROM current_setting('lts.v296.cash_before') THEN RAISE EXCEPTION 'Historical cash rows changed beyond category';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id)::text,'[]')) INTO v
 FROM public.lts_open_finance_staging r WHERE r.user_id=u;
 IF v IS DISTINCT FROM current_setting('lts.v296.bank_before') THEN RAISE EXCEPTION 'Bank source changed';END IF;
 SELECT md5(coalesce(jsonb_agg(to_jsonb(r) ORDER BY r.id)::text,'[]')) INTO v
 FROM public.financial_events r WHERE r.user_id=u;
 IF v IS DISTINCT FROM current_setting('lts.v296.events_before') THEN RAISE EXCEPTION 'Financial events changed';END IF;
 IF has_function_privilege('anon','public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)','EXECUTE')
 OR has_function_privilege('authenticated','lts_income_private.rows_v296(uuid,date,date)','EXECUTE')
 THEN RAISE EXCEPTION 'Income review helper exposure';END IF;
 IF(SELECT proacl::text FROM pg_proc WHERE oid='lts_income_private.review_v183(text,text,date,text,numeric,text,text)'::regprocedure)
 IS DISTINCT FROM '{postgres=X/postgres,authenticated=X/postgres}' THEN RAISE EXCEPTION 'Income writer ACL changed';END IF;
END $verify$;
