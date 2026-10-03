CREATE OR REPLACE FUNCTION public.lts_bank_own_global_return_v1(p_user_id uuid,p_staging_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO ''
AS $function$
SELECT EXISTS(
 SELECT 1 FROM public.lts_open_finance_staging s
 JOIN public.lts_open_finance_staging a ON a.user_id=s.user_id
  AND a.resource_type='balance' AND a.provider_account_ref=s.provider_account_ref
  AND a.institution_code=s.institution_code AND a.provider_deleted_at IS NULL
  AND a.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 WHERE s.user_id=p_user_id AND s.id=p_staging_id AND s.resource_type='transaction'
  AND s.institution_code='336' AND s.currency='BRL' AND s.provider_deleted_at IS NULL
  AND s.normalized_payload->>'status'='POSTED'
  AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
  AND s.signed_amount>0 AND s.raw_payload->>'type'='CREDIT'
  AND s.description_raw='RETORNO CONTA GLOBAL'
  AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
  AND regexp_replace(a.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
  AND regexp_replace(a.raw_payload->>'taxNumber','[^0-9]','','g')=
      regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')
);
$function$;
REVOKE ALL ON FUNCTION public.lts_bank_own_global_return_v1(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bank_own_global_return_v1(uuid,uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_card_source_rows_v226(p_user_id uuid)
 RETURNS TABLE(source_id uuid, bank text, family text, card_name text, last4 text, billing_last4 text, posting_date date, purchase_date date, reference_month date, due_date date, provider_status text, amount numeric, description text, category text, category_basis text, installment_number integer, total_installments integer, is_payment boolean, bill_id text, observed_at timestamp with time zone)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH provider_rows(source_id,bank,family,card_name,last4,billing_last4,posting_date,purchase_date,reference_month,due_date,provider_status,amount,description,category,category_basis,installment_number,total_installments,is_payment,bill_id,observed_at) AS MATERIALIZED (
with installment_decisions as materialized (
 select public.lts_card_installment_key_v231(s) purchase_key,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)<=1 then min(d.category_label) end category,
 case when count(distinct d.category_label)=1 and count(distinct d.beneficiary)=1 then min(d.beneficiary) end person
 from public.lts_open_finance_staging s join public.lts_v178_review_decision d
 on d.user_id=s.user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
 where s.user_id=p_user_id and s.provider_deleted_at is null and d.category_label is not null
 group by public.lts_card_installment_key_v231(s)
), evidence as materialized (
 select public.lts_card_merchant_key_v226(p.description_raw) k,round(p.installment_amount,2) amount,
 coalesce(d.category_label,p.category) category,p.card_final last4,p.installments,
 p.invoice_due_date evidence_date,d.beneficiary person
 from public.lts_card_purchase_detail p left join public.lts_v178_review_decision d
 on d.user_id=p.user_id and d.source_table='card_purchase_detail' and d.source_ref=p.line_key
 where p.user_id=p_user_id
 union all
 select public.lts_card_merchant_key_v226(a.description_norm),round(a.amount,2),a.category,null,null,a.event_date,null
 from public.lts_semantic_amount_signature a where a.user_id=p_user_id and a.source_kind='card'
), exact_categories as materialized (
 select k,amount,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 group by k,amount
), nature_categories as materialized (
 select k,case when count(distinct regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i'))=1
 then min(regexp_replace(category,'^(Lucas|Larissa|Benjamin)[[:space:]]*[-—][[:space:]]*','','i')) end category
 from evidence where pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(category,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') not in ('','a classificar','nao identificado','sem categoria','—')
 and k !~ 'mercado|amazon|shop|pagseguro|merpago' group by k
), rule_keys as materialized (
 select public.lts_card_merchant_key_v226(r.match_value) k,r.category,r.center_cost person,
 case when r.confidence='user_confirmed' then 0 else 1 end priority
 from public.lts_semantic_rule r where r.user_id=p_user_id and r.active and r.match_type='exact'
 and r.confidence in ('high','alta','system_high','user_confirmed')
), rule_categories as materialized (
 select k,case when count(distinct category)=1 then min(category) end category,case when count(distinct person)=1 then min(person) end person
 from (select *,dense_rank() over(partition by k order by priority) rank from rule_keys where k !~ '^(mercado|shopee|pagseguro|merpago)')q where rank=1 group by k
), src as materialized (
 select s.*,case s.institution_code when '237' then 'Bradesco' when '341' then 'Itaú' when '336' then 'C6' end bank,
 public.lts_card_family_v226(s.normalized_payload->>'card_name',s.institution_name) family,
 public.lts_card_merchant_key_v226(s.description_raw) merchant_key,
 public.lts_card_installment_key_v231(s) purchase_key,
 s.raw_payload#>>'{creditCardMetadata,billId}' raw_bill_id,
 case when s.raw_payload#>>'{creditCardMetadata,billForecastDate}' ~ '^[0-9]{4}-[0-9]{2}$'
 then (s.raw_payload#>>'{creditCardMetadata,billForecastDate}'||'-01')::date end forecast,
 (coalesce(s.raw_payload->>'operationType','')='PAGAMENTO_FATURA'
 or coalesce(s.raw_payload->>'category','')='Credit card payment'
 or pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(s.description_raw,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') ~ '^(inclusao de pagamento ciclo corrente|pagamento recebido|pagto fatura)') payment
 from public.lts_open_finance_staging s where s.user_id=p_user_id and s.resource_type='card_transaction'
 and s.provider_deleted_at is null
), open_cards as materialized (
 select distinct on (family) family,reference_month,due_date from (
  select public.lts_card_family_v226(i.card_name,case when i.card_name ~* 'c6' then 'C6' when i.card_name ~* 'aeternum|bradesco|prime' then 'Bradesco' else 'Itaú' end) family,i.reference_month,i.due_date
  from public.card_invoices i where i.user_id=p_user_id and i.status='open' and i.due_date>=current_date
 )q order by family,due_date
), dated as materialized (
 select s.*,b.posting_date bill_due,
 case when b.id is not null then date_trunc('month',b.posting_date)::date
 -- C6 reports the purchase month for its current open cycle. The document supplies the due month.
 when s.institution_code='336' and s.normalized_payload->>'status'='PENDING'
 and s.forecast<=date_trunc('month',current_date)::date then coalesce(c.reference_month,s.forecast)
 else s.forecast end cycle,
 c.due_date open_due
 from src s left join public.lts_open_finance_staging b on b.user_id=s.user_id
 and b.institution_code=s.institution_code and b.resource_type='invoice'
 and b.normalized_payload->>'provider_id'=s.raw_bill_id
 left join open_cards c on c.family=s.family
), classified as (
 select s.*,coalesce(d.category_label,ic.category,ec.category,sr.category,nc.category) known_category,coalesce(d.beneficiary,ic.person,ec.person,sr.person) known_person,
 case when d.category_label is not null then case when d.decision_basis like 'workbook_restore_v226%' then 'historical_workbook' else 'user_decision' end
 when ic.category is not null then 'confirmed_same_purchase_installments'
 when ec.category is not null then 'same_merchant_and_amount'
 when sr.category is not null then 'restored_explicit_rule'
 when nc.category is not null then 'historical_merchant_nature' end known_basis
 from dated s left join installment_decisions ic on ic.purchase_key=s.purchase_key
 left join exact_categories ec on ec.k=s.merchant_key and ec.amount=round(-s.signed_amount,2)
 left join nature_categories nc on nc.k=s.merchant_key
 left join rule_categories sr on sr.k=s.merchant_key
 left join public.lts_v178_review_decision d on d.user_id=p_user_id and d.source_table='lts_open_finance_staging' and d.source_ref=s.id::text
), provider_classification as (
 select c.*,case
 when c.raw_payload->>'category' in ('Credit card fees','Bank fees') then 'Tarifas bancárias'
 when c.raw_payload->>'category'='Tax on financial operations' then 'IOF'
 when c.merchant_key ~ '^(ifd|ifood)' and c.raw_payload->>'category' in ('Food delivery','Restaurants','Eating out','Groceries') then 'Ifood'
 when c.raw_payload->>'category'='Pharmacy' and c.merchant_key ~ 'drog|pharma|farma' then 'Farmácia'
 when c.raw_payload->>'category'='Groceries' and c.merchant_key ~ 'paodeacucar|obahortifruti|supermercado' then 'Mercado'
 when c.raw_payload->>'category' in ('Restaurants','Eating out') then 'Restaurantes'
 when c.raw_payload#>>'{creditCardMetadata,payeeMCC}'='5812' and c.merchant_key ~ 'bbq|restaur' then 'Restaurantes'
 when c.raw_payload->>'category'='Gas stations' and c.merchant_key ~ 'posto' then 'Combustível'
 when c.raw_payload->>'category'='Parking' and c.merchant_key ~ 'park|vallet|estacion' then 'Estacionamento e Pedágio'
 when c.raw_payload->>'category'='Healthcare' and c.merchant_key ~ '^(dr|clinica)' then 'Saúde'
 when c.raw_payload->>'category'='Clothing' and c.merchant_key ~ 'minimalclub|^ecreise|^paypalfrancagrif' then 'Vestuário'
 when c.raw_payload->>'category'='Tickets' and c.merchant_key ~ '^fevercandlelight' then 'Passeios'
 end provider_category from classified c
)
select s.id,s.bank,s.family,s.normalized_payload->>'card_name',
 coalesce(nullif(s.raw_payload#>>'{creditCardMetadata,cardNumber}',''),s.normalized_payload->>'last4'),
 s.normalized_payload->>'last4',s.posting_date,
 case when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*(Z|[+-][0-9]{2}:[0-9]{2})$'
 then ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date
 when s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}'
 then left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date else s.posting_date end,
 s.cycle,coalesce(s.bill_due,case when date_trunc('month',s.open_due)::date=s.cycle then s.open_due end),
 s.normalized_payload->>'status',-s.signed_amount,s.description_raw,
 coalesce(case when s.known_person in ('Lucas','Larissa','Benjamin') and s.known_category is not null and s.known_category !~* '^(Lucas|Larissa|Benjamin)' then s.known_person||' — '||s.known_category else s.known_category end,s.provider_category,'A classificar'),
 coalesce(s.known_basis,case when s.provider_category is null then 'unresolved' when s.raw_payload->>'category' in ('Credit card fees','Bank fees','Tax on financial operations') then 'explicit_fee_type' else 'merchant_and_provider_category' end),
 case when s.raw_payload#>>'{creditCardMetadata,installmentNumber}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,installmentNumber}')::integer end,
 case when s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' then (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::integer end,
 s.payment,s.raw_bill_id,s.last_seen_at
from provider_classification s
), documented_decisions AS MATERIALIZED (
 SELECT m.provider_id,d.category_label,d.beneficiary
 FROM public.lts_card_document_matches_v234(p_user_id) m
 JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id
  AND d.source_table='lts_card_document_supplement_v234' AND d.source_ref=m.document_id::text
 WHERE d.category_label IS NOT NULL
)
SELECT p.source_id,p.bank,p.family,p.card_name,p.last4,p.billing_last4,p.posting_date,p.purchase_date,p.reference_month,p.due_date,
 p.provider_status,p.amount,p.description,
 coalesce(CASE WHEN d.beneficiary IN ('Larissa','Benjamin','Rafiki') THEN d.beneficiary||' — '||d.category_label ELSE d.category_label END,p.category),
 CASE WHEN d.category_label IS NOT NULL THEN 'user_decision_document' ELSE p.category_basis END,
 p.installment_number,p.total_installments,p.is_payment,p.bill_id,p.observed_at
FROM provider_rows p LEFT JOIN documented_decisions d ON d.provider_id=p.source_id
UNION ALL SELECT * FROM public.lts_card_document_rows_v234(p_user_id)

$function$
;
CREATE OR REPLACE FUNCTION public.lts_browser_flow_pre_v238(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); anchors jsonb; positions jsonb; own_global_return boolean;
 lo date; result jsonb; f jsonb; events jsonb; recent jsonb; observed jsonb;
 s record; b text; a jsonb; e jsonb; matched jsonb; match_count int; added jsonb:='[]';
 d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;
 bal numeric; net numeric; fin numeric; inc numeric; outflow numeric; internal numeric;
 op_in numeric; op_out numeric; rsu numeric; d0 numeric; fgts numeric; gaps jsonb:='{}';
 pending_predictions jsonb:='[]'; morgan jsonb; cofrinho jsonb; asof date; asset_net numeric; gap_dates jsonb:='{}'; first_gap date; day_gap numeric;
BEGIN
 IF p_from IS NULL OR p_to IS NULL OR p_from>p_to OR p_to-p_from>12000 THEN RAISE EXCEPTION 'invalid range'; END IF;
 SELECT coalesce(jsonb_agg(x),'[]'),min((x->>'date')::date) INTO anchors,lo FROM (
  SELECT DISTINCT ON (institution) jsonb_build_object('bank',institution,'date',metadata->>'balance_as_of','balance',(metadata->>'balance')::numeric) x
  FROM public.accounts WHERE user_id=u AND is_active AND metadata->>'evidence_sha256' IS NOT NULL
   AND institution IN ('Itaú','Bradesco','C6') AND (metadata->>'balance_as_of')::date<current_date
  ORDER BY institution,(metadata->>'balance_as_of')::date DESC
 ) q;
 IF lo IS NULL OR p_to<=lo OR p_from>current_date THEN RETURN public.lts_browser_flow_base_v229(p_from,p_to); END IF;
 -- A complete recent context makes balances independent of the selected range.
 result:=public.lts_browser_flow_base_v229(p_from,p_to); f:=result->'flow';
 events:=coalesce(f#>'{historical,events}','[]')||coalesce(f#>'{current_future,events}','[]');
 -- Read only movement rows for context, without rendering historical balances.
 -- Prefer the existing reader's rich event metadata inside the requested range.
 WITH candidates AS (
  SELECT x,0 priority FROM jsonb_array_elements(events) x
   WHERE (x->>'event_date')::date>lo AND (x->>'event_date')::date<=current_date
  UNION ALL
  SELECT x,1 FROM jsonb_array_elements(public.lts_flow_operational_read_v229(u,lo+1,current_date)) x
 ), ranked AS (
  SELECT DISTINCT ON (x->>'event_date',x->>'account',x->>'source',x->>'source_ref') x
   FROM candidates ORDER BY x->>'event_date',x->>'account',x->>'source',x->>'source_ref',priority
 ) SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM ranked;
 positions:=public.lts_open_finance_checking_positions_v1(u);
 IF jsonb_array_length(positions)<>3 THEN RAISE EXCEPTION 'checking account positions incomplete or ambiguous'; END IF;
 FOR s IN SELECT st.*,case institution_code when '341' then 'Itaú' when '237' then 'Bradesco' else 'C6' end bank
  FROM public.lts_bank_posted_rows_v231(u) st WHERE user_id=u AND resource_type='transaction'
   AND institution_code IN ('341','237','336') AND currency='BRL' AND provider_deleted_at IS NULL
   AND normalized_payload->>'status'='POSTED' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT'
   AND posting_date>lo AND posting_date<=current_date ORDER BY posting_date,id
 LOOP
  SELECT x INTO a FROM jsonb_array_elements(anchors) x WHERE x->>'bank'=s.bank;
  IF a IS NULL OR s.posting_date<=(a->>'date')::date THEN CONTINUE; END IF;
  IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(positions) x WHERE x->>'bank'=s.bank
   AND x#>>'{payload,provider_account_id}'=s.normalized_payload->>'provider_account_id'
   AND s.occurred_at<=(x->>'as_of')::timestamptz) THEN CONTINUE; END IF;
  -- Cross-date matches require a private documentary identity and exact bank/cents.
  -- This is not an amount-only proximity match or a generic suppression rule.
  IF EXISTS(SELECT 1 FROM public.lts_v229_documentary_match dm WHERE dm.user_id=u AND dm.staging_id=s.id
   AND dm.bank=s.bank AND dm.signed_amount=s.signed_amount AND dm.canonical_date<=(a->>'date')::date
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND (fe.id::text=dm.source_ref OR fe.legacy_id=dm.source_ref) AND fe.event_date=dm.canonical_date AND fe.amount=dm.signed_amount)) THEN CONTINUE; END IF;
  -- Require exact source identity (or exact description), bank, date and cents.
  SELECT count(*),(jsonb_agg(x))->0 INTO match_count,matched FROM jsonb_array_elements(recent) x
   WHERE x->>'account'=s.bank AND (x->>'event_date')::date=s.posting_date AND (x->>'signed_amount')::numeric=s.signed_amount
   AND (EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(s.normalized_payload#>'{reconciliation,candidates}','[]')) z
     WHERE z->>'ref' IN (x->>'source_ref',(x->>'source')||':'||(x->>'source_ref')))
    OR lower(trim(x->>'description'))=lower(trim(s.description_raw))
    OR x->>'open_finance_id'=s.id::text);
  IF match_count>1 THEN RAISE EXCEPTION 'ambiguous bank movement identity'; END IF;
  IF match_count=1 THEN
   e:=matched||jsonb_build_object('open_finance_id',s.id,'bank_confirmed',true);
   SELECT coalesce(jsonb_agg(case when x=matched then e else x end),'[]') INTO recent FROM jsonb_array_elements(recent) x;
  ELSE
   own_global_return:=public.lts_bank_own_global_return_v1(u,s.id);
   e:=jsonb_build_object('source','open_finance','source_ref',s.id,'open_finance_id',s.id,'event_date',s.posting_date,
    'account',s.bank,'account_attribution','assigned','description',s.description_raw,'signed_amount',s.signed_amount,
    'direction',case when s.signed_amount<0 then 'saida' else 'entrada' end,'confidence','bank_posted','bank_confirmed',true,
    'category',case when s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return then 'Movimentação interna' else 'A classificar' end,
    'internal_transfer',s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return,
    'asset_movement',s.description_raw ILIKE '%RESGATE COFRINH%','excluded',s.description_raw ILIKE '%RESGATE COFRINH%' OR own_global_return);
   recent:=recent||jsonb_build_array(e);added:=added||jsonb_build_array(e);
  END IF;
 END LOOP;
 -- A realized payroll replaces its matched forecast even when an older cache exists.
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
 WHERE NOT EXISTS(SELECT 1 FROM public.lts_payroll_bank_matches_v231(u) pm WHERE pm.projection_ref=x->>'source_ref');
 -- A scheduled event for today affects today's operational closing, while
 -- only posted/current facts participate in observed-bank reconciliation.
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;
 -- Past/current projections are not posted cash. Retain them for review, never erase.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions FROM jsonb_array_elements(recent) x
  WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
  AND (x->>'event_date')::date>(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot')
  OR (x->>'event_date')::date<=(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x||CASE WHEN k.c->>'category' IS NOT NULL THEN jsonb_build_object(
  'category',k.c->>'category','center_cost',k.c->>'beneficiary','classification_confirmed',true,'classification_basis',k.c->>'basis') ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;
 SELECT coalesce(jsonb_agg(x||CASE
  WHEN coalesce((x->>'asset_movement')::boolean,false) AND x->>'description' ILIKE '%RESGATE COFRINH%' THEN jsonb_build_object('description','Resgate Cofrinho')
  WHEN coalesce((x->>'internal_transfer')::boolean,false) AND pair.bank IS NOT NULL THEN jsonb_build_object('description','Transferência entre contas — '||CASE WHEN (x->>'signed_amount')::numeric<0 THEN (x->>'account')||' → '||pair.bank ELSE pair.bank||' → '||(x->>'account') END)
  ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN LATERAL(SELECT CASE WHEN count(*)=1 THEN min(y->>'account') END bank FROM jsonb_array_elements(recent) y
  WHERE coalesce((y->>'internal_transfer')::boolean,false) AND y->>'event_date'=x->>'event_date'
  AND y->>'account'<>x->>'account' AND (y->>'signed_amount')::numeric=-(x->>'signed_amount')::numeric) pair ON true;
 -- Preserve older history and projected events; replace only the recent context.
 SELECT coalesce(jsonb_agg(x),'[]') INTO events FROM jsonb_array_elements(events) x
  WHERE (x->>'event_date')::date<=lo OR (x->>'event_date')::date>current_date;
 events:=events||recent;
 -- Compare the recent ledger to its older documentary anchor. Differences remain
 -- evidence gaps, never synthetic transactions. Current bank positions stay exact.
 FOR a IN SELECT x FROM jsonb_array_elements(anchors) x LOOP
  b:=a->>'bank';SELECT (x->>'balance')::numeric INTO bal FROM jsonb_array_elements(positions) x WHERE x->>'bank'=b;
  SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO net FROM jsonb_array_elements(recent) x
   WHERE x->>'account'=b AND (x->>'event_date')::date>(a->>'date')::date AND x->>'source'<>'economic_withholding' AND NOT coalesce((x->>'unposted_current_projection')::boolean,false);
  gaps:=gaps||jsonb_build_object(b,round(bal-(a->>'balance')::numeric-net,2));
  IF abs((gaps->>b)::numeric)>.005 THEN
   -- Repeated provider observations do not change the first discrepancy date.
   -- Parse each observed balance and the recent ledger once before comparing.
   WITH observed_balances AS MATERIALIZED (
    SELECT DISTINCT ((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date dt,
     (o.normalized_payload->>'amount')::numeric amount
    FROM public.lts_open_finance_observation o JOIN public.lts_open_finance_connection cn ON cn.id=o.connection_id
    WHERE o.user_id=u AND o.resource_type='balance' AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
    AND CASE cn.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END=b
    AND ((o.normalized_payload->>'as_of')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date>(a->>'date')::date
   ), ledger AS MATERIALIZED (
    SELECT (x->>'event_date')::date dt,sum((x->>'signed_amount')::numeric) amount
    FROM jsonb_array_elements(recent) x WHERE x->>'account'=b
     AND (x->>'event_date')::date>(a->>'date')::date AND x->>'source'<>'economic_withholding' AND NOT coalesce((x->>'unposted_current_projection')::boolean,false)
    GROUP BY (x->>'event_date')::date
   )
   SELECT min(o.dt) INTO first_gap FROM observed_balances o
   WHERE abs(o.amount-(a->>'balance')::numeric-coalesce((SELECT sum(l.amount) FROM ledger l WHERE l.dt<=o.dt),0))>.005;
   gap_dates:=gap_dates||jsonb_build_object(b,first_gap);
  END IF;
 END LOOP;
 SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%' ORDER BY canonical_value->>'as_of' DESC LIMIT 1;
 SELECT canonical_value INTO cofrinho FROM public.lts_validated_lock_registry WHERE superseded_at IS NULL AND lock_key LIKE 'itau_cofrinho_%' ORDER BY canonical_value->>'as_of' DESC LIMIT 1;
 FOREACH part IN ARRAY ARRAY['historical','current_future'] LOOP
  outdays:='[]';
  FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to ORDER BY x->>'date' LOOP
   dt:=(d->>'date')::date;
   IF dt>lo AND dt<=current_date AND (dt=current_date OR EXISTS(SELECT 1 FROM jsonb_array_elements(added) observed_entry WHERE (observed_entry->>'event_date')::date<=dt)) THEN
    FOREACH b IN ARRAY ARRAY['Itaú','Bradesco','C6'] LOOP
     SELECT x INTO a FROM jsonb_array_elements(anchors) x WHERE x->>'bank'=b;
     IF a IS NULL OR dt<=(a->>'date')::date THEN CONTINUE; END IF;
     -- Reconstruct forwards from the dated documentary opening. The observed
     -- position is a check, not an input that can force the ledger to balance.
     SELECT (a->>'balance')::numeric+coalesce(sum((x->>'signed_amount')::numeric),0) INTO bal
      FROM jsonb_array_elements(recent) x WHERE x->>'account'=b
       AND (x->>'event_date')::date>(a->>'date')::date AND (x->>'event_date')::date<=dt
       AND x->>'source'<>'economic_withholding';
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO net FROM jsonb_array_elements(recent) x
      WHERE x->>'account'=b AND (x->>'event_date')::date=dt AND x->>'source'<>'economic_withholding';
     first_gap:=NULL;
     d:=jsonb_set(d,ARRAY[b],coalesce(d->b,'{}')||jsonb_build_object('balance',bal,'net',net,'operational_balance',bal,'operational_net',net,
      'balance_basis','observed_bank_position_and_recent_movements','balance_certified',abs((gaps->>b)::numeric)<0.005 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(recent) proj WHERE proj->>'account'=b AND (proj->>'event_date')::date=dt AND coalesce((proj->>'unposted_current_projection')::boolean,false)),
      'unposted_projection_net',coalesce((SELECT sum((proj->>'signed_amount')::numeric) FROM jsonb_array_elements(recent) proj WHERE proj->>'account'=b AND (proj->>'event_date')::date=dt AND coalesce((proj->>'unposted_current_projection')::boolean,false)),0),
      'observed_balance',CASE WHEN dt=current_date THEN (SELECT (p->>'balance')::numeric FROM jsonb_array_elements(positions) p WHERE p->>'bank'=b) END,
      'movements_complete',dt IS DISTINCT FROM first_gap,'opening_balance',bal-net-CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,'position_gap',CASE WHEN dt=first_gap THEN (gaps->>b)::numeric ELSE 0 END,'reconciliation_gap',(gaps->>b)::numeric));
    END LOOP;
    SELECT coalesce(jsonb_agg(x),'[]') INTO dayev FROM jsonb_array_elements(recent) x WHERE (x->>'event_date')::date=dt
     AND x->>'account' IN ('Itaú','Bradesco','C6') AND x->>'source'<>'economic_withholding';
    SELECT coalesce(sum(greatest((x->>'signed_amount')::numeric,0)) FILTER(WHERE NOT coalesce((x->>'internal_transfer')::boolean,false)),0),
     coalesce(-sum(least((x->>'signed_amount')::numeric,0)) FILTER(WHERE NOT coalesce((x->>'internal_transfer')::boolean,false)),0),
     coalesce(sum((x->>'signed_amount')::numeric) FILTER(WHERE coalesce((x->>'internal_transfer')::boolean,false)),0)
     INTO op_in,op_out,internal FROM jsonb_array_elements(dayev) x;
    inc:=op_in+greatest(internal,0);outflow:=op_out+greatest(-internal,0);
    fin:=(d#>>'{Itaú,balance}')::numeric+(d#>>'{Bradesco,balance}')::numeric+(d#>>'{C6,balance}')::numeric;
    c:=d->'fix86_columns';d0:=(c->>'liq_d0_1_recurso')::numeric;rsu:=(c->>'rsus_vested')::numeric;fgts:=(c->>'fgts')::numeric;
    IF dt>=(morgan->>'as_of')::date THEN rsu:=(morgan->>'total_available_brl')::numeric; END IF;
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=(cofrinho->>'amount')::numeric;
    ELSE
     SELECT coalesce(sum((x->>'signed_amount')::numeric),0) INTO asset_net FROM jsonb_array_elements(added) x
      WHERE coalesce((x->>'asset_movement')::boolean,false) AND (x->>'event_date')::date<=dt;
     d0:=d0-asset_net;
    END IF;
    c:=c||jsonb_build_object('saldo_final',fin,'saldo_final_operacional',fin,'saldo_anterior',fin-inc+outflow,'saldo_anterior_operacional',fin-inc+outflow,
     'entradas',inc,'saidas',outflow,'entradas_operacionais',inc,'saidas_operacionais',outflow,'rsus_vested',rsu,'liq_d0_1_recurso',d0,
     'saldo_apos_d0_1',fin+d0,'liq_d0_1',fin+d0,'posicao_antes_rsus',fin+d0,'saldo_apos_rsu',fin+d0+rsu,
     'disponivel_total',fin+d0+rsu,'posicao_curto_prazo',fin+d0+rsu,'saldo_apos_fgts',fin+d0+rsu+fgts);
    d:=d||jsonb_build_object('fix86_columns',c,'Consolidado',(d->'Consolidado')||jsonb_build_object('bank_balance',fin,'net',inc-outflow,'economic_net',op_in-op_out,'balance_certified',coalesce((d#>>'{Itaú,balance_certified}')::boolean,false) AND coalesce((d#>>'{Bradesco,balance_certified}')::boolean,false) AND coalesce((d#>>'{C6,balance_certified}')::boolean,false)),
     'summary',(d->'summary')||jsonb_build_object('entries',inc,'exits',outflow,'net',inc-outflow,'events',jsonb_array_length(dayev),'Consolidado',jsonb_build_object('entries',inc,'exits',outflow)),
     'v170_cash_arithmetic',jsonb_build_object('version','tracked-bank-cash-arithmetic-v1','balanced',true,'arithmetic_gap_brl',0,
      'operating_entries_brl',op_in,'operating_exits_brl',op_out,'internal_transfer_net_brl',internal,'tracked_bank_net_brl',inc-outflow));
   END IF;
   day_gap:=coalesce((d#>>'{Itaú,position_gap}')::numeric,0)+coalesce((d#>>'{Bradesco,position_gap}')::numeric,0)+coalesce((d#>>'{C6,position_gap}')::numeric,0);
   IF abs(day_gap)>.005 THEN
    d:=d||jsonb_build_object('movements_complete',false,'position_gap',day_gap,'fix86_columns',(d->'fix86_columns')||jsonb_build_object(
     'saldo_anterior',(d#>>'{fix86_columns,saldo_anterior}')::numeric-day_gap,
     'saldo_anterior_operacional',(d#>>'{fix86_columns,saldo_anterior_operacional}')::numeric-day_gap,'entradas',null,'saidas',null));
   END IF;
   IF dt<current_date AND dt>=(morgan->>'as_of')::date THEN
    c:=d->'fix86_columns';rsu:=(morgan->>'total_available_brl')::numeric;
    IF rsu IS NOT NULL THEN
     c:=c||jsonb_build_object('rsus_vested',rsu,
      'saldo_apos_rsu',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'disponivel_total',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'posicao_curto_prazo',(c->>'saldo_apos_d0_1')::numeric+rsu,
      'saldo_apos_fgts',(c->>'saldo_apos_d0_1')::numeric+rsu+(c->>'fgts')::numeric,
      'historical_rsu_basis','dated_validated_brokerage_available');
     d:=d||jsonb_build_object('fix86_columns',c);
    END IF;
   END IF;
   outdays:=outdays||jsonb_build_array(d);
  END LOOP;
  f:=jsonb_set(f,ARRAY[part],coalesce(f->part,'{}')||jsonb_build_object('days',outdays,'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref')
   FROM jsonb_array_elements(events) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
    AND case when part='historical' then (x->>'event_date')::date<current_date else (x->>'event_date')::date>=current_date end),'[]')));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'observed_bank_movements',jsonb_build_object('version','v229','added_count',jsonb_array_length(added),'documentary_gaps',gaps,'position_gap_dates',gap_dates,'pending_projections',pending_predictions,
  'matched_projections',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.lts_payroll_bank_matches_v231(u) m),'[]'::jsonb)));

 RETURN result||jsonb_build_object('flow',public.lts_flow_review_overlay_v229(u,f),'version','browser-flow-v229-consistent-evidence','reader_revision','v231-forward-realized-ledger');
END $function$
;

CREATE OR REPLACE FUNCTION public.lts_current_evidence_position_v2(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
with b as (select public.lts_open_finance_current_bank_position_v1(p_user_id) j), c as (select (canonical_value->>'amount')::numeric v from public.lts_validated_lock_registry where lock_key='itau_cofrinho_20260926' and superseded_at is null)
select jsonb_build_object('as_of',current_date,'scope','current_liquidity_live_bank_validated_assets','version','evidence-v3-open-finance-current-bank-position',
'accounts',b.j->'accounts','bank_cash',(b.j->>'bank_cash')::numeric,
'assets',jsonb_build_array(jsonb_build_object('name','Cofrinho Itaú','type','cash_investment','as_of',current_date,'value_brl',c.v,'available_now',true,'liquidity_class','D+0')),
'liquid_d0_assets',c.v,'liquidity_now_d0',(b.j->>'bank_cash')::numeric+c.v,
'liquid_d1_d3_assets',0,'liquidity_through_d3',(b.j->>'bank_cash')::numeric+c.v,
'restricted_assets',22432.31,'future_assets',1722886.99,
'guardrails',jsonb_build_array('Current bank cash uses latest Open Finance balances.','Cofrinho uses validated Itaú app anchor until provider can isolate it.','RSU is intentionally excluded from this current-liquidity bridge until its current value is reconciled independently.'))
from b,c $function$
;
