-- Operator-only component trial. Set lts_backup_test.owner_uuid in the same SQL session.
-- Captures are read or created temporarily; every write is rolled back.
-- Typed recovery uses source column types, recomputes generated columns, and preserves identities.
begin;
set local timezone='America/Sao_Paulo';
do $trial$
declare u uuid:=current_setting('lts_backup_test.owner_uuid')::uuid;b jsonb;capture jsonb;again jsonb;r record;tbl text;ordering text;actual text;expected text;n int;i int:=0;existed boolean;cols text;identity_override text;
begin
 existed:=exists(select 1 from public.lts_backup_supplement_v380 where user_id=u and snapshot_date=current_date);
 capture:=public.lts_backup_snapshot_take_v380(u,current_date);
 if (capture->>'inserted')::boolean=existed then raise exception 'unexpected capture state';end if;
 b:=public.lts_backup_bundle_read_v380(u,current_date);
 again:=public.lts_backup_snapshot_take_v380(u,current_date);
 if again->>'inserted'<>'false' or again->>'payload_sha256'<>capture->>'payload_sha256' then raise exception 'trial idempotency failed';end if;
 if b#>>'{manifest,legacy_restore_compatible}'<>'false' or b#>>'{manifest,full_restore_tested}'<>'false' then raise exception 'incorrect recovery contract';end if;
 for r in select key,value from jsonb_each(b#>'{modern,tables}') order by key loop
  i:=i+1;tbl:='v380_restore_'||i;
  execute format('create temporary table %I (like public.%I including all) on commit drop',tbl,r.key);
  select string_agg(format('%I',attname),',' order by attnum),case when bool_or(attidentity='a') then ' overriding system value' else '' end into cols,identity_override from pg_attribute where attrelid=format('public.%I',r.key)::regclass and attnum>0 and not attisdropped and attgenerated='';
  execute format('insert into pg_temp.%I (%s)%s select %s from jsonb_populate_recordset(null::public.%I,$1)',tbl,cols,identity_override,cols,r.key)using r.value;
  select string_agg(format('t.%I',a.attname),',' order by o.ordinality)into ordering
  from pg_index idx cross join lateral unnest(idx.indkey)with ordinality o(attnum,ordinality)
  join pg_attribute a on a.attrelid=idx.indrelid and a.attnum=o.attnum
  where idx.indrelid=format('public.%I',r.key)::regclass and idx.indisprimary;
  if ordering is null then raise exception 'missing source primary key';end if;
  execute format('select count(*),md5(coalesce(string_agg(md5(to_jsonb(t)::text),'''' order by %s),'''')) from pg_temp.%I t',ordering,tbl)into n,actual;
  select md5(coalesce(string_agg(md5(value::text),'' order by ordinality),''))into expected from jsonb_array_elements(r.value)with ordinality;
  if n<>jsonb_array_length(r.value)or actual<>expected then raise exception 'typed recovery mismatch for %',r.key;end if;
 end loop;
 if i<>29 then raise exception 'missing restored tables';end if;
 begin
  perform public.lts_restore_stage_v1(u,b);raise exception 'legacy restorer accepted new envelope';
 exception when others then if sqlerrm<>'unsupported backup format' then raise;end if;end;
 begin
  update public.lts_backup_supplement_v380 set payload=payload||'{"trial_corruption":true}'::jsonb where user_id=u and snapshot_date=current_date;
  perform public.lts_backup_bundle_read_v380(u,current_date);raise exception 'corrupted modern payload accepted';
 exception when others then if sqlerrm<>'modern backup integrity mismatch' then raise;end if;end;
 perform public.lts_backup_bundle_read_v380(u,current_date);
end $trial$;
rollback;
select jsonb_build_object('native_component_trial_passed',true,'typed_tables_restored',29,'retained_backup_rows_after_trial',(select count(*) from public.lts_backup_supplement_v380),'full_project_restore_certified',false,'legacy_restore_rejected_new_envelope',true)as result;
