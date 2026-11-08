\set ON_ERROR_STOP on
\ir lts_v430_setup.sql
ALTER FUNCTION public.lts_payroll_bank_matches_v231(uuid) SET work_mem='8MB';
\ir ../patches/v430/optional_memo_writes.sql
