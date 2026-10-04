CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4_pre_v237(p_user_id uuid, p_from date, p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH resolved AS (
 SELECT e.*,coalesce(sr.category,e.category) resolved_category,coalesce(sr.counterparty,e.counterparty) resolved_counterparty,
  coalesce(sr.center_cost,e.center_cost) resolved_center,coalesce(sr.exclude_from_spend,e.excluded_from_spend) resolved_excluded
 FROM public.lts_historical_effective_cash_v3(p_user_id,p_from,p_to)e
 LEFT JOIN LATERAL (
  SELECT r.category,r.counterparty,r.center_cost,r.exclude_from_spend FROM public.lts_semantic_rule r
  WHERE r.active AND r.user_id=p_user_id AND (
   (r.match_type='exact' AND lower(trim(e.description))=lower(trim(r.match_value))) OR
   (r.match_type='prefix' AND lower(trim(e.description)) LIKE lower(trim(r.match_value))||'%') OR
   (r.match_type='contains' AND lower(trim(e.description)) LIKE '%'||lower(trim(r.match_value))||'%'))
  ORDER BY CASE WHEN r.confidence='user_confirmed' THEN 0 ELSE 1 END,
   CASE r.match_type WHEN 'exact' THEN 0 WHEN 'prefix' THEN 1 WHEN 'contains' THEN 2 ELSE 9 END,length(r.match_value) DESC,r.updated_at DESC LIMIT 1
 )sr ON true
), posted_identity AS (
 SELECT ev.id evidence_id,min(f.id::text) fact_id FROM public.lts_reconciliation_evidence ev
 JOIN public.financial_events f ON f.user_id=ev.user_id AND f.event_date::text=ev.metadata->>'posting_date'
  AND f.amount=ev.amount AND lower(trim(f.description_raw))=lower(trim(ev.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
  AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(ev.account)),'ú','u')
 WHERE ev.user_id=p_user_id AND ev.evidence_type='bank_statement' AND ev.status='documented'
  AND ev.metadata->>'cash_effect'='statement_fact_not_new_projection' AND ev.metadata->>'initiated_date'=ev.evidence_date::text
  AND ev.metadata->>'posting_date'>ev.evidence_date::text AND f.metadata->>'documented_statement_fact'='true'
  AND NOT f.is_suppressed AND NOT f.is_projection AND f.status<>'cancelled'
 GROUP BY ev.id HAVING count(*)=1
)
SELECT e.event_date,e.account,e.description,e.signed_amount,e.source,e.source_ref,e.confidence,e.account_assignment,e.legacy_index,e.original_date,e.displaced,e.internal_transfer,
 CASE WHEN lower(trim(coalesce(e.resolved_category,''))) IN ('','a classificar','—','classificação pendente') THEN coalesce(nullif(src.category,''),e.resolved_category) ELSE e.resolved_category END,
 CASE WHEN lower(trim(coalesce(e.resolved_counterparty,''))) IN ('','não identificado') THEN coalesce(nullif(src.counterparty,''),e.resolved_counterparty) ELSE e.resolved_counterparty END,
 coalesce(nullif(nullif(src.metadata#>>'{classification_h_answers_20260914,center_cost}',''),'Não atribuído'),nullif(nullif(src.metadata#>>'{user_classification_20260913,beneficiary}',''),'Não atribuído'),e.resolved_center),e.resolved_excluded
FROM resolved e LEFT JOIN LATERAL (
 SELECT f.category,f.metadata,f.counterparty FROM public.financial_events f JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 WHERE f.user_id=p_user_id AND NOT f.is_suppressed AND f.status<>'cancelled' AND e.source IN ('current_event','financial_events','confirmed_fact')
  AND (f.id::text=e.source_ref OR f.legacy_id=e.source_ref OR 'financial_events:'||f.id::text=e.source_ref)
  AND f.event_date=e.event_date AND f.amount=e.signed_amount AND translate(lower(a.institution),'ú','u')=translate(lower(e.account),'ú','u')
  AND lower(trim(coalesce(f.category,''))) NOT IN ('','a classificar','—') LIMIT 1
)src ON true WHERE NOT(e.source='reconciliation_evidence' AND EXISTS(SELECT 1 FROM posted_identity p WHERE p.evidence_id::text=e.source_ref));
$function$;

CREATE OR REPLACE FUNCTION public.lts_c6_paid_identity_v237(p_user_id uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $f$
WITH inv AS MATERIALIZED (
 SELECT i.*,pay FROM public.lts_open_finance_staging i
 CROSS JOIN LATERAL jsonb_array_elements(coalesce(i.normalized_payload->'payments','[]')) pay
 WHERE i.user_id=p_user_id AND i.institution_code='336' AND i.resource_type='invoice'
 AND i.provider_deleted_at IS NULL AND i.normalized_payload->>'layer'='card_invoice_obligation'
 AND i.normalized_payload->>'currency'='BRL' AND pay->>'currencyCode'='BRL'
 AND (pay->>'amount')::numeric=(i.normalized_payload->>'amount')::numeric
 AND left(pay->>'paymentDate',10)::date=date '2026-07-06'
 AND i.normalized_payload->>'due_date'='2026-07-05'
), candidates AS (
 SELECT i.id invoice_id,i.raw_hash invoice_hash,i.pay, d.id debit_id,d.raw_hash debit_hash,
 r.id receipt_id,r.raw_hash receipt_hash,t.id transfer_id,t.raw_hash transfer_hash,
 v.idx payment_idx,ot.idx transfer_idx,orx.idx receipt_idx,
 (i.pay->>'amount')::numeric amount,left(i.pay->>'paymentDate',10)::date paid_date
 FROM inv i
 JOIN public.lts_open_finance_staging d ON d.user_id=i.user_id AND d.institution_code='336'
 AND d.resource_type='transaction' AND d.posting_date=left(i.pay->>'paymentDate',10)::date
 AND d.signed_amount=-(i.pay->>'amount')::numeric AND d.description_raw='C6 BANK'
 AND d.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND d.normalized_payload->>'layer'='bank_cash' AND d.normalized_payload->>'status'='POSTED'
 AND d.currency='BRL' AND d.provider_deleted_at IS NULL
 JOIN public.lts_open_finance_staging r ON r.user_id=i.user_id AND r.institution_code='336'
 AND r.resource_type='transaction' AND r.posting_date=d.posting_date AND r.signed_amount=-d.signed_amount
 AND r.provider_account_ref=d.provider_account_ref AND r.description_raw ILIKE 'Pix recebido %'
 AND r.normalized_payload->>'status'='POSTED' AND r.normalized_payload->>'layer'='bank_cash'
 AND r.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND r.currency='BRL' AND r.provider_deleted_at IS NULL
 JOIN public.lts_open_finance_staging t ON t.user_id=i.user_id AND t.institution_code='341'
 AND t.resource_type='transaction' AND t.posting_date=r.posting_date AND t.signed_amount=-r.signed_amount
 AND t.description_raw ILIKE 'Pix enviado %'
 AND lower(regexp_replace(t.description_raw,'^Pix enviado ','','i'))=lower(regexp_replace(r.description_raw,'^Pix recebido (de )?','','i'))
 AND abs(extract(epoch from (t.occurred_at-r.occurred_at)))<=60
 AND t.normalized_payload->>'status'='POSTED' AND t.normalized_payload->>'layer'='bank_cash'
 AND t.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND t.currency='BRL' AND t.provider_deleted_at IS NULL
 JOIN public.evento_base v ON v.usuario_id=p_user_id AND v.dados->>'dia'='2026-07-05'
 AND lower(v.dados->>'desc')='cartão c6master' AND v.dados->>'conta'='C6'
 AND (v.dados->>'valor')::numeric=(i.pay->>'amount')::numeric AND v.dados->>'efeito'='saida'
 JOIN public.evento_base ot ON ot.usuario_id=p_user_id AND ot.dados->>'dia'=v.dados->>'dia'
 AND lower(ot.dados->>'desc')='transferência itaú para c6' AND ot.dados->>'conta'='Itau'
 AND (ot.dados->>'valor')::numeric=(i.pay->>'amount')::numeric AND ot.dados->>'efeito'='saida'
 JOIN public.evento_base orx ON orx.usuario_id=p_user_id AND orx.dados->>'dia'=v.dados->>'dia'
 AND lower(orx.dados->>'desc')='recebimento itaú para c6' AND orx.dados->>'conta'='C6'
 AND (orx.dados->>'valor')::numeric=(i.pay->>'amount')::numeric AND orx.dados->>'efeito'='entrada'
 WHERE EXISTS(SELECT 1 FROM public.lts_open_finance_staging cp WHERE cp.user_id=p_user_id
 AND cp.resource_type='card_transaction' AND cp.institution_code='336' AND cp.posting_date=d.posting_date
 AND cp.signed_amount=-d.signed_amount AND cp.normalized_payload->>'status'='POSTED'
 AND cp.description_raw ILIKE 'Inclusao de Pagamento Ciclo Corrente%'
 AND cp.normalized_payload->>'last4'=i.normalized_payload->>'last4' AND cp.provider_deleted_at IS NULL)
)
SELECT CASE WHEN count(*)=1 THEN jsonb_agg(to_jsonb(c))->0 ELSE NULL END FROM candidates c;
$f$;

CREATE OR REPLACE FUNCTION public.lts_historical_effective_cash_v4(p_user_id uuid,p_from date,p_to date)
 RETURNS TABLE(event_date date, account text, description text, signed_amount numeric, source text, source_ref text, confidence text, account_assignment text, legacy_index integer, original_date date, displaced boolean, internal_transfer boolean, category text, counterparty text, center_cost text, excluded_from_spend boolean)
 LANGUAGE sql SECURITY DEFINER SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $f$
WITH paid AS MATERIALIZED(SELECT public.lts_c6_paid_identity_v237(p_user_id) j),
base AS MATERIALIZED(SELECT * FROM public.lts_historical_effective_cash_v4_pre_v237(p_user_id,p_from-7,p_to+7)),
effective AS MATERIALIZED(
 SELECT e.evidence_date,f.id::text fact_id
 FROM public.lts_reconciliation_evidence e JOIN public.financial_events f
 ON f.user_id=e.user_id AND f.event_date::text=e.metadata->>'posting_date'
 AND f.amount=e.amount AND lower(trim(f.description_raw))=lower(trim(e.description))
 JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
 AND translate(lower(trim(a.institution)),'ú','u')=translate(lower(trim(e.account)),'ú','u')
 WHERE e.user_id=p_user_id AND e.evidence_type='bank_statement' AND e.status='documented'
 AND e.metadata->>'cash_effect'='statement_fact_not_new_projection'
 AND e.metadata->>'balance_effective_date'=e.evidence_date::text AND e.metadata->>'initiated_date'=e.evidence_date::text
 AND f.event_date>e.evidence_date AND f.event_date<=e.evidence_date+7
 AND f.metadata->>'documented_statement_fact'='true' AND NOT f.is_projection AND NOT f.is_suppressed AND f.status<>'cancelled'
 AND e.evidence_date BETWEEN p_from-7 AND p_to+7
 GROUP BY e.id,e.evidence_date,f.id,a.institution
 HAVING (SELECT count(*) FROM public.financial_events fx JOIN public.accounts ax ON ax.id=fx.account_id
 WHERE fx.user_id=e.user_id AND fx.event_date=f.event_date AND fx.amount=e.amount
 AND lower(trim(fx.description_raw))=lower(trim(e.description)) AND ax.institution=a.institution
 AND NOT fx.is_projection AND NOT fx.is_suppressed AND fx.status<>'cancelled')=1
), displaced AS(
 SELECT CASE WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx'))
 THEN (paid.j->>'paid_date')::date ELSE coalesce(e.evidence_date,b.event_date) END event_date,
 b.account,b.description,b.signed_amount,b.source,b.source_ref,
 CASE WHEN e.fact_id IS NOT NULL THEN 'documented_statement_balance_effective_date'
 WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx')) THEN 'bank_documented_settlement_date' ELSE b.confidence END confidence,
 b.account_assignment,b.legacy_index,b.original_date,
 b.displaced OR e.fact_id IS NOT NULL OR coalesce((b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx'))),false) displaced,
 CASE WHEN b.source='legacy_fix86' AND b.source_ref IN('evento_base:'||(paid.j->>'transfer_idx'),'evento_base:'||(paid.j->>'receipt_idx')) THEN true ELSE b.internal_transfer END internal_transfer,
 b.category,b.counterparty,b.center_cost,b.excluded_from_spend
 FROM base b CROSS JOIN paid LEFT JOIN effective e ON b.source IN('current_event','financial_events','confirmed_fact') AND b.source_ref IN(e.fact_id,'financial_events:'||e.fact_id)
), recovered AS(
 SELECT (j->>'paid_date')::date event_date,'C6'::text account,'Pagamento fatura C6 · liquidação bancária'::text description,
 -(j->>'amount')::numeric signed_amount,'bank_documented_card_settlement'::text source,'evento_base:'||(j->>'payment_idx') source_ref,
 'invoice_and_checking_settlement_identity'::text confidence,'documented_bank_account'::text account_assignment,(j->>'payment_idx')::int legacy_index,
 date '2026-07-05' original_date,true displaced,false internal_transfer,'Pagamento de fatura'::text category,'C6 Bank'::text counterparty,
 'Não atribuído'::text center_cost,true excluded_from_spend FROM paid
 WHERE j IS NOT NULL AND NOT EXISTS(SELECT 1 FROM base b WHERE b.source_ref='evento_base:'||(j->>'payment_idx'))
)
SELECT * FROM displaced WHERE event_date BETWEEN p_from AND p_to
UNION ALL SELECT * FROM recovered WHERE event_date BETWEEN p_from AND p_to;
$f$;

REVOKE ALL ON FUNCTION public.lts_c6_paid_identity_v237(uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_paid_identity_v237(uuid),public.lts_historical_effective_cash_v4_pre_v237(uuid,date,date) TO service_role;
