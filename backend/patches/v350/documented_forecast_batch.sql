-- Service-side input: owner, a bounded reading window, and a private manifest.
-- Reuse existing events/replacement rules. Preserve raw imports and actual cash.
DO $apply$
DECLARE u uuid:=current_setting('lts.v350_owner')::uuid;
 p jsonb:=current_setting('lts.v350_manifest')::jsonb;
 f date:=(p->>'window_from')::date;t date:=(p->>'window_to')::date;
 before_flow jsonb;after_flow jsonb;before_spend jsonb;after_spend jsonb;
 before_raw text;after_raw text;ev jsonb;rule jsonb;v jsonb;n integer;
 adds integer:=jsonb_array_length(p->'events');removes integer:=jsonb_array_length(p->'replacements');
 expected_delta numeric;actual_delta numeric;
BEGIN
 IF u IS NULL OR f IS NULL OR t IS NULL OR f>t OR t-f>400 OR adds=0 OR removes=0
 THEN RAISE EXCEPTION 'V350_INVALID_MANIFEST';END IF;
 IF(SELECT count(DISTINCT e->>'legacy_id')FROM jsonb_array_elements(p->'events')e)<>adds
 OR(SELECT count(DISTINCT r->>'id')FROM jsonb_array_elements(p->'rules')r)<>jsonb_array_length(p->'rules')
 THEN RAISE EXCEPTION 'V350_REPEATED_OPERATION';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p->'events')e JOIN public.financial_events fe ON fe.user_id=u AND fe.legacy_id=e->>'legacy_id')
 OR EXISTS(SELECT 1 FROM jsonb_array_elements(p->'rules')r JOIN public.lts_projection_replacement_rule live ON live.user_id=u AND live.id=r->>'id')
 THEN RAISE EXCEPTION 'V350_ALREADY_APPLIED_REVIEW_REQUIRED';END IF;
 FOR ev IN SELECT e FROM jsonb_array_elements(p->'events')e LOOP
  IF (ev->>'event_date')::date NOT BETWEEN f AND t OR(ev->>'amount')::numeric=0
  OR ev->>'status'NOT IN('scheduled','expected') OR ev->>'nature'NOT IN('expense','income')
  OR NOT EXISTS(SELECT 1 FROM public.accounts a WHERE a.user_id=u AND a.id=(ev->>'account_id')::uuid
   AND public.lts_v178_norm(a.institution)=public.lts_v178_norm(ev->>'bank'))
  OR EXISTS(SELECT 1 FROM public.financial_events e WHERE e.user_id=u AND e.account_id=(ev->>'account_id')::uuid
   AND e.event_date=(ev->>'event_date')::date AND e.amount=(ev->>'amount')::numeric AND NOT e.is_suppressed)
  THEN RAISE EXCEPTION 'V350_EVENT_ACCOUNT_OR_MEMBERSHIP_CHANGED';END IF;
  IF ev->>'kind'='documented_net_payroll' THEN
   IF ev->>'description_normalized'IS DISTINCT FROM 'Salário líquido' OR ev->>'nature'IS DISTINCT FROM 'income' OR(ev->>'amount')::numeric<=0
   OR ev->'metadata'->>'cash_basis'IS DISTINCT FROM 'documented_net_payroll' OR coalesce(ev->'metadata'->>'document_sha256','')!~'^[0-9a-f]{64}$'
   OR ev->'metadata'->>'source_file'IS NULL THEN RAISE EXCEPTION 'V350_INVALID_NET_PAYROLL_PROOF';END IF;
  ELSIF ev->>'kind'='documented_bank_schedule' THEN
   IF (SELECT count(*)FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.id=(ev->>'staging_id')::uuid
    AND s.resource_type='transaction' AND s.provider_deleted_at IS NULL
    AND s.normalized_payload->>'status'='PENDING' AND s.raw_payload->>'status'='PENDING'
    AND s.posting_date=(ev->>'event_date')::date AND s.signed_amount=(ev->>'amount')::numeric
    AND s.raw_hash=ev->>'staging_raw_hash' AND s.provider_account_ref=ev->>'provider_account_ref'
    AND s.description_raw=ev->>'description_raw'
    AND public.lts_v178_norm(s.institution_name)=public.lts_v178_norm(ev->>'bank'))<>1
   OR ev->'metadata'->>'bank_scheduled_received'<>'true'
   OR jsonb_array_length(ev->'metadata'->'schedule_evidence_files')=0
   THEN RAISE EXCEPTION 'V350_BANK_SCHEDULE_SOURCE_CHANGED';END IF;
  ELSE RAISE EXCEPTION 'V350_UNSUPPORTED_SOURCE';END IF;
 END LOOP;
 FOR rule IN SELECT r FROM jsonb_array_elements(p->'rules')r LOOP
  IF rule->>'action'NOT IN('replace_legacy','suppress_legacy')
  OR rule->>'date_from'IS DISTINCT FROM rule->>'date_to'
  OR(rule->>'date_from')::date NOT BETWEEN f AND t
  OR(SELECT count(*)FROM public.evento_base b WHERE b.usuario_id=u AND b.idx::text=rule->>'source_ref'
   AND b.dados=rule->'source_payload' AND b.dados->>'desc'=rule->>'description_exact'
   AND b.dados->>'conta'=rule->>'account_exact' AND b.dados->>'dia'=rule->>'date_from')<>1
  OR(SELECT count(*)FROM public.evento_base b WHERE b.usuario_id=u AND b.dados->>'desc'=rule->>'description_exact'
   AND b.dados->>'conta'=rule->>'account_exact' AND b.dados->>'dia'=rule->>'date_from')<>1
  THEN RAISE EXCEPTION 'V350_REPLACEMENT_SOURCE_CHANGED';END IF;
 END LOOP;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY event_date,source,source_ref)INTO before_flow FROM public.lts_corrected_cashflow_operational_v1(u,f,t)r;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO before_spend FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
 SELECT md5(jsonb_agg(jsonb_build_array(idx,dados)ORDER BY idx)::text)INTO before_raw FROM public.evento_base WHERE usuario_id=u;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p->'replacements')x WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(before_flow)r WHERE r=x))
 OR(SELECT count(*)FROM jsonb_array_elements(before_flow)r JOIN jsonb_array_elements(p->'replacements')x ON x=r)<>removes
 THEN RAISE EXCEPTION 'V350_EFFECTIVE_FLOW_SOURCE_CHANGED';END IF;
 INSERT INTO public.financial_events(user_id,account_id,legacy_id,event_date,description_raw,description_normalized,amount,nature,category,counterparty,source,status,is_internal_transfer,is_projection,is_suppressed,metadata)
 SELECT u,(e->>'account_id')::uuid,e->>'legacy_id',(e->>'event_date')::date,e->>'description_raw',e->>'description_normalized',(e->>'amount')::numeric,e->>'nature',e->>'category',e->>'counterparty',e->>'source',e->>'status',false,true,false,e->'metadata'
 FROM jsonb_array_elements(p->'events')e;
 GET DIAGNOSTICS n=ROW_COUNT;IF n<>adds THEN RAISE EXCEPTION 'V350_INSERT_COUNT_CHANGED';END IF;
 INSERT INTO public.lts_projection_replacement_rule(id,user_id,source_table,description_exact,account_exact,date_from,date_to,action,replacement_source,replacement_ref,reason,evidence,active)
 SELECT r->>'id',u,'evento_base',r->>'description_exact',r->>'account_exact',(r->>'date_from')::date,(r->>'date_to')::date,r->>'action',r->>'replacement_source',r->>'replacement_ref',r->>'reason',r->'evidence',true FROM jsonb_array_elements(p->'rules')r;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY event_date,source,source_ref)INTO after_flow FROM public.lts_corrected_cashflow_operational_v1(u,f,t)r;
 SELECT jsonb_agg(to_jsonb(r)ORDER BY row_key)INTO after_spend FROM public.lts_v229_expense_rows(u,date '2013-10-10',current_date)r;
 IF before_spend IS DISTINCT FROM after_spend THEN RAISE EXCEPTION 'V350_REALIZED_SPENDING_CHANGED';END IF;
 IF jsonb_array_length(after_flow)<>jsonb_array_length(before_flow)-removes+adds THEN RAISE EXCEPTION 'V350_FLOW_COUNT_CHANGED';END IF;
 IF EXISTS((SELECT r FROM jsonb_array_elements(before_flow)r WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'replacements')x WHERE x=r)
 EXCEPT ALL SELECT r FROM jsonb_array_elements(after_flow)r WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'events')x WHERE x->>'legacy_id'=r->>'source_ref'))
 UNION ALL(SELECT r FROM jsonb_array_elements(after_flow)r WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'events')x WHERE x->>'legacy_id'=r->>'source_ref')
 EXCEPT ALL SELECT r FROM jsonb_array_elements(before_flow)r WHERE NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p->'replacements')x WHERE x=r)))
 THEN RAISE EXCEPTION 'V350_UNRELATED_FLOW_ROWS_CHANGED';END IF;
 IF(SELECT count(*)FROM jsonb_array_elements(after_flow)r JOIN jsonb_array_elements(p->'events')x ON x->>'legacy_id'=r->>'source_ref'
 WHERE r->>'event_date'=x->>'event_date'AND(r->>'signed_amount')::numeric=(x->>'amount')::numeric
 AND r->>'account'=x->>'bank'AND r->>'description'=x->>'description_normalized')<>adds
 THEN RAISE EXCEPTION 'V350_NEW_FLOW_AMOUNT_OR_IDENTITY_CHANGED';END IF;
 SELECT sum((x->>'amount')::numeric)INTO expected_delta FROM jsonb_array_elements(p->'events')x;
 expected_delta:=expected_delta-(SELECT sum((x->>'signed_amount')::numeric)FROM jsonb_array_elements(p->'replacements')x);
 actual_delta:=(SELECT sum((x->>'signed_amount')::numeric)FROM jsonb_array_elements(after_flow)x)-(SELECT sum((x->>'signed_amount')::numeric)FROM jsonb_array_elements(before_flow)x);
 IF actual_delta<>expected_delta THEN RAISE EXCEPTION 'V350_FLOW_DELTA_CHANGED';END IF;
 SELECT md5(jsonb_agg(jsonb_build_array(idx,dados)ORDER BY idx)::text)INTO after_raw FROM public.evento_base WHERE usuario_id=u;
 IF before_raw IS DISTINCT FROM after_raw THEN RAISE EXCEPTION 'V350_RAW_SOURCE_CHANGED';END IF;
 PERFORM set_config('lts.v350_receipt',jsonb_build_object('pass',true,'new_events',adds,'replaced_occurrences',removes,'before_flow_count',jsonb_array_length(before_flow),'after_flow_count',jsonb_array_length(after_flow),'delta',expected_delta,'realized_spending_unchanged',true,'raw_source_unchanged',true,'other_flow_rows_unchanged',true)::text,true);
END $apply$;
