-- Read only incoming cash identities; do not render balances or card projections.
CREATE OR REPLACE FUNCTION lts_income_private.own_credits_v296(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(credit_id uuid) LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH posted AS MATERIALIZED(
 SELECT s.id,s.user_id,s.posting_date,s.signed_amount,s.institution_code,s.provider_account_ref,
  s.raw_payload#>>'{paymentData,payer,documentNumber,type}' payer_type,
  s.raw_payload#>>'{paymentData,receiver,documentNumber,type}' receiver_type,
  regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
  regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf,
  s.raw_payload#>>'{paymentData,payer,routingNumber}' payer_bank,
  s.raw_payload#>>'{paymentData,receiver,routingNumber}' receiver_bank
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='transaction'
 AND s.currency='BRL' AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND s.posting_date BETWEEN p_from AND p_to
),owned AS MATERIALIZED(
 SELECT DISTINCT s.institution_code,s.provider_account_ref,
 regexp_replace(s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.resource_type='balance'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
),pairs AS MATERIALIZED(
 SELECT d.id debit_id,c.id credit_id FROM posted d JOIN posted c ON c.user_id=d.user_id
 AND c.posting_date=d.posting_date AND c.signed_amount=-d.signed_amount AND c.institution_code<>d.institution_code
 JOIN owned od ON od.institution_code=d.institution_code AND od.provider_account_ref=d.provider_account_ref AND od.cpf=d.payer_cpf
 JOIN owned oc ON oc.institution_code=c.institution_code AND oc.provider_account_ref=c.provider_account_ref AND oc.cpf=c.receiver_cpf
 WHERE d.signed_amount<0 AND c.signed_amount>0 AND d.institution_code IN('341','237','336') AND c.institution_code IN('341','237','336')
 AND d.payer_type='CPF' AND d.receiver_type='CPF' AND c.payer_type='CPF' AND c.receiver_type='CPF'
 AND d.payer_cpf ~ '^[0-9]{11}$' AND d.payer_cpf=d.receiver_cpf
 AND c.payer_cpf=d.payer_cpf AND c.receiver_cpf=d.receiver_cpf
 AND d.receiver_bank=c.institution_code AND c.payer_bank=d.institution_code
),counted AS(SELECT *,count(*) OVER(PARTITION BY debit_id) nd,count(*) OVER(PARTITION BY credit_id) nc FROM pairs)
SELECT credit_id FROM counted WHERE nd=1 AND nc=1
UNION SELECT p.credit_id FROM public.lts_owner_confirmed_transfer_pairs_v263(p_user_id)p;
$fn$;
REVOKE ALL ON FUNCTION lts_income_private.own_credits_v296(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.own_credits_v296(uuid,date,date) TO service_role;

CREATE OR REPLACE FUNCTION lts_income_private.rows_v296(p_user_id uuid,p_from date,p_to date)
RETURNS SETOF jsonb LANGUAGE plpgsql SET search_path='' SET TimeZone='America/Sao_Paulo' AS $fn$
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
END $fn$;
REVOKE ALL ON FUNCTION lts_income_private.rows_v296(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION lts_income_private.rows_v296(uuid,date,date) TO service_role;

DO $cheap_direction$
DECLARE d text;a aclitem[];
BEGIN
 SELECT pg_get_functiondef(oid),proacl INTO d,a FROM pg_proc WHERE oid='public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure;
 IF strpos(d,$old$public.lts_v178_norm(coalesce(r.semantic_nature,'')) NOT IN('income','receita','entrada')$old$)=0
 THEN RAISE EXCEPTION 'Bank direction expression lease changed';END IF;
 d:=replace(d,$old$public.lts_v178_norm(coalesce(r.semantic_nature,'')) NOT IN('income','receita','entrada')$old$,
 $new$lower(btrim(coalesce(r.semantic_nature,''))) NOT IN('income','receita','entrada')$new$);
 EXECUTE d;
 IF(SELECT proacl FROM pg_proc WHERE oid='public.lts_bank_known_classification_v231(uuid,uuid)'::regprocedure) IS DISTINCT FROM a
 THEN RAISE EXCEPTION 'Bank classifier ACL changed';END IF;
END $cheap_direction$;
