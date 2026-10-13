DO $lease$ BEGIN
 IF md5(pg_get_functiondef('public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure))<>'5056c939887aea838382c0114f7a98d9'
 THEN RAISE EXCEPTION 'recurring audit definition lease changed'; END IF;
END; $lease$;
CREATE OR REPLACE FUNCTION public.lts_recurring_future_gap_audit_v6(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE, p_horizon_end date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH params AS (
 SELECT coalesce(p_as_of,current_date) as_of,
 greatest(coalesce(p_horizon_end,(date_trunc('year',coalesce(p_as_of,current_date))+interval '6 years'-interval '1 day')::date),coalesce(p_as_of,current_date)+1) horizon_end
), base AS MATERIALIZED (
 SELECT public.lts_recurring_future_gap_audit_v4(p_user_id,p.as_of) j FROM params p
), history_sources AS MATERIALIZED (
 SELECT h.*,public.lts_forecast_series_key_v1(h.description) series_key,
 CASE WHEN h.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(h.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_historical_effective_cash_v4(p_user_id,(p.as_of-interval '36 months')::date,p.as_of) h
 WHERE h.signed_amount<>0 AND NOT h.internal_transfer AND NOT h.excluded_from_spend
), bank_actual AS MATERIALIZED (
 SELECT s.id,s.posting_date event_date,s.signed_amount,
 coalesce(identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,s.description_raw) description,
 public.lts_forecast_series_key_v1(coalesce(identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,s.description_raw)) series_key,
 CASE WHEN s.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(s.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_bank_posted_rows_v231(p_user_id) s
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(p_user_id,s.id) c OFFSET 0)k ON true
 LEFT JOIN LATERAL (
 SELECT CASE WHEN count(DISTINCT h.series_key)=1 THEN min(h.description) END description
 FROM history_sources h
 WHERE h.event_date>=date_trunc('month',p.as_of)::date
 AND h.account=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' ELSE s.institution_name END AND h.signed_amount=s.signed_amount
 AND (
 EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm WHERE dm.user_id=p_user_id
  AND dm.staging_id=s.id AND dm.source_ref=h.source_ref AND dm.bank=h.account AND dm.signed_amount=s.signed_amount)
 OR (h.event_date=s.posting_date AND (
  EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]'::jsonb)) z
   WHERE z->>'ref' IN(h.source_ref,h.source||':'||h.source_ref))
  OR lower(trim(h.description))=lower(trim(s.description_raw))
  OR public.lts_documented_bank_event_identity_v242(p_user_id,s.id,to_jsonb(h)))))
 ) identity ON true
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND s.posting_date BETWEEN date_trunc('month',p.as_of)::date AND p.as_of
 AND s.signed_amount<>0
), history_raw AS MATERIALIZED (
 SELECT h.event_date,h.description,h.series_key,h.direction,h.amount
 FROM history_sources h CROSS JOIN params p
 WHERE h.event_date<date_trunc('month',p.as_of)::date
 OR (h.confidence NOT IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
 AND NOT EXISTS(SELECT 1 FROM public.financial_events f WHERE f.user_id=p_user_id
  AND f.is_projection AND NOT f.is_suppressed AND (f.id::text=h.source_ref OR f.legacy_id=h.source_ref))
 AND NOT EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm
  JOIN bank_actual b ON b.id=dm.staging_id WHERE dm.user_id=p_user_id AND dm.source_ref=h.source_ref)
 AND NOT EXISTS(SELECT 1 FROM bank_actual b WHERE b.event_date=h.event_date
  AND b.series_key=h.series_key AND b.direction=h.direction AND b.amount=h.amount))
), history AS MATERIALIZED (
 SELECT * FROM history_raw
 UNION ALL
 SELECT b.event_date,b.description,b.series_key,b.direction,b.amount FROM bank_actual b
 UNION ALL
 SELECT f.event_date,coalesce(f.description_normalized,f.description_raw),public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)),
 CASE WHEN f.amount>0 THEN 'income' ELSE 'expense' END,abs(f.amount)
 FROM public.financial_events f CROSS JOIN params p
 WHERE f.user_id=p_user_id AND f.event_date BETWEEN date_trunc('month',p.as_of)::date AND p.as_of
 AND f.metadata->>'bank_confirmed'='true' AND NOT f.is_projection AND NOT f.is_suppressed
 AND NOT EXISTS (SELECT 1 FROM history_raw h WHERE h.event_date=f.event_date AND h.series_key=public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)) AND h.amount=abs(f.amount))
 AND NOT EXISTS (SELECT 1 FROM bank_actual b WHERE b.event_date=f.event_date AND b.series_key=public.lts_forecast_series_key_v1(coalesce(f.description_normalized,f.description_raw)) AND b.amount=abs(f.amount))
), future_raw AS MATERIALIZED (
 SELECT f.event_date,f.description,f.source,f.source_ref,f.confidence,public.lts_forecast_series_key_v1(f.description) series_key,
 CASE WHEN f.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(f.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_corrected_cashflow_operational_v1(p_user_id,date_trunc('month',p.as_of)::date,p.horizon_end) f
 WHERE f.signed_amount<>0 AND f.account IN ('Itaú','Bradesco','C6')
), future AS MATERIALIZED (
 SELECT f.* FROM future_raw f CROSS JOIN params p WHERE f.event_date>=p.as_of
), unconfirmed_obligations AS MATERIALIZED (
 SELECT f.* FROM future_raw f CROSS JOIN params p
 WHERE f.event_date<p.as_of
 AND f.confidence IN('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
), fixed_specs AS (
 SELECT * FROM (VALUES
 ('salary','Salário','income','monthly'),
 ('salary_advance','Adiantamento quinzenal','income','monthly'),
 ('card_itau','Fatura Itaú Mastercard','expense','monthly'),
 ('card_aeternum','Fatura Visa Aeternum','expense','monthly'),
 ('card_c6','Fatura C6','expense','monthly'),
 ('vehicle_tax','IPVA, DPVAT e licenciamento','expense','annual'),
 ('seguro volvo xc40','Seguro Volvo XC40','expense','monthly')
 ) s(series_key,title,direction,cadence)
), observed_specs AS (
 SELECT DISTINCT public.lts_forecast_series_key_v1(x->>'description') series_key,x->>'description' title,x->>'direction' direction,
 CASE WHEN public.lts_forecast_series_key_v1(x->>'description')='property_tax_cipo' THEN 'annual' WHEN x->>'recurrence_pattern'='annual_or_seasonal' AND NOT EXISTS (
  SELECT 1 FROM future f WHERE f.series_key=public.lts_forecast_series_key_v1(x->>'description') GROUP BY f.series_key HAVING count(DISTINCT date_trunc('month',event_date))>=6
 ) THEN 'annual' ELSE 'monthly' END cadence
 FROM base CROSS JOIN LATERAL jsonb_array_elements(base.j->'items') x
 WHERE x->>'review_kind' IN ('covered','planning_review') AND NOT EXISTS(
  SELECT 1 FROM fixed_specs s WHERE s.series_key=public.lts_forecast_series_key_v1(x->>'description'))
), specs AS (SELECT series_key,min(title) title,direction,min(cadence) cadence FROM (SELECT * FROM fixed_specs UNION SELECT * FROM observed_specs) z GROUP BY series_key,direction),
periods AS (
 SELECT s.*,g::date period_start,
 least((g+CASE WHEN s.cadence='monthly' THEN interval '1 month' ELSE interval '1 year' END-interval '1 day')::date,p.horizon_end) period_end,p.as_of,p.horizon_end
 FROM specs s CROSS JOIN params p CROSS JOIN LATERAL generate_series(
 CASE WHEN s.cadence='monthly' THEN date_trunc('month',p.as_of) ELSE date_trunc('year',p.as_of)+interval '1 year' END,
 p.horizon_end,CASE WHEN s.cadence='monthly' THEN interval '1 month' ELSE interval '1 year' END) g
), coverage AS (
 SELECT p.*,
 (SELECT count(*) FROM future f WHERE f.series_key=p.series_key AND f.direction=p.direction AND f.event_date BETWEEN p.period_start AND p.period_end)::int future_count,
 (SELECT count(*) FROM history h WHERE h.series_key=p.series_key AND h.direction=p.direction AND h.event_date BETWEEN p.period_start AND least(p.period_end,p.as_of))::int actual_count,
 (SELECT count(*) FROM unconfirmed_obligations u WHERE u.series_key=p.series_key AND u.direction=p.direction
 AND u.event_date BETWEEN p.period_start AND least(p.period_end,p.as_of))::int unconfirmed_count,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('date',u.event_date,'description',u.description,
 'amount',u.amount,'source',u.source,'source_ref',u.source_ref,'confidence',u.confidence)
 ORDER BY u.event_date,u.source,u.source_ref),'[]'::jsonb)
 FROM unconfirmed_obligations u WHERE u.series_key=p.series_key AND u.direction=p.direction
 AND u.event_date BETWEEN p.period_start AND least(p.period_end,p.as_of)) unconfirmed_evidence
 FROM periods p
), history_periods AS (
 SELECT s.series_key,s.direction,
 CASE WHEN s.cadence='monthly' THEN date_trunc('month',h.event_date) ELSE date_trunc('year',h.event_date) END bucket,sum(h.amount) amount
 FROM specs s JOIN history h USING(series_key,direction) GROUP BY 1,2,3
), checks AS (
 SELECT c.series_key,c.title,c.direction,c.cadence,
 coalesce(jsonb_agg(to_char(c.period_start,'YYYY-MM') ORDER BY c.period_start) FILTER(WHERE c.cadence='monthly' AND c.future_count+c.actual_count=0 AND c.unconfirmed_count=0),'[]'::jsonb) missing_months,
 coalesce(jsonb_agg(DISTINCT extract(year FROM c.period_start)::int ORDER BY extract(year FROM c.period_start)::int) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count=0),'[]'::jsonb) missing_years,
 jsonb_agg(jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' ELSE 'review' END) ORDER BY c.period_start) period_coverage,
 count(*) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count=0)::int gaps,
 count(*) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count>0)::int pending_evidence_periods,
 coalesce(jsonb_agg(to_char(c.period_start,'YYYY-MM') ORDER BY c.period_start)
 FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count>0),'[]'::jsonb) pending_evidence_months,
 (SELECT max(f.event_date) FROM future f WHERE f.series_key=c.series_key AND f.direction=c.direction) last_future_date,
 (SELECT max(h.event_date) FROM history h WHERE h.series_key=c.series_key AND h.direction=c.direction) historical_last_date,
 (SELECT round(percentile_cont(.5) WITHIN GROUP(ORDER BY h.amount)::numeric,2) FROM history_periods h WHERE h.series_key=c.series_key AND h.direction=c.direction) median_amount
 FROM coverage c GROUP BY c.series_key,c.title,c.direction,c.cadence
), items AS (
 SELECT jsonb_build_object('key',c.series_key,'description_key',c.series_key,'title',c.title,'description',c.title,'direction',c.direction,
 'cadence',c.cadence,'recurrence_pattern',CASE WHEN c.cadence='annual' THEN 'annual_or_seasonal' ELSE 'frequent_monthly' END,
 'status',CASE WHEN c.gaps>0 THEN 'review_future_gap' WHEN c.pending_evidence_periods>0 THEN 'awaiting_payment_evidence' ELSE 'covered_to_horizon' END,
 'review_kind',CASE WHEN c.gaps>0 THEN 'planning_review' WHEN c.pending_evidence_periods>0 THEN 'reconciliation_review' ELSE 'covered' END,
 'missing_months',c.missing_months,'missing_years',c.missing_years,'period_coverage',c.period_coverage,'gap_count',c.gaps,'awaiting_payment_evidence_count',c.pending_evidence_periods,'awaiting_payment_evidence_months',c.pending_evidence_months,
 'last_future_date',c.last_future_date,'historical_last_date',c.historical_last_date,'observed_median_amount_brl',c.median_amount,
 'suggestion_basis','Histórico observado; valor apenas para referência, sem lançamento automático.',
 'coverage_basis','Ocorrências na mesma série e direção, verificadas em cada período; pagamentos postados contam no mês atual; previsões vencidas sem comprovação não contam como realizadas.',
 'review_reason',CASE WHEN c.pending_evidence_periods>0 THEN 'Existe obrigação já registrada no mês atual sem comprovação de pagamento. Ela não é uma projeção ausente; as lacunas futuras ficam listadas separadamente.'
 WHEN c.series_key='seguro volvo xc40' THEN 'As parcelas da apólice cobrem apenas os meses registrados. Confirme a renovação, a vigência e a forma de pagamento após esse período.'
 WHEN c.series_key IN ('salary','salary_advance') THEN 'Confirme a continuidade do recebimento nos meses sem projeção. Salário líquido e adiantamento são verificados separadamente; a auditoria não soma nem altera seus valores.'
 ELSE 'Confirme se o compromisso continua, terminou ou foi substituído; depois informe frequência, valor e vigência para os períodos sem cobertura.' END) item,c.gaps
 FROM checks c
)
SELECT base.j||jsonb_build_object('version','calendar-forecast-coverage-v266','as_of',p.as_of,'future_horizon_end',p.horizon_end,
 'horizon_checks',(SELECT coalesce(jsonb_agg(item ORDER BY gaps DESC,item->>'title'),'[]'::jsonb) FROM items),
 'horizon_review_count',(SELECT count(*) FROM items WHERE gaps>0),
 'horizon_reconciliation_count',(SELECT count(*) FROM checks WHERE pending_evidence_periods>0),
 'horizon_contract','Cada mês ou ano é verificado individualmente no horizonte escolhido. Valores históricos são referências; nada é criado automaticamente. Término, substituição e renovação exigem revisão explícita.')
FROM base CROSS JOIN params p;
$function$;

DO $access$ BEGIN
 IF has_function_privilege('anon','public.lts_recurring_future_gap_audit_v6(uuid,date,date)','EXECUTE')
 OR has_function_privilege('authenticated','public.lts_recurring_future_gap_audit_v6(uuid,date,date)','EXECUTE')
 THEN RAISE EXCEPTION 'private audit helper exposed'; END IF;
END; $access$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
