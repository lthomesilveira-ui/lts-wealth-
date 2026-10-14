BEGIN;
-- Draft compatibility layer; production installation must use the leased private atomic packet.
-- Presentation capability only. Authentication/ownership stays in existing browser assertions.
CREATE OR REPLACE FUNCTION public.lts_has_card_presentation_v269()
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path='' AS $function$
DECLARE headers jsonb; request_path text:=current_setting('request.path',true);
BEGIN
 BEGIN headers:=coalesce(nullif(current_setting('request.headers',true),''),'{}')::jsonb;
 EXCEPTION WHEN invalid_text_representation THEN RETURN false; END;
 RETURN coalesce(jsonb_typeof(headers)='object' AND headers->>'x-client-info'='lts-wealth-v269-c6-completeness'
 AND request_path=ANY(ARRAY['/rpc/lts_browser_flow_v242','/rpc/lts_browser_card_cycles_v226','/rpc/lts_browser_card_cycles_v229','/rpc/lts_browser_card_detail_v226','/rpc/lts_browser_product_v1']),false);
END $function$;
REVOKE ALL ON FUNCTION public.lts_has_card_presentation_v269() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_has_card_presentation_v269() TO service_role;

CREATE OR REPLACE FUNCTION public.lts_c6_completeness_state_v269(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $function$
DECLARE fingerprint text; epoch bigint; result jsonb; cycles jsonb;
BEGIN
 SELECT e.epoch INTO epoch FROM public.lts_read_cache_epoch_v242 e WHERE singleton=true;
 SELECT 'v269-c6-state:'||epoch||':'||md5(coalesce((SELECT string_agg(to_jsonb(s)::text,'' ORDER BY s.id)
 FROM public.lts_open_finance_staging s WHERE s.user_id=p_user_id AND s.institution_code='336'
 AND s.resource_type IN('credit_card','card_transaction','invoice')),'')||coalesce((SELECT string_agg(to_jsonb(i)::text,'' ORDER BY i.id)
 FROM public.card_invoices i WHERE i.user_id=p_user_id AND public.lts_card_family_v226(i.card_name,i.card_name)='c6'),'')||
 coalesce((SELECT string_agg(to_jsonb(d)::text,'' ORDER BY d.id) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=p_user_id AND d.family='c6'),'')) INTO fingerprint;
 SELECT payload INTO result FROM public.lts_v229_read_cache WHERE user_id=p_user_id AND kind='card_completeness_v269'
 AND as_of=current_date AND from_date=current_date AND to_date=current_date AND source_fingerprint=fingerprint;
 IF FOUND THEN RETURN result; END IF;
 cycles:=public.lts_card_cycles_v226(p_user_id);
 result:=jsonb_build_object('complete',coalesce((cycles->>'complete')::boolean,true),'incomplete_families',coalesce(cycles->'incomplete_families','[]'::jsonb),'source_revision',fingerprint,'source_epoch',epoch);
 IF NOT current_setting('transaction_read_only')::boolean THEN
  INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
  VALUES(p_user_id,'card_completeness_v269',current_date,current_date,current_date,result,clock_timestamp(),fingerprint)
  ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 END IF;
 RETURN result;
END $function$;
REVOKE ALL ON FUNCTION public.lts_c6_completeness_state_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_c6_completeness_state_v269(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_require_card_presentation_v269(p_user_id uuid,p_incomplete_supported boolean DEFAULT false)
RETURNS void LANGUAGE plpgsql SET search_path='' AS $function$
BEGIN
 -- Request path is assigned by PostgREST, not a client header. Nested readers inherit the prepared boundary.
 IF public.lts_has_card_presentation_v269() THEN RETURN; END IF;
 IF public.lts_c6_completeness_state_v269(p_user_id)->>'complete'='false' THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='O C6 está em conferência e esta projeção está incompleta. Abra a versão V269 para consultar as evidências e os demais bancos.';
 END IF;
END $function$;
REVOKE ALL ON FUNCTION public.lts_require_card_presentation_v269(uuid,boolean) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_require_card_presentation_v269(uuid,boolean) TO service_role;

-- Retain bootstrap metadata/source structures but never bootstrap stale forecast claims.
CREATE OR REPLACE FUNCTION public.lts_product_card_completeness_v269(p_payload jsonb,p_state jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' AS $function$
DECLARE m jsonb; c jsonb; card jsonb; planning jsonb; wealth jsonb; f jsonb;
BEGIN
 IF p_state->>'complete' IS DISTINCT FROM 'false' THEN RETURN p_payload; END IF;
 m:=p_payload->'mvp';
 planning:=jsonb_build_object('complete',false,'status','incomplete','layers','[]'::jsonb,'gap_episodes','[]'::jsonb,
 'summary',jsonb_build_object('fgts_covers_horizon',NULL,'first_real_gap_date',NULL,'first_negative_even_with_fgts',NULL),
 'fgts_access',jsonb_build_object('covers_horizon',NULL));
 c:=coalesce(m->'dashboard_cockpit','{}'::jsonb)||jsonb_build_object('complete',false,'planning_audited',planning->'summary','horizons','[]'::jsonb,
 'cards',jsonb_build_object('complete',false,'open_cycles_total',NULL,'closed_or_due_total',NULL,'next_due',NULL),
 'expenses',jsonb_build_object('complete',false,'current_month',jsonb_build_object('spend',NULL,'top_categories','[]'::jsonb)));
 card:=coalesce(m->'card_operating','{}'::jsonb)||jsonb_build_object('complete',false,'open_cycles_total',NULL,'open_cycles','[]'::jsonb,'next_due',NULL,
 'contracted_installment_floor_total',NULL,'contracted_installment_floor_months','[]'::jsonb);
 wealth:=coalesce(m->'wealth_executive','{}'::jsonb)||jsonb_build_object('complete',false,'summary',coalesce(m#>'{wealth_executive,summary}','{}'::jsonb)||
 jsonb_build_object('known_debt_total',NULL,'net_worth_central',NULL,'net_worth_low',NULL,'net_worth_high',NULL,'known_debt_to_assets_pct',NULL));
 f:=m->'flow';
 IF f ? 'current_future' THEN
  f:=public.lts_flow_card_completeness_v269(jsonb_build_object('flow',f),p_state)->'flow';
 ELSIF f ? 'days' THEN
  f:=public.lts_flow_card_completeness_v269(jsonb_build_object('flow',jsonb_build_object('current_future',f)),p_state)#>'{flow,current_future}';
 END IF;
 m:=m||jsonb_build_object('complete',false,'incomplete_families',p_state->'incomplete_families','dashboard_cockpit',c,
 'planning_ladder',planning,'planning_executive',planning,'wealth_executive',wealth,'card_operating',card,'flow',f);
 RETURN p_payload||jsonb_build_object('complete',false,'incomplete_families',p_state->'incomplete_families','mvp',m);
END $function$;
REVOKE ALL ON FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_product_card_completeness_v269(jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_read_start_v269(p_user_id uuid)
RETURNS text LANGUAGE plpgsql SET search_path='' AS $function$
DECLARE s jsonb;
BEGIN
 s:=public.lts_c6_completeness_state_v269(p_user_id);
 PERFORM public.lts_require_card_presentation_v269(p_user_id);
 RETURN s->>'source_revision';
END $function$;
REVOKE ALL ON FUNCTION public.lts_card_read_start_v269(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_read_start_v269(uuid) TO service_role;
CREATE OR REPLACE FUNCTION public.lts_card_read_finish_v269(p_user_id uuid,p_revision text,p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $function$
DECLARE s jsonb;
BEGIN
 s:=public.lts_c6_completeness_state_v269(p_user_id);
 IF s->>'source_revision' IS DISTINCT FROM p_revision THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='Os dados foram atualizados durante a leitura. Atualize a tela.'; END IF;
 PERFORM public.lts_require_card_presentation_v269(p_user_id);
 IF public.lts_has_card_presentation_v269() THEN RETURN p_payload||jsonb_build_object('source_revision',p_revision,'source_complete',(s->>'complete')::boolean,'source_epoch',(s->>'source_epoch')::bigint); END IF;
 RETURN p_payload;
END $function$;
REVOKE ALL ON FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_card_read_finish_v269(uuid,text,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v226()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1()); RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_card_cycles_v226(u)); end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_cycles_v229()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; cards jsonb;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_card_cycles_v226();
 WITH source_dates AS MATERIALIZED (
 SELECT public.lts_card_family_v226(s.normalized_payload->>'name',s.institution_name) family,
 max(coalesce(nullif(s.normalized_payload->>'as_of',''),nullif(s.normalized_payload->>'provider_updated_at',''),nullif(s.raw_payload->>'updatedAt',''))::timestamptz) source_updated_at,
 max(s.last_seen_at) received_at
 FROM public.lts_open_finance_staging s WHERE s.user_id=u AND s.resource_type='credit_card' AND s.provider_deleted_at IS NULL GROUP BY 1
 ) SELECT jsonb_agg(c||jsonb_build_object('source_updated_at',sd.source_updated_at,'received_at',sd.received_at,'source_time_basis','provider_resource_update')||jsonb_build_object('document_source_as_of',doc.as_of,'document_source_file',doc.source_file,'documented_supplement_items',doc.n)||CASE WHEN hint.amount IS NOT NULL AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(c->'cycles','[]'::jsonb)) q
 WHERE q->>'month'=((date_trunc('month',current_date)+interval '1 month')::date)::text) THEN jsonb_build_object(
 'cycles',coalesce(c->'cycles','[]'::jsonb)||jsonb_build_array(jsonb_build_object('month',(date_trunc('month',current_date)+interval '1 month')::date,'due_date',
 CASE WHEN c->>'last_due' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
 make_date(extract(year FROM current_date+interval '1 month')::int,extract(month FROM current_date+interval '1 month')::int,
 least(extract(day FROM (c->>'last_due')::date)::int,extract(day FROM date_trunc('month',current_date)+interval '2 months -1 day')::int)) END,
 'due_date_basis','estimate_from_received_due_day',
 'amount',hint.amount,'basis','user_confirmed_recurring_estimate','items',hint.items))) ELSE '{}'::jsonb END ORDER BY ord) INTO cards
 FROM jsonb_array_elements(j->'cards') WITH ORDINALITY src(c,ord)
 LEFT JOIN source_dates sd ON sd.family=c->>'family'
 LEFT JOIN LATERAL(SELECT max(d.source_as_of) as_of,min(d.source_file_ref) source_file,count(*) n
 FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.family=c->>'family'
 AND d.reference_month=date_trunc('month',current_date)::date) doc ON true
 LEFT JOIN LATERAL(SELECT sum(h.amount) amount,jsonb_agg(jsonb_build_object('description',h.description,'amount',h.amount,'last4',c->>'last4','category',h.category,'category_basis','user_confirmed_recurring_estimate')) items
 FROM public.lts_v229_card_recurring_commitment h WHERE h.user_id=u AND h.active AND h.family=c->>'family') hint ON true;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j||jsonb_build_object('cards',cards,'recurring_estimates_separate',true));
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb; official record; matched boolean; cycle_state jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 if p_family not in ('aeternum','bradesco_prime','itau_mastercard','itau_visa','c6') or p_month is null then raise exception 'invalid card cycle'; end if;
 with r as materialized(select * from public.lts_card_source_rows_v226(u) where family=p_family and reference_month=date_trunc('month',p_month)::date and not is_payment),
 b as(select s.* from public.lts_open_finance_staging s where s.user_id=u and s.resource_type='invoice' and s.provider_deleted_at is null
 and public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name)=p_family
 and date_trunc('month',s.posting_date)::date=date_trunc('month',p_month)::date),
 d as(select reported_invoice_total,due_date,source_as_of from public.lts_card_document_supplement_v234 where user_id=u and family=p_family and reference_month=date_trunc('month',p_month)::date order by source_as_of desc,created_at desc limit 1),
 t as(select count(*) n,coalesce(sum(amount),0) amount,count(*) filter(where category_basis='unresolved') pending from r)
 select jsonb_build_object('version','card-detail-v226','family',p_family,'month',date_trunc('month',p_month)::date,
 'amount',(select amount from t),'item_count',(select n from t),'unclassified',(select pending from t),
 'invoice_amount',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d)),'due_date',coalesce((select posting_date from b limit 1),(select due_date from d),(select min(due_date) from r)),
 'difference',coalesce((select signed_amount from b limit 1),(select reported_invoice_total from d))-(select amount from t),
 'basis',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'bank_document_composition' else null end,
 'source_note',case when exists(select 1 from r where provider_status='DOCUMENTED') then 'Composição do banco complementada pelas parcelas comprovadas na fatura parcial.' else null end,
 'items',coalesce((select jsonb_agg(to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of,'amount',d.amount)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND (d.id=r.source_id OR d.id=(SELECT m.document_id FROM public.lts_card_document_matches_v234(u) m WHERE m.provider_id=r.source_id))),'{}'::jsonb) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
 'financial_effect','none') into result;
 if (result->>'item_count')::int=0 or abs(coalesce((result->>'difference')::numeric,0))>=0.005 then
  select w into alternative from jsonb_array_elements(public.lts_card_workbook_cycles_v226(u)||public.lts_card_document_cycles_v226(u))w
  where w->>'family'=p_family and (w->>'reference_month')::date=date_trunc('month',p_month)::date
  and (result->>'invoice_amount' is null or (w->>'amount')::numeric=(result->>'invoice_amount')::numeric)
  and (result->>'invoice_amount' is null or abs((w->>'difference')::numeric)<abs((result->>'difference')::numeric))
  order by abs((w->>'difference')::numeric),case when w->>'source'='document_reconciled' then 0 else 1 end limit 1;
  if alternative is not null then
   result:=result||alternative||jsonb_build_object('version','card-detail-v226','invoice_amount',(alternative->>'amount')::numeric,
    'due_date',coalesce(result->>'due_date',alternative->>'due_date'),'amount',(alternative->>'detail_total')::numeric,
    'alternative_items',result->'items','alternative_note','Itens também recebidos do banco para esta mesma fatura. São outra fonte de consulta, não despesas adicionais; não somar novamente.',
    'source_note',case when alternative->>'source'='document_reconciled' then 'Composição do documento importado, conferida com o total desta fatura.'
     else 'Composição da planilha por categoria, valor e mês de referência. Estabelecimento e dia da compra não estão informados nessa fonte. A diferença, quando houver, permanece explícita.' end);
  end if;
 end if;
 result:=result||jsonb_build_object(
  'unclassified',(select count(*) from jsonb_array_elements(result->'items')x where x->>'category_basis'='unresolved'),
  'categories',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'category' category,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'category')q),
  'instruments',(select coalesce(jsonb_agg(to_jsonb(q)),'[]'::jsonb) from (select x->>'last4' last4,count(*) n,sum((x->>'amount')::numeric) amount from jsonb_array_elements(result->'items')x group by x->>'last4')q)
 );

 SELECT ci.amount,ci.due_date,sd.id source_document_id,sd.sha256,sd.storage_path,sd.metadata,
  coalesce((sd.metadata->>'closing_date')::date,(ci.metadata->>'bank_statement_closing_date')::date) closing_date
 INTO official
 FROM public.card_invoices ci JOIN public.source_documents sd
  ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
 WHERE ci.user_id=u AND public.lts_card_family_v226(ci.card_name,sd.institution)=p_family
  AND ci.reference_month=date_trunc('month',p_month)::date AND ci.status='closed'
  AND ci.metadata->>'bank_statement_closed'='true'
  AND ci.metadata->>'bank_statement_full_composition'='true'
  AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
  AND sd.sha256=ci.metadata->>'bank_statement_sha256'
  AND sd.metadata->>'all_source_lines_matched'='true'
  AND (sd.metadata->>'statement_amount')::numeric=ci.amount
  AND (sd.metadata->>'due_date')::date=ci.due_date
 ORDER BY ci.created_at DESC LIMIT 1;
 IF FOUND THEN
  SELECT count(*)=(official.metadata->>'nonpayment_detail_lines')::int
   AND NOT EXISTS (
    SELECT 1 FROM jsonb_array_elements(official.metadata->'existing_source_items') e
    WHERE NOT coalesce((e->>'is_payment')::boolean,false)
     AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(result->'items') i
      WHERE i->>'source_id'=e->>'source_id'
       AND (i->>'amount')::numeric=(e->>'amount')::numeric
       AND i->>'last4' IS NOT DISTINCT FROM e->>'last4'
       AND i->>'purchase_date' IS NOT DISTINCT FROM e->>'purchase_date'
       AND i->>'installment_number' IS NOT DISTINCT FROM e->>'installment_number'
       AND i->>'total_installments' IS NOT DISTINCT FROM e->>'total_installments'))
  INTO matched FROM jsonb_array_elements(result->'items');
  result:=result||jsonb_build_object(
   'invoice_amount',official.amount,'due_date',official.due_date,
   'difference',official.amount-(result->>'amount')::numeric,
   'basis','bank_document_composition',
   'source_note',CASE WHEN matched AND official.amount=(result->>'amount')::numeric
    THEN 'Fatura oficial fechada em '||to_char(official.closing_date,'DD/MM/YYYY')||'; itens conferidos com o documento e diferença zero.'
    ELSE 'Fatura oficial recebida; a correspondência dos itens ou a diferença requer revisão.' END,
   'document_items_matched',matched,
   'invoice_document',jsonb_build_object('source_document_id',official.source_document_id,
    'file_ref',coalesce(official.metadata->>'library_file_id',official.storage_path),
    'sha256',official.sha256,'pages',official.metadata->'pages',
    'closing_date',official.closing_date,'document_date',official.metadata->'document_date'),
   'financial_effect','none');
 END IF;

 IF p_family='c6' AND date_trunc('month',p_month)::date>=date_trunc('month',current_date)::date THEN
  SELECT ca INTO cycle_state FROM jsonb_array_elements(public.lts_card_cycles_v226(u)->'cards') ca WHERE ca->>'family'='c6' LIMIT 1;
  IF cycle_state->>'complete'='false' THEN
   result:=result||jsonb_build_object('complete',false,'amount',NULL,'detail_total',NULL,'difference',NULL,
    'invoice_composition_complete',false,'detail_complete',false,'categories','[]'::jsonb,'instruments','[]'::jsonb,
    'unresolved_items',cycle_state->'unresolved_items','ambiguous_document_candidates',cycle_state->'ambiguous_document_candidates',
    'source_note','Evidências ainda não conciliadas. Não somar possíveis correspondências duplicadas como despesas.');
  END IF;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_flow_schedule_v1(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text;
  v_uid uuid := public.lts_browser_assert_user_v1();
  v_flow jsonb;
  v_events jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  if p_from is null or p_to is null or p_from>p_to then
    raise exception 'invalid card flow range';
  end if;
  v_flow := case when p_from>=current_date and p_to+30<=current_date+1800
    then public.lts_flow_future_read_slice_v9(v_uid,p_from,p_to)
    else public.lts_daily_flow_fix86_v12(v_uid,p_from,p_to) end;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'event_date',x->>'event_date',
      'account',x->>'account',
      'description',x->>'description',
      'card_name',coalesce(x->>'counterparty',x->>'description'),
      'amount',abs((x->>'signed_amount')::numeric),
      'source',x->>'source',
      'source_ref',x->>'source_ref',
      'confidence',x->>'confidence'
    )
    order by x->>'event_date',x->>'description'
  ),'[]'::jsonb)
  into v_events
  from jsonb_array_elements(coalesce(v_flow->'events','[]'::jsonb)) x
  where (x->>'signed_amount')::numeric<0
    and (
      coalesce(x->>'category','') in ('Cartões','Cartão de Crédito')
      or coalesce(x->>'description','') ~* '(Aeternum|Mastercard|Personnalit|Cart[aã]o C6|C6 Carbon|Visa Infinite)'
    );

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,jsonb_build_object(
    'version','card-flow-schedule-v1',
    'from',p_from,
    'to',p_to,
    'events',v_events
  ));
end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_card_flow_schedule_v2(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text;
  v_base jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 v_base:=public.lts_browser_card_flow_schedule_v1(p_from,p_to);
  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,v_base||jsonb_build_object(
    'version','card-flow-schedule-v2-v175',
    'inventory',public.lts_browser_card_inventory_v1(),
    'reading_contract',jsonb_build_object(
      'observed_invoice_precedence',true,
      'installment_floor_is_not_flow',true,
      'historical_inactive_cards_in_inventory',true
    )
  ));
end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_dashboard_cockpit_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE v269_revision text;
  u uuid;
  c record;
  pc timestamptz;
  j jsonb;
  w jsonb;
  v_had_cache boolean:=false;
  v_refreshed boolean:=false;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  u:=public.lts_browser_assert_user_v1();

  perform public.lts_apply_current_liquidity_anchor_v1(u);

  select refreshed_at,payload->'wealth_executive'
  into pc,w
  from public.lts_product_read_cache
  where user_id=u;

  select * into c
  from public.lts_dashboard_cockpit_cache
  where user_id=u;
  v_had_cache:=found;

  if not v_had_cache
     or c.as_of<>current_date
     or c.source_product_refreshed_at is distinct from pc then
    j:=public.lts_refresh_dashboard_cockpit_v1(u);
    v_refreshed:=true;
  else
    j:=c.payload;
  end if;

  -- Prefer the already-reconciled canonical product cache. Only recompute the
  -- expensive wealth report when the cache is absent or predates the current
  -- effective-position reconciliation contract.
  if w is null
     or coalesce(w->>'reconciliation_version','')<>'wealth-summary-current-effective-v240' then
    w:=public.lts_wealth_executive_report_v5(u);
  end if;

  j:=jsonb_set(
    j,
    '{wealth}',
    coalesce(j->'wealth','{}'::jsonb) || jsonb_build_object(
      'net_worth_central',w#>'{summary,net_worth_central}',
      'known_debt_total',w#>'{summary,known_debt_total}',
      'assets_central',w#>'{summary,assets_central}',
      'distribution',coalesce(w->'distribution','[]'::jsonb),
      'reconciliation_version',w->'reconciliation_version'
    ),
    true
  );

  j:=jsonb_set(j,'{work,top_actions}',public.lts_dashboard_cockpit_top_actions_v1(u),true);

  if nullif(j#>>'{planning_audited,first_negative_date}','') is null
     and nullif(j#>>'{planning_audited,first_uncovered_gap_date}','') is not null then
    j:=jsonb_set(
      j,
      '{planning_audited,first_negative_date}',
      j#>'{planning_audited,first_uncovered_gap_date}',
      true
    );
  end if;

  -- Avoid an unnecessary write on every browser read. A refreshed cockpit is
  -- already persisted by the refresh routine; otherwise persist only a real
  -- overlay change (for example a newly available reconciliation field).
  if not v_refreshed and v_had_cache and c.payload is distinct from j then
    update public.lts_dashboard_cockpit_cache
    set payload=j
    where user_id=u;
  end if;

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j);
end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_expenses_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); result jsonb; source_epoch bigint;fingerprint text;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid expense range';END IF;
 SELECT epoch INTO source_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 fingerprint:='expenses-v251:'||source_epoch||':'||current_date::text;
 SELECT c.payload INTO result FROM public.lts_v229_read_cache c WHERE c.user_id=u AND c.kind='expenses_v251'
 AND c.as_of=current_date AND c.from_date=p_from AND c.to_date=p_to AND c.source_fingerprint=fingerprint
 AND c.refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);END IF;
 result:=public.lts_browser_expenses_v229_engine_v251(p_from,p_to);
 IF source_epoch IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
   VALUES(u,'expenses_v251',current_date,p_from,p_to,result,clock_timestamp(),fingerprint)
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v241(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; epoch_before bigint; k text;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range';END IF;
 SELECT epoch INTO epoch_before FROM public.lts_read_cache_epoch_v242 WHERE singleton;
 k:='flow-v241-exact-v254:'||epoch_before||':'||public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO j FROM public.lts_v229_read_cache
 WHERE user_id=u AND kind='flow_v241_exact_v254' AND as_of=current_date
 AND from_date=p_from AND to_date=p_to AND source_fingerprint=k
 AND refreshed_at>clock_timestamp()-interval '30 minutes';
 IF FOUND THEN RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_flow_card_completeness_v269(j,public.lts_c6_completeness_state_v269(u)));END IF;
 j:=public.lts_flow_v241_engine_v254(p_from,p_to);
 IF epoch_before IS DISTINCT FROM (SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton) THEN
  RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read';
 END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
  BEGIN
   INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,source_fingerprint,refreshed_at)
   VALUES(u,'flow_v241_exact_v254',current_date,p_from,p_to,j,k,clock_timestamp())
   ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET
    payload=excluded.payload,source_fingerprint=excluded.source_fingerprint,refreshed_at=excluded.refreshed_at;
  EXCEPTION WHEN read_only_sql_transaction THEN NULL;
  END;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_flow_card_completeness_v269(j,public.lts_c6_completeness_state_v269(u)));
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v242(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
 SET jit TO 'off'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); cached jsonb; j jsonb; f jsonb; cache_epoch bigint; freshness_key text;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT epoch INTO cache_epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true;
 freshness_key:=public.lts_flow_bank_freshness_key_v246(u);
 SELECT payload INTO cached FROM public.lts_v229_read_cache WHERE user_id=u AND kind='flow_v242' AND as_of=current_date
 AND from_date<=p_from AND to_date>=p_to AND source_fingerprint='v246.1:'||cache_epoch||':'||freshness_key AND refreshed_at>clock_timestamp()-interval '30 minutes'
 ORDER BY to_date-from_date,refreshed_at DESC LIMIT 1;
 IF FOUND THEN RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_flow_card_completeness_v269(public.lts_flow_slice_v242(cached,p_from,p_to),public.lts_card_cycles_v226(u))); END IF;
 -- Keep the original bank and historical arithmetic, including unknown positions.
 j:=public.lts_browser_flow_v241(least(p_from,current_date),p_to);
 f:=public.lts_flow_liquidity_adjustments_v242(u,j->'flow',current_date);
 j:=j||jsonb_build_object('flow',f,'reader_revision','v245-dated-resources-and-movement-identity');
 j:=public.lts_flow_slice_v242(j,p_from,p_to);
 IF cache_epoch<>(SELECT epoch FROM public.lts_read_cache_epoch_v242 WHERE singleton=true) THEN RAISE EXCEPTION USING ERRCODE='40001',MESSAGE='source changed during read'; END IF;
 IF NOT current_setting('transaction_read_only')::boolean THEN
 BEGIN
 INSERT INTO public.lts_v229_read_cache(user_id,kind,as_of,from_date,to_date,payload,refreshed_at,source_fingerprint)
 VALUES(u,'flow_v242',current_date,p_from,p_to,j,clock_timestamp(),'v246.1:'||cache_epoch||':'||freshness_key)
 ON CONFLICT(user_id,kind,as_of,from_date,to_date) DO UPDATE SET payload=excluded.payload,refreshed_at=excluded.refreshed_at,source_fingerprint=excluded.source_fingerprint;
 EXCEPTION WHEN read_only_sql_transaction THEN NULL;
 END;
 END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_flow_card_completeness_v269(j,public.lts_card_cycles_v226(u)));
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v3(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text;
  uid uuid; j jsonb; f jsonb; hd jsonb:='[]'::jsonb; x jsonb; d date;
  bank numeric; d0 numeric; rsu numeric; fgts numeric; c jsonb; d01 numeric; total numeric; total_fgts numeric;
  lb_d0 text; lb_rsu text; lb_fgts text;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  uid:=public.lts_browser_assert_user_v1();
  j:=public.lts_browser_flow_v1(p_from,p_to);
  f:=j->'flow';
  for x in select value from jsonb_array_elements(coalesce(f#>'{historical,days}','[]'::jsonb)) order by value->>'date' loop
    d:=(x->>'date')::date;
    if d>=date '2026-07-07' and nullif(x#>>'{Consolidado,bank_balance}','') is not null then
      select h.d0_resource,h.rsu_vested,h.d0_basis,h.rsu_basis into d0,rsu,lb_d0,lb_rsu
      from public.lts_historical_liquidity_layers_v1(uid,d,d) h limit 1;
      select h.fgts_value,h.fgts_basis into fgts,lb_fgts from public.lts_historical_fgts_layer_v1(uid,d,d) h limit 1;
      bank:=(x#>>'{Consolidado,bank_balance}')::numeric;
      d01:=case when d0 is null then null else bank+d0 end;
      total:=case when d01 is null then null else d01+coalesce(rsu,0) end;
      total_fgts:=case when total is null then null else total+coalesce(fgts,0) end;
      c:=coalesce(x->'fix86_columns','{}'::jsonb) || jsonb_build_object(
        'liq_d0_1_recurso',d0,
        'liq_d0_1',d01,
        'saldo_apos_d0_1',d01,
        'rsus_vested',rsu,
        'saldo_apos_rsu',total,
        'disponivel_total',total,
        'posicao_curto_prazo',total,
        'fgts',fgts,
        'saldo_apos_fgts',total_fgts,
        'historical_d0_basis',lb_d0,
        'historical_rsu_basis',lb_rsu,
        'historical_fgts_basis',lb_fgts,
        'basis','historical_cash_ladder_reconstructed_from_legacy_and_documentary_evidence'
      );
      x:=jsonb_set(x,'{fix86_columns}',c,true);
    end if;
    hd:=hd||jsonb_build_array(x);
  end loop;
  f:=jsonb_set(f,'{historical,days}',hd,true);
  f:=f||jsonb_build_object('liquidity_history_contract',jsonb_build_object(
    'version','historical-liquidity-layers-v1',
    'from','2026-07-07',
    'd0','legacy official liquidity anchor + recorded redemptions + documentary Cofrinho snapshots',
    'rsu','legacy official vested-RSU adjustment + documentary vested snapshot',
    'no_current_value_backfill',true
  ));
  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,jsonb_set(j,'{flow}',f,true));
end
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_v4(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; uid uuid; v_email text:=lower(coalesce(auth.jwt()->>'email','')); cf jsonb; flow jsonb;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 uid:=public.lts_browser_assert_user_v1();
 if p_from is null or p_to is null or p_from>p_to then raise exception 'invalid range'; end if;
 if p_from<current_date then RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_browser_flow_v3(p_from,p_to)); end if;
 cf:=public.lts_flow_future_read_slice_v3(uid,p_from,p_to);
 flow:=jsonb_build_object('from',p_from,'to',p_to,'calculation_context_from',current_date,'historical',jsonb_build_object('days','[]'::jsonb,'events','[]'::jsonb),'current_future',cf,'version','daily-flow-full-query-v8-flow-v14-future-read-cache','liquidity_history_contract',jsonb_build_object('d0_rsu_from','2026-07-07','fgts_recent_from','2026-07-21','period_queries_same_financial_layers_as_initial_view',true,'current_day_documentary_facts',true,'semantic_context_pairs',true,'future_fast_path',true,'future_read_cache',true,'documentary_d0_same_day',true));
 insert into public.lts_access_audit(user_id,email,action,meta) values(uid,v_email,'browser_rpc_flow_read',jsonb_build_object('rpc_version',8,'from',p_from,'to',p_to,'future_read_cache',true,'flow_engine','v14','future_events',jsonb_array_length(coalesce(cf->'events','[]'::jsonb))));
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,jsonb_build_object('ok',true,'flow',flow));
end $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_monthly_v229(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); b jsonb; groups jsonb; computed numeric; month_amounts jsonb; coverage jsonb;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_from<date '2013-10-10' OR p_to>current_date THEN RAISE EXCEPTION 'invalid monthly range';END IF;
 b:=public.lts_browser_monthly_balance_v6(p_from,p_to);
 WITH r AS MATERIALIZED(SELECT * FROM public.lts_v229_expense_rows(u,p_from,p_to)),
 months AS(SELECT (m#>>'{}')::date month_key FROM jsonb_array_elements(b->'months') m),
 a AS(SELECT management_group label,competence_month month_key,sum(amount) amount,count(*) source_rows FROM r WHERE coverage_mode<>'card_invoice_aggregate_fallback' GROUP BY 1,2),
 labels AS(SELECT label,sum(amount) total,sum(source_rows) source_rows FROM a GROUP BY label),
 monthly AS(SELECT competence_month month_key,sum(amount) amount FROM r GROUP BY 1),
 unknown AS(SELECT competence_month month_key,sum(amount) amount FROM r WHERE coverage_mode='card_invoice_aggregate_fallback' GROUP BY 1)
 SELECT coalesce(jsonb_agg(jsonb_build_object('label',l.label,'total',round(l.total,2),'source_rows',l.source_rows,
 'monthly',(SELECT jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(a.amount,0)) ORDER BY m.month_key)
 FROM months m LEFT JOIN a ON a.month_key=m.month_key AND a.label=l.label)) ORDER BY l.total DESC,l.label),'[]'),
 (SELECT round(coalesce(sum(amount),0),2) FROM r),
 (SELECT coalesce(jsonb_agg(to_jsonb(monthly)),'[]') FROM monthly),
 jsonb_build_object('total',(SELECT coalesce(sum(amount),0) FROM unknown),
 'monthly',(SELECT coalesce(jsonb_agg(jsonb_build_object('month',m.month_key,'amount',coalesce(x.amount,0)) ORDER BY m.month_key),'[]')
 FROM months m LEFT JOIN unknown x ON x.month_key=m.month_key))
 INTO groups,computed,month_amounts,coverage FROM labels l;
 b:=b||jsonb_build_object('monthly_totals',coalesce((SELECT jsonb_agg(m||jsonb_build_object(
 'expenses',coalesce((a->>'amount')::numeric,0),
 'operating_balance',(m->>'revenue')::numeric-coalesce((a->>'amount')::numeric,0),
 'cash_after_extraordinary',(m->>'revenue')::numeric+coalesce((m->>'extraordinary')::numeric,0)-coalesce((a->>'amount')::numeric,0)) ORDER BY m->>'month')
 FROM jsonb_array_elements(b->'monthly_totals') m LEFT JOIN jsonb_array_elements(month_amounts) a ON a->>'month_key'=m->>'month'),'[]'),
 'totals',(b->'totals')||jsonb_build_object('expenses',computed,
 'operating_balance',(b#>>'{totals,revenue}')::numeric-computed,
 'cash_after_extraordinary',(b#>>'{totals,revenue}')::numeric+coalesce((b#>>'{totals,extraordinary}')::numeric,0)-computed),
 'expense_unclassified_card_coverage',coverage);
 IF abs(computed-coalesce((SELECT sum((m->>'expenses')::numeric) FROM jsonb_array_elements(b->'monthly_totals') m),0))>.005
 OR abs(computed-coalesce((SELECT sum((g->>'total')::numeric) FROM jsonb_array_elements(groups)g),0)-(coverage->>'total')::numeric)>.005
 THEN RAISE EXCEPTION 'monthly classified rows, months and total do not reconcile';END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,b||jsonb_build_object('version','monthly-v178-person-integrity','expense_groups',groups,'expense_total_verified',computed));
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_planning_executive_v1(p_from date DEFAULT CURRENT_DATE, p_to date DEFAULT (CURRENT_DATE + 365))
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1();
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1()); RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_planning_executive_v2(u,coalesce(p_from,current_date),least(coalesce(p_to,date '2027-12-31'),date '2027-12-31'))); end $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_planning_executive_v2()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1();
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1()); RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_planning_executive_v2(u,current_date,make_date(extract(year from current_date)::int+1,12,31))); end $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE v269_revision text; j jsonb; d01 text; rsu text; fg text;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_planning_executive_v2();
 if j->>'version'<>'planning-executive-v2-current-anchors' then raise exception 'planning v2 not ready'; end if;
 select x->>'first_need_next_layer' into d01 from jsonb_array_elements(j->'layers') x where x->>'id'='d01';
 select x->>'first_need_next_layer' into rsu from jsonb_array_elements(j->'layers') x where x->>'id'='future_vestings';
 fg:=j#>>'{summary,first_negative_even_with_fgts}';
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,jsonb_build_object('version','planning-ui-contract-v2','period_to',j#>>'{period,to}','d01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',(j#>>'{summary,fgts_covers_horizon}')::boolean,'fgts_request_by',j#>>'{summary,fgts_request_by}',
 'labels',jsonb_build_object('d01',case when d01 is null then 'Caixa consolidado após D0/D1 preservado até 31/12/2027' else 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') end,
 'rsu',case when rsu is null then 'Com RSUs atuais e vestings programados, sem ruptura até 31/12/2027' else 'Com RSUs atuais e vestings programados, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') end,
 'fgts',case when fg is null then 'Com FGTS, sem ruptura até 31/12/2027' else 'Mesmo com FGTS, a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') end)));
end $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_planning_ui_contract_v241()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '45s'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; result jsonb; last_day date:=make_date(extract(year FROM current_date)::int+1,12,31);
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_flow_v241(current_date,last_day);
 WITH d AS (SELECT x->>'date' dt,x->'fix86_columns' c FROM jsonb_array_elements(j#>'{flow,current_future,days}')x),
 s AS (SELECT min(dt) FILTER(WHERE (c->>'saldo_apos_d0_1')::numeric<0) d01,
  min(dt) FILTER(WHERE (c->>'saldo_apos_rsu')::numeric<0) rsu,
  min(dt) FILTER(WHERE (c->>'saldo_apos_fgts')::numeric<0) fg,
  min((c->>'saldo_apos_fgts')::numeric) fg_min FROM d)
 SELECT jsonb_build_object('version','planning-ui-contract-v2','scenario_revision','v241','period_to',last_day,
  'd01_first_need',d01,'rsu_first_need',rsu,'fgts_first_negative',fg,'fgts_covers_horizon',fg IS NULL,
  'fgts_documented_first_negative',fg,'fgts_documented_minimum',fg_min,
  'fgts_projection_contract',j#>'{flow,fgts_projection_contract}',
  'labels',jsonb_build_object(
   'd01',CASE WHEN d01 IS NULL THEN 'Caixa consolidado após D0/D1 preservado até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Caixa consolidado após D0/D1 fica negativo em '||to_char(d01::date,'DD/MM/YYYY') END,
   'rsu',CASE WHEN rsu IS NULL THEN 'Com RSUs atuais e vestings programados, sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE 'Com RSUs atuais e vestings programados, a primeira falta ocorre em '||to_char(rsu::date,'DD/MM/YYYY') END,
   'fgts','Com FGTS documental'||CASE WHEN fg IS NULL THEN ', sem ruptura até '||to_char(last_day,'DD/MM/YYYY') ELSE ', a primeira falta ocorre em '||to_char(fg::date,'DD/MM/YYYY') END)) INTO result FROM s;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,result);
END $function$;
CREATE OR REPLACE FUNCTION public.lts_browser_product_v1()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text;
  v_uid uuid;
  c jsonb;
  m jsonb;
  v_email text:=lower(coalesce(auth.jwt()->>'email',''));
  v_version text;
  v_cached_today date;
  v_mode text:='cache_hit_fresh';
  v_doc_change_version text;
  v_is_stale boolean:=false;
begin
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
  v_uid:=public.lts_browser_assert_user_v1();
  c:=public.lts_product_read_cached_v1(v_uid);
  v_version:=coalesce(c->>'payload_version','');

  begin
    v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
  exception when others then
    v_cached_today:=null;
  end;
  v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');

  if c is null or c->'payload' is null or v_version<>'lts-product-fix86-v36' then
    m:=public.lts_product_payload_fix86_v36(v_uid);
    insert into public.lts_product_read_cache(user_id,payload_version,payload,refreshed_at,source)
    values(v_uid,'lts-product-fix86-v36',m,now(),'browser_full_initialize_v36')
    on conflict(user_id) do update
      set payload_version=excluded.payload_version,
          payload=excluded.payload,
          refreshed_at=excluded.refreshed_at,
          source=excluded.source;
    c:=public.lts_product_read_cached_v1(v_uid);
    begin
      v_cached_today:=nullif(c#>>'{payload,updates,freshness,today}','')::date;
    exception when others then
      v_cached_today:=null;
    end;
    v_doc_change_version:=coalesce(c#>>'{payload,updates,document_change_summary_version}','');
    m:=c->'payload';
    v_mode:='full_initialize';
  else
    m:=c->'payload';
    v_is_stale := v_cached_today is distinct from current_date
                  or v_doc_change_version<>'document-change-summary-v1';
    if v_is_stale then
      v_mode:='cache_hit_stale_deferred';
    end if;
  end if;

  m:=public.lts_browser_enrich_flow_bank_gross_v1(m);

  insert into public.lts_access_audit(user_id,email,action,meta)
  values(
    v_uid,
    v_email,
    'browser_rpc_product_read',
    jsonb_build_object(
      'rpc_version',11,
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'refresh_mode',v_mode,
      'refresh_required',v_is_stale,
      'document_change_summary_version',v_doc_change_version,
      'flow_bank_gross_basis','payload_events_reconciled_v1'
    )
  );

  RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,public.lts_product_card_completeness_v269(jsonb_build_object(
    'ok',true,
    'api_version',41,
    'product','lts-wealth-fix86-plus',
    'cache',jsonb_build_object(
      'refreshed_at',c->'refreshed_at',
      'payload_version',coalesce(c->>'payload_version','lts-product-fix86-v36'),
      'cached_today',v_cached_today,
      'server_today',current_date,
      'is_stale',v_is_stale,
      'refresh_required',v_is_stale,
      'refresh_mode',v_mode
    ),
    'mvp',m
  ),public.lts_c6_completeness_state_v269(v_uid)));
end;
$function$;
CREATE OR REPLACE FUNCTION public.lts_browser_wealth_detail_v242()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
DECLARE v269_revision text; u uuid:=public.lts_browser_assert_user_v1(); j jsonb; a jsonb; cash jsonb; s jsonb; summary jsonb; delta numeric; key text; d0_delta numeric;
BEGIN
 v269_revision:=public.lts_card_read_start_v269(public.lts_browser_assert_user_v1());
 j:=public.lts_browser_wealth_detail_v4();
 a:=public.lts_liquidity_adjustments_v242(u,current_date);
 cash:=public.lts_browser_cash_today_v242();
 s:=j->'rsu_summary';
 summary:=j#>'{wealth,summary}';
 d0_delta:=coalesce((j#>>'{wealth,liquidity,d0}')::numeric,0)-(cash->>'d0')::numeric;
 j:=jsonb_set(j,'{rsu_summary}',s||jsonb_build_object('available_total_brl',cash->'brokerage_available','settled_withdrawals_brl',a->'brokerage_settled_withdrawals','component_position_requires_new_statement',(a->>'brokerage_settled_withdrawals')::numeric>0));
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('bank_cash',cash->'cash','fgts_contingency',cash->'fgts','d0',cash->'d0'));
 j:=jsonb_set(j,'{morgan_statement,available_after_settled_transfers_brl}',cash->'brokerage_available');
 j:=jsonb_set(j,'{current_liquidity}',cash-'day');
 j:=jsonb_set(j,'{wealth,liquidity}',coalesce(j#>'{wealth,liquidity}','{}')||jsonb_build_object('d3',cash->'brokerage_available','through_d3',cash->'available_total'));
 j:=jsonb_set(j,'{wealth,distribution}',coalesce((SELECT jsonb_agg(x||CASE x->>'name' WHEN 'Liquidez até D+3' THEN jsonb_build_object('value',cash->'available_total','detail','Contas, aplicações e ações') WHEN 'FGTS' THEN jsonb_build_object('value',cash->'fgts','detail','Saldo restrito') ELSE '{}'::jsonb END) FROM jsonb_array_elements(coalesce(j#>'{wealth,distribution}','[]'))x),'[]'));
 delta:=d0_delta+(a->>'brokerage_settled_withdrawals')::numeric+coalesce((summary->>'restricted_contingency')::numeric,0)-(cash->>'fgts')::numeric;
 FOREACH key IN ARRAY ARRAY['assets_central','net_worth_central','net_worth_low','net_worth_high'] LOOP
  IF summary ? key THEN summary:=jsonb_set(summary,ARRAY[key],to_jsonb((summary->>key)::numeric-delta)); END IF;
 END LOOP;
 summary:=summary||jsonb_build_object('liquidity_through_d3',cash->'available_total','restricted_contingency',cash->'fgts');
 IF (summary->>'assets_central')::numeric>0 THEN summary:=summary||jsonb_build_object('cipo_share_of_assets_pct',round((j#>>'{wealth,assets,cipo_396,market_central}')::numeric/(summary->>'assets_central')::numeric*100,1),'known_debt_to_assets_pct',round((summary->>'known_debt_total')::numeric/(summary->>'assets_central')::numeric*100,1)); END IF;
 j:=jsonb_set(j,'{wealth,summary}',summary);
 IF j#>'{wealth_v167,assets_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,assets_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,assets_central_including_pensions}')::numeric-delta)); END IF;
 IF j#>'{wealth_v167,net_worth_central_including_pensions}' IS NOT NULL THEN j:=jsonb_set(j,'{wealth_v167,net_worth_central_including_pensions}',to_jsonb((j#>>'{wealth_v167,net_worth_central_including_pensions}')::numeric-delta)); END IF;
 RETURN public.lts_card_read_finish_v269(public.lts_browser_assert_user_v1(),v269_revision,j||jsonb_build_object('reader_revision','v242-settled-resource-transfers'));
END $function$;

ROLLBACK;
