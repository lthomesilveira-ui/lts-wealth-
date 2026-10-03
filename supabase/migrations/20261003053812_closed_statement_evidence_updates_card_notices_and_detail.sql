CREATE OR REPLACE FUNCTION public.lts_updates_current_sources_v240(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH base AS MATERIALIZED (select coalesce((select payload->'updates' from public.lts_product_read_cache where user_id=p_user_id),public.lts_updates_fix86plus_v12(p_user_id)) j),
positions AS MATERIALIZED (select public.lts_open_finance_checking_positions_v1(p_user_id) j),
kept AS (select x from base,lateral jsonb_array_elements(base.j->'items') x
 where coalesce(x->>'type','')<>'projection_payment_review'
 AND NOT (x->>'type'='card_payment_review' AND EXISTS(select 1 from public.card_invoices i join public.lts_fact_confirmation fc on fc.user_id=i.user_id and fc.source_ref=i.card_name||'|'||to_char(i.reference_month,'YYYY-MM')
 where i.user_id=p_user_id and x->>'id'='card_payment_'||i.id::text and fc.signed_amount=-i.amount))
 AND NOT (x->>'maintenance_kind'='bank_statement' and exists(
  select 1 from positions,lateral jsonb_array_elements(positions.j) p
  where (p->>'as_of')::timestamptz BETWEEN current_timestamp-interval '24 hours' AND current_timestamp and
   x->>'id'=case p->>'bank' when 'Itaú' then 'maintenance_bank_ita_' when 'Bradesco' then 'maintenance_bank_bradesco' when 'C6' then 'maintenance_bank_c6' end)) AND NOT (coalesce(x->>'maintenance_kind','')='card_statement' AND EXISTS(
  SELECT 1 FROM public.card_invoices ci JOIN public.source_documents sd
   ON sd.id::text=ci.metadata->>'bank_statement_document_id' AND sd.user_id=ci.user_id
  WHERE ci.user_id=p_user_id AND ci.status='closed'
   AND ci.reference_month=date_trunc('month',current_date)::date
   AND ci.metadata->>'bank_statement_closed'='true'
   AND ci.metadata->>'bank_statement_full_composition'='true'
   AND sd.document_type='credit_card_statement' AND sd.processing_status='processed'
   AND sd.sha256=ci.metadata->>'bank_statement_sha256'
   AND sd.metadata->>'all_source_lines_matched'='true'
   AND (sd.metadata->>'statement_amount')::numeric=ci.amount
   AND (sd.metadata->>'due_date')::date=ci.due_date
   AND public.lts_v178_norm(x->>'title')=public.lts_v178_norm('Fatura '||ci.card_name)))),
pending AS (select x from jsonb_array_elements(public.lts_pending_projections_v233(p_user_id)) x),
current_card_detail AS (select CASE WHEN i.card_name IS NOT NULL THEN x||jsonb_build_object(
 'detail','Última fatura fechada registrada: '||to_char(i.reference_month,'MM/YYYY')||'. O ciclo atual permanece sujeito à fatura oficial; valores de projeção não são confirmação de fatura fechada.',
 'last_closed_reference_month',i.reference_month,'last_closed_invoice_id',i.id) ELSE x END x
 from kept left join lateral(select ci.id,ci.card_name,ci.reference_month from public.card_invoices ci
 where ci.user_id=p_user_id AND ci.status='closed' AND x->>'maintenance_kind'='card_statement'
 AND public.lts_v178_norm(x->>'title')=public.lts_v178_norm('Fatura '||ci.card_name)
 order by ci.reference_month desc,ci.due_date desc limit 1) i ON true),
items AS (select x from current_card_detail union all select jsonb_build_object(
 'id','pending_projection_'||coalesce(x->>'source_ref',x->>'id'),'type','projection_payment_review',
 'title','Confirmar previsão · '||coalesce(x->>'description','Pagamento'),
 'detail','Classificação conhecida; o pagamento desta obrigação ainda requer correspondência documental.',
 'status','needs_confirmation','priority',1,'destination','Atualizações',
 'source_ref',x->'source_ref','category',x->'category','amount',x->'signed_amount','event_date',x->'event_date') from pending),
summary AS (select coalesce(jsonb_agg(x order by coalesce((x->>'priority')::int,9),x->>'id'),'[]') j,
 count(*) total,count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current')) actionable,
 count(*) filter(where x->>'status' not in ('informational','guarded','resolved','current') and (x->>'priority')::int=1) urgent from items)
select base.j||jsonb_build_object('version','updates-v240-current-source-evidence','items',summary.j,
 'pending_count',summary.total,'actionable_count',summary.actionable,'urgent_count',summary.urgent,
 'current_bank_evidence',positions.j) from base,summary,positions
$function$
;

CREATE OR REPLACE FUNCTION public.lts_browser_card_detail_v226(p_family text, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare u uuid:=public.lts_browser_assert_user_v1(); result jsonb; alternative jsonb; official record; matched boolean;
begin
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
 'items',coalesce((select jsonb_agg(to_jsonb(r)||coalesce((SELECT jsonb_build_object('source_document',jsonb_build_object('file_ref',d.source_file_ref,'sha256',d.source_sha256,'page',d.source_page,'line',d.source_line,'as_of',d.source_as_of)) FROM public.lts_card_document_supplement_v234 d WHERE d.user_id=u AND d.id=r.source_id),'{}'::jsonb) order by posting_date desc,description,source_id) from r),'[]'::jsonb),
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

 return result;
end
$function$
;

CREATE OR REPLACE FUNCTION public.lts_dashboard_source_key_v240(p_user_id uuid)
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
SELECT md5(jsonb_build_object(
 'revision','canonical-cache-v248-closed-bank-document','date',current_date,
 'operational',public.lts_operational_source_key_v238(p_user_id),
 'fact_confirmations',(select md5(coalesce(string_agg(to_jsonb(f)::text,'|' order by id),'empty')) from public.lts_fact_confirmation f where user_id=p_user_id),
 'bank',public.lts_open_finance_checking_positions_v1(p_user_id),
 'staging',(select md5(coalesce(string_agg(jsonb_build_array(id,resource_type,raw_hash,normalized_payload,posting_date,signed_amount,provider_deleted_at)::text,'|' order by id),'empty')) from public.lts_open_finance_staging where user_id=p_user_id),
 'decisions',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by source_table,source_ref),'empty')) from public.lts_v178_review_decision d where user_id=p_user_id),
 'assets',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.asset_positions a where user_id=p_user_id),
 'movements',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_liquidity_movement a where user_id=p_user_id),
 'schedule',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_future_liquidity_schedule a where user_id=p_user_id),
 'brokerage',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.lts_brokerage_position_snapshots a where user_id=p_user_id),
 'invoices',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by id),'empty')) from public.card_invoices a where user_id=p_user_id),
 'closed_statement_documents',(select md5(coalesce(string_agg(to_jsonb(d)::text,'|' order by d.id),'empty')) from public.source_documents d
  where d.user_id=p_user_id and exists(select 1 from public.card_invoices ci where ci.user_id=p_user_id and ci.metadata->>'bank_statement_document_id'=d.id::text)),
 'locks',(select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by lock_key),'empty')) from public.lts_validated_lock_registry a where superseded_at is null)
)::text)
$function$
;
