-- Caller sets lts.qa_user_id and lts.qa_evento_index; no source rows are changed.
WITH target AS (
 SELECT current_setting('lts.qa_user_id')::uuid u,
 jsonb_build_object('source','legacy_fix86','source_ref','evento_base:'||e.idx::text,
 'description',e.dados->>'desc','account','Itaú','event_date',e.dados->>'dia',
 'signed_amount',-abs((e.dados->>'valor')::numeric),'internal_transfer',false) j
 FROM public.evento_base e WHERE e.usuario_id=current_setting('lts.qa_user_id')::uuid
 AND e.idx=current_setting('lts.qa_evento_index')::integer
), cases AS (
 SELECT 'exact owned plan' name,u,j,true expected FROM target UNION ALL
 SELECT 'wrong owner','00000000-0000-0000-0000-000000000000'::uuid,j,false FROM target UNION ALL
 SELECT 'wrong bank',u,j||'{"account":"Bradesco"}',false FROM target UNION ALL
 SELECT 'wrong source',u,j||'{"source":"current_event"}',false FROM target UNION ALL
 SELECT 'wrong card',u,j||'{"description":"Visa"}',false FROM target UNION ALL
 SELECT 'changed date',u,j||jsonb_build_object('event_date',((j->>'event_date')::date+1)::text),false FROM target UNION ALL
 SELECT 'changed amount',u,j||jsonb_build_object('signed_amount',(j->>'signed_amount')::numeric-0.01),false FROM target UNION ALL
 SELECT 'credit',u,j||jsonb_build_object('signed_amount',abs((j->>'signed_amount')::numeric)),false FROM target UNION ALL
 SELECT 'wrong reference',u,j||'{"source_ref":"evento_base:missing"}',false FROM target UNION ALL
 SELECT 'own transfer',u,j||'{"internal_transfer":true}',false FROM target UNION ALL
 SELECT 'different cycle',u,j||jsonb_build_object('event_date',((j->>'event_date')::date+interval '1 month')::date::text),false FROM target UNION ALL
 SELECT 'ambiguous card',u,j||'{"description":"Mastercard ou Visa"}',false FROM target
)
SELECT name,public.lts_legacy_mastercard_settled_v291(u,j) IS NOT DISTINCT FROM expected passed
FROM cases ORDER BY name;
