#!/usr/bin/env python3
"""Compose the reviewed V418 patch as one guarded atomic deployment.

This is generic code only. It never connects to a database or starts a worker.
The existing scheduler will process the one coalesced request per policy owner.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
PATCH = ROOT / 'backend/patches/v418'


def compose():
    prefix = '''BEGIN;
SET LOCAL statement_timeout='30s';
SET LOCAL lock_timeout='2s';
SET LOCAL TimeZone='America/Sao_Paulo';
'''
    preflight = '''
CREATE TEMP TABLE v418_predecessor_attributes ON COMMIT DROP AS
SELECT p.oid,to_jsonb(p)-'prosrc' AS attributes FROM pg_proc p
WHERE p.oid IN ('lts_projection_private_v412.build(uuid,date)'::regprocedure,
 'lts_projection_private_v412.read_policy()'::regprocedure,
 'lts_product_refresh_private_v415.run_claimed()'::regprocedure);
DO $idle$
DECLARE owner_id uuid;
BEGIN
 FOR owner_id IN SELECT q.user_id FROM lts_product_refresh_private_v415.queue q
  ORDER BY q.user_id LOOP
  IF NOT pg_try_advisory_xact_lock(hashtextextended(owner_id::text,415)) THEN
   RAISE EXCEPTION 'An existing refresh owns its calculation lock; defer V418 installation';
  END IF;
 END LOOP;
 IF EXISTS(SELECT 1 FROM lts_product_refresh_private_v415.queue WHERE state='running') THEN
  RAISE EXCEPTION 'An existing refresh claim is running; defer V418 installation';
 END IF;
END $idle$;
'''
    suffix = '''
DO $metadata$
BEGIN
 IF EXISTS(SELECT 1 FROM v418_predecessor_attributes b JOIN pg_proc p USING(oid)
  WHERE b.attributes IS DISTINCT FROM to_jsonb(p)-'prosrc') THEN
  RAISE EXCEPTION 'V418 changed predecessor attributes, owner or execution privileges';
 END IF;
END $metadata$;
-- Request the existing queue once; do not calculate, clear caches, change the
-- source epoch or create another worker/schedule during deployment.
DO $request$
DECLARE owner_id uuid;
BEGIN
 FOR owner_id IN SELECT p.user_id FROM public.lts_product_read_cache p
  WHERE lts_product_refresh_private_v415.allowed_owner(p.user_id)
   AND lts_projection_private_v412.owner_policy(p.user_id) IS NOT NULL
  ORDER BY p.user_id LOOP
  PERFORM lts_product_refresh_private_v415.enqueue(owner_id,'cache_read',false);
 END LOOP;
END $request$;
COMMIT;
'''
    return prefix + (PATCH / 'guard.sql').read_text() + preflight + (PATCH / 'capture.sql').read_text() + (PATCH / 'read.sql').read_text() + suffix


if __name__ == '__main__':
    print(compose(), end='')
