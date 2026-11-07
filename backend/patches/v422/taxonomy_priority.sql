BEGIN;
SET LOCAL lock_timeout='2s';
SET LOCAL statement_timeout='8s';
DO $patch$
DECLARE original text; baseline text; updated text; attrs jsonb;
 needle text:=$n$ WHEN c~'^emprestimos$|compromissos financeiros'THEN macro:='Compromissos financeiros';g:='Empréstimos e compromissos';$n$;
 added text:=$n$ WHEN c='compromissos financeiros'AND m='emprestimos'THEN macro:='Patrimônio e financiamentos';g:='Empréstimos';
$n$;
BEGIN
 SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO original,attrs FROM pg_proc p WHERE oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure;
 baseline:=replace(original,added,'');
 IF md5(baseline)<>'b73aaab59b0677ca0499606e8e607823' OR (length(baseline)-length(replace(baseline,needle,'')))/length(needle)<>1 THEN
  RAISE EXCEPTION 'Unexpected taxonomy predecessor; review before applying';END IF;
 updated:=replace(baseline,needle,added||needle);
 PERFORM set_config('lts.v422_changed',(updated<>original)::text,true);
 IF updated<>original THEN EXECUTE updated;END IF;
 IF attrs IS DISTINCT FROM (SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE oid='public.lts_expense_taxonomy_v353(text,text,text)'::regprocedure) THEN
  RAISE EXCEPTION 'Unexpected taxonomy attributes or privileges';END IF;
END $patch$;
COMMIT;
