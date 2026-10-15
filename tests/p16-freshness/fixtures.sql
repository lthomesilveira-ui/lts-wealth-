BEGIN READ ONLY;
SET LOCAL statement_timeout='8s'; SET LOCAL lock_timeout='2s'; SET LOCAL TIME ZONE 'America/Sao_Paulo';
WITH specs(id,name,raw,expected) AS (VALUES
(1,'valid_z','"2020-10-14T18:00:00Z"'::jsonb,'2020-10-14T18:00:00Z'),
(2,'valid_offset','"2020-10-14T15:00:00-03:00"'::jsonb,'2020-10-14T15:00:00-03:00'),
(3,'missing','null'::jsonb,NULL),
(4,'invalid_date','"2020-02-30T18:00:00Z"'::jsonb,NULL),
(5,'invalid_month','"2020-13-14T18:00:00Z"'::jsonb,NULL),
(6,'date_only','"2020-10-14"'::jsonb,NULL),
(7,'offset_missing','"2020-10-14T18:00:00"'::jsonb,NULL),
(8,'infinity','"infinity"'::jsonb,NULL),
(9,'json_number','123'::jsonb,NULL),
(10,'json_object','{}'::jsonb,NULL),
(11,'future_of_receipt','"2020-10-15T06:00:00Z"'::jsonb,NULL),
(12,'seconds60','"2020-10-14T18:00:60Z"'::jsonb,NULL),
(13,'sql_text','"not a timestamp; DROP TABLE x"'::jsonb,NULL),
(14,'wrong_owner','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(15,'wrong_connection','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(16,'failed_run','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(17,'wrong_finished','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(18,'duplicate_match','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(19,'null_success','"2020-10-14T18:00:00Z"'::jsonb,NULL),
(20,'valid_old_source','"2019-01-01T00:00:00Z"'::jsonb,'2019-01-01T00:00:00Z'),
(21,'offset_invalid','"2020-10-14T18:00:00+99:00"'::jsonb,NULL),
(22,'invalid_with_old_valid','"2020-02-30T18:00:00Z"'::jsonb,NULL),
(23,'metadata_sql_null','null'::jsonb,NULL),
(24,'item_missing','null'::jsonb,NULL),
(25,'item_scalar','null'::jsonb,NULL),
(26,'key_missing','null'::jsonb,NULL),
(27,'fraction_valid','"2020-10-14T18:00:00.123456Z"'::jsonb,'2020-10-14T18:00:00.123456Z'),
(28,'equal_receipt','"2020-10-15T03:18:00Z"'::jsonb,'2020-10-15T03:18:00Z'),
(29,'future_vs_now','null'::jsonb,NULL),
(30,'no_run','null'::jsonb,NULL),
(31,'leap_day_valid','"2016-02-29T18:00:00Z"'::jsonb,'2016-02-29T18:00:00Z'),
(32,'leap_day_invalid','"2019-02-29T18:00:00Z"'::jsonb,NULL)), connections AS (
 SELECT id,1 AS user_id,case when name='null_success' then null when name='future_vs_now' then statement_timestamp()+interval '2 days' else timestamptz '2020-10-15T03:18:00Z' end last_success_at FROM specs
), runs AS (
 SELECT s.id,s.id AS connection_id,1 AS user_id,'success'::text AS status,timestamptz '2020-10-15T03:15:00Z' AS started_at,case when name='future_vs_now' then statement_timestamp()+interval '2 days' else timestamptz '2020-10-15T03:18:00Z' end AS finished_at,
 case when name='metadata_sql_null' then null::jsonb
 when name='item_missing' then '{}'::jsonb
 when name='item_scalar' then '{"item":123}'::jsonb
 when name='key_missing' then '{"item":{}}'::jsonb
 when name='future_vs_now' then jsonb_build_object('item',jsonb_build_object('lastUpdatedAt',to_char((statement_timestamp()+interval '1 day') at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS')||'Z'))
 else jsonb_build_object('item',jsonb_build_object('lastUpdatedAt',s.raw)) end metadata,s.name FROM specs s
), adjusted AS (
 SELECT id,case when name='wrong_connection' then 999 else connection_id end connection_id,case when name='wrong_owner' then 2 else user_id end user_id,case when name='failed_run' then 'error' else status end status,started_at,case when name='wrong_finished' then finished_at-interval '1 minute' else finished_at end finished_at,metadata FROM runs WHERE name<>'no_run'
 UNION ALL SELECT id+1000,connection_id,user_id,status,started_at,finished_at,metadata FROM runs WHERE name='duplicate_match'
 UNION ALL SELECT id+1000,connection_id,user_id,status,started_at-interval '1 hour',finished_at-interval '1 hour',jsonb_build_object('item',jsonb_build_object('lastUpdatedAt','2020-10-14T18:00:00Z')) FROM runs WHERE name='invalid_with_old_valid'
), evaluated AS (
 SELECT c.id,s.name,s.expected,(
          select case when r.match_count=1 and jsonb_typeof(r.metadata#>'{item,lastUpdatedAt}')='string'
            then case when r.metadata#>>'{item,lastUpdatedAt}' ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]([.][0-9]+)?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$'
              and pg_catalog.pg_input_is_valid(r.metadata#>>'{item,lastUpdatedAt}','pg_catalog.timestamptz')
              then case when (r.metadata#>>'{item,lastUpdatedAt}')::pg_catalog.timestamptz<=r.finished_at
                and (r.metadata#>>'{item,lastUpdatedAt}')::pg_catalog.timestamptz<=statement_timestamp()
                then r.metadata#>>'{item,lastUpdatedAt}' else null end
              else null end
            else null end
          from (
            select r.metadata,r.finished_at,count(*) over () as match_count
            from adjusted r
            where r.user_id=c.user_id and r.connection_id=c.id
              and r.status='success' and r.finished_at=c.last_success_at
            order by r.started_at desc,r.id desc limit 1
          ) r
        ) actual
 FROM connections c JOIN specs s ON s.id=c.id
)
SELECT name,expected,actual,actual IS NOT DISTINCT FROM expected AS passed FROM evaluated ORDER BY id;
COMMIT;
