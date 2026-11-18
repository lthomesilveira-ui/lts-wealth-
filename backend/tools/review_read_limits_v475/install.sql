-- The mobile readers have 22s and 25s transport budgets. The authenticated
-- role's 8s default can interrupt a valid cold read after a bank refresh.
-- Use the same bounded server budget as the existing card review endpoint.
ALTER FUNCTION public.lts_browser_expense_review_queue_v229(date,date,integer,integer,text)
  SET statement_timeout = '18s';
ALTER FUNCTION public.lts_browser_income_review_queue_v296(date,date,integer,integer,text)
  SET statement_timeout = '18s';
NOTIFY pgrst, 'reload schema';
