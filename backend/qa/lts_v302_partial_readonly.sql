-- Private owner-scoped administrative verification; manifest is not committed.
BEGIN READ ONLY;
SET LOCAL timezone='America/Sao_Paulo';
SET LOCAL statement_timeout='25s';
WITH manifest AS(SELECT current_setting('lts.v302.input')::jsonb m),
owner AS(SELECT public.lts_open_finance_pilot_owner_v1() u),
binding AS(SELECT r.* FROM public.lts_realized_bank_event_v238 r CROSS JOIN manifest CROSS JOIN owner
 WHERE r.user_id=u AND r.financial_event_id=(m->>'event_id')::uuid),
expense AS(SELECT r.* FROM manifest CROSS JOIN owner
 CROSS JOIN LATERAL public.lts_v229_expense_rows(u,'2013-10-10',current_date)r
 WHERE (r.source_table='financial_events' AND r.source_ref=m->>'event_id') OR r.source_ref=m->>'bank_source_id'),
ledger AS(SELECT r.* FROM manifest CROSS JOIN owner
 CROSS JOIN LATERAL public.lts_historical_effective_cash_v5(u,'2013-10-10',current_date)r
 WHERE r.source_ref IN(m->>'event_id',m->>'bank_source_id','financial_events:'||(m->>'event_id')))
SELECT jsonb_build_object('valid_binding_count',(SELECT count(*) FROM binding r
 JOIN public.financial_events f ON f.user_id=r.user_id AND f.id=r.financial_event_id
 JOIN public.lts_open_finance_staging s ON s.user_id=r.user_id AND s.id=r.staging_id
 WHERE public.lts_partial_obligation_settlement_valid_v302(to_jsonb(f),to_jsonb(s),to_jsonb(r),r.evidence)),
 'expense_occurrences',(SELECT count(*) FROM expense),'expense_amount',(SELECT sum(amount) FROM expense),
 'ledger_occurrences',(SELECT count(*) FROM ledger),'ledger_amount',(SELECT sum(signed_amount) FROM ledger),
 'bank_classification',(SELECT public.lts_bank_known_classification_v231(u,(m->>'bank_source_id')::uuid) FROM owner CROSS JOIN manifest),
 'audit_receipts',(SELECT count(*) FROM public.audit_log CROSS JOIN owner CROSS JOIN manifest
 WHERE user_id=u AND action='reconcile_confirmed_partial_obligation' AND entity_id=m->>'event_id'),
 'target_is_realized',(SELECT NOT f.is_projection AND f.status='confirmed' FROM public.financial_events f CROSS JOIN owner CROSS JOIN manifest
 WHERE f.user_id=u AND f.id=(m->>'event_id')::uuid)) receipt;
ROLLBACK;
