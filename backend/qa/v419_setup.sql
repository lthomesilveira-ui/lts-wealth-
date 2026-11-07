CREATE ROLE anon;CREATE ROLE authenticated;CREATE ROLE service_role;
CREATE TABLE public.lts_validated_lock_registry(lock_key text,canonical_value jsonb,superseded_at timestamptz);
INSERT INTO public.lts_validated_lock_registry VALUES('morgan_available_synthetic','{"total_available_brl":20,"as_of":"2020-01-01"}',NULL);
CREATE TABLE public.v419_tests(name text PRIMARY KEY,passed boolean NOT NULL);
CREATE FUNCTION public.v419_assert(name text,condition boolean) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
 IF condition IS DISTINCT FROM true THEN RAISE EXCEPTION 'Failed: %',name;END IF;
 INSERT INTO public.v419_tests VALUES(name,true);
END $$;
