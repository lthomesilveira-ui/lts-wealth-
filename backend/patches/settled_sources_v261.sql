-- Combine an evidenced FGTS bank receipt only when the scheduled components and owned bank identity agree.
CREATE OR REPLACE FUNCTION public.lts_bank_fgts_combined_receipt_v261(p_user_id uuid,p_staging_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path='' SET "TimeZone"='America/Sao_Paulo' AS $fn$
DECLARE s public.lts_open_finance_staging%ROWTYPE; policy jsonb; refs jsonb; count_rows integer; count_components integer;
 principal numeric; jam numeric; total numeric; group_count integer; same_accounts boolean; receipt_count integer;
BEGIN
 SELECT * INTO s FROM public.lts_open_finance_staging WHERE user_id=p_user_id AND id=p_staging_id;
 IF NOT FOUND OR s.resource_type<>'transaction' OR s.institution_code<>'341' OR s.currency<>'BRL'
 OR s.provider_deleted_at IS NOT NULL OR s.normalized_payload->>'status' IS DISTINCT FROM 'POSTED'
 OR s.normalized_payload->>'account_type' IS DISTINCT FROM 'CHECKING_ACCOUNT' OR s.signed_amount<=0
 OR s.raw_payload#>>'{paymentData,payer,documentNumber,type}' IS DISTINCT FROM 'CNPJ'
 OR regexp_replace(s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') IS DISTINCT FROM '00360305000104'
 OR s.raw_payload#>>'{paymentData,payer,routingNumber}' IS DISTINCT FROM '104'
 OR s.raw_payload#>>'{paymentData,receiver,documentNumber,type}' IS DISTINCT FROM 'CPF' THEN RETURN NULL;END IF;
 IF NOT EXISTS(SELECT 1 FROM public.lts_open_finance_staging owner_account
 WHERE owner_account.user_id=p_user_id AND owner_account.resource_type='balance'
 AND owner_account.institution_code=s.institution_code AND owner_account.provider_account_ref=s.provider_account_ref
 AND owner_account.provider_deleted_at IS NULL AND owner_account.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND regexp_replace(owner_account.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
 AND regexp_replace(owner_account.raw_payload->>'taxNumber','[^0-9]','','g')=
 regexp_replace(s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g')) THEN RETURN NULL;END IF;
 SELECT settings#>'{liquidity_movements_v242,fgts}' INTO policy FROM public.app_settings WHERE user_id=p_user_id;
 IF policy->>'receipt_date' IS NULL OR s.posting_date<>(policy->>'receipt_date')::date
 OR s.signed_amount<>(policy->>'total_brl')::numeric THEN RETURN NULL;END IF;
 SELECT count(*),count(DISTINCT f.metadata->>'receipt_component'),count(DISTINCT f.metadata->>'receipt_group_id'),
 sum(f.amount),max(f.amount) FILTER(WHERE f.metadata->>'receipt_component'='principal'),
 max(f.amount) FILTER(WHERE f.metadata->>'receipt_component'='jam'),
 coalesce(bool_and(a.institution='Itaú' AND a.is_active),false),
 jsonb_agg(coalesce(f.legacy_id,f.id::text) ORDER BY f.metadata->>'receipt_component')
 INTO count_rows,count_components,group_count,total,principal,jam,same_accounts,refs
 FROM public.financial_events f JOIN public.accounts a ON a.user_id=f.user_id AND a.id=f.account_id
 WHERE f.user_id=p_user_id AND f.is_projection AND NOT f.is_suppressed
 AND f.source='owner_confirmed_asset_redemption' AND f.metadata->>'source_asset_type'='FGTS'
 AND f.metadata->>'economic_effect'='asset_reclassification' AND f.metadata->>'receipt_component' IN('principal','jam')
 AND f.metadata->>'receipt_group_id' IS NOT NULL AND f.event_date=s.posting_date;
 IF count_rows<>2 OR count_components<>2 OR group_count<>1 OR NOT same_accounts
 OR total IS DISTINCT FROM s.signed_amount OR principal IS DISTINCT FROM (policy->>'principal_brl')::numeric
 OR jam IS DISTINCT FROM (policy->>'jam_brl')::numeric OR principal<=0 OR jam<=0 THEN RETURN NULL;END IF;
 SELECT count(*) INTO receipt_count FROM public.lts_bank_posted_rows_v231(p_user_id) other
 WHERE other.user_id=p_user_id AND other.resource_type='transaction' AND other.institution_code=s.institution_code
 AND other.provider_account_ref=s.provider_account_ref AND other.posting_date=s.posting_date AND other.currency='BRL'
 AND other.provider_deleted_at IS NULL AND other.normalized_payload->>'status'='POSTED'
 AND other.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND other.signed_amount IN(total,principal,jam);
 IF receipt_count<>1 THEN RETURN NULL;END IF;
 RETURN jsonb_build_object('projection_refs',refs,'principal',principal,'jam',jam,'total',total,
 'bank_source_id',s.id,'bank_source_hash',s.raw_hash,'basis','posted_combined_fgts_receipt_with_owner_confirmed_components');
END $fn$;
REVOKE ALL ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) TO service_role;

DO $patch$
DECLARE d text; before_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_browser_flow_pre_v238(date,date)'::regprocedure),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_browser_flow_pre_v238(date,date)'::regprocedure;
 IF md5(d)<>'af6a02ed7dbd0fe3e33ba36b29a6f717' THEN RAISE EXCEPTION 'V261 lease changed: lts_browser_flow_pre_v238(date,date)'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_browser_flow_pre_v238(p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=public.lts_browser_assert_user_v1(); anchors jsonb; positions jsonb; own_global_return boolean; fgts_receipt jsonb;
 lo date; result jsonb; f jsonb; events jsonb; recent jsonb; observed jsonb;
 s record; b text; a jsonb; e jsonb; matched jsonb; match_count int; added jsonb:='[]';
 d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;
 bal numeric; net numeric; fin numeric; inc numeric; outflow numeric; internal numeric;
 op_in numeric; op_out numeric; rsu numeric; d0 numeric; fgts numeric; gaps jsonb:='{}';
 out_day_rows jsonb[];
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
  UNION ALL
  SELECT jsonb_build_object('source','liquidity_movement','source_ref','financial_events:'||fe.id::text,
   'event_date',m.event_date,'account',a.institution,'description',m.description,'signed_amount',m.bank_delta_brl,
   'direction',CASE WHEN m.bank_delta_brl<0 THEN 'saida' ELSE 'entrada' END,
   'confidence','documented_current_internal_transfer','internal_transfer',true,'asset_movement',true,
   'is_asset_movement',true,'excluded',true,'excluded_from_spend',true,
   'liquidity_movement_id',m.id,'category','Movimentação de liquidez'),0
  FROM public.lts_liquidity_movement m JOIN public.financial_events fe ON fe.id=m.bank_event_id AND fe.user_id=m.user_id
  JOIN public.accounts a ON a.id=m.account_id AND a.user_id=m.user_id
  JOIN public.asset_positions ap ON ap.id=m.asset_position_id AND ap.user_id=m.user_id
  WHERE m.user_id=u AND m.status='active' AND NOT fe.is_suppressed
   AND ap.asset_name='Cofrinho Itaú' AND ap.asset_type='cash_investment'
   AND m.event_date>greatest(lo,(SELECT max((canonical_value->>'as_of')::date)
     FROM public.lts_validated_lock_registry WHERE lock_key LIKE 'itau_cofrinho_%' AND superseded_at IS NULL))
   AND m.event_date<=current_date
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
  -- A combined posted receipt replaces its two scheduled components, with no new bank credit.
  fgts_receipt:=public.lts_bank_fgts_combined_receipt_v261(u,s.id);
  IF fgts_receipt IS NOT NULL THEN
   SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
    WHERE NOT ((x->>'source'='current_event') AND fgts_receipt->'projection_refs' ? (x->>'source_ref'));
   e:=jsonb_build_object('source','open_finance','source_ref',s.id,'open_finance_id',s.id,
    'event_date',s.posting_date,'account',s.bank,'account_attribution','assigned',
    'description','Resgate FGTS','signed_amount',s.signed_amount,'direction','entrada',
    'confidence','bank_posted','bank_confirmed',true,'category','Resgate FGTS',
    'internal_transfer',true,'asset_movement',true,'is_asset_movement',true,
    'excluded',true,'excluded_from_spend',true,'classification_confirmed',true,
    'classification_basis',fgts_receipt->>'basis','receipt_composition',fgts_receipt);
   recent:=recent||jsonb_build_array(e);added:=added||jsonb_build_array(e);
   CONTINUE;
  END IF;
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
    OR x->>'open_finance_id'=s.id::text OR public.lts_documented_bank_event_identity_v242(u,s.id,x));
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
 -- A validated forecast is still a forecast until its own occurrence is bank-confirmed.
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date<current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_past_projection',true) ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x;
 -- Past/current projections are not posted cash. Retain them for review, never erase.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions FROM jsonb_array_elements(recent) x
  WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND (x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') OR coalesce((x->>'unposted_past_projection')::boolean,false))
  AND (x->>'event_date')::date>(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))
  OR (x->>'event_date')::date<=(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x||CASE WHEN k.c->>'category' IS NOT NULL THEN jsonb_build_object(
  'category',k.c->>'category','center_cost',k.c->>'beneficiary','classification_confirmed',true,'classification_basis',k.c->>'basis') ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 -- Keep this expression behind a lateral evaluation barrier: the same
 -- classification JSON is consumed by several output fields.
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL OFFSET 0) k ON true;
 WITH posted AS MATERIALIZED (
 SELECT tx_s.*,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf
 FROM public.lts_bank_posted_rows_v231(u) tx_s
), owned_identity AS MATERIALIZED (
 SELECT DISTINCT tx_s.institution_code,tx_s.provider_account_ref,
 regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging tx_s
 WHERE tx_s.user_id=u AND tx_s.resource_type='balance' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(tx_s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
), eligible_pairs AS MATERIALIZED (
 SELECT tx_d.id debit_id,tx_c.id credit_id
 FROM posted tx_d JOIN posted tx_c ON tx_c.user_id=tx_d.user_id
 AND tx_c.posting_date=tx_d.posting_date AND tx_c.signed_amount=-tx_d.signed_amount
 AND tx_c.institution_code<>tx_d.institution_code
 JOIN owned_identity od ON od.institution_code=tx_d.institution_code
 AND od.provider_account_ref=tx_d.provider_account_ref AND od.cpf=tx_d.payer_cpf
 JOIN owned_identity oc ON oc.institution_code=tx_c.institution_code
 AND oc.provider_account_ref=tx_c.provider_account_ref AND oc.cpf=tx_c.receiver_cpf
 WHERE tx_d.signed_amount<0 AND tx_c.signed_amount>0
 AND tx_d.institution_code IN ('341','237','336') AND tx_c.institution_code IN ('341','237','336')
 AND tx_d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_d.payer_cpf~'^[0-9]{11}$' AND tx_d.payer_cpf=tx_d.receiver_cpf
 AND tx_c.payer_cpf=tx_d.payer_cpf AND tx_c.receiver_cpf=tx_d.receiver_cpf
 AND tx_d.raw_payload#>>'{paymentData,receiver,routingNumber}'=tx_c.institution_code
 AND tx_c.raw_payload#>>'{paymentData,payer,routingNumber}'=tx_d.institution_code
), counted_pairs AS (
 SELECT *,count(*) OVER(PARTITION BY debit_id) debit_count,
 count(*) OVER(PARTITION BY credit_id) credit_count FROM eligible_pairs
), own_pairs AS MATERIALIZED (
 SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
), own_legs AS (
 SELECT debit_id id,credit_id counterparty_id FROM own_pairs
 UNION ALL SELECT credit_id,debit_id FROM own_pairs
 )
 SELECT coalesce(jsonb_agg(x||CASE WHEN p.id IS NOT NULL THEN jsonb_build_object(
 'category','Movimentação interna','internal_transfer',true,'excluded',true,
 'excluded_from_spend',true,'classification_confirmed',true,
 'classification_basis','posted_pair_same_owner_cpf_and_bank_routing',
 'own_transfer_counterparty_id',p.counterparty_id) ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN own_legs p ON p.id::text=x->>'open_finance_id';
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
  outdays:='[]';out_day_rows:=ARRAY[]::jsonb[];
  FOR d IN SELECT x FROM jsonb_array_elements(coalesce(f#>ARRAY[part,'days'],'[]')) x WHERE (x->>'date')::date BETWEEN p_from AND p_to ORDER BY x->>'date' LOOP
   dt:=(d->>'date')::date;
   -- A later primary position must never replace an earlier day's anchor.
   SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry
    WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%'
    AND (canonical_value->>'as_of')::date<=least(dt,current_date)
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;
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
    IF dt>=(cofrinho->>'as_of')::date THEN d0:=public.lts_cofrinho_effective_locked_v245(u,dt);
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
   out_day_rows:=array_append(out_day_rows,d);
  END LOOP;
  outdays:=to_jsonb(out_day_rows);
  f:=jsonb_set(f,ARRAY[part],coalesce(f->part,'{}')||jsonb_build_object('days',outdays,'events',coalesce((SELECT jsonb_agg(x ORDER BY x->>'event_date',x->>'source_ref')
   FROM jsonb_array_elements(events) x WHERE (x->>'event_date')::date BETWEEN p_from AND p_to
    AND case when part='historical' then (x->>'event_date')::date<current_date else (x->>'event_date')::date>=current_date end),'[]')));
 END LOOP;
 f:=f||jsonb_build_object('from',p_from,'to',p_to,'observed_bank_movements',jsonb_build_object('version','v229','added_count',jsonb_array_length(added),'documentary_gaps',gaps,'position_gap_dates',gap_dates,'pending_projections',pending_predictions,
  'matched_projections',coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM public.lts_payroll_bank_matches_v231(u) m),'[]'::jsonb)));

 RETURN result||jsonb_build_object('flow',public.lts_flow_review_overlay_v229(u,f),'version','browser-flow-v229-consistent-evidence','reader_revision','v231-forward-realized-ledger');
END $function$
$definition$;
 IF before_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='public.lts_browser_flow_pre_v238(date,date)'::regprocedure) THEN RAISE EXCEPTION 'V261 ACL changed';END IF;
 SELECT pg_get_functiondef('public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure;
 IF md5(d)<>'eb9e748d2501b277d0141a92075acf9c' THEN RAISE EXCEPTION 'V261 lease changed: lts_flow_cache_pre_v240(uuid,date,date)'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_flow_cache_pre_v240(p_user_id uuid, p_from date, p_to date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
 SET statement_timeout TO '18s'
AS $function$
DECLARE
 u uuid:=p_user_id; anchors jsonb; positions jsonb; own_global_return boolean; fgts_receipt jsonb;
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
 IF lo IS NULL OR p_to<=lo OR p_from>current_date THEN RETURN public.lts_flow_cache_base_v240(u,p_from,p_to); END IF;
 -- A complete recent context makes balances independent of the selected range.
 result:=public.lts_flow_cache_base_v240(u,p_from,p_to); f:=result->'flow';
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
  -- A combined posted receipt replaces its two scheduled components, with no new bank credit.
  fgts_receipt:=public.lts_bank_fgts_combined_receipt_v261(u,s.id);
  IF fgts_receipt IS NOT NULL THEN
   SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
    WHERE NOT ((x->>'source'='current_event') AND fgts_receipt->'projection_refs' ? (x->>'source_ref'));
   e:=jsonb_build_object('source','open_finance','source_ref',s.id,'open_finance_id',s.id,
    'event_date',s.posting_date,'account',s.bank,'account_attribution','assigned',
    'description','Resgate FGTS','signed_amount',s.signed_amount,'direction','entrada',
    'confidence','bank_posted','bank_confirmed',true,'category','Resgate FGTS',
    'internal_transfer',true,'asset_movement',true,'is_asset_movement',true,
    'excluded',true,'excluded_from_spend',true,'classification_confirmed',true,
    'classification_basis',fgts_receipt->>'basis','receipt_composition',fgts_receipt);
   recent:=recent||jsonb_build_array(e);added:=added||jsonb_build_array(e);
   CONTINUE;
  END IF;
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
    OR x->>'open_finance_id'=s.id::text OR public.lts_documented_bank_event_identity_v240(u,s.id,x));
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
 -- A validated forecast is still a forecast until its own occurrence is bank-confirmed.
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date<current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_past_projection',true) ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x;
 -- Past/current projections are not posted cash. Retain them for review, never erase.
 SELECT coalesce(jsonb_agg(x),'[]') INTO pending_predictions FROM jsonb_array_elements(recent) x
  WHERE NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND (x->>'confidence' IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') OR coalesce((x->>'unposted_past_projection')::boolean,false))
  AND (x->>'event_date')::date>(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x),'[]') INTO recent FROM jsonb_array_elements(recent) x
  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))
  OR (x->>'event_date')::date<=(SELECT (anchor_item->>'date')::date FROM jsonb_array_elements(anchors) anchor_item WHERE anchor_item->>'bank'=x->>'account');
 SELECT coalesce(jsonb_agg(x||CASE WHEN k.c->>'category' IS NOT NULL THEN jsonb_build_object(
  'category',k.c->>'category','center_cost',k.c->>'beneficiary','classification_confirmed',true,'classification_basis',k.c->>'basis') ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN LATERAL(SELECT public.lts_bank_known_classification_v231(u,(x->>'open_finance_id')::uuid) c WHERE x->>'open_finance_id' IS NOT NULL) k ON true;
 WITH posted AS MATERIALIZED (
 SELECT tx_s.*,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,payer,documentNumber,value}','[^0-9]','','g') payer_cpf,
 regexp_replace(tx_s.raw_payload#>>'{paymentData,receiver,documentNumber,value}','[^0-9]','','g') receiver_cpf
 FROM public.lts_bank_posted_rows_v231(u) tx_s
), owned_identity AS MATERIALIZED (
 SELECT DISTINCT tx_s.institution_code,tx_s.provider_account_ref,
 regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') cpf
 FROM public.lts_open_finance_staging tx_s
 WHERE tx_s.user_id=u AND tx_s.resource_type='balance' AND tx_s.provider_deleted_at IS NULL
 AND tx_s.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
 AND nullif(tx_s.provider_account_ref,'') IS NOT NULL
 AND regexp_replace(tx_s.raw_payload->>'taxNumber','[^0-9]','','g') ~ '^[0-9]{11}$'
), eligible_pairs AS MATERIALIZED (
 SELECT tx_d.id debit_id,tx_c.id credit_id
 FROM posted tx_d JOIN posted tx_c ON tx_c.user_id=tx_d.user_id
 AND tx_c.posting_date=tx_d.posting_date AND tx_c.signed_amount=-tx_d.signed_amount
 AND tx_c.institution_code<>tx_d.institution_code
 JOIN owned_identity od ON od.institution_code=tx_d.institution_code
 AND od.provider_account_ref=tx_d.provider_account_ref AND od.cpf=tx_d.payer_cpf
 JOIN owned_identity oc ON oc.institution_code=tx_c.institution_code
 AND oc.provider_account_ref=tx_c.provider_account_ref AND oc.cpf=tx_c.receiver_cpf
 WHERE tx_d.signed_amount<0 AND tx_c.signed_amount>0
 AND tx_d.institution_code IN ('341','237','336') AND tx_c.institution_code IN ('341','237','336')
 AND tx_d.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_d.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,payer,documentNumber,type}'='CPF'
 AND tx_c.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF'
 AND tx_d.payer_cpf~'^[0-9]{11}$' AND tx_d.payer_cpf=tx_d.receiver_cpf
 AND tx_c.payer_cpf=tx_d.payer_cpf AND tx_c.receiver_cpf=tx_d.receiver_cpf
 AND tx_d.raw_payload#>>'{paymentData,receiver,routingNumber}'=tx_c.institution_code
 AND tx_c.raw_payload#>>'{paymentData,payer,routingNumber}'=tx_d.institution_code
), counted_pairs AS (
 SELECT *,count(*) OVER(PARTITION BY debit_id) debit_count,
 count(*) OVER(PARTITION BY credit_id) credit_count FROM eligible_pairs
), own_pairs AS MATERIALIZED (
 SELECT debit_id,credit_id FROM counted_pairs WHERE debit_count=1 AND credit_count=1
), own_legs AS (
 SELECT debit_id id,credit_id counterparty_id FROM own_pairs
 UNION ALL SELECT credit_id,debit_id FROM own_pairs
 )
 SELECT coalesce(jsonb_agg(x||CASE WHEN p.id IS NOT NULL THEN jsonb_build_object(
 'category','Movimentação interna','internal_transfer',true,'excluded',true,
 'excluded_from_spend',true,'classification_confirmed',true,
 'classification_basis','posted_pair_same_owner_cpf_and_bank_routing',
 'own_transfer_counterparty_id',p.counterparty_id) ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent) x
 LEFT JOIN own_legs p ON p.id::text=x->>'open_finance_id';
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
   -- A later primary position must never replace an earlier day's anchor.
   SELECT canonical_value INTO morgan FROM public.lts_validated_lock_registry
    WHERE superseded_at IS NULL AND lock_key LIKE 'morgan_available_%'
    AND (canonical_value->>'as_of')::date<=least(dt,current_date)
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1;
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
$definition$;
 IF before_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='public.lts_flow_cache_pre_v240(uuid,date,date)'::regprocedure) THEN RAISE EXCEPTION 'V261 ACL changed';END IF;
 SELECT pg_get_functiondef('public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure),proacl INTO d,before_acl FROM pg_proc WHERE oid='public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure;
 IF md5(d)<>'e02888e78cf6e972ce80325e44fcfe37' THEN RAISE EXCEPTION 'V261 lease changed: lts_review_suggestions_v231(uuid,jsonb)'; END IF;
 EXECUTE $definition$CREATE OR REPLACE FUNCTION public.lts_review_suggestions_v231(p_user_id uuid, p_targets jsonb)
 RETURNS TABLE(source_table text, source_ref text, suggestion jsonb)
 LANGUAGE sql
 STABLE
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
WITH targets AS MATERIALIZED (
 SELECT t.*,coalesce(s.resource_type='transaction' AND s.signed_amount<0 AND s.normalized_payload->>'operation_type' IN('PIX','TED') AND s.raw_payload#>>'{paymentData,receiver,documentNumber,type}'='CPF',false) person_transfer,
 public.lts_card_merchant_key_v226(t.description) merchant_key,
  public.lts_bank_merchant_key_v231(t.description) bank_key,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}' last4,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END installments,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' THEN ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date::text ELSE left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) END purchase_date
 FROM jsonb_to_recordset(p_targets) t(source_table text,source_ref text,description text,amount numeric,event_date date,category text,question_kind text)
 LEFT JOIN public.lts_open_finance_staging s ON t.source_table='lts_open_finance_staging' AND s.user_id=p_user_id AND s.id::text=t.source_ref
), raw_history AS MATERIALIZED (
 SELECT 'card_purchase_detail'::text st,p.line_key sr,p.description_raw description,p.category,p.installment_amount amount,
  p.invoice_due_date event_date,p.purchase_date,p.card_final last4,p.installments,null::text person,null::text property_code
 FROM public.lts_card_purchase_detail p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'financial_events',p.id::text,p.description_raw,p.category,abs(p.amount),p.event_date,null,null,null,
  coalesce(p.metadata->>'center_cost',p.metadata->>'cost_center',p.metadata#>>'{user_classification_20260913,beneficiary}'),null
 FROM public.financial_events p WHERE p.user_id=p_user_id AND NOT p.is_suppressed AND NOT p.is_projection
 UNION ALL
 SELECT 'lts_document_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_document_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_manual_card_purchase',p.id::text,p.description,p.category,p.amount,p.purchase_date,p.purchase_date,
  p.metadata->>'last4',null,p.cost_center,null FROM public.lts_manual_card_purchase p WHERE p.user_id=p_user_id AND p.status<>'cancelled'
 UNION ALL
 SELECT 'lts_card_history_recovered_purchase',p.source_hash,p.description_raw,coalesce(p.canonical_category,p.category_raw),p.amount,p.invoice_due_date,
  null,p.card_final,null,p.evidence->>'center_cost',null FROM public.lts_card_history_recovered_purchase p WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'card_invoice_current_items',p.id::text||':'||(i->>'source_line'),i->>'description',i->>'category',
  CASE WHEN coalesce(i->>'amount','') ~ '^-?[0-9]+([.][0-9]+)?$' THEN (i->>'amount')::numeric END,
  p.due_date,CASE WHEN i->>'purchase_date' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN (i->>'purchase_date')::date END,
  coalesce(i->>'last4',i->>'card_final'),CASE WHEN i->>'total_installments' ~ '^[0-9]+$' THEN (i->>'total_installments')::int END,
  coalesce(i->>'cost_center',i->>'center_cost'),null
 FROM public.card_invoices p CROSS JOIN LATERAL jsonb_array_elements(coalesce(p.metadata->'items','[]')) i WHERE p.user_id=p_user_id
 UNION ALL
 SELECT 'lts_open_finance_staging',s.id::text,s.description_raw,d.category_label,abs(s.signed_amount),s.posting_date,
  CASE WHEN s.raw_payload#>>'{creditCardMetadata,purchaseDate}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T' THEN ((s.raw_payload#>>'{creditCardMetadata,purchaseDate}')::timestamptz AT TIME ZONE 'America/Sao_Paulo')::date WHEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10) ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN left(s.raw_payload#>>'{creditCardMetadata,purchaseDate}',10)::date END,
  s.raw_payload#>>'{creditCardMetadata,cardNumber}',CASE WHEN s.raw_payload#>>'{creditCardMetadata,totalInstallments}' ~ '^[0-9]+$' THEN (s.raw_payload#>>'{creditCardMetadata,totalInstallments}')::int END,
  d.beneficiary,d.property_code
 FROM public.lts_open_finance_staging s JOIN public.lts_v178_review_decision d ON d.user_id=s.user_id AND d.source_table='lts_open_finance_staging' AND d.source_ref=s.id::text
 WHERE s.user_id=p_user_id AND s.provider_deleted_at IS NULL
 UNION ALL
 SELECT 'historico_analitico',h.idx::text,h.dados->>'desc',coalesce(h.dados->>'categoria',h.dados->>'cat'),
  abs((h.dados->>'valor')::numeric), (h.dados->>'dia')::date,null,null,null,coalesce(h.dados->>'center_cost',h.dados->>'cost_center'),null
 FROM public.historico_analitico h WHERE h.usuario_id=p_user_id AND h.dados->>'valor' ~ '^-?[0-9]+([.][0-9]+)?$'
  AND h.dados->>'dia' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
), history AS MATERIALIZED (
 SELECT h.*,coalesce(d.category_label,h.category) decided_category,
  coalesce(d.beneficiary,h.person,substring(coalesce(d.category_label,h.category) from '^(Lucas|Larissa|Benjamin)')) decided_person,
  coalesce(d.property_code,h.property_code) decided_property,
  public.lts_card_merchant_key_v226(h.description) merchant_key,public.lts_bank_merchant_key_v231(h.description) bank_key
 FROM raw_history h LEFT JOIN public.lts_v178_review_decision d ON d.user_id=p_user_id AND d.source_table=h.st AND d.source_ref=h.sr
 WHERE pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(coalesce(d.category_label,h.category),''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\s+',' ','g') NOT IN ('','a classificar','nao identificado','sem categoria','—')
), candidates AS (
 SELECT t.source_table,t.source_ref,h.decided_category category,h.decided_person person,h.decided_property property_code,
  CASE WHEN h.st='lts_open_finance_staging' AND t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<.005 THEN 10
       WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 15
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 20
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 AND t.last4=h.last4 THEN 25
       ELSE 45 END priority,
  CASE WHEN t.last4=h.last4 AND t.installments=h.installments AND t.purchase_date=h.purchase_date::text AND abs(t.amount-h.amount)<=.05 THEN 'same_purchase_installments'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<.005 THEN 'same_merchant_amount_history'
       WHEN t.merchant_key=h.merchant_key AND abs(t.amount-h.amount)<=.05 THEN 'merchant_card_near_amount_history'
       ELSE 'merchant_history' END basis,
  jsonb_build_object('source_table',h.st,'source_ref',h.sr,'date',h.event_date,'description',h.description,'amount',h.amount,'category',h.decided_category) evidence,
  null::text note,null::text source_url
 FROM targets t JOIN history h ON (t.merchant_key=h.merchant_key OR t.bank_key=h.bank_key)
  AND NOT (h.st=t.source_table AND h.sr=t.source_ref)
 WHERE (t.question_kind='classification'
 OR (t.question_kind='person' AND h.decided_person IS NOT NULL AND abs(t.event_date-h.event_date)<=100)
 OR (t.question_kind IN ('property','property_purpose') AND h.decided_property IS NOT NULL AND abs(t.event_date-h.event_date)<=100))
 AND (t.merchant_key !~ 'mercado|amazon|shopee|pagseguro|merpago' OR abs(t.amount-h.amount)<=.05)
 UNION ALL
 SELECT t.source_table,t.source_ref,r.category,r.center_cost,null,35,'confirmed_rule',
  jsonb_build_object('rule',r.id,'description',r.match_value,'category',r.category),null,null
 FROM targets t JOIN public.lts_semantic_rule r ON r.user_id=p_user_id AND r.active
  AND r.confidence IN ('user_confirmed','high','alta','system_high')
  AND ((r.match_type='exact' AND public.lts_card_merchant_key_v226(r.match_value)=t.merchant_key)
   OR (r.match_type='prefix' AND public.lts_bank_merchant_key_v231(r.match_value)=t.bank_key))
 WHERE t.question_kind='classification'
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,50,s.basis,'{}',s.note,s.source_url
 FROM targets t JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
 UNION ALL
 SELECT t.source_table,t.source_ref,s.category,null,null,60,'public_merchant_source','{}',s.note,s.source_url
 FROM targets t JOIN public.lts_merchant_research_v231 s ON s.user_id=p_user_id AND s.merchant_key=t.merchant_key
 WHERE t.question_kind='classification' AND s.category IS NOT NULL
), ranked AS (
 SELECT *,min(priority) OVER(PARTITION BY source_table,source_ref) best FROM candidates
), best AS (
 SELECT source_table,source_ref,count(DISTINCT category) category_count,
  CASE WHEN count(DISTINCT category)=1 THEN min(category) END category,
  CASE WHEN count(DISTINCT person)=1 THEN min(person) END person,
  CASE WHEN count(DISTINCT property_code)=1 THEN min(property_code) END property_code,
  min(basis) basis,min(note) note,min(source_url) source_url,count(*) evidence_count,
  (jsonb_agg(DISTINCT evidence))->0 evidence,
  jsonb_agg(DISTINCT category) alternatives
 FROM ranked WHERE priority=best GROUP BY source_table,source_ref
)
SELECT t.source_table,t.source_ref,
 CASE WHEN t.person_transfer AND t.question_kind='classification' THEN jsonb_build_object('category',null,'requires_confirmation',true,'alternatives','[]'::jsonb,'basis','recipient_does_not_establish_purpose','note','O destinatário não comprova a finalidade desta transferência. Confirme o que foi pago.')
 WHEN b.category IS NOT NULL THEN jsonb_build_object('category',b.category,'beneficiary',b.person,'property_code',b.property_code,
  'basis',b.basis,'source_url',b.source_url,'evidence_count',b.evidence_count,'evidence',b.evidence,'requires_confirmation',true,
  'note',coalesce(b.note,CASE b.basis
   WHEN 'same_purchase_installments' THEN 'Sugestão baseada em parcela da mesma compra. Confira e confirme.'
   WHEN 'same_merchant_amount_history' THEN 'Mesmo estabelecimento e valor no histórico. Confira e confirme.'
   WHEN 'merchant_card_near_amount_history' THEN 'Mesmo estabelecimento e cartão; pequena diferença de centavos entre parcelas. Confira e confirme.'
   WHEN 'confirmed_rule' THEN 'Regra já confirmada no histórico. Confira se vale para esta compra.'
   ELSE 'Sugestão do histórico deste estabelecimento. Confira e confirme.' END))
 ELSE jsonb_build_object('category',null,'requires_confirmation',true,
  'alternatives',coalesce(b.alternatives,'[]'),'basis',CASE WHEN b.category_count>1 THEN 'conflicting_history' ELSE 'insufficient_evidence' END,
  'note',coalesce(r.note,s.note,CASE WHEN b.category_count>1 THEN 'O histórico tem classificações diferentes; confirme a finalidade deste lançamento.'
   WHEN t.question_kind='property' THEN 'A categoria está preservada. Falta somente identificar o imóvel.'
   WHEN t.question_kind='person' THEN 'A categoria está preservada. Falta somente identificar a pessoa.'
   WHEN t.merchant_key ~ 'mercado|amazon|shopee|pagseguro|merpago' THEN 'O nome identifica a plataforma, mas não o produto. A finalidade permanece a confirmar.'
   ELSE 'Não encontrei correspondência suficiente para sugerir com segurança.' END),'source_url',coalesce(r.source_url,s.source_url)) END
FROM targets t LEFT JOIN best b USING(source_table,source_ref)
LEFT JOIN public.lts_merchant_research_v231 r ON r.user_id=p_user_id AND r.merchant_key=t.merchant_key
LEFT JOIN public.lts_v229_review_suggestion s ON s.user_id=p_user_id AND s.source_table=t.source_table AND s.source_ref=t.source_ref
$function$
$definition$;
 IF before_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='public.lts_review_suggestions_v231(uuid,jsonb)'::regprocedure) THEN RAISE EXCEPTION 'V261 ACL changed';END IF;
END $patch$;

