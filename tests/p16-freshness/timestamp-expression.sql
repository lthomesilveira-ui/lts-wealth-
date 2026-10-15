(
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
            from public.lts_open_finance_sync_run r
            where r.user_id=v_uid and r.connection_id=c.id
              and r.status='success' and r.finished_at=c.last_success_at
            order by r.started_at desc,r.id desc limit 1
          ) r
        )