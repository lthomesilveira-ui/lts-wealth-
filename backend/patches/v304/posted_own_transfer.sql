-- A posted debit can retain its already-confirmed own-transfer destination.
-- This does not prove, create or synthesize a receiving bank leg.
CREATE OR REPLACE FUNCTION public.lts_posted_own_transfer_valid_v304(
 p_user_id uuid,p_source jsonb,p_confirmation jsonb,p_origin jsonb,p_destination jsonb,p_balance jsonb)
RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path='' AS $f$
SELECT coalesce(
 p_source->>'user_id'=p_user_id::text AND p_confirmation->>'user_id'=p_user_id::text
 AND p_origin->>'user_id'=p_user_id::text AND p_destination->>'user_id'=p_user_id::text
 AND p_balance->>'user_id'=p_user_id::text
 AND p_source->>'resource_type'='transaction' AND p_source->>'currency'='BRL'
 AND p_source->>'provider_deleted_at' IS NULL
 AND p_source#>>'{normalized_payload,status}'='POSTED' AND p_source#>>'{raw_payload,status}'='POSTED'
 AND p_source#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND CASE WHEN jsonb_typeof(p_source->'signed_amount')='number' THEN (p_source->>'signed_amount')::numeric<0 ELSE false END
 AND p_source#>'{normalized_payload,amount}'=p_source->'signed_amount'
 AND p_source#>'{raw_payload,amount}'=p_source->'signed_amount'
 AND p_source#>>'{raw_payload,currencyCode}'='BRL'
 AND p_source#>>'{normalized_payload,date}'=p_source->>'posting_date'
 AND nullif(p_source#>>'{normalized_payload,item_id}','') IS NOT NULL
 AND nullif(p_source#>>'{raw_payload,id}','')=p_source#>>'{normalized_payload,provider_id}'
 AND p_source->>'provider_record_id'=(p_source#>>'{normalized_payload,item_id}')||':'||(p_source#>>'{raw_payload,id}')
 AND nullif(p_source->>'provider_account_ref','')=p_source#>>'{raw_payload,accountId}'
 AND p_source->>'provider_account_ref'=p_source#>>'{normalized_payload,provider_account_id}'
 AND p_source->>'raw_hash' ~ '^[0-9a-f]{64}$'
 AND p_confirmation->>'action'='confirm_scheduled_transfer_destination'
 AND p_confirmation->>'entity_type'='open_finance_schedule'
 AND p_confirmation->>'entity_id'=p_source->>'id'
 AND p_confirmation#>>'{details,version}'='owner-schedule-destination-v292'
 AND p_confirmation#>>'{details,basis}'='owner_confirmed_registered_destination'
 AND p_confirmation#>>'{details,scope}'='destination_confirmation_only'
 AND p_confirmation#>>'{details,source_status}'='PENDING'
 AND p_confirmation#>>'{details,source_id}'=p_source->>'id'
 AND p_confirmation#>>'{details,source_raw_hash}' ~ '^[0-9a-f]{64}$'
 AND p_confirmation#>>'{details,date}'=p_source->>'posting_date'
 AND p_confirmation#>'{details,signed_amount}'=p_source->'signed_amount'
 AND p_confirmation#>>'{details,financial_effect}'='none'
 AND p_confirmation#>>'{details,does_not_mark_paid}'='true'
 AND p_confirmation#>>'{details,destination_account_id}'=p_destination->>'id'
 AND p_confirmation#>>'{details,destination_bank}'=p_destination->>'institution'
 AND p_confirmation#>>'{details,origin_bank}'=p_origin->>'institution'
 AND (p_source->>'first_seen_at')::timestamptz<=(p_confirmation->>'created_at')::timestamptz
 AND p_origin->>'id'<>p_destination->>'id'
 AND p_origin->>'is_active'='true' AND p_destination->>'is_active'='true'
 AND p_origin->>'account_type'='checking' AND p_destination->>'account_type'='checking'
 AND p_origin->>'currency'='BRL' AND p_destination->>'currency'='BRL'
 AND p_origin->>'institution'=CASE p_source->>'institution_code' WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 AND p_source#>>'{raw_payload,paymentData,receiver,routingNumber}'=CASE p_destination->>'institution' WHEN 'Itaú' THEN '341' WHEN 'Bradesco' THEN '237' WHEN 'C6' THEN '336' END
 AND p_balance->>'resource_type'='balance' AND p_balance->>'provider_deleted_at' IS NULL
 AND p_balance->>'provider_account_ref'=p_source->>'provider_account_ref'
 AND p_balance->>'institution_code'=p_source->>'institution_code'
 AND p_balance#>>'{normalized_payload,account_type}'='CHECKING_ACCOUNT'
 AND p_source#>>'{raw_payload,paymentData,payer,documentNumber,type}'='CPF'
 AND p_source#>>'{raw_payload,paymentData,receiver,documentNumber,type}'='CPF'
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')~'^[0-9]{11}$'
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')=regexp_replace(p_source#>>'{raw_payload,paymentData,payer,documentNumber,value}','[^0-9]','','g')
 AND regexp_replace(p_balance#>>'{raw_payload,taxNumber}','[^0-9]','','g')=regexp_replace(p_source#>>'{raw_payload,paymentData,receiver,documentNumber,value}','[^0-9]','','g')
,false)
$f$;
REVOKE ALL ON FUNCTION public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_posted_own_transfer_valid_v304(uuid,jsonb,jsonb,jsonb,jsonb,jsonb) TO service_role;

CREATE OR REPLACE FUNCTION public.lts_posted_own_transfer_out_v304(p_user_id uuid)
RETURNS TABLE(source_id uuid,event_date date,from_bank text,to_bank text,signed_amount numeric,source_raw_hash text,confirmation_raw_hash text)
LANGUAGE sql STABLE SET search_path='' SET timezone='America/Sao_Paulo' AS $f$
WITH matched AS MATERIALIZED (
 SELECT s.id source_id,s.posting_date event_date,o.institution from_bank,d.institution to_bank,s.signed_amount,
 s.raw_hash source_raw_hash,a.details->>'source_raw_hash' confirmation_raw_hash,d.id destination_id
 FROM public.lts_open_finance_staging s
 JOIN public.audit_log a ON a.user_id=s.user_id AND a.action='confirm_scheduled_transfer_destination'
 AND a.entity_type='open_finance_schedule' AND a.entity_id=s.id::text
 JOIN public.accounts o ON o.user_id=s.user_id AND o.is_active AND o.account_type='checking' AND o.currency='BRL'
 AND o.institution=CASE s.institution_code WHEN '341' THEN 'Itaú' WHEN '237' THEN 'Bradesco' WHEN '336' THEN 'C6' END
 JOIN public.accounts d ON d.user_id=s.user_id AND d.id::text=a.details->>'destination_account_id'
 AND d.is_active AND d.account_type='checking' AND d.currency='BRL'
 WHERE s.user_id=p_user_id AND s.resource_type='transaction' AND s.currency='BRL'
 AND s.provider_deleted_at IS NULL AND s.normalized_payload->>'status'='POSTED'
 AND s.normalized_payload->>'account_type'='CHECKING_ACCOUNT' AND s.signed_amount<0 AND s.posting_date<=current_date
 AND (SELECT count(*) FROM public.accounts x WHERE x.user_id=p_user_id AND x.is_active
 AND x.account_type='checking' AND x.currency='BRL' AND x.institution=o.institution)=1
 AND (SELECT count(*) FROM public.accounts x WHERE x.user_id=p_user_id AND x.is_active
 AND x.account_type='checking' AND x.currency='BRL' AND x.institution=d.institution)=1
 AND EXISTS(SELECT 1 FROM public.lts_open_finance_staging b WHERE b.user_id=s.user_id
 AND b.resource_type='balance' AND b.provider_account_ref=s.provider_account_ref AND b.provider_deleted_at IS NULL
 AND public.lts_posted_own_transfer_valid_v304(p_user_id,to_jsonb(s),to_jsonb(a),to_jsonb(o),to_jsonb(d),to_jsonb(b)))
)
SELECT source_id,event_date,min(from_bank),min(to_bank),signed_amount,source_raw_hash,min(confirmation_raw_hash)
FROM matched GROUP BY source_id,event_date,signed_amount,source_raw_hash HAVING count(DISTINCT destination_id)=1
$f$;
REVOKE ALL ON FUNCTION public.lts_posted_own_transfer_out_v304(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_posted_own_transfer_out_v304(uuid) TO service_role;

DO $patch$
DECLARE d text;r record;anchor text;replacement text;prior jsonb;
BEGIN
 FOR r IN SELECT * FROM(VALUES
 ('public.lts_v229_new_bank_rows(uuid,date,date)',1),
 ('public.lts_browser_flow_pre_v238(date,date)',2))x(sig,kind) LOOP
 SELECT pg_get_functiondef(oid),jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'config',proconfig,'definer',prosecdef,'volatility',provolatile)
 INTO d,prior FROM pg_proc WHERE oid=r.sig::regprocedure;
 IF d LIKE '%lts_posted_own_transfer_out_v304%' THEN CONTINUE;END IF;
 IF r.kind=1 THEN
  anchor:='AND NOT EXISTS(SELECT 1 FROM own_pairs p WHERE p.debit_id=s.id)';
  replacement:=anchor||E'\n AND NOT EXISTS(SELECT 1 FROM public.lts_posted_own_transfer_out_v304(p_user_id) ot WHERE ot.source_id=s.id)';
 ELSE
  anchor:=$a$ LEFT JOIN own_legs p ON p.id::text=x->>'open_finance_id';$a$;
  replacement:=anchor||$b$
 SELECT coalesce(jsonb_agg(x||CASE WHEN ot.source_id IS NOT NULL
 AND NOT coalesce((x->>'internal_transfer')::boolean,false) THEN jsonb_build_object(
 'category','Movimentação interna','internal_transfer',true,'excluded',true,'excluded_from_spend',true,
 'classification_confirmed',true,'classification_basis','owner_confirmed_posted_transfer_v304',
 'own_transfer_destination_bank',ot.to_bank,'own_transfer_counterleg_status','not_yet_received') ELSE '{}'::jsonb END),'[]')
 INTO recent FROM jsonb_array_elements(recent)x
 LEFT JOIN public.lts_posted_own_transfer_out_v304(u) ot ON ot.source_id::text=x->>'open_finance_id';$b$;
 END IF;
 IF (length(d)-length(replace(d,anchor,'')))/length(anchor)<>1 THEN RAISE EXCEPTION 'Posted transfer anchor changed: %',r.sig;END IF;
 EXECUTE replace(d,anchor,replacement);
 IF prior IS DISTINCT FROM(SELECT jsonb_build_object('oid',oid,'owner',proowner,'acl',proacl,'config',proconfig,'definer',prosecdef,'volatility',provolatile)
 FROM pg_proc WHERE oid=r.sig::regprocedure) THEN RAISE EXCEPTION 'Reader attributes changed';END IF;
 END LOOP;
END $patch$;
UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton=true;
