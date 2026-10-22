-- V298: return an unchanged workbook record directly when no bank overlay applies.
-- Certified bank overrides and removal of an existing overlay flag use the original path.
DO $patch$
DECLARE d text; before_oid oid; before_owner oid; before_acl aclitem[]; before_config text[]; before_security boolean; before_volatility "char";
BEGIN
 SELECT oid,pg_get_functiondef(oid),proowner,proacl,proconfig,prosecdef,provolatile INTO before_oid,d,before_owner,before_acl,before_config,before_security,before_volatility
 FROM pg_proc WHERE oid='public.lts_card_workbook_bank_rows_v1(uuid)'::regprocedure;
 IF md5(d)='e7912321b844aa828da58fc94f00390c' THEN RETURN; END IF;
 IF md5(d)<>'a06bbae089c045121ecd9afc588835f6' THEN RAISE EXCEPTION 'V298 workbook reader changed; inspect before applying'; END IF;
 IF strpos(d,$a0$SELECT jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$a0$)=0 THEN RAISE EXCEPTION 'V298 workbook anchor 0 changed'; END IF;
 d:=replace(d,$a0$SELECT jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$a0$,$b0$SELECT CASE WHEN v.user_id IS NULL AND jsonb_typeof(w.evidence)='object' AND NOT (w.evidence ? 'bank_precedence_applied')
 THEN w ELSE jsonb_populate_record(NULL::public.lts_card_workbook_evidence_v226,$b0$);
 IF strpos(d,$a1$END) AS corrected_row$a1$)=0 THEN RAISE EXCEPTION 'V298 workbook anchor 1 changed'; END IF;
 d:=replace(d,$a1$END) AS corrected_row$a1$,$b1$END) END AS corrected_row$b1$);
 EXECUTE d;
 IF md5(pg_get_functiondef(before_oid))<>'e7912321b844aa828da58fc94f00390c' THEN RAISE EXCEPTION 'V298 workbook replacement mismatch'; END IF;
 IF 'public.lts_card_workbook_bank_rows_v1(uuid)'::regprocedure::oid<>before_oid
 OR EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=before_oid AND (p.proowner<>before_owner OR p.proacl IS DISTINCT FROM before_acl OR p.proconfig IS DISTINCT FROM before_config OR p.prosecdef IS DISTINCT FROM before_security OR p.provolatile<>before_volatility))
 THEN RAISE EXCEPTION 'V298 workbook identity, privileges or configuration changed'; END IF;
END $patch$;
