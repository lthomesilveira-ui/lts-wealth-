CREATE VIEW public.lts_expense_realized WITH(security_invoker=true) AS
 SELECT user_id,
    source_table,
    source_ref,
    event_date,
    description_raw,
    account_raw,
    category_raw,
    macro_raw,
    direction,
    amount,
    is_future_vs_checkpoint,
    raw_payload,
    semantic_rule_id,
    semantic_nature,
    category_candidate,
    counterparty_candidate,
    center_cost_candidate,
    is_internal_transfer,
    is_asset_movement,
    exclude_from_spend,
    semantic_confidence,
    (EXISTS ( SELECT 1
           FROM lts_projection_replacement_rule rr
          WHERE rr.active AND (rr.user_id IS NULL OR rr.user_id = c.user_id) AND rr.source_table = c.source_table AND lower(TRIM(BOTH FROM rr.description_exact)) = lower(TRIM(BOTH FROM c.description_raw)) AND (rr.account_exact IS NULL OR lower(TRIM(BOTH FROM rr.account_exact)) = lower(TRIM(BOTH FROM c.account_raw))) AND c.event_date >= rr.date_from AND c.event_date <= rr.date_to AND (rr.action = ANY (ARRAY['replace_legacy'::text, 'suppress_legacy'::text])))) AS superseded_or_suppressed_legacy
   FROM lts_expense_analytics_candidate c
  WHERE is_future_vs_checkpoint = false;
GRANT ALL ON public.lts_expense_realized TO service_role;
