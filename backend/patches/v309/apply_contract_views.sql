-- V309: current contract schedules from dated sources and existing verified payments.
DO $guard$ DECLARE r record;p record; BEGIN
IF md5(pg_get_functiondef('public.lts_realized_bank_sources_v238(uuid)'::regprocedure)) <> '02696060487b81ddf0592be23a2e044f' THEN RAISE EXCEPTION 'V309 realized-source dependency changed';END IF;
FOR r IN SELECT * FROM(VALUES ('public.lts_commitments_summary_v1(uuid,date)','c9597e9581f23c0c04c0d503ca1db3c3','e96b7351f2e6f02de361c0eb52b862aa'),('public.lts_documentary_commitments_v1(uuid)','f322c2cf4c7832114612930067ff2ad5','51fc166932d08509bf6e241344d26051'),('public.lts_browser_wealth_detail_v242()','d52c3bd1ec5d5c788e6bc6f0cceeee21','769a6cf3621b8dfb422acf23384827d4')) v(signature,before_md5,after_md5) LOOP
IF md5(pg_get_functiondef(to_regprocedure(r.signature))) IS NULL OR md5(pg_get_functiondef(to_regprocedure(r.signature))) NOT IN(r.before_md5,r.after_md5) THEN RAISE EXCEPTION 'V309 target lease changed: %',r.signature;END IF;END LOOP;
FOR r IN SELECT * FROM(VALUES ('public.lts_commitment_read_state_v309(uuid,date)','bc7a7785fc30b06c8cdb2993da420688'),('public.lts_commitment_summary_overlay_v309(uuid,date,jsonb)','0070bd9c57042c02742e2149888bb880'),('public.lts_commitment_documentary_overlay_v309(uuid,date,jsonb)','c565a73692736b15a2fb59acf34002cb')) v(signature,source_md5) LOOP
SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure(r.signature);IF FOUND AND (md5(p.prosrc)<>r.source_md5 OR p.prosecdef OR p.proowner<>current_user::regrole::oid OR p.provolatile<>'s' OR p.proconfig IS DISTINCT FROM ARRAY['search_path=""']::text[] OR has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')) THEN RAISE EXCEPTION 'V309 helper lease changed: %',r.signature;END IF;END LOOP;END $guard$;
-- Derived contract state. Never changes a source, forecast, payment or debt stock.
CREATE OR REPLACE FUNCTION public.lts_commitment_read_state_v309(p_user_id uuid,p_as_of date)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH schedules AS MATERIALIZED (
 SELECT s.id::text source_ref,'documentary_schedule'::text origin,s.commitment_id,
 s.installment_number,s.due_date,s.amount_total,s.principal,s.interest,s.balance_after,
 s.status original_status,s.paid_date source_paid_date,s.paid_amount source_paid_amount,
 s.metadata->>'contract_ref' contract_ref
 FROM public.lts_commitment_documentary_schedule s
 WHERE s.user_id=p_user_id AND s.status IN('scheduled','paid')
 UNION ALL
 SELECT f.id::text,'financial_event','volvo',
 CASE WHEN f.metadata->>'installment_number' ~ '^[0-9]+$' THEN (f.metadata->>'installment_number')::integer END,
 CASE WHEN pg_catalog.pg_input_is_valid(f.metadata->>'documentary_schedule_due_date','date') THEN (f.metadata->>'documentary_schedule_due_date')::date ELSE f.event_date END,
 CASE WHEN f.metadata->>'documentary_schedule_amount' ~ '^[0-9]+([.][0-9]+)?$' THEN (f.metadata->>'documentary_schedule_amount')::numeric ELSE abs(f.amount) END,
 NULL::numeric,NULL::numeric,NULL::numeric,'scheduled',NULL::date,NULL::numeric,f.metadata->>'contract_ref'
 FROM public.financial_events f WHERE f.user_id=p_user_id
 AND f.metadata->>'contract_ref'='volvo_financing_2026' AND NOT f.is_suppressed
 AND f.nature='expense' AND NOT f.is_internal_transfer AND f.status NOT IN('cancelled','canceled')
 UNION ALL
 SELECT 'evento_base:'||e.idx::text,'legacy_projection','pai_mae',NULL::integer,
 (e.dados->>'dia')::date,abs((e.dados->>'valor')::numeric),NULL::numeric,NULL::numeric,NULL::numeric,
 'scheduled',NULL::date,NULL::numeric,NULL::text
 FROM public.evento_base e WHERE e.usuario_id=p_user_id
 AND lower(e.dados->>'desc')=lower('Pagamento Empréstimo Pai/Mãe')
), bank_sources AS MATERIALIZED (
 SELECT * FROM public.lts_realized_bank_sources_v238(p_user_id)
 WHERE event_date<=p_as_of AND signed_amount<0
), candidates AS MATERIALIZED (
 SELECT s.source_ref,s.origin,b.financial_event_id,b.event_date paid_date,-b.signed_amount paid_amount
 FROM schedules s JOIN public.financial_events f ON f.user_id=p_user_id
 JOIN bank_sources b ON b.financial_event_id=f.id
 WHERE f.status='confirmed' AND f.nature='expense' AND NOT f.is_internal_transfer
 AND f.metadata->>'contract_ref'=s.contract_ref
 AND ((s.origin='financial_event' AND s.source_ref=f.id::text)
 OR (s.origin='documentary_schedule'
  AND f.metadata->>'installment_number'=s.installment_number::text
  AND f.metadata->>'documentary_schedule_due_date'=s.due_date::text
  AND CASE WHEN f.metadata->>'documentary_schedule_amount' ~ '^[0-9]+([.][0-9]+)?$'
   THEN (f.metadata->>'documentary_schedule_amount')::numeric END=s.amount_total))
), unique_bank_claims AS (
 SELECT financial_event_id FROM candidates GROUP BY financial_event_id HAVING count(*)=1
), unique_proofs AS (
 SELECT source_ref,origin,min(paid_date) paid_date,min(paid_amount) paid_amount
 FROM candidates WHERE financial_event_id IN(SELECT financial_event_id FROM unique_bank_claims)
 GROUP BY source_ref,origin HAVING count(*)=1
), effective AS MATERIALIZED (
 SELECT s.*,coalesce(b.paid_date,CASE WHEN s.original_status='paid'
  AND s.source_paid_date<=p_as_of AND s.source_paid_amount>0 THEN s.source_paid_date END) paid_date,
 coalesce(b.paid_amount,CASE WHEN s.original_status='paid'
  AND s.source_paid_date<=p_as_of AND s.source_paid_amount>0 THEN s.source_paid_amount END) paid_amount,
 CASE WHEN b.paid_date IS NOT NULL THEN 'validated_existing_bank_identity'
  WHEN s.original_status='paid' AND s.source_paid_date<=p_as_of AND s.source_paid_amount>0
  THEN 'documentary_paid_fact' ELSE NULL END payment_basis
 FROM schedules s LEFT JOIN unique_proofs b USING(source_ref,origin)
), grouped AS (
 SELECT commitment_id,jsonb_build_object(
  'schedule_as_of',p_as_of,'loaded_count',count(*),
  'first_installment',min(installment_number),'last_installment',max(installment_number),
  'distinct_installments',count(DISTINCT installment_number),
  'future_count',count(*) FILTER(WHERE paid_date IS NULL AND due_date>=p_as_of),
  'future_total',coalesce(sum(amount_total) FILTER(WHERE paid_date IS NULL AND due_date>=p_as_of),0),
  'next_due',min(due_date) FILTER(WHERE paid_date IS NULL AND due_date>=p_as_of),
  'next_amount',(array_agg(amount_total ORDER BY due_date,source_ref)
   FILTER(WHERE paid_date IS NULL AND due_date>=p_as_of))[1],
  'last_due',max(due_date),'confirmed_loaded_paid_count',count(*) FILTER(WHERE paid_date IS NOT NULL),
  'confirmed_loaded_paid_total',coalesce(sum(paid_amount) FILTER(WHERE paid_date IS NOT NULL),0),
  'unconfirmed_past_count',count(*) FILTER(WHERE paid_date IS NULL AND due_date<p_as_of),
  'unconfirmed_past_total',coalesce(sum(amount_total) FILTER(WHERE paid_date IS NULL AND due_date<p_as_of),0),
  'rows',coalesce(jsonb_agg(jsonb_build_object('source_ref',source_ref,'installment_number',installment_number,
   'due_date',due_date,'amount',amount_total,'principal',principal,'interest',interest,'balance_after',balance_after,
   'status',CASE WHEN due_date<p_as_of THEN 'payment_unconfirmed' ELSE 'scheduled' END)
   ORDER BY due_date,source_ref) FILTER(WHERE paid_date IS NULL),'[]'::jsonb),
  'realized_rows',coalesce(jsonb_agg(jsonb_build_object('source_ref',source_ref,'installment_number',installment_number,
   'due_date',due_date,'scheduled_amount',amount_total,'paid_date',paid_date,'paid_amount',paid_amount,
   'status','paid','payment_basis',payment_basis) ORDER BY paid_date,source_ref)
   FILTER(WHERE paid_date IS NOT NULL),'[]'::jsonb)
 ) state FROM effective GROUP BY commitment_id
)
SELECT coalesce(jsonb_object_agg(commitment_id,state),'{}'::jsonb) FROM grouped;
$fn$;
REVOKE ALL ON FUNCTION public.lts_commitment_read_state_v309(uuid,date) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.lts_commitment_summary_overlay_v309(p_user_id uuid,p_as_of date,p_base jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH states AS MATERIALIZED(SELECT public.lts_commitment_read_state_v309(p_user_id,p_as_of) j),
positions AS MATERIALIZED(
 SELECT DISTINCT ON(commitment_id) commitment_id,to_jsonb(p) p
 FROM public.lts_debt_position p WHERE user_id=p_user_id AND as_of_date<=p_as_of
 ORDER BY commitment_id,as_of_date DESC,created_at DESC,id
), items AS (
 SELECT x.c,x.ordinality,s.j->(x.c->>'id') state,p.p doc_position
 FROM jsonb_array_elements(coalesce(p_base->'commitments','[]')) WITH ORDINALITY x(c,ordinality)
 CROSS JOIN states s LEFT JOIN positions p ON p.commitment_id=x.c->>'id'
), patched AS (
 SELECT ordinality,CASE WHEN c->>'id' IN('cipo_396','coopharma') THEN c||jsonb_build_object(
  'contract_ref',doc_position->'contract_ref','current_debt_as_of',doc_position->'as_of_date',
  'current_documentary_debt_balance',CASE WHEN c->>'id'='cipo_396' THEN doc_position->'debt_balance' ELSE NULL END,
  'remaining_events',CASE WHEN doc_position IS NOT NULL THEN state->'future_count' ELSE NULL END,
  'next_due',CASE WHEN doc_position IS NOT NULL THEN state->'next_due' ELSE NULL END,
  'next_amount',CASE WHEN doc_position IS NOT NULL THEN state->'next_amount' ELSE NULL END,
  'documentary_remaining_installments',doc_position#>'{metadata,remaining_installments}',
  'documentary_remaining_scheduled_outflow',doc_position#>'{metadata,remaining_schedule_current_terms}',
  'documentary_source_label',doc_position->'source_label',
  'final_due',CASE WHEN c->>'id'='cipo_396' THEN doc_position#>'{metadata,final_due}' ELSE c->'last_date' END,
  'unconfirmed_past_events',CASE WHEN doc_position IS NOT NULL THEN state->'unconfirmed_past_count' ELSE NULL END,
  'unconfirmed_past_amount',CASE WHEN doc_position IS NOT NULL THEN state->'unconfirmed_past_total' ELSE NULL END,
  'confirmed_loaded_paid_events',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_count' ELSE NULL END,
  'confirmed_loaded_paid_amount',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_total' ELSE NULL END,
  'confirmed_paid_installments',CASE WHEN doc_position IS NULL OR state IS NULL THEN NULL
   WHEN c->>'id'='coopharma' THEN state->'confirmed_loaded_paid_count'
   WHEN doc_position#>>'{metadata,installment_paid_through}' ~ '^[0-9]+$'
    AND (state->>'first_installment')::integer=(doc_position#>>'{metadata,installment_paid_through}')::integer+1
    AND (state->>'loaded_count')::integer=(state->>'distinct_installments')::integer
    AND (state->>'last_installment')::integer-(state->>'first_installment')::integer+1=(state->>'loaded_count')::integer
   THEN to_jsonb((doc_position#>>'{metadata,installment_paid_through}')::integer+(state->>'confirmed_loaded_paid_count')::integer)
   ELSE NULL END,
  'schedule_as_of',p_as_of,'schedule_coverage',CASE WHEN doc_position IS NULL THEN 'no_dated_position'
   WHEN state IS NULL THEN 'not_loaded' ELSE 'loaded_rows' END,
  'note',CASE WHEN c->>'id'='cipo_396' THEN 'Saldo documental com sua data de referência. Parcelas futuras seguem o cronograma recebido e estão sujeitas à TR; não são saldo para quitação.'
   ELSE c->>'note' END
 )||CASE WHEN c->>'id'='cipo_396' THEN jsonb_build_object('remaining_scheduled_outflow_current_terms',CASE WHEN doc_position IS NOT NULL THEN state->'future_total' ELSE NULL END)
 ELSE jsonb_build_object('remaining_economic_outflow',CASE WHEN doc_position IS NOT NULL THEN state->'future_total' ELSE NULL END,
 'total_paid',CASE WHEN doc_position IS NOT NULL THEN state->'confirmed_loaded_paid_total' ELSE NULL END) END
 WHEN c->>'id' IN('volvo','pai_mae') THEN c||jsonb_build_object(
  'remaining_events',state->'future_count','remaining_scheduled_outflow',state->'future_total',
  'next_due',state->'next_due','next_amount',state->'next_amount','schedule_as_of',p_as_of,
  'confirmed_paid_installments',state->'confirmed_loaded_paid_count',
  'schedule_rows',state->'rows','realized_rows',state->'realized_rows',
  'unconfirmed_past_events',state->'unconfirmed_past_count','unconfirmed_past_amount',state->'unconfirmed_past_total')
 ELSE c END c FROM items
)
SELECT p_base||jsonb_build_object('as_of',p_as_of,'commitments',coalesce((SELECT jsonb_agg(c ORDER BY ordinality) FROM patched),'[]'::jsonb),
 'schedule_revision','v309-dated-contract-state');
$fn$;
REVOKE ALL ON FUNCTION public.lts_commitment_summary_overlay_v309(uuid,date,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.lts_commitment_documentary_overlay_v309(p_user_id uuid,p_as_of date,p_base jsonb)
RETURNS jsonb LANGUAGE sql STABLE SET search_path='' AS $fn$
WITH states AS MATERIALIZED(SELECT public.lts_commitment_read_state_v309(p_user_id,p_as_of) j),
items AS (
 SELECT x.item,x.ordinality,s.j->(x.item->>'commitment_id') state
 FROM jsonb_array_elements(coalesce(p_base->'items','[]')) WITH ORDINALITY x(item,ordinality) CROSS JOIN states s
)
SELECT p_base||jsonb_build_object('items',coalesce((SELECT jsonb_agg(
 CASE WHEN state IS NULL THEN item ELSE item||jsonb_build_object('schedule_loaded',jsonb_build_object(
 'schedule_as_of',p_as_of,'remaining_loaded',coalesce((state->>'future_count')::integer,0)+coalesce((state->>'unconfirmed_past_count')::integer,0),
 'future_loaded_count',state->'future_count','future_loaded_total',state->'future_total',
 'next_date',state->'next_due','next_amount',state->'next_amount','last_loaded_date',state->'last_due',
 'unconfirmed_past_count',state->'unconfirmed_past_count','unconfirmed_past_total',state->'unconfirmed_past_total',
 'rows',state->'rows','realized_rows',state->'realized_rows')) END ORDER BY ordinality) FROM items),'[]'::jsonb),
 'schedule_revision','v309-dated-contract-state');
$fn$;
REVOKE ALL ON FUNCTION public.lts_commitment_documentary_overlay_v309(uuid,date,jsonb) FROM PUBLIC,anon,authenticated;

DO $patch$ DECLARE r record;d text;s text;n text;attrs jsonb;BEGIN
FOR r IN SELECT * FROM(VALUES ('public.lts_commitments_summary_v1(uuid,date)','c9597e9581f23c0c04c0d503ca1db3c3','e96b7351f2e6f02de361c0eb52b862aa','summary'),('public.lts_documentary_commitments_v1(uuid)','f322c2cf4c7832114612930067ff2ad5','51fc166932d08509bf6e241344d26051','documentary'),('public.lts_browser_wealth_detail_v242()','d52c3bd1ec5d5c788e6bc6f0cceeee21','769a6cf3621b8dfb422acf23384827d4','wealth')) v(signature,before_md5,after_md5,kind) LOOP
SELECT pg_get_functiondef(p.oid),p.prosrc,jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) INTO d,s,attrs FROM pg_proc p WHERE p.oid=to_regprocedure(r.signature);IF md5(d)=r.after_md5 THEN CONTINUE;END IF;
IF r.kind='summary' THEN n:=E'\n-- v309-dated-contract-state\nWITH v309_previous(payload) AS MATERIALIZED (\n'||rtrim(btrim(s,chr(32)||chr(10)||chr(13)||chr(9)),';')||E'\n)\nSELECT public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload) FROM v309_previous;\n';
ELSIF r.kind='documentary' THEN n:=E'\n-- v309-dated-contract-state\nWITH v309_previous(payload) AS MATERIALIZED (\n'||rtrim(btrim(s,chr(32)||chr(10)||chr(13)||chr(9)),';')||E'\n)\nSELECT public.lts_commitment_documentary_overlay_v309(p_user_id,(current_timestamp AT TIME ZONE ''America/Sao_Paulo'')::date,payload) FROM v309_previous;\n';
ELSE IF length(s)-length(replace(s,' RETURN public.lts_card_read_finish_v269(',''))<>length(' RETURN public.lts_card_read_finish_v269(') THEN RAISE EXCEPTION 'V309 wealth insertion point changed';END IF;n:=replace(s,' RETURN public.lts_card_read_finish_v269(',' -- v309-dated-contract-state: compatibility fields share the current canonical contract view.
 j:=jsonb_set(j,''{commitments}'',coalesce(j#>''{financing,summary}'',''null''::jsonb));
 j:=jsonb_set(j,''{documentary_commitments}'',coalesce(j#>''{financing,documentary}'',''null''::jsonb));
 j:=jsonb_set(j,''{cipo_detail,documentary_contractual_outflow_brl}'',coalesce((SELECT c->''documentary_remaining_scheduled_outflow'' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>''{financing,summary,commitments}'')=''array'' THEN j#>''{financing,summary,commitments}'' ELSE ''[]''::jsonb END) c WHERE c->>''id''=''cipo_396''),''null''::jsonb));
 j:=jsonb_set(j,''{cipo_detail,contractual_outflow_current_terms_brl}'',coalesce((SELECT c->''remaining_scheduled_outflow_current_terms'' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>''{financing,summary,commitments}'')=''array'' THEN j#>''{financing,summary,commitments}'' ELSE ''[]''::jsonb END) c WHERE c->>''id''=''cipo_396''),''null''::jsonb));
 j:=j||jsonb_build_object(''contract_schedule_revision'',''v309-dated-contract-state'');
'||' RETURN public.lts_card_read_finish_v269(');END IF;
IF position(s in d)=0 THEN RAISE EXCEPTION 'V309 source not found';END IF;EXECUTE replace(d,s,n);IF md5(pg_get_functiondef(to_regprocedure(r.signature)))<>r.after_md5 THEN RAISE EXCEPTION 'V309 output definition changed: %',r.signature;END IF;
IF attrs IS DISTINCT FROM(SELECT jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) FROM pg_proc p WHERE p.oid=to_regprocedure(r.signature)) THEN RAISE EXCEPTION 'V309 existing attributes changed';END IF;END LOOP;END $patch$;
