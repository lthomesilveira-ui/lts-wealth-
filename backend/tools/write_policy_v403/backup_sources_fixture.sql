-- Extends the real V401 formatter fixture with synthetic V402 source evidence.
CREATE TABLE public.lts_open_finance_resource_map(id bigint PRIMARY KEY,user_id uuid,provider_resource_id text,metadata jsonb);
CREATE TABLE public.lts_open_finance_observation(id uuid PRIMARY KEY,user_id uuid,connection_id uuid,sync_run_id uuid,resource_type text,provider_record_id text,raw_hash text,raw_payload jsonb,normalized_payload jsonb,observed_at timestamptz);
CREATE UNIQUE INDEX ON public.lts_open_finance_observation(sync_run_id,resource_type,provider_record_id);
INSERT INTO public.lts_open_finance_connection(id,user_id,provider)VALUES('cccccccc-cccc-4ccc-8ccc-000000000001','00000000-0000-4000-8000-000000000004','synthetic');
INSERT INTO public.lts_open_finance_sync_run(id,user_id,connection_id,status,started_at)VALUES
 ('bbbbbbbb-bbbb-4bbb-8bbb-000000000001','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','success',current_date-1+interval'9 hours'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-000000000002','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','success',current_date-1+interval'10 hours'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-000000000003','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','success',current_date+interval'1 minute');
INSERT INTO public.lts_open_finance_resource_map VALUES(1,'00000000-0000-4000-8000-000000000004','component-a','{"verified":true}'),(2,'00000000-0000-4000-8000-000000000005','other-owner','{}');
INSERT INTO public.lts_open_finance_observation VALUES
 ('dddddddd-dddd-4ddd-8ddd-000000000001','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-000000000001','investment','a','first','{"balance":100}','{}',current_date-1+interval'9 hours'),
 ('dddddddd-dddd-4ddd-8ddd-000000000002','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-000000000002','investment','a','last','{"balance":101}','{}',current_date-1+interval'10 hours'),
 ('dddddddd-dddd-4ddd-8ddd-000000000003','00000000-0000-4000-8000-000000000004','cccccccc-cccc-4ccc-8ccc-000000000001','bbbbbbbb-bbbb-4bbb-8bbb-000000000003','investment','a','today','{"balance":102}','{}',current_date+interval'1 minute');
CREATE TABLE public.qa_backup_history_v403 AS SELECT snapshot_date,user_id,payload_hash,payload_bytes FROM public.lts_backup_snapshot;
CREATE TABLE public.qa_backup_modern_history_v403 AS SELECT snapshot_date,user_id,payload_sha256,payload_bytes,counts FROM public.lts_backup_supplement_v380;
CREATE TABLE public.accounts(id uuid,user_id uuid,balance numeric);
CREATE TABLE public.financial_events(id uuid,user_id uuid,amount numeric);
CREATE TABLE public.asset_positions(id uuid,user_id uuid,value_brl numeric);
CREATE TABLE public.card_invoices(id uuid,user_id uuid,amount numeric);
CREATE TABLE public.source_documents(id uuid,user_id uuid,metadata jsonb);
CREATE TABLE public.lts_input_inbox(id uuid,user_id uuid,storage_path text,payload jsonb);
CREATE TABLE public.lts_project_checkpoint(id text,payload jsonb);
CREATE TABLE public.evento_base(id bigint,usuario_id uuid,dados jsonb);
CREATE TABLE public.evento_usuario(id bigint,usuario_id uuid,dados jsonb);
CREATE TABLE public.contrato(id bigint,usuario_id uuid,dados jsonb);
CREATE TABLE public.compromisso(id bigint,usuario_id uuid,dados jsonb);
CREATE TABLE public.legacy_namespace(id bigint,usuario_id uuid,dados jsonb);
CREATE FUNCTION public.lts_integrity_gate_diagnostic_v1(p_user_id uuid)RETURNS jsonb LANGUAGE plpgsql AS $$BEGIN RAISE EXCEPTION 'Runtime QA must not run during a data backup';END$$;
INSERT INTO public.accounts VALUES('eeeeeeee-eeee-4eee-8eee-000000000001','00000000-0000-4000-8000-000000000004',500);
INSERT INTO public.asset_positions VALUES('eeeeeeee-eeee-4eee-8eee-000000000002','00000000-0000-4000-8000-000000000004',102);
GRANT SELECT ON public.lts_open_finance_resource_map,public.lts_open_finance_observation TO service_role;
