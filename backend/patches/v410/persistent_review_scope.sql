-- V410: preserve previously opened recurring reviews independently of aging signals.
-- Generic reader only. Owner-specific scope is seeded separately and privately.
-- No financial event, amount, payment, plan, source or namespace is written here.
SET LOCAL lock_timeout='5s';
DO $migration$
DECLARE target regprocedure:='public.lts_recurring_future_gap_audit_v6(uuid,date,date)'::regprocedure;
 before_definition text; before_attributes jsonb;
 next_definition text:=$v410_definition$CREATE OR REPLACE FUNCTION public.lts_recurring_future_gap_audit_v6(p_user_id uuid, p_as_of date DEFAULT CURRENT_DATE, p_horizon_end date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE
 -- v410-persistent-review-scope. This namespace records review scope only.
 scope_raw text; scope_hash text; scope_doc jsonb; entry jsonb; decision jsonb;
 scopes jsonb := '[]'::jsonb; seen text[] := ARRAY[]::text[]; identity text;
 evidence jsonb; opened_on date; effective_on date; decided_on date;
 last_revision integer; revision integer; invalid_decisions integer;
 disposition text; closed_on date; replacement_key text; replacement_title text;
 result jsonb; scope_item jsonb; notices jsonb; scoped jsonb;
 closed_reviews jsonb; deferred_reviews jsonb; field_name text; filtered jsonb;
 review_as_of date := coalesce(p_as_of,current_date);
BEGIN
 SELECT n.valor_bruto,n.sha256 INTO scope_raw,scope_hash
 FROM public.legacy_namespace n
 WHERE n.usuario_id=p_user_id AND n.chave='lts_recurring_review_scope_v410';
 IF FOUND THEN
  BEGIN
   IF scope_hash IS DISTINCT FROM encode(sha256(convert_to(scope_raw,'UTF8')),'hex') THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='scope digest mismatch';
   END IF;
   scope_doc:=scope_raw::jsonb;
   IF scope_doc->>'schema' IS DISTINCT FROM 'lts-recurring-review-scope-v1'
    OR jsonb_typeof(scope_doc->'entries') IS DISTINCT FROM 'array'
    OR jsonb_array_length(scope_doc->'entries')=0 THEN
    RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='invalid scope structure';
   END IF;
   FOR entry IN SELECT value FROM jsonb_array_elements(scope_doc->'entries') LOOP
    IF jsonb_typeof(entry) IS DISTINCT FROM 'object'
     OR nullif(trim(entry->>'control_id'),'') IS NULL
     OR nullif(trim(entry->>'title'),'') IS NULL
     OR nullif(trim(entry->>'key'),'') IS NULL
     OR entry->>'key' IS DISTINCT FROM public.lts_forecast_series_key_v1(entry->>'title')
     OR coalesce(entry->>'direction','') NOT IN('income','expense')
     OR coalesce(entry->>'cadence','') NOT IN('monthly','annual')
     OR coalesce(entry->>'opened_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
     RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='invalid review identity';
    END IF;
    opened_on:=(entry->>'opened_on')::date;
    identity:=(entry->>'direction')||':'||(entry->>'key');
    IF identity=ANY(seen) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='duplicate review identity'; END IF;
    seen:=array_append(seen,identity);
    evidence:=entry->'opening_evidence';
    IF evidence->>'kind' IS DISTINCT FROM 'existing_control_review'
     OR nullif(trim(evidence->>'reference'),'') IS NULL
     OR nullif(evidence->>'content','') IS NULL
     OR evidence->>'sha256' IS DISTINCT FROM encode(sha256(convert_to(evidence->>'content','UTF8')),'hex') THEN
     RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='review source unavailable';
    END IF;
    disposition:='open';closed_on:=NULL;replacement_key:=NULL;replacement_title:=NULL;
    invalid_decisions:=0;last_revision:=0;
    IF jsonb_typeof(entry->'decisions') IS DISTINCT FROM 'array' THEN
     invalid_decisions:=1;
    ELSE
     FOR decision IN SELECT value FROM jsonb_array_elements(entry->'decisions') LOOP
      BEGIN
       IF jsonb_typeof(decision) IS DISTINCT FROM 'object'
        OR coalesce(decision->>'revision','') !~ '^[1-9][0-9]{0,8}$' THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='invalid decision revision';
       END IF;
       revision:=(decision->>'revision')::integer;
       IF revision<=last_revision THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='unordered decision revision'; END IF;
       last_revision:=revision;
       evidence:=decision->'evidence';
       IF decision->>'scope' IS DISTINCT FROM 'whole_series_review'
        OR coalesce(decision->>'action','') NOT IN('open','end','replace')
        OR coalesce(decision->>'effective_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        OR coalesce(decision->>'decided_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
        OR evidence->>'kind' IS DISTINCT FROM 'explicit_owner_confirmation'
        OR evidence->>'owner_id' IS DISTINCT FROM p_user_id::text
        OR nullif(trim(evidence->>'reference'),'') IS NULL
        OR nullif(evidence->>'content','') IS NULL
        OR evidence->>'sha256' IS DISTINCT FROM encode(sha256(convert_to(evidence->>'content','UTF8')),'hex') THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='decision lacks explicit whole-series evidence';
       END IF;
       effective_on:=(decision->>'effective_on')::date;
       decided_on:=(decision->>'decided_on')::date;
       IF effective_on<opened_on OR decided_on<opened_on THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='decision predates tracked review';
       END IF;
       IF decision->>'action'='replace' AND (
        nullif(trim(decision->>'replacement_title'),'') IS NULL
        OR decision->>'replacement_key' IS DISTINCT FROM public.lts_forecast_series_key_v1(decision->>'replacement_title')
        OR decision->>'replacement_key'=entry->>'key'
        OR decision->>'replacement_direction' IS DISTINCT FROM entry->>'direction') THEN
        RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='replacement identity not proved';
       END IF;
       IF greatest(effective_on,decided_on)<=review_as_of THEN
        disposition:=decision->>'action';
        closed_on:=CASE WHEN disposition='open' THEN NULL ELSE effective_on END;
        replacement_key:=CASE WHEN disposition='replace' THEN decision->>'replacement_key' END;
        replacement_title:=CASE WHEN disposition='replace' THEN decision->>'replacement_title' END;
       END IF;
      EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range OR invalid_parameter_value THEN
       invalid_decisions:=invalid_decisions+1;
      END;
     END LOOP;
    END IF;
    IF opened_on<=review_as_of THEN
     scopes:=scopes||jsonb_build_array(jsonb_build_object('series_key',entry->>'key','title',entry->>'title',
      'direction',entry->>'direction','cadence',entry->>'cadence','closed_on',closed_on,'disposition',disposition,
      'replacement_key',replacement_key,'replacement_title',replacement_title,'invalid_decisions',invalid_decisions));
    END IF;
   END LOOP;
  EXCEPTION WHEN invalid_text_representation OR datetime_field_overflow OR numeric_value_out_of_range OR invalid_parameter_value THEN
   -- V407 already exposes RPC failures and retains its last successfully read list.
   -- Never publish a successful empty/partial review count for unreadable scope.
   RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='Não foi possível conferir as revisões pendentes. Atualize a consulta; as revisões anteriores continuam abertas.',
    DETAIL='Persisted recurring-review scope failed integrity or source validation.';
  END;
 END IF;
 result := (
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
), receipt_identities_v303 AS MATERIALIZED (
 SELECT r.* FROM params p CROSS JOIN LATERAL public.lts_recurring_receipt_identities_v303(p_user_id,p.as_of)r
), bank_actual AS MATERIALIZED (
 SELECT s.id,s.posting_date event_date,s.signed_amount,
 coalesce(receipt_v303.description,identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,/* v334-exact-received-merchant-alias */CASE
 WHEN public.lts_forecast_series_key_v1(s.description_raw)='debito automatico deb autor netflix.com'
 THEN 'netflix' END,s.description_raw) description,
 public.lts_forecast_series_key_v1(coalesce(receipt_v303.description,identity.description,
 CASE WHEN k.c->>'beneficiary' IN('Benjamin','Larissa','Rafiki') AND nullif(k.c->>'category','') IS NOT NULL
 THEN (k.c->>'beneficiary')||' - '||(k.c->>'category') END,/* v334-exact-received-merchant-alias */CASE
 WHEN public.lts_forecast_series_key_v1(s.description_raw)='debito automatico deb autor netflix.com'
 THEN 'netflix' END,s.description_raw)) series_key,
 CASE WHEN s.signed_amount>0 THEN 'income' ELSE 'expense' END direction,abs(s.signed_amount) amount
 FROM params p CROSS JOIN LATERAL public.lts_bank_posted_rows_v231(p_user_id) s
 LEFT JOIN receipt_identities_v303 receipt_v303 ON receipt_v303.staging_id=s.id
  AND receipt_v303.actual_date=s.posting_date AND receipt_v303.actual_amount=s.signed_amount
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
 AND NOT EXISTS(SELECT 1 FROM receipt_identities_v303 paid WHERE paid.projection_ref=f.source_ref
  AND paid.projection_date=f.event_date AND paid.series_key=f.series_key AND paid.direction=f.direction)
), owner_cancelled_v360 AS MATERIALIZED (
 SELECT DISTINCT r.id,r.replacement_ref source_ref,r.date_from event_date,
 public.lts_forecast_series_key_v1(r.description_exact) series_key,'expense'::text direction
 FROM public.lts_projection_replacement_rule r JOIN public.evento_base b
 ON b.usuario_id=r.user_id AND r.replacement_ref='evento_base:'||b.idx
 WHERE r.user_id=p_user_id AND r.active IS TRUE AND r.action='suppress_legacy'
 AND r.replacement_source='owner_confirmation' AND r.source_table='evento_base'
 AND r.evidence->>'scope'='one_original_occurrence' AND r.evidence->>'legacy_ref'=r.replacement_ref
 AND r.date_from=r.date_to AND b.dados->>'dia'=r.date_from::text
 AND b.dados->>'desc'=r.description_exact AND b.dados->>'conta'=r.account_exact
 AND b.dados->>'efeito'='saida'
 AND CASE WHEN coalesce(b.dados->>'valor','')~'^[0-9]+([.][0-9]+)?$' THEN (b.dados->>'valor')::numeric>0 ELSE false END
 AND (SELECT count(*) FROM public.evento_base other WHERE other.usuario_id=b.usuario_id AND other.idx=b.idx)=1
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
  SELECT 1 FROM (
   SELECT count(*) OVER (ORDER BY event_month RANGE BETWEEN CURRENT ROW AND interval '11 months' FOLLOWING) AS months_in_year
   FROM (SELECT DISTINCT date_trunc('month',f.event_date) AS event_month FROM future f
         WHERE f.series_key=public.lts_forecast_series_key_v1(x->>'description')) AS months
  ) AS density WHERE density.months_in_year>=6
 ) THEN 'annual' ELSE 'monthly' END cadence
 FROM base CROSS JOIN LATERAL jsonb_array_elements(base.j->'items') x
 WHERE x->>'review_kind' IN ('covered','planning_review') AND NOT EXISTS(
  SELECT 1 FROM fixed_specs s WHERE s.series_key=public.lts_forecast_series_key_v1(x->>'description'))
), native_specs AS (SELECT series_key,min(title) title,direction,min(cadence) cadence FROM (SELECT * FROM fixed_specs UNION SELECT * FROM observed_specs) z GROUP BY series_key,direction),
tracked_specs AS MATERIALIZED (
 SELECT * FROM jsonb_to_recordset(scopes) AS s(series_key text,title text,direction text,cadence text,
 closed_on date,disposition text,replacement_key text,replacement_title text,invalid_decisions integer)
), all_specs AS MATERIALIZED (
 SELECT * FROM native_specs
 UNION ALL
 SELECT s.series_key,s.title,s.direction,s.cadence FROM tracked_specs s
 WHERE NOT EXISTS(SELECT 1 FROM native_specs n WHERE n.series_key=s.series_key AND n.direction=s.direction)
), closure_checks AS MATERIALIZED (
 SELECT s.*,
  EXISTS(SELECT 1 FROM unconfirmed_obligations u WHERE u.series_key=s.series_key AND u.direction=s.direction
   AND u.event_date<s.closed_on) AS earlier_unconfirmed_obligation,
  s.disposition<>'replace' OR EXISTS(SELECT 1 FROM all_specs replacement
   WHERE replacement.series_key=s.replacement_key AND replacement.direction=s.direction
    AND NOT EXISTS(SELECT 1 FROM tracked_specs ended WHERE ended.series_key=replacement.series_key
      AND ended.direction=replacement.direction AND ended.closed_on IS NOT NULL)) AS replacement_available
 FROM tracked_specs s
), closed_reviews_v410 AS MATERIALIZED (
 SELECT c.series_key,c.direction FROM closure_checks c
 WHERE c.closed_on IS NOT NULL AND NOT c.earlier_unconfirmed_obligation AND c.replacement_available
), specs AS (
 SELECT n.* FROM all_specs n
 WHERE NOT EXISTS(SELECT 1 FROM closed_reviews_v410 c WHERE c.series_key=n.series_key AND c.direction=n.direction)
),
periods AS (
 SELECT s.*,g::date period_start,
 least((g+CASE WHEN s.cadence='monthly' THEN interval '1 month' ELSE interval '1 year' END-interval '1 day')::date,p.horizon_end) period_end,p.as_of,p.horizon_end
 FROM specs s CROSS JOIN params p CROSS JOIN LATERAL generate_series(
 CASE WHEN s.cadence='monthly' THEN date_trunc('month',p.as_of) ELSE date_trunc('year',p.as_of)+interval '1 year' END,
 p.horizon_end,CASE WHEN s.cadence='monthly' THEN interval '1 month' ELSE interval '1 year' END) g
), transition_periods_v371 AS MATERIALIZED (
 SELECT t.family,t.last_old_due,t.first_new_due,t.decision_source,t.confirmed_at,
 CASE t.family WHEN 'aeternum' THEN 'card_aeternum' WHEN 'itau_mastercard' THEN 'card_itau' WHEN 'c6' THEN 'card_c6' END series_key,
 g::date period_start
 FROM public.lts_card_due_transition_v370 t
 CROSS JOIN LATERAL generate_series(date_trunc('month',t.last_old_due)+interval '1 month',
 date_trunc('month',t.first_new_due)-interval '1 month',interval '1 month')g
 WHERE t.user_id=p_user_id
), coverage AS MATERIALIZED (
 SELECT p.*,
 (SELECT count(*) FROM transition_periods_v371 t WHERE p.cadence='monthly' AND p.direction='expense'
 AND t.series_key=p.series_key AND t.period_start=p.period_start)::int transition_count,
 (SELECT jsonb_build_object('family',t.family,'last_old_due',t.last_old_due,'first_new_due',t.first_new_due,
 'source',t.decision_source,'confirmed_at',t.confirmed_at,'reason','Mudança de vencimento confirmada; sem débito neste mês.')
 FROM transition_periods_v371 t WHERE p.cadence='monthly' AND p.direction='expense'
 AND t.series_key=p.series_key AND t.period_start=p.period_start LIMIT 1) transition_evidence,
 (SELECT count(*) FROM owner_cancelled_v360 x WHERE p.cadence='monthly' AND x.series_key=p.series_key AND x.direction=p.direction
 AND x.event_date BETWEEN p.period_start AND p.period_end)::int cancelled_count,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('date',x.event_date,'rule_id',x.id,'source_ref',x.source_ref,'status','cancelled_by_owner') ORDER BY x.event_date,x.id),'[]'::jsonb)
 FROM owner_cancelled_v360 x WHERE p.cadence='monthly' AND x.series_key=p.series_key AND x.direction=p.direction
 AND x.event_date BETWEEN p.period_start AND p.period_end) confirmed_exceptions,
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
 coalesce(jsonb_agg(to_char(c.period_start,'YYYY-MM') ORDER BY c.period_start) FILTER(WHERE c.cadence='monthly' AND c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0),'[]'::jsonb) missing_months,
 coalesce(jsonb_agg(DISTINCT extract(year FROM c.period_start)::int ORDER BY extract(year FROM c.period_start)::int) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0),'[]'::jsonb) missing_years,
 jsonb_agg((jsonb_build_object('period_start',c.period_start,'period_end',c.period_end,'actual_events',c.actual_count,'future_events',c.future_count,'unconfirmed_obligations',c.unconfirmed_count,'unconfirmed_evidence',c.unconfirmed_evidence,'status',CASE WHEN c.future_count+c.actual_count>0 THEN 'covered' WHEN c.unconfirmed_count>0 THEN 'awaiting_payment_evidence' WHEN c.cancelled_count>0 THEN 'cancelled_by_owner' WHEN c.transition_count>0 THEN 'no_payment_due' ELSE 'review' END)||CASE WHEN c.transition_count>0 AND c.future_count+c.actual_count+c.unconfirmed_count+c.cancelled_count=0 THEN jsonb_build_object('confirmed_transition',c.transition_evidence) ELSE '{}'::jsonb END||CASE WHEN c.cancelled_count>0 THEN jsonb_build_object('confirmed_exceptions',c.confirmed_exceptions) ELSE '{}'::jsonb END) ORDER BY c.period_start) period_coverage,
 count(*) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count=0 AND c.cancelled_count=0 AND c.transition_count=0)::int gaps,
 count(*) FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count>0)::int pending_evidence_periods,
 coalesce(jsonb_agg(to_char(c.period_start,'YYYY-MM') ORDER BY c.period_start)
 FILTER(WHERE c.future_count+c.actual_count=0 AND c.unconfirmed_count>0),'[]'::jsonb) pending_evidence_months,
 (SELECT coalesce(jsonb_agg(jsonb_build_object('date',x.event_date,'rule_id',x.id,'source_ref',x.source_ref,'status','cancelled_by_owner') ORDER BY x.event_date,x.id),'[]'::jsonb)
 FROM owner_cancelled_v360 x CROSS JOIN params p WHERE c.cadence='monthly' AND x.series_key=c.series_key AND x.direction=c.direction
 AND x.event_date BETWEEN date_trunc('month',p.as_of)::date AND p.horizon_end) owner_confirmed_exceptions,
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
 ELSE 'Confirme se o compromisso continua, terminou ou foi substituído; depois informe frequência, valor e vigência para os períodos sem cobertura.' END)||CASE WHEN jsonb_array_length(c.owner_confirmed_exceptions)>0 THEN jsonb_build_object('owner_confirmed_exceptions',c.owner_confirmed_exceptions,
 'review_reason','As ocorrências listadas como canceladas já foram confirmadas. Revise apenas os demais períodos sem cobertura; não crie novo pagamento para as ocorrências canceladas.') ELSE '{}'::jsonb END item,c.gaps
 FROM checks c
)
SELECT base.j||jsonb_build_object('_v410_closed',coalesce((SELECT jsonb_agg(to_jsonb(c)) FROM closed_reviews_v410 c),'[]'::jsonb),'_v410_deferred',coalesce((SELECT jsonb_agg(jsonb_build_object('series_key',c.series_key,'direction',c.direction,'earlier_unconfirmed_obligation',c.earlier_unconfirmed_obligation)) FROM closure_checks c WHERE c.closed_on IS NOT NULL AND (c.earlier_unconfirmed_obligation OR NOT c.replacement_available)),'[]'::jsonb))||jsonb_build_object('version','calendar-forecast-coverage-v266','receipt_identity_revision','v303-proved-bank-receipts','as_of',p.as_of,'future_horizon_end',p.horizon_end,
 'horizon_checks',(SELECT coalesce(jsonb_agg(item ORDER BY gaps DESC,item->>'title'),'[]'::jsonb) FROM items),
 'horizon_review_count',(SELECT count(*) FROM items WHERE gaps>0),
 'horizon_reconciliation_count',(SELECT count(*) FROM checks WHERE pending_evidence_periods>0),
 'horizon_contract','Cada mês ou ano é verificado individualmente no horizonte escolhido. Valores históricos são referências; nada é criado automaticamente. Término, substituição e renovação exigem revisão explícita.')
FROM base CROSS JOIN params p
 );
 closed_reviews:=result->'_v410_closed';deferred_reviews:=result->'_v410_deferred';
 result:=result-'_v410_closed'-'_v410_deferred';
 -- Legacy items also feed the published Actions fallback; a valid closure must
 -- suppress that same identity there, not just remove its horizon row.
 IF jsonb_array_length(closed_reviews)>0 THEN
  FOREACH field_name IN ARRAY ARRAY['items','planning_review_candidates','reconciliation_review_candidates',
   'monitor_only_candidates','covered','review_candidates'] LOOP
   IF jsonb_typeof(result->field_name)='array' THEN
    SELECT coalesce(jsonb_agg(x ORDER BY ord),'[]'::jsonb) INTO filtered
    FROM jsonb_array_elements(result->field_name) WITH ORDINALITY a(x,ord)
    WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(closed_reviews)c
     WHERE c->>'direction'=x->>'direction' AND c->>'series_key'=public.lts_forecast_series_key_v1(
      coalesce(x->>'description',x->>'title',x->>'key',x->>'description_key')));
    result:=jsonb_set(result,ARRAY[field_name],filtered);
   END IF;
  END LOOP;
  -- Only update legacy aggregate fields that the predecessor actually supplied.
  FOR field_name,filtered IN SELECT key,value FROM jsonb_each((
   SELECT jsonb_build_object('total_recurring_series',count(*),
    'income_series',count(*)FILTER(WHERE x->>'direction'='income'),
    'expense_series',count(*)FILTER(WHERE x->>'direction'='expense'),
    'review_series',count(*)FILTER(WHERE x->>'status'='review_future_gap'),
    'covered_series',count(*)FILTER(WHERE x->>'status'='covered'),
    'covered_count',count(*)FILTER(WHERE x->>'review_kind'='covered'),
    'planning_review_count',count(*)FILTER(WHERE x->>'review_kind'='planning_review'),
    'reconciliation_review_count',count(*)FILTER(WHERE x->>'review_kind'='reconciliation_review'),
    'monitor_only_count',count(*)FILTER(WHERE x->>'review_kind'='monitor_only'),
    'possible_rename_count',count(*)FILTER(WHERE x->>'coverage_match'='possible_rename'))
   FROM jsonb_array_elements(coalesce(result->'items','[]'::jsonb))x)) LOOP
   IF result?field_name THEN result:=jsonb_set(result,ARRAY[field_name],filtered); END IF;
  END LOOP;
 END IF;
 -- Preserve the original reason field; these additions are reader metadata.
 -- The V407 action summary does not currently display this field verbatim.
 -- With a valid open scope, every existing native scope_item is byte-for-byte equal.
 notices:='[]'::jsonb;
 FOR scope_item IN SELECT value FROM jsonb_array_elements(result->'horizon_checks') LOOP
  SELECT value INTO scoped FROM jsonb_array_elements(scopes)
   WHERE value->>'series_key'=scope_item->>'key' AND value->>'direction'=scope_item->>'direction';
  IF scoped IS NOT NULL AND scoped->>'closed_on' IS NOT NULL THEN
   scope_item:=scope_item||jsonb_build_object('review_reason',
    CASE WHEN EXISTS(SELECT 1 FROM jsonb_array_elements(deferred_reviews)d
      WHERE d->>'series_key'=scope_item->>'key' AND d->>'direction'=scope_item->>'direction'
       AND (d->>'earlier_unconfirmed_obligation')::boolean)
     THEN 'O encerramento foi registrado. Confira a obrigação anterior ainda sem comprovação para concluir esta revisão.'
     ELSE 'A substituição registrada ainda precisa de vínculo comprovado com a outra série. Esta revisão continua aberta.' END);
  ELSIF scoped IS NOT NULL AND (scoped->>'invalid_decisions')::integer>0 THEN
   scope_item:=scope_item||jsonb_build_object('review_reason','A decisão registrada precisa ser conferida com sua fonte. Esta revisão continua aberta.');
  END IF;
  notices:=notices||jsonb_build_array(scope_item);
 END LOOP;
 RETURN jsonb_set(result,'{horizon_checks}',notices);
END;
$function$
$v410_definition$;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc'-'prolang' INTO before_definition,before_attributes FROM pg_proc p WHERE p.oid=target;
 IF before_definition=next_definition THEN RETURN; END IF;
 IF md5(before_definition)<>'8b1e3201ebed90f75659a02c20c2bba9' THEN
  RAISE EXCEPTION 'V410: recurring audit predecessor changed';
 END IF;
 EXECUTE next_definition;
 IF pg_get_functiondef(target) IS DISTINCT FROM next_definition THEN
  RAISE EXCEPTION 'V410: unexpected deployed reader definition';
 END IF;
 IF before_attributes IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc'-'prolang' FROM pg_proc p WHERE p.oid=target) THEN
  RAISE EXCEPTION 'V410: reader attributes or privileges changed';
 END IF;
END $migration$;
