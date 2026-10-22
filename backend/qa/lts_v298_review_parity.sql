-- Full canonical rows/multiplicity and complete queue JSON, including idempotence.
-- This administrative parity check does not certify a private HTTP session.
\set ON_ERROR_STOP on
BEGIN ISOLATION LEVEL REPEATABLE READ;
 set local timezone='America/Sao_Paulo';
 set local statement_timeout='55s';
 set local lock_timeout='1s';
 do $$begin perform set_config('request.jwt.claims',(select jsonb_build_object('sub',id,'email',email,'role','authenticated')::text from auth.users where id=public.lts_open_finance_pilot_owner_v1()),true);
 end$$;
 create temp table v298_before on commit drop as select (select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2013-10-10',current_date) r) expenses,public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,0,25,null) queue;

\ir ../patches/v298/review_source_lookup.sql
\ir ../patches/v298/review_normalization.sql
\ir ../patches/v298/c6_reuse.sql
\ir ../patches/v298/workbook_unchanged_row.sql
\ir ../patches/v298/card_cycle_reuse.sql
\ir ../patches/v298/review_source_lookup.sql
\ir ../patches/v298/review_normalization.sql
\ir ../patches/v298/c6_reuse.sql
\ir ../patches/v298/workbook_unchanged_row.sql
\ir ../patches/v298/card_cycle_reuse.sql
 create temp table v298_after on commit drop as select (select coalesce(jsonb_agg(to_jsonb(r) order by to_jsonb(r)::text),'[]') from public.lts_v229_expense_rows(public.lts_open_finance_pilot_owner_v1(),'2013-10-10',current_date) r) expenses,public.lts_browser_expense_review_queue_v229('2013-10-10',current_date,0,25,null) queue;
 do $$begin if (select expenses from v298_before) is distinct from (select expenses from v298_after) then raise exception 'V298 expense rows/multiplicity changed';
 end if;
 if (select queue from v298_before) is distinct from (select queue from v298_after) then raise exception 'V298 full review JSON changed';
 end if;
 end$$;
 select jsonb_build_object('status','PASS','canonical_rows',jsonb_array_length(a.expenses),'expense_digest',md5(a.expenses::text),'queue_digest',md5(a.queue::text),'pending',a.queue->'row_count','definition_hash',md5(pg_get_functiondef('public.lts_expense_rows_pre_categories_v290(uuid,date,date)'::regprocedure))) as parity from v298_after a;
 rollback;
