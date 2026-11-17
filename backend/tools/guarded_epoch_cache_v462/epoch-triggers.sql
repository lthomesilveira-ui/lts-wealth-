CREATE TRIGGER lts_v246_read_d AFTER DELETE ON public.lts_open_finance_staging REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_i AFTER INSERT ON public.lts_open_finance_staging REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_t AFTER TRUNCATE ON public.lts_open_finance_staging FOR EACH STATEMENT EXECUTE FUNCTION lts_v246_invalidate_finance_cache();
CREATE TRIGGER lts_v246_read_u AFTER UPDATE ON public.lts_open_finance_staging REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION lts_v246_invalidate_finance_cache();
