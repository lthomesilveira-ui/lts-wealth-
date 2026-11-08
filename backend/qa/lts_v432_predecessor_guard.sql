\set ON_ERROR_STOP on
\ir lts_v432_fgts.sql
ALTER FUNCTION public.lts_bank_fgts_combined_receipt_v261(uuid,uuid) SET work_mem='8MB';
\ir ../patches/v432/owner_confirmed_fgts.sql
