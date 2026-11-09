\set ON_ERROR_STOP on
\ir v309_fixture.sql
\ir v309_realized_dependency.sql
\ir ../patches/v309/contract_read_state.sql
ALTER FUNCTION public.lts_commitment_summary_overlay_v309(uuid,date,jsonb) SET search_path TO public;
\ir ../patches/v434/coopharma_dated_balance.sql
