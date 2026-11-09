\set ON_ERROR_STOP on
\ir fixtures/v435/bounded_bank_setup.sql
ALTER FUNCTION public.lts_v229_new_bank_rows(uuid,date,date) SET work_mem TO '16MB';
\ir ../patches/v435/bounded_bank_expense_reader.sql
