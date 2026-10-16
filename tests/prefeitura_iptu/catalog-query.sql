WITH relations AS (
 SELECT c.* FROM pg_catalog.pg_class c JOIN pg_catalog.pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relname IN (__TABLES__)
), funcs AS (
 SELECT p.* FROM pg_catalog.pg_proc p
 WHERE p.oid IN (SELECT pg_catalog.to_regprocedure(value) FROM jsonb_array_elements_text('__FUNCTIONS_JSON__'::jsonb))
 OR p.oid IN (SELECT t.tgfoid FROM pg_catalog.pg_trigger t JOIN relations r ON r.oid=t.tgrelid WHERE NOT t.tgisinternal)
), sequences AS (
 SELECT DISTINCT s.* FROM pg_catalog.pg_class s
 JOIN pg_catalog.pg_depend dep ON dep.objid=s.oid
 JOIN relations r ON r.oid=dep.refobjid
 WHERE s.relkind='S' AND dep.deptype IN ('a','i')
)
SELECT jsonb_build_object(
 'server_major',current_setting('server_version_num')::int/10000,
 'session_role',current_user,
 'role', (SELECT jsonb_build_object('superuser',r.rolsuper,'inherit',r.rolinherit,'bypassrls',r.rolbypassrls) FROM pg_catalog.pg_roles r WHERE r.rolname=current_user),
 'relations',coalesce((SELECT jsonb_agg(jsonb_build_object('name',r.relname,'kind',r.relkind,'owner',pg_get_userbyid(r.relowner),'acl',r.relacl,'rls',r.relrowsecurity,'force_rls',r.relforcerowsecurity,'options',r.reloptions) ORDER BY r.relname) FROM relations r),'[]'::jsonb),
 'columns',coalesce((SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',a.attname,'position',a.attnum,'type',format_type(a.atttypid,a.atttypmod),'not_null',a.attnotnull,'identity',a.attidentity,'generated',a.attgenerated,'acl',a.attacl,'default',pg_get_expr(d.adbin,d.adrelid)) ORDER BY r.relname,a.attnum) FROM relations r JOIN pg_catalog.pg_attribute a ON a.attrelid=r.oid AND a.attnum>0 AND NOT a.attisdropped LEFT JOIN pg_catalog.pg_attrdef d ON d.adrelid=r.oid AND d.adnum=a.attnum),'[]'::jsonb),
 'constraints',coalesce((SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',c.conname,'type',c.contype,'validated',c.convalidated,'deferrable',c.condeferrable,'deferred',c.condeferred,'definition',pg_get_constraintdef(c.oid)) ORDER BY r.relname,c.conname) FROM relations r JOIN pg_catalog.pg_constraint c ON c.conrelid=r.oid),'[]'::jsonb),
 'indexes',coalesce((SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',c.relname,'valid',i.indisvalid,'ready',i.indisready,'unique',i.indisunique,'definition',pg_get_indexdef(i.indexrelid)) ORDER BY r.relname,c.relname) FROM relations r JOIN pg_catalog.pg_index i ON i.indrelid=r.oid JOIN pg_catalog.pg_class c ON c.oid=i.indexrelid),'[]'::jsonb),
 'triggers',coalesce((SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',t.tgname,'enabled',t.tgenabled,'type',t.tgtype,'internal',t.tgisinternal,'deferrable',t.tgdeferrable,'deferred',t.tginitdeferred,'definition',pg_get_triggerdef(t.oid)) ORDER BY r.relname,t.tgname) FROM relations r JOIN pg_catalog.pg_trigger t ON t.tgrelid=r.oid),'[]'::jsonb),
 'policies',coalesce((SELECT jsonb_agg(jsonb_build_object('table',r.relname,'name',p.polname,'command',p.polcmd,'permissive',p.polpermissive,'roles',(SELECT jsonb_agg(CASE WHEN rr=0 THEN 'public' ELSE pg_get_userbyid(rr) END ORDER BY rr) FROM unnest(p.polroles) rr),'using',pg_get_expr(p.polqual,p.polrelid),'check',pg_get_expr(p.polwithcheck,p.polrelid)) ORDER BY r.relname,p.polname) FROM relations r JOIN pg_catalog.pg_policy p ON p.polrelid=r.oid),'[]'::jsonb),
 'functions',coalesce((SELECT jsonb_agg(jsonb_build_object('signature',p.oid::regprocedure::text,'owner',pg_get_userbyid(p.proowner),'acl',p.proacl,'security_definer',p.prosecdef,'volatility',p.provolatile,'config',p.proconfig,'definition_md5',md5(pg_get_functiondef(p.oid))) ORDER BY p.oid::regprocedure::text) FROM funcs p),'[]'::jsonb),
 'sequences',coalesce((SELECT jsonb_agg(jsonb_build_object('name',s.relname,'owner',pg_get_userbyid(s.relowner),'acl',s.relacl,'type',format_type(q.seqtypid,NULL),'start',q.seqstart::text,'increment',q.seqincrement::text,'max',q.seqmax::text,'min',q.seqmin::text,'cache',q.seqcache::text,'cycle',q.seqcycle) ORDER BY s.relname) FROM sequences s JOIN pg_catalog.pg_sequence q ON q.seqrelid=s.oid),'[]'::jsonb)
)
