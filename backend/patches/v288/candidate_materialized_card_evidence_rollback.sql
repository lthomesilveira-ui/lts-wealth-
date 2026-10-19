-- CANDIDATE ONLY: component parity passed; complete acceptance is still blocked.
BEGIN;
SET LOCAL search_path='';
-- Query-local reuse only. No new financial matching, cache, API or source policy.
DO $v288$
DECLARE before_acl aclitem[]; before_owner oid; before_oid oid; d text;
BEGIN
 SELECT pg_get_functiondef(p.oid),p.proacl,p.proowner,p.oid INTO d,before_acl,before_owner,before_oid
 FROM pg_proc p WHERE p.oid='public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure;
 IF md5(d)<>'7ad9c0296f9582e47c9a6c63cf8558d2' THEN RAISE EXCEPTION 'V288 lts_card_invoice_amounts_v230_engine_v243 definition lease changed'; END IF;
 IF (length(d)-length(replace(d,$call$public.lts_c6_cycle_identity_v269(p_user_id)$call$,'')))/length($call$public.lts_c6_cycle_identity_v269(p_user_id)$call$)<>2
 OR (length(d)-length(replace(d,$anchor$WITH c6_eligible AS MATERIALIZED ($anchor$,'')))/length($anchor$WITH c6_eligible AS MATERIALIZED ($anchor$)<>1
 THEN RAISE EXCEPTION 'V288 lts_card_invoice_amounts_v230_engine_v243 anchors changed'; END IF;
 d:=replace(d,$call$public.lts_c6_cycle_identity_v269(p_user_id)$call$,'c6_identities_v288 ');
 d:=replace(d,$anchor$WITH c6_eligible AS MATERIALIZED ($anchor$,$new$WITH c6_identities_v288 AS MATERIALIZED (
 SELECT * FROM public.lts_c6_cycle_identity_v269(p_user_id)
), c6_eligible AS MATERIALIZED ($new$);
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proacl IS DISTINCT FROM before_acl OR p.proowner<>before_owner))
 OR 'public.lts_card_invoice_amounts_v230_engine_v243(uuid)'::regprocedure::oid<>before_oid
 THEN RAISE EXCEPTION 'V288 lts_card_invoice_amounts_v230_engine_v243 privilege or identity drift'; END IF;
 SELECT pg_get_functiondef(p.oid),p.proacl,p.proowner,p.oid INTO d,before_acl,before_owner,before_oid
 FROM pg_proc p WHERE p.oid='public.lts_card_cycles_v226(uuid)'::regprocedure;
 IF md5(d)<>'c5011ceab6b5451fb5cf173523cfc40d' THEN RAISE EXCEPTION 'V288 lts_card_cycles_v226 definition lease changed'; END IF;
 IF (length(d)-length(replace(d,$call$public.lts_card_document_matches_v234(p_user_id)$call$,'')))/length($call$public.lts_card_document_matches_v234(p_user_id)$call$)<>4
 OR (length(d)-length(replace(d,$anchor$with c6_eligible AS MATERIALIZED ($anchor$,'')))/length($anchor$with c6_eligible AS MATERIALIZED ($anchor$)<>1
 THEN RAISE EXCEPTION 'V288 lts_card_cycles_v226 anchors changed'; END IF;
 d:=replace(d,$call$public.lts_card_document_matches_v234(p_user_id)$call$,'document_matches_v288 ');
 d:=replace(d,$anchor$with c6_eligible AS MATERIALIZED ($anchor$,$new$with document_matches_v288 AS MATERIALIZED (
 SELECT * FROM public.lts_card_document_matches_v234(p_user_id)
), c6_eligible AS MATERIALIZED ($new$);
 EXECUTE d;
 IF EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proacl IS DISTINCT FROM before_acl OR p.proowner<>before_owner))
 OR 'public.lts_card_cycles_v226(uuid)'::regprocedure::oid<>before_oid
 THEN RAISE EXCEPTION 'V288 lts_card_cycles_v226 privilege or identity drift'; END IF;
END $v288$;
ROLLBACK;
