\set ON_ERROR_STOP on

-- Entirely synthetic data. This script is restricted to the dedicated CI database.
BEGIN;

DO $guard$
BEGIN
    IF pg_catalog.current_database() <> 'reconciliation_ci' THEN
        RAISE EXCEPTION 'fixture setup requires database reconciliation_ci';
    END IF;
    IF pg_catalog.current_setting('server_version_num')::integer / 10000 <> 17 THEN
        RAISE EXCEPTION 'fixture setup requires PostgreSQL major version 17';
    END IF;
END;
$guard$;

DROP SCHEMA IF EXISTS reconciliation_fixture CASCADE;
CREATE SCHEMA reconciliation_fixture;
SET LOCAL search_path = pg_catalog;
SET LOCAL TIME ZONE 'UTC';

CREATE TABLE reconciliation_fixture.owners (
    id uuid PRIMARY KEY,
    name text NOT NULL
);

CREATE TABLE reconciliation_fixture.accounts (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES reconciliation_fixture.owners(id),
    name text NOT NULL
);

CREATE TABLE reconciliation_fixture.events (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES reconciliation_fixture.owners(id),
    account_id uuid REFERENCES reconciliation_fixture.accounts(id),
    legacy_id text,
    legacy_index integer,
    event_date date NOT NULL,
    description_raw text,
    description_normalized text,
    amount numeric NOT NULL,
    nature text,
    category text,
    counterparty text,
    source text,
    status text,
    is_internal_transfer boolean NOT NULL DEFAULT false,
    is_projection boolean NOT NULL DEFAULT false,
    is_suppressed boolean NOT NULL DEFAULT false,
    suppression_reason text,
    metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
    CONSTRAINT events_user_id_legacy_id_key UNIQUE (user_id, legacy_id)
);

CREATE TABLE reconciliation_fixture.credits (
    id uuid PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES reconciliation_fixture.owners(id),
    provider_account_ref text NOT NULL,
    provider_record_id text NOT NULL,
    connection_id uuid NOT NULL,
    resource_type text NOT NULL,
    currency text NOT NULL,
    posting_date date NOT NULL,
    signed_amount numeric NOT NULL,
    raw_hash text NOT NULL,
    raw_payload jsonb NOT NULL,
    normalized_payload jsonb NOT NULL,
    provider_deleted_at timestamptz,
    updated_at timestamptz NOT NULL,
    last_seen_at timestamptz NOT NULL,
    sync_run_id uuid NOT NULL
);

CREATE TABLE reconciliation_fixture.links (
    id bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES reconciliation_fixture.owners(id),
    target_event_id uuid NOT NULL REFERENCES reconciliation_fixture.events(id),
    candidate_source_table text NOT NULL,
    candidate_source_ref text NOT NULL,
    candidate_event_date date NOT NULL,
    candidate_amount numeric NOT NULL,
    note text,
    confirmed_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
    CONSTRAINT links_user_id_target_event_id_key UNIQUE (user_id, target_event_id)
);

CREATE TABLE reconciliation_fixture.operations (
    id bigserial PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES reconciliation_fixture.owners(id),
    target_event_id uuid NOT NULL,
    operation text NOT NULL,
    payload jsonb NOT NULL DEFAULT '{}'::jsonb,
    CONSTRAINT operations_target_event_id_fkey
        FOREIGN KEY (target_event_id) REFERENCES reconciliation_fixture.events(id)
        NOT DEFERRABLE INITIALLY IMMEDIATE
);

CREATE TABLE reconciliation_fixture.epoch (
    singleton boolean PRIMARY KEY CHECK (singleton),
    epoch bigint NOT NULL
);

CREATE TABLE reconciliation_fixture.cache (
    user_id uuid,
    payload jsonb NOT NULL,
    id text PRIMARY KEY
);

CREATE FUNCTION reconciliation_fixture.invalidate_cache()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
DECLARE
    rows_changed boolean;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT EXISTS (SELECT 1 FROM new_rows) INTO rows_changed;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT EXISTS (SELECT 1 FROM old_rows) INTO rows_changed;
    ELSIF TG_OP = 'UPDATE' THEN
        SELECT EXISTS (
            SELECT 1
            FROM old_rows AS previous
            FULL JOIN new_rows AS current_row ON current_row.id = previous.id
            WHERE pg_catalog.to_jsonb(previous)
                IS DISTINCT FROM pg_catalog.to_jsonb(current_row)
        ) INTO rows_changed;
    ELSE
        RAISE EXCEPTION 'unsupported synthetic cache trigger operation: %', TG_OP;
    END IF;

    IF rows_changed THEN
        UPDATE reconciliation_fixture.epoch
        SET epoch = epoch + 1
        WHERE singleton;
        DELETE FROM reconciliation_fixture.cache WHERE user_id IS NOT NULL;
    END IF;
    RETURN NULL;
END;
$function$;

CREATE FUNCTION reconciliation_fixture.block_delete()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog
AS $function$
BEGIN
    RAISE EXCEPTION USING
        ERRCODE = '55000',
        MESSAGE = 'synthetic fixture events cannot be deleted';
    RETURN OLD;
END;
$function$;

CREATE TRIGGER events_block_delete
BEFORE DELETE ON reconciliation_fixture.events
FOR EACH ROW EXECUTE FUNCTION reconciliation_fixture.block_delete();

CREATE TRIGGER events_cache_insert
AFTER INSERT ON reconciliation_fixture.events
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE TRIGGER events_cache_update
AFTER UPDATE ON reconciliation_fixture.events
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE TRIGGER events_cache_delete
AFTER DELETE ON reconciliation_fixture.events
REFERENCING OLD TABLE AS old_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE TRIGGER links_cache_insert
AFTER INSERT ON reconciliation_fixture.links
REFERENCING NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE TRIGGER links_cache_update
AFTER UPDATE ON reconciliation_fixture.links
REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE TRIGGER links_cache_delete
AFTER DELETE ON reconciliation_fixture.links
REFERENCING OLD TABLE AS old_rows
FOR EACH STATEMENT EXECUTE FUNCTION reconciliation_fixture.invalidate_cache();

CREATE FUNCTION reconciliation_fixture.current_rows(
    p_user_id uuid, p_start_date date, p_end_date date
)
RETURNS SETOF reconciliation_fixture.events
LANGUAGE sql
STABLE
SET search_path = pg_catalog
AS $function$
    SELECT event.*
    FROM reconciliation_fixture.events AS event
    WHERE event.user_id = p_user_id
      AND event.event_date BETWEEN p_start_date AND p_end_date
      AND NOT event.is_suppressed
    ORDER BY event.event_date, event.id;
$function$;

CREATE FUNCTION reconciliation_fixture.cashflow_engine(
    p_user_id uuid, p_start_date date, p_end_date date
)
RETURNS SETOF reconciliation_fixture.events
LANGUAGE sql
STABLE
SET search_path = pg_catalog
AS $function$
    SELECT event.*
    FROM reconciliation_fixture.events AS event
    WHERE event.user_id = p_user_id
      AND event.event_date BETWEEN p_start_date AND p_end_date
      AND NOT event.is_suppressed
    ORDER BY event.event_date, event.id;
$function$;

CREATE FUNCTION reconciliation_fixture.cashflow_rows(
    p_user_id uuid, p_start_date date, p_end_date date
)
RETURNS SETOF reconciliation_fixture.events
LANGUAGE sql
STABLE
SET search_path = pg_catalog
AS $function$
    SELECT event.*
    FROM reconciliation_fixture.cashflow_engine(
        p_user_id, p_start_date, p_end_date
    ) AS event
    WHERE NOT event.is_suppressed
    ORDER BY event.event_date, event.id;
$function$;

INSERT INTO reconciliation_fixture.owners (id, name) VALUES
    ('00000000-0000-4000-8000-000000000001', 'Fixture A'),
    ('00000000-0000-4000-8000-000000000007', 'Fixture B');

INSERT INTO reconciliation_fixture.accounts (id, user_id, name) VALUES
    ('00000000-0000-4000-8000-000000000004',
     '00000000-0000-4000-8000-000000000001', 'Synthetic account');

INSERT INTO reconciliation_fixture.epoch (singleton, epoch) VALUES (true, 0);

INSERT INTO reconciliation_fixture.events (
    id, user_id, account_id, legacy_id, legacy_index, event_date,
    description_raw, description_normalized, amount, nature, category,
    counterparty, source, status, is_internal_transfer, is_projection,
    is_suppressed, suppression_reason, metadata, created_at
) VALUES
    ('00000000-0000-4000-8000-000000000002',
     '00000000-0000-4000-8000-000000000001',
     '00000000-0000-4000-8000-000000000004',
     'synthetic-expected', 1, '2030-01-10',
     'Synthetic expected credit', 'synthetic expected credit', 725,
     'income', 'synthetic', 'Synthetic counterparty', 'synthetic', 'expected',
     false, true, false, NULL, '{"fixture":"expected"}', '2030-01-01 00:00:00+00'),
    ('00000000-0000-4000-8000-000000000006',
     '00000000-0000-4000-8000-000000000001',
     '00000000-0000-4000-8000-000000000004',
     'synthetic-future', 2, '2030-02-10',
     'Synthetic future credit', 'synthetic future credit', 975,
     'income', 'synthetic', 'Synthetic counterparty', 'synthetic', 'expected',
     false, true, false, NULL, '{"fixture":"future"}', '2030-01-01 00:00:00+00'),
    ('00000000-0000-4000-8000-000000000009',
     '00000000-0000-4000-8000-000000000001',
     '00000000-0000-4000-8000-000000000004',
     'synthetic-pending', 3, '2030-01-11',
     'Synthetic pending credit', 'synthetic pending credit', 85.20,
     'income', 'synthetic', 'Synthetic counterparty', 'synthetic', 'pending',
     false, true, false, NULL, '{"fixture":"pending"}', '2030-01-01 00:00:00+00'),
    ('00000000-0000-4000-8000-000000000008',
     '00000000-0000-4000-8000-000000000007', NULL,
     'synthetic-unrelated', 1, '2030-01-10',
     'Synthetic unrelated credit', 'synthetic unrelated credit', 40,
     'income', 'synthetic', 'Synthetic counterparty', 'synthetic', 'expected',
     false, true, false, NULL, '{"fixture":"unrelated"}', '2030-01-01 00:00:00+00');

INSERT INTO reconciliation_fixture.credits (
    id, user_id, provider_account_ref, provider_record_id, connection_id,
    resource_type, currency, posting_date, signed_amount, raw_hash,
    raw_payload, normalized_payload, provider_deleted_at,
    updated_at, last_seen_at, sync_run_id
)
SELECT
    '00000000-0000-4000-8000-000000000003'::uuid,
    '00000000-0000-4000-8000-000000000001'::uuid,
    'synthetic-account-ref', 'synthetic-record-ref',
    '00000000-0000-4000-8000-000000000005'::uuid,
    'transaction', 'XTS', '2030-01-09'::date, 600,
    pg_catalog.md5(payload::text), payload,
    '{"fixture":true,"status":"POSTED","description":"Synthetic posted credit","amount":600,"currency":"XTS"}'::jsonb,
    NULL, '2030-01-09 12:00:00+00'::timestamptz,
    '2030-01-09 12:00:00+00'::timestamptz,
    '00000000-0000-4000-8000-000000000000'::uuid
FROM (
    VALUES ('{"fixture":true,"record":"synthetic-record-ref","status":"POSTED","posting_date":"2030-01-09","amount":600,"currency":"XTS"}'::jsonb)
) AS synthetic(payload);

-- Establish a deterministic post-seed baseline and three cache sentinels.
UPDATE reconciliation_fixture.epoch SET epoch = 0 WHERE singleton;
INSERT INTO reconciliation_fixture.cache (user_id, payload, id) VALUES
    ('00000000-0000-4000-8000-000000000001', '{"fixture":"owner-a"}', 'owner-a'),
    ('00000000-0000-4000-8000-000000000007', '{"fixture":"owner-b"}', 'owner-b'),
    (NULL, '{"fixture":"global"}', 'global');

COMMIT;
