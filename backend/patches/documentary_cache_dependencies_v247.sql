-- Both documentary relations are live inputs to the corrected flow engine.
-- Use the same transition-based invalidation as other financial source tables.
DO $dependencies$
DECLARE target text;
BEGIN
 FOREACH target IN ARRAY ARRAY['lts_card_document_supplement_v234','lts_card_history_source_audit_v235'] LOOP
  IF EXISTS(SELECT 1 FROM pg_trigger WHERE tgrelid=('public.'||target)::regclass AND tgname LIKE 'lts_v246_read_%') THEN
   RAISE EXCEPTION 'source already has V246 invalidation: %',target;
  END IF;
  EXECUTE format('CREATE TRIGGER lts_v246_read_i AFTER INSERT ON public.%I REFERENCING NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',target);
  EXECUTE format('CREATE TRIGGER lts_v246_read_u AFTER UPDATE ON public.%I REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',target);
  EXECUTE format('CREATE TRIGGER lts_v246_read_d AFTER DELETE ON public.%I REFERENCING OLD TABLE AS old_rows FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',target);
  EXECUTE format('CREATE TRIGGER lts_v246_read_t AFTER TRUNCATE ON public.%I FOR EACH STATEMENT EXECUTE FUNCTION public.lts_v246_invalidate_finance_cache()',target);
 END LOOP;
END $dependencies$;
