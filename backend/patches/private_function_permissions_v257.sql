-- Close anonymous access without changing any function body or table policy.
DO $lease$ DECLARE r record;sig text; BEGIN
 FOR r IN SELECT * FROM(VALUES
  ('lts_open_finance_enqueue_bank_probe_v1','p_url text, p_code text','2225c2234f944661824a495404fa759b'),
  ('lts_cipo_cashflow_reconciliation_qa_v1','','bd56409fe705b6527d70690e6a982ffc'),
  ('lts_expense_history_anchor_qa_v1','','0485d913124eaa23bc79afaace0429ee'),
  ('lts_card_history_recovery_qa_v1','','e7fbc7dfad56f499a218f759136dad73'),
  ('lts_cipo_summary_qa_v1','','b744c4f24ca0477c5b963f466c538cdf'),
  ('lts_validated_lock_gate_v1','','2d8f36be3a084005ff3f72ee8325b592'),
  ('lts_expense_signed_economic_qa_v3','p_user_id uuid','c6f47834fd635fd7f4872ae384554928'),
  ('lts_open_finance_current_bank_position_v1','p_user_id uuid','4380100d2159de06ff93b36f0ba21297'),
  ('lts_browser_current_liquidity_v1','','578225d925a47910fbcaa5a87f2be2d2'),
  ('lts_current_cash_release_qa_v1','','f36bca4d49d046c6756c30f06a896015'),
  ('lts_flow_current_anchor_qa_v1','','f9e1009046dc2d2bd18fc921c66f7b45'),
  ('lts_planning_current_release_qa_v1','','69a3dca333836cf912e74c5b9dd77c58'),
  ('lts_planning_ui_release_qa_v1','','0436abefaf4d1c8d30f6622ac633e6fe'),
  ('lts_refresh_product_read_cache_operational_v5','p_user_id uuid','952a64ab6d57634f488ae1fdda378934'),
  ('lts_open_finance_multibank_qa_v1','','fdeb0737e26a9f5d9ec597bcef802c0d'),
  ('lts_current_evidence_position_v2','p_user_id uuid','bb5f404ad0d2cd23afca5551d50f80ad'),
  ('lts_apply_current_liquidity_anchor_v1','p_user_id uuid','031583a065b1585710b386ec57cf7d45'),
  ('lts_browser_planning_ui_contract_v1','','6d1fbbc6fee3dace3a218a029deb27e8')
 )v(fn,args,expected_hash) LOOP
sig:='public.'||r.fn||'('||regexp_replace(r.args,'(^|, )[^ ]+ ','\1','g')||')';
 IF md5(btrim(pg_get_functiondef(sig::regprocedure),E' \t\r\n')) IS DISTINCT FROM r.expected_hash THEN RAISE EXCEPTION 'V257_ACL_SOURCE_LEASE_CHANGED %',r.fn;END IF;
 END LOOP;
END $lease$;
REVOKE ALL ON FUNCTION public.lts_open_finance_enqueue_bank_probe_v1(p_url text, p_code text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_cipo_cashflow_reconciliation_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_expense_history_anchor_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_card_history_recovery_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_cipo_summary_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_validated_lock_gate_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_expense_signed_economic_qa_v3(p_user_id uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_open_finance_current_bank_position_v1(p_user_id uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_current_liquidity_v1() FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.lts_current_cash_release_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_flow_current_anchor_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_planning_current_release_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_planning_ui_release_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_refresh_product_read_cache_operational_v5(p_user_id uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_open_finance_multibank_qa_v1() FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_current_evidence_position_v2(p_user_id uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_apply_current_liquidity_anchor_v1(p_user_id uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.lts_browser_planning_ui_contract_v1() FROM PUBLIC,anon;
