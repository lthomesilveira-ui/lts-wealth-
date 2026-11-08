-- Run only in the invented-data fixture; never a production benchmark.
DO $guard$ BEGIN
 IF public.lts_open_finance_pilot_owner_v1()<>'11111111-1111-4111-8111-111111111111'::uuid THEN
  RAISE EXCEPTION 'This probe requires the synthetic owner fixture';
 END IF;
END $guard$;
CREATE SCHEMA qa_v427_probe;
CREATE TABLE qa_v427_probe.payload(id int PRIMARY KEY,value jsonb,consulted_at timestamptz);
INSERT INTO qa_v427_probe.payload
SELECT i,jsonb_build_object('source_sync_at','2026-01-01T00:00:00Z','body',
 (SELECT string_agg(md5(j::text),'') FROM generate_series(1,160)j)),now()
FROM generate_series(1,400)i;
CREATE TABLE qa_v427_probe.results(kind text,wal_bytes bigint,elapsed_ms numeric,payload_same boolean);
DO $measure$
DECLARE b pg_lsn;t timestamptz;k int;original jsonb;
BEGIN
 SELECT value INTO original FROM qa_v427_probe.payload LIMIT 1;
 b:=pg_current_wal_insert_lsn();t:=clock_timestamp();
 FOR k IN 1..8 LOOP
  UPDATE qa_v427_probe.payload p SET consulted_at=clock_timestamp(),
   value=jsonb_set(p.value,'{source_sync_at}','"2026-01-01T00:00:00Z"'::jsonb);
 END LOOP;
 INSERT INTO qa_v427_probe.results
 SELECT 'rebuild_unchanged',pg_current_wal_insert_lsn()-b,
  extract(epoch FROM clock_timestamp()-t)*1000,bool_and(value=original)
 FROM qa_v427_probe.payload;
 b:=pg_current_wal_insert_lsn();t:=clock_timestamp();
 FOR k IN 1..8 LOOP
  UPDATE qa_v427_probe.payload p SET consulted_at=clock_timestamp(),
   value=CASE WHEN p.value->'source_sync_at' IS DISTINCT FROM '"2026-01-01T00:00:00Z"'::jsonb
    THEN jsonb_set(p.value,'{source_sync_at}','"2026-01-01T00:00:00Z"'::jsonb)
    ELSE p.value END;
 END LOOP;
 INSERT INTO qa_v427_probe.results
 SELECT 'reuse_unchanged',pg_current_wal_insert_lsn()-b,
  extract(epoch FROM clock_timestamp()-t)*1000,bool_and(value=original)
 FROM qa_v427_probe.payload;
END $measure$;
SELECT jsonb_build_object('synthetic_large_payload_probe',jsonb_agg(to_jsonb(r)),
 'production_iops_measured',false) FROM qa_v427_probe.results r;
