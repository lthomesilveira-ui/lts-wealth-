\set ON_ERROR_STOP on

-- A single JSON document containing the immutable, synthetic rehearsal baseline.
-- Row JSON text is canonicalized by jsonb before any fingerprint is calculated.
WITH target AS (
    SELECT pg_catalog.to_jsonb(event) AS original_event
    FROM reconciliation_fixture.events AS event
    WHERE event.id = '00000000-0000-4000-8000-000000000002'::uuid
      AND event.user_id = '00000000-0000-4000-8000-000000000001'::uuid
), credit AS (
    SELECT pg_catalog.to_jsonb(candidate) AS credit
    FROM reconciliation_fixture.credits AS candidate
    WHERE candidate.id = '00000000-0000-4000-8000-000000000003'::uuid
      AND candidate.user_id = '00000000-0000-4000-8000-000000000001'::uuid
), function_signatures(signature) AS (
    VALUES
        ('reconciliation_fixture.current_rows(uuid,date,date)'),
        ('reconciliation_fixture.cashflow_engine(uuid,date,date)'),
        ('reconciliation_fixture.cashflow_rows(uuid,date,date)'),
        ('reconciliation_fixture.invalidate_cache()')
), definitions AS (
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'signature', signature,
            'md5', pg_catalog.md5(pg_catalog.pg_get_functiondef(signature::regprocedure))
        ) ORDER BY signature
    ) AS definitions
    FROM function_signatures
), triggers AS (
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'table', relation.relname,
            'name', trigger.tgname,
            'enabled', trigger.tgenabled,
            'definition', pg_catalog.pg_get_triggerdef(trigger.oid)
        ) ORDER BY relation.relname, trigger.tgname
    ) AS triggers
    FROM pg_catalog.pg_trigger AS trigger
    JOIN pg_catalog.pg_class AS relation ON relation.oid = trigger.tgrelid
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'reconciliation_fixture'
      AND relation.relname IN ('events', 'links')
      AND NOT trigger.tgisinternal
), constraints AS (
    SELECT pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
            'table_name', relation.relname,
            'conname', constraint_row.conname,
            'definition', pg_catalog.pg_get_constraintdef(constraint_row.oid)
        ) ORDER BY relation.relname, constraint_row.conname
    ) AS constraints
    FROM pg_catalog.pg_constraint AS constraint_row
    JOIN pg_catalog.pg_class AS relation ON relation.oid = constraint_row.conrelid
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
    WHERE namespace.nspname = 'reconciliation_fixture'
      AND relation.relname IN ('events', 'links')
), operations_fk AS (
    SELECT pg_catalog.pg_get_constraintdef(constraint_row.oid) AS definition
    FROM pg_catalog.pg_constraint AS constraint_row
    JOIN pg_catalog.pg_class AS relation ON relation.oid = constraint_row.conrelid
    JOIN pg_catalog.pg_namespace AS namespace ON namespace.oid = relation.relnamespace
    JOIN pg_catalog.pg_attribute AS column_row
      ON column_row.attrelid = relation.oid
     AND column_row.attname = 'target_event_id'
     AND NOT column_row.attisdropped
    WHERE namespace.nspname = 'reconciliation_fixture'
      AND relation.relname = 'operations'
      AND constraint_row.conname = 'operations_target_event_id_fkey'
      AND constraint_row.contype = 'f'
      AND constraint_row.conkey = ARRAY[column_row.attnum]::smallint[]
)
SELECT pg_catalog.jsonb_build_object(
    'original_event', target.original_event,
    'event_md5', pg_catalog.md5(target.original_event::text),
    'credit', credit.credit,
    'credit_md5', pg_catalog.md5(credit.credit::text),
    'credit_stable_md5', pg_catalog.md5(
        (credit.credit - ARRAY['sync_run_id', 'last_seen_at', 'updated_at'])::text
    ),
    'credit_raw_hash', credit.credit ->> 'raw_hash',
    'credit_updated_at', credit.credit ->> 'updated_at',
    'note', 'synthetic reconciliation contract',
    'fixture_contract', true,
    'marker', 'reconciliation_fixture_v1',
    'user_message_id', 'fixture-message',
    'definitions', definitions.definitions,
    'triggers', triggers.triggers,
    'constraints', constraints.constraints,
    'operations_fk_definition', operations_fk.definition
)
FROM target
CROSS JOIN credit
CROSS JOIN definitions
CROSS JOIN triggers
CROSS JOIN constraints
CROSS JOIN operations_fk;
