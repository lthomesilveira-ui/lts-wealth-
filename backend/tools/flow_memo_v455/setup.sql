CREATE ROLE service_role NOLOGIN;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE SCHEMA lts_read_private_v430;
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean PRIMARY KEY, epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_v229_read_cache(
 user_id uuid,kind text,as_of date,from_date date,to_date date,payload jsonb,
 source_fingerprint text,refreshed_at timestamptz,
 PRIMARY KEY(user_id,kind,as_of,from_date,to_date));
CREATE TABLE fixture_sources(owner uuid PRIMARY KEY,engine_key text,revision text,as_of timestamptz);
INSERT INTO fixture_sources VALUES
 ('00000000-0000-4000-8000-000000000001','source-one','schedule-one',now()),
 ('00000000-0000-4000-8000-000000000002','source-two','schedule-two',now());
CREATE TABLE fixture_calls(n integer);
INSERT INTO fixture_calls VALUES(0);
CREATE FUNCTION public.lts_open_finance_checking_positions_v1(uuid)
RETURNS jsonb LANGUAGE sql SET search_path='' AS $$
 SELECT jsonb_build_array(jsonb_build_object('bank','fixture','as_of',as_of))
 FROM public.fixture_sources WHERE owner=$1 $$;
CREATE FUNCTION public.lts_scheduled_transfer_revision_v293(uuid)
RETURNS text LANGUAGE sql SET search_path='' AS $$
 SELECT revision FROM public.fixture_sources WHERE owner=$1 $$;
CREATE FUNCTION public.lts_flow_read_key_engine_v243(uuid)
RETURNS text LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 IF NOT current_setting('transaction_read_only')::boolean THEN
  UPDATE public.fixture_calls SET n=n+1;
 END IF;
 IF current_setting('fixture.change',true)='yes' THEN
  UPDATE public.lts_read_cache_epoch_v242 SET epoch=epoch+1;
 END IF;
 IF current_setting('fixture.error',true)='yes' THEN
  RAISE EXCEPTION 'fixture source unavailable';
 END IF;
 RETURN (SELECT engine_key FROM public.fixture_sources WHERE owner=$1);
END $$;
