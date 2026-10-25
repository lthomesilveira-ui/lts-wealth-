-- Frozen function definitions; code only, no account data.
CREATE OR REPLACE FUNCTION lts_income_private.rows_v296(p_user_id uuid, p_from date, p_to date)
 RETURNS SETOF jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
BEGIN
 IF p_user_id IS DISTINCT FROM public.lts_browser_assert_user_v1() THEN RAISE EXCEPTION 'Acesso não autorizado.';END IF;

 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date
 THEN RAISE EXCEPTION 'Período inválido.';END IF;
 RETURN QUERY WITH anchors AS MATERIALIZED(
  SELECT institution bank,max((metadata->>'balance_as_of')::date) dt FROM public.accounts
  WHERE user_id=p_user_id AND is_active AND metadata->>'evidence_sha256' IS NOT NULL
  AND institution IN('Itaú','Bradesco','C6') AND(metadata->>'balance_as_of')::date<current_date GROUP BY institution
 ),positions AS MATERIALIZED(SELECT public.lts_open_finance_checking_positions_v1(p_user_id) p),
 history AS MATERIALIZED(
  SELECT public.lts_flow_classification_decision_v1(p_user_id,to_jsonb(r)) x
  FROM public.lts_historical_effective_cash_v5(p_user_id,p_from,p_to)r
  WHERE r.signed_amount>0
 ),bank AS MATERIALIZED(
  SELECT s.*,a.bank FROM public.lts_bank_posted_rows_v231(p_user_id)s JOIN anchors a
  ON a.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
  WHERE s.signed_amount>0 AND s.posting_date>a.dt AND s.posting_date BETWEEN p_from AND p_to
  AND EXISTS(SELECT 1 FROM positions,jsonb_array_elements(p)x WHERE x->>'bank'=a.bank
   AND x#>>'{payload,provider_account_id}'=s.normalized_payload->>'provider_account_id' AND s.occurred_at<=(x->>'as_of')::timestamptz)
  AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm WHERE dm.user_id=p_user_id
   AND dm.staging_id=s.id AND dm.bank=a.bank AND dm.signed_amount=s.signed_amount AND dm.canonical_date<=a.dt
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=p_user_id
    AND(fe.id::text=dm.source_ref OR fe.legacy_id=dm.source_ref) AND fe.event_date=dm.canonical_date AND fe.amount=dm.signed_amount))
 ),matches AS MATERIALIZED(
  SELECT b.id,h.x FROM bank b JOIN history h ON h.x->>'account'=b.bank
  AND(h.x->>'event_date')::date=b.posting_date AND(h.x->>'signed_amount')::numeric=b.signed_amount
  AND(h.x->>'open_finance_id'=b.id::text
   OR lower(trim(h.x->>'description'))=lower(trim(b.description_raw))
   OR public.lts_documented_bank_event_identity_v242(p_user_id,b.id,h.x)
   OR EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(b.normalized_payload#>'{reconciliation,candidates}','[]'))z
    WHERE z->>'ref' IN(h.x->>'source_ref',(h.x->>'source')||':'||(h.x->>'source_ref'))))
 ),kept AS MATERIALIZED(
  SELECT h.x FROM history h LEFT JOIN anchors a ON a.bank=h.x->>'account'
  WHERE NOT coalesce((h.x->>'internal_transfer')::boolean,false)
  AND NOT coalesce((h.x->>'excluded_from_spend')::boolean,false)
  AND NOT EXISTS(SELECT 1 FROM matches m WHERE m.x=h.x)
  AND((h.x->>'event_date')::date<=coalesce(a.dt,p_to)
   OR coalesce(h.x->>'confidence','') NOT IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot'))
  AND NOT EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id=p_user_id AND f.is_projection
   AND h.x->>'source' IN('current_event','financial_events','confirmed_fact')
   AND(h.x->>'source_ref') IN(f.id::text,f.legacy_id,'financial_events:'||f.id::text))
 ),own AS MATERIALIZED(SELECT * FROM lts_income_private.own_credits_v296(p_user_id,p_from,p_to)),
 received AS MATERIALIZED(
  SELECT jsonb_build_object('source','open_finance','source_ref',b.id,'open_finance_id',b.id,
   'event_date',b.posting_date,'account',b.bank,'description',b.description_raw,'signed_amount',b.signed_amount,
   'bank_confirmed',true,'internal_transfer',false,'excluded_from_spend',false,
   'category',coalesce(k.c->>'category',
    (SELECT min(m.x->>'category') FROM matches m WHERE m.id=b.id HAVING count(*)=1),'A classificar')) x
  FROM bank b LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(p_user_id,b.id)c OFFSET 0)k ON true
  WHERE NOT EXISTS(SELECT 1 FROM own o WHERE o.credit_id=b.id)
  AND NOT EXISTS(SELECT 1 FROM matches m WHERE m.id=b.id AND(
   coalesce((m.x->>'internal_transfer')::boolean,false) OR coalesce((m.x->>'excluded_from_spend')::boolean,false)))
  AND b.description_raw NOT ILIKE '%RESGATE COFRINH%'
  AND NOT public.lts_bank_own_global_return_v1(p_user_id,b.id)
  AND public.lts_bank_fgts_combined_receipt_v261(p_user_id,b.id) IS NULL
 ),original AS MATERIALIZED(
  SELECT x FROM kept UNION ALL SELECT x FROM received
 ),mapped AS MATERIALIZED(
  SELECT x,lts_income_private.category_v296(p_user_id,x->>'description',x->>'category') category,
   CASE WHEN x->>'source'='open_finance' OR x->>'open_finance_id' IS NOT NULL THEN 'lts_open_finance_staging'
    WHEN x->>'source'='legacy_fix86' AND x->>'source_ref' ~ '^evento_base:[0-9]+$' THEN 'evento_base'
    WHEN x->>'source'='current_event' THEN 'daily_flow_documentary_bridge' ELSE x->>'source' END source_table,
   CASE WHEN x->>'open_finance_id' IS NOT NULL THEN x->>'open_finance_id'
    WHEN x->>'source'='legacy_fix86' AND x->>'source_ref' ~ '^evento_base:[0-9]+$' THEN split_part(x->>'source_ref',':',2)
    ELSE x->>'source_ref' END source_ref FROM original
 ),identified AS MATERIALIZED(
  SELECT m.*,coalesce(
   (SELECT s.raw_hash FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.id::text=m.source_ref
    AND m.source_table='lts_open_finance_staging' AND s.normalized_payload->>'status'='POSTED' AND s.provider_deleted_at IS NULL),
   (SELECT md5(to_jsonb(f)::text) FROM public.financial_events f WHERE f.user_id=p_user_id
    AND m.source_table IN('daily_flow_documentary_bridge','financial_events','confirmed_fact')
    AND m.source_ref IN(f.id::text,f.legacy_id,'financial_events:'||f.id::text)
    AND NOT f.is_projection AND NOT f.is_suppressed AND NOT f.is_internal_transfer AND f.nature='income'
    AND f.status IN('active','confirmed') LIMIT 1),
   (SELECT md5(to_jsonb(b)::text) FROM public.evento_base b WHERE b.usuario_id=p_user_id
    AND m.source_table='evento_base' AND b.idx::text=m.source_ref AND b.dados->>'efeito'='entrada')) source_hash,
   (SELECT to_jsonb(d) FROM public.lts_v178_review_decision d WHERE d.user_id=p_user_id
    AND d.source_table=m.source_table AND d.source_ref=m.source_ref) decision
  FROM mapped m
 ),unique_rows AS(
  SELECT DISTINCT ON(source_table,source_ref,x->>'event_date',x->>'account') * FROM identified
  ORDER BY source_table,source_ref,x->>'event_date',x->>'account',x::text
 ) SELECT x||jsonb_build_object('category',category,'source_table',source_table,'decision_ref',source_ref,
  'review_key',source_table||':'||source_ref||':'||(x->>'event_date'),
  'editable',source_hash IS NOT NULL,'token',md5(jsonb_build_object(
   'source',source_table,'ref',source_ref,'date',x->>'event_date','account',x->>'account',
   'amount',x->>'signed_amount','category',category,'source_hash',source_hash,'decision',decision)::text)) FROM unique_rows;
END $function$;

CREATE OR REPLACE FUNCTION lts_income_private.queue_v296(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
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
END $function$;

CREATE OR REPLACE FUNCTION public.lts_browser_income_review_queue_v296(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
AS $function$
 SELECT lts_income_private.queue_v296(p_from,p_to,p_offset,p_limit,p_query);
$function$;

CREATE OR REPLACE FUNCTION public.lts_v178_norm(v text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(v,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') $function$;

