-- Label only a newly confirmed net-receipt bridge whose gross trade valuation is unproven.
DO $patch$
DECLARE d text; prior_acl aclitem[];
BEGIN
 SELECT pg_get_functiondef('public.lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure),proacl INTO d,prior_acl
 FROM pg_proc WHERE oid='public.lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure;
 IF md5(d)<>'566882d7ddcdaf5f673f3fbf85814f05' THEN RAISE EXCEPTION 'V259 interim basis definition lease failed'; END IF;
 IF position($old$'brokerage_settled_withdrawals',debit)) ELSE d END d$old$ IN d)=0 THEN RAISE EXCEPTION 'V259 interim basis replacement absent'; END IF;
 d:=replace(d,$old$'brokerage_settled_withdrawals',debit)) ELSE d END d$old$,$new$'brokerage_settled_withdrawals',debit) ||
  CASE WHEN EXISTS (
   SELECT 1 FROM jsonb_array_elements(coalesce(a#>'{policy,brokerage_withdrawals}','[]')) w
   WHERE coalesce((w->>'trade_gross_fx_and_quantity_not_inferred')::boolean,false)
   AND (w->>'settled_on')::date<=(d->>'date')::date
   AND (w->>'settled_on')::date>(
    SELECT (canonical_value->>'as_of')::date FROM public.lts_validated_lock_registry
    WHERE lock_key LIKE 'morgan_available_%' AND superseded_at IS NULL
    AND (canonical_value->>'as_of')::date<=(d->>'date')::date
    ORDER BY (canonical_value->>'as_of')::date DESC,lock_key DESC LIMIT 1)
  ) THEN jsonb_build_object('brokerage_resource_basis','interim_net_receipt_bridge_not_exact_trade_position',
   'brokerage_position_is_statement',false,'brokerage_gross_settlement_unverified',true)
  ELSE '{}'::jsonb END) ELSE d END d$new$);
 EXECUTE d;
 IF prior_acl IS DISTINCT FROM (SELECT proacl FROM pg_proc WHERE oid='public.lts_flow_liquidity_adjustments_v242(uuid,jsonb,date)'::regprocedure) THEN RAISE EXCEPTION 'V259 interim basis ACL changed'; END IF;
 UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1 WHERE singleton;
END $patch$;

