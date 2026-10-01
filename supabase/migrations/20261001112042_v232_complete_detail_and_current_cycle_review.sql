-- Complete history in one bounded read, without rerunning the ledger per 500 rows.
DO $patch$
DECLARE definition text; original text;
BEGIN
 original:=pg_get_functiondef('public.lts_browser_expense_detail_v229(date,date,text,text,integer,integer,text)'::regprocedure);
 definition:=replace(original,'p_limit NOT BETWEEN 1 AND 500','p_limit NOT BETWEEN 1 AND 10000');
 IF definition=original THEN RAISE EXCEPTION 'Unexpected detail validation definition'; END IF;
 definition:=replace(definition,'Classificação original preservada. A planilha não especifica pessoa ou imóvel adicional.','Categoria conferida com a planilha original.');
 EXECUTE definition;
 original:=pg_get_functiondef('public.lts_v229_review_rows(uuid,date,date)'::regprocedure);
 definition:=replace(original,'reference_month>date_trunc','reference_month>=date_trunc');
 IF definition=original THEN RAISE EXCEPTION 'Unexpected current invoice filter'; END IF;
 EXECUTE definition;
END $patch$;
