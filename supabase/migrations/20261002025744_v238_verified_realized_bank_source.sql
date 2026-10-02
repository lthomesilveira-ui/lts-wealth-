-- Adopt a verified existing loan event once its own bank debit is received.
CREATE TABLE public.lts_realized_bank_event_v238(
 user_id uuid NOT NULL REFERENCES auth.users(id),
 financial_event_id uuid NOT NULL REFERENCES public.financial_events(id),
 staging_id uuid NOT NULL REFERENCES public.lts_open_finance_staging(id),
 bank text NOT NULL CHECK(bank IN ('Itaú','Bradesco','C6')),
 expected_date date NOT NULL, expected_amount numeric NOT NULL,
 category text NOT NULL, beneficiary text, property_code text,
 management_group text NOT NULL, management_subgroup text NOT NULL, property_component text,
 evidence jsonb NOT NULL, verified_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,financial_event_id),UNIQUE(user_id,staging_id)
);
ALTER TABLE public.lts_realized_bank_event_v238 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.lts_realized_bank_event_v238 FROM PUBLIC,anon,authenticated;

CREATE FUNCTION public.lts_realized_bank_sources_v238(p_user_id uuid)
RETURNS TABLE(financial_event_id uuid,staging_id uuid,bank text,event_date date,signed_amount numeric,
 description text,legacy_id text,category text,beneficiary text,property_code text,management_group text,management_subgroup text,property_component text)
LANGUAGE sql STABLE SET search_path=''
AS $function$
SELECT f.id,s.id,r.bank,f.event_date,f.amount,f.description_raw,f.legacy_id,r.category,r.beneficiary,r.property_code,r.management_group,r.management_subgroup,r.property_component
FROM public.lts_realized_bank_event_v238 r
JOIN public.financial_events f ON f.id=r.financial_event_id AND f.user_id=r.user_id
JOIN public.lts_open_finance_staging s ON s.id=r.staging_id AND s.user_id=r.user_id
JOIN public.accounts a ON a.id=f.account_id AND a.user_id=f.user_id
WHERE r.user_id=p_user_id AND NOT f.is_projection AND NOT f.is_suppressed
AND f.event_date=r.expected_date AND f.amount=r.expected_amount
AND s.posting_date=f.event_date AND s.signed_amount=f.amount AND s.currency='BRL'
AND s.resource_type='transaction' AND s.provider_deleted_at IS NULL
AND s.normalized_payload->>'status'='POSTED' AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
AND a.institution=r.bank AND r.bank=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
AND f.metadata->>'contract_ref'=r.evidence->>'contract_ref'
AND s.description_raw LIKE '%'||(r.evidence->>'contract_ref')||'%'
$function$;
REVOKE ALL ON FUNCTION public.lts_realized_bank_sources_v238(uuid) FROM PUBLIC,anon,authenticated;

ALTER FUNCTION public.lts_v229_expense_rows(uuid,date,date) RENAME TO lts_v229_expense_rows_pre_v238;
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows_pre_v238(uuid,date,date) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.lts_v229_expense_rows(p_user_id uuid,p_from date,p_to date)
RETURNS TABLE(row_key text,event_date date,transaction_date date,competence_month date,amount numeric,category text,
 beneficiary text,description text,account_source text,source_table text,source_ref text,coverage_mode text,
 raw_category text,raw_reference text,purchase_date date,identity_status text,management_group text,
 management_subgroup text,property_code text,property_component text)
LANGUAGE sql STABLE SET search_path=''
AS $function$
WITH existing AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows_pre_v238(p_user_id,p_from,p_to))
SELECT * FROM existing
UNION ALL
SELECT 'financial_events:'||v.financial_event_id::text||':'||v.event_date::text||':'||v.category,
 v.event_date,v.event_date,date_trunc('month',v.event_date)::date,abs(v.signed_amount),v.category,v.beneficiary,
 v.description,v.bank,'financial_events',v.financial_event_id::text,'bank_posted_documentary_reconciled',
 f.category,f.description_raw,null::date,'identified',v.management_group,v.management_subgroup,v.property_code,v.property_component
FROM public.lts_realized_bank_sources_v238(p_user_id) v JOIN public.financial_events f ON f.id=v.financial_event_id
WHERE v.event_date BETWEEN p_from AND p_to AND v.signed_amount<0
AND NOT EXISTS(SELECT 1 FROM existing e WHERE
 (e.source_table='financial_events' AND e.source_ref IN(v.financial_event_id::text,v.legacy_id))
 OR (e.source_table='lts_open_finance_staging' AND e.source_ref=v.staging_id::text))
$function$;
REVOKE ALL ON FUNCTION public.lts_v229_expense_rows(uuid,date,date) FROM PUBLIC,anon,authenticated;

ALTER FUNCTION public.lts_browser_flow_v229(date,date) RENAME TO lts_browser_flow_pre_v238;
REVOKE ALL ON FUNCTION public.lts_browser_flow_pre_v238(date,date) FROM PUBLIC,anon,authenticated;
CREATE FUNCTION public.lts_browser_flow_v229(p_from date,p_to date)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path='' SET TimeZone='America/Sao_Paulo' SET statement_timeout='18s'
AS $function$
DECLARE u uuid:=public.lts_browser_assert_user_v1(); result jsonb; f jsonb; lo date:=p_from;
 v record; d jsonb; prev jsonb; ev jsonb; part text; all_events jsonb; newdays jsonb; c jsonb;
 old_net numeric; actual_net numeric; opening numeric; closing numeric; inc numeric; outflow numeric; prior numeric; gap numeric;
 recovered jsonb:='[]';
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to THEN RAISE EXCEPTION 'invalid range';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_realized_bank_sources_v238(u) s WHERE s.event_date=p_from AND s.event_date<current_date) THEN lo:=p_from-1;END IF;
 result:=public.lts_browser_flow_pre_v238(lo,p_to);f:=result->'flow';
 all_events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 FOR v IN SELECT * FROM public.lts_realized_bank_sources_v238(u) WHERE event_date BETWEEN p_from AND p_to AND event_date<current_date ORDER BY event_date,financial_event_id LOOP
  IF EXISTS(SELECT 1 FROM jsonb_array_elements(all_events) x WHERE x->>'source_ref' IN(v.staging_id::text,v.financial_event_id::text,v.legacy_id) OR x->>'open_finance_id'=v.staging_id::text) THEN CONTINUE;END IF;
  SELECT x INTO d FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date;
  SELECT x INTO prev FROM jsonb_array_elements(coalesce(f#>'{historical,days}','[]')) x WHERE (x->>'date')::date=v.event_date-1;
  IF d IS NULL OR prev IS NULL OR NOT coalesce((prev#>>ARRAY[v.bank,'balance_certified'])::boolean,false) THEN RAISE EXCEPTION 'verified posted debit requires its preceding documented position';END IF;
  old_net:=(d#>>ARRAY[v.bank,'net'])::numeric;prior:=(prev#>>ARRAY[v.bank,'balance'])::numeric;closing:=(d#>>ARRAY[v.bank,'balance'])::numeric;
  actual_net:=old_net+v.signed_amount;
  IF abs(prior+actual_net-closing)>.005 THEN RAISE EXCEPTION 'posted debit does not reconcile independent dated bank positions';END IF;
  d:=jsonb_set(d,ARRAY[v.bank],(d->v.bank)||jsonb_build_object('net',actual_net,'operational_net',actual_net,'opening_balance',prior,'reconciliation_gap',0,'movements_complete',true,'bank_posted_recovery',v.staging_id));
  opening:=coalesce((prev#>>'{Itaú,balance}')::numeric,0)+coalesce((prev#>>'{Bradesco,balance}')::numeric,0)+coalesce((prev#>>'{C6,balance}')::numeric,0);
  closing:=(d#>>'{Consolidado,bank_balance}')::numeric;
  inc:=coalesce((d#>>'{v170_cash_arithmetic,operating_entries_brl}')::numeric,(d#>>'{summary,entries}')::numeric,0)+greatest(v.signed_amount,0)+greatest(coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  outflow:=coalesce((d#>>'{v170_cash_arithmetic,operating_exits_brl}')::numeric,(d#>>'{summary,exits}')::numeric,0)-least(v.signed_amount,0)+greatest(-coalesce((d#>>'{v170_cash_arithmetic,internal_transfer_net_brl}')::numeric,0),0);
  gap:=closing-opening-inc+outflow;
  IF abs(gap)>.005 THEN RAISE EXCEPTION 'posted event does not reconcile consolidated cash';END IF;
  c:=d->'fix86_columns';c:=c||jsonb_build_object('saldo_anterior',opening,'saldo_anterior_operacional',opening,'entradas',inc,'saidas',outflow,'entradas_operacionais',inc,'saidas_operacionais',outflow);
  d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('net',inc-outflow,'economic_net',inc-outflow),
   'summary',(d->'summary')||jsonb_build_object('entries',inc,'exits',outflow,'net',inc-outflow,'events',coalesce((d#>>'{summary,events}')::int,0)+1,'Consolidado',jsonb_build_object('entries',inc,'exits',outflow)),
   'v170_cash_arithmetic',(d->'v170_cash_arithmetic')||jsonb_build_object('balanced',true,'arithmetic_gap_brl',gap,'operating_entries_brl',inc,'operating_exits_brl',outflow,'tracked_bank_net_brl',inc-outflow),
   'bank_posted_recovery',jsonb_build_object('source','existing_financial_event_and_bank_posting','financial_event_id',v.financial_event_id,'staging_id',v.staging_id));
  SELECT coalesce(jsonb_agg(CASE WHEN (x->>'date')::date=v.event_date THEN d ELSE x END ORDER BY x->>'date'),'[]') INTO newdays FROM jsonb_array_elements(f#>'{historical,days}') x;
  f:=jsonb_set(f,'{historical,days}',newdays);
  ev:=jsonb_build_object('source','open_finance','source_ref',v.staging_id,'open_finance_id',v.staging_id,'financial_event_id',v.financial_event_id,'event_date',v.event_date,
   'account',v.bank,'description',v.description,'signed_amount',v.signed_amount,'direction',CASE WHEN v.signed_amount<0 THEN 'saida' ELSE 'entrada' END,
   'confidence','bank_posted','bank_confirmed',true,'category',v.category,'center_cost',v.beneficiary,'property_code',v.property_code,'internal_transfer',false,'excluded',false);
  all_events:=all_events||jsonb_build_array(ev);
  f:=jsonb_set(f,'{historical,events}',coalesce(f#>'{historical,events}','[]')||jsonb_build_array(ev));
  recovered:=recovered||jsonb_build_array(jsonb_build_object('financial_event_id',v.financial_event_id,'staging_id',v.staging_id,'date',v.event_date,'bank',v.bank,'amount',v.signed_amount));
 END LOOP;
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  f:=jsonb_set(f,ARRAY[part,'days'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'date') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to),'[]'));
  f:=jsonb_set(f,ARRAY[part,'events'],coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref') FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'events'],'[]')) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to),'[]'));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'realized_bank_recovery',jsonb_build_object('version','v238','events',recovered,'guardrail','Existing bank-posted source identity and independent adjacent bank positions are required. No position or amount is fabricated.'));
 RETURN result||jsonb_build_object('flow',f,'reader_revision','v238-realized-source-and-immutable-bank-positions');
END
$function$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_v229(date,date) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_v229(date,date) TO authenticated;
