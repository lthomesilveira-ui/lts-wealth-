-- V301: run separately for each private settlement identity.
-- Caller sets lts.qa_user_id and lts.qa_payment_id locally.
WITH c AS MATERIALIZED(SELECT * FROM public.lts_card_settlement_expense_contract_v273 WHERE user_id=current_setting('lts.qa_user_id')::uuid AND active AND payment_source_id=current_setting('lts.qa_payment_id')::uuid),
l AS MATERIALIZED(SELECT to_jsonb(l) j FROM public.lts_card_documentary_payment_link_v272 l,c WHERE l.user_id=c.user_id AND l.payment_source_id=c.payment_source_id AND l.active),
b AS MATERIALIZED(SELECT to_jsonb(s) j FROM public.lts_open_finance_staging s,l WHERE s.id::text=l.j->>'invoice_source_id'),
p AS MATERIALIZED(SELECT to_jsonb(s) j FROM public.lts_open_finance_staging s,l WHERE s.id::text=l.j->>'payment_source_id'),
items AS MATERIALIZED(SELECT jsonb_agg(to_jsonb(s) ORDER BY s.id) j FROM public.lts_open_finance_staging s,c,b
 WHERE s.user_id=c.user_id AND s.resource_type='card_transaction' AND s.provider_deleted_at IS NULL
 AND s.provider_account_ref=b.j->>'provider_account_ref' AND s.institution_code=b.j->>'institution_code'
 AND s.raw_payload#>>'{creditCardMetadata,billId}'=b.j#>>'{normalized_payload,provider_id}'),
cov AS MATERIALIZED(SELECT coalesce(jsonb_agg(jsonb_build_object('source_ref',e.source_ref,'amount',e.amount,'competence_month',e.competence_month,'coverage_mode',e.coverage_mode)),'[]') j
 FROM c CROSS JOIN LATERAL public.lts_expense_effective_rows_v176(c.user_id,(c.payload->>'competence_month')::date,
 ((c.payload->>'competence_month')::date+interval '1 month -1 day')::date)e
 WHERE e.source_table='lts_open_finance_staging' AND e.source_ref IN(SELECT m->>'id' FROM jsonb_array_elements(c.payload->'consumption_manifest')m)),
cases AS(
 SELECT v.name,v.expected,public.lts_card_settlement_evidence_valid_v273(v.uid,c.payment_source_id,v.link,v.bill,v.pay,v.items,current_date,v.contract,v.coverage) actual
 FROM c,l,b,p,items,cov CROSS JOIN LATERAL(VALUES
 ('positive',true,c.user_id,l.j,b.j,p.j,items.j,c.payload,cov.j),
 ('order_and_update_only',true,c.user_id,l.j,b.j,p.j,jsonb_set(jsonb_set(items.j,'{0,raw_payload,order}','999999'),'{0,raw_payload,updatedAt}','"2026-10-19T23:00:00Z"'),c.payload,cov.j),
 ('wrong_owner',false,'00000000-0000-4000-8000-000000000000'::uuid,l.j,b.j,p.j,items.j,c.payload,cov.j),
 ('inactive_link',false,c.user_id,l.j||'{"active":false}',b.j,p.j,items.j,c.payload,cov.j),
 ('inactive_contract',false,c.user_id,l.j,b.j,p.j,items.j,c.payload||'{"active":false}',cov.j),
 ('wrong_payment_amount',false,c.user_id,l.j,b.j,p.j||jsonb_build_object('signed_amount',(p.j->>'signed_amount')::numeric-0.01),items.j,c.payload,cov.j),
 ('wrong_invoice_amount',false,c.user_id,l.j,b.j||jsonb_build_object('signed_amount',(b.j->>'signed_amount')::numeric+0.01),p.j,items.j,c.payload,cov.j),
 ('changed_due_date',false,c.user_id,l.j,jsonb_set(b.j,'{normalized_payload,due_date}','"2026-10-13"'),p.j,items.j,c.payload,cov.j),
 ('deleted_invoice',false,c.user_id,l.j,b.j||'{"provider_deleted_at":"2026-10-19T20:00:00Z"}',p.j,items.j,c.payload,cov.j),
 ('pending_payment',false,c.user_id,l.j,b.j,jsonb_set(p.j,'{normalized_payload,status}','"PENDING"'),items.j,c.payload,cov.j),
 ('wrong_currency',false,c.user_id,l.j,b.j,p.j||'{"currency":"USD"}',items.j,c.payload,cov.j),
 ('missing_purchase',false,c.user_id,l.j,b.j,p.j,items.j-0,c.payload,cov.j),
 ('duplicate_purchase',false,c.user_id,l.j,b.j,p.j,items.j||jsonb_build_array(items.j->0),c.payload,cov.j),
 ('changed_purchase_amount',false,c.user_id,l.j,b.j,p.j,jsonb_set(items.j,'{0,signed_amount}',to_jsonb((items.j#>>'{0,signed_amount}')::numeric+0.01)),c.payload,cov.j),
 ('substantive_description_change',false,c.user_id,l.j,b.j,p.j,jsonb_set(items.j,'{0,raw_payload,description}','"CHANGED FINANCIAL SOURCE"'),c.payload,cov.j),
 ('foreign_bill_purchase',false,c.user_id,l.j,b.j,p.j,jsonb_set(items.j,'{0,raw_payload,creditCardMetadata,billId}','"other-bill"'),c.payload,cov.j),
 ('missing_coverage',false,c.user_id,l.j,b.j,p.j,items.j,c.payload,cov.j-0),
 ('duplicate_coverage',false,c.user_id,l.j,b.j,p.j,items.j,c.payload,cov.j||jsonb_build_array(cov.j->0)),
 ('changed_coverage_amount',false,c.user_id,l.j,b.j,p.j,items.j,c.payload,jsonb_set(cov.j,'{0,amount}',to_jsonb((cov.j#>>'{0,amount}')::numeric+0.01))),
 ('changed_coverage_month',false,c.user_id,l.j,b.j,p.j,items.j,c.payload,jsonb_set(cov.j,'{0,competence_month}','"2026-11-01"')),
 ('changed_coverage_basis',false,c.user_id,l.j,b.j,p.j,items.j,c.payload,jsonb_set(cov.j,'{0,coverage_mode}','"unverified"'))
 )v(name,expected,uid,link,bill,pay,items,contract,coverage))
SELECT jsonb_build_object('cases',count(*),'passed',count(*)=21 AND bool_and(actual IS NOT DISTINCT FROM expected),
 'failed',coalesce(jsonb_agg(name)FILTER(WHERE actual IS DISTINCT FROM expected),'[]')) receipt FROM cases;
