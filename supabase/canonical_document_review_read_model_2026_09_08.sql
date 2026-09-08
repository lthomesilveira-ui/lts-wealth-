-- LTS Wealth canonical document-review read model — 2026-09-08
-- Scope: authenticated, owner-scoped, read-only visibility of interpreted evidence.
-- No approval, reconciliation or financial writer is added by this migration.

create or replace function public.lts_document_review_queue_v1(
  p_user_id uuid,
  p_limit integer default 6
)
returns jsonb
language sql
stable
set search_path to pg_catalog, public
as $function$
with cfg as (
  select greatest(1, least(coalesce(p_limit, 6), 6)) as lim
), eligible as (
  select
    i.id,
    i.original_name,
    i.input_type,
    i.mime_type,
    i.status as technical_status,
    coalesce(l.phase, 'received') as phase,
    coalesce(l.updated_at, i.interpreted_at, i.created_at) as updated_at,
    case
      when jsonb_typeof(i.interpretation) = 'object' then i.interpretation
      else '{}'::jsonb
    end as interpretation
  from public.lts_input_inbox i
  left join public.lts_document_lifecycle l
    on l.inbox_id = i.id
   and l.user_id = i.user_id
  where i.user_id = p_user_id
    and i.input_type in ('photo', 'pdf', 'file')
    and lower(coalesce(i.interpretation ->> 'review_required', 'false')) in ('true', 't', '1', 'yes')
    and coalesce(i.status, '') not in ('rejected', 'discarded')
), limited as (
  select *
  from eligible
  order by updated_at desc, id
  limit (select lim from cfg)
), shaped as (
  select
    e.*,
    coalesce(e.interpretation #> '{task_context,document_association}', '{}'::jsonb) as document_association,
    case
      when jsonb_typeof(e.interpretation -> 'entries') = 'array'
      then jsonb_array_length(e.interpretation -> 'entries')
      else 0
    end as entry_count,
    jsonb_strip_nulls(jsonb_build_object(
      'version', e.interpretation -> 'version',
      'extraction_status', e.interpretation -> 'extraction_status',
      'entries', (
        select coalesce(jsonb_agg(v.value order by v.ordinality), '[]'::jsonb)
        from jsonb_array_elements(
          case
            when jsonb_typeof(e.interpretation -> 'entries') = 'array' then e.interpretation -> 'entries'
            else '[]'::jsonb
          end
        ) with ordinality as v(value, ordinality)
        where v.ordinality <= 25
      ),
      'extracted_fields', case when pg_column_size(e.interpretation -> 'extracted_fields') <= 32768 then e.interpretation -> 'extracted_fields' end,
      'fields', case when pg_column_size(e.interpretation -> 'fields') <= 32768 then e.interpretation -> 'fields' end,
      'facts', case when pg_column_size(e.interpretation -> 'facts') <= 32768 then e.interpretation -> 'facts' end,
      'document', case when pg_column_size(e.interpretation -> 'document') <= 32768 then e.interpretation -> 'document' end,
      'summary', case when pg_column_size(e.interpretation -> 'summary') <= 32768 then e.interpretation -> 'summary' end,
      'metadata', case when pg_column_size(e.interpretation -> 'metadata') <= 32768 then e.interpretation -> 'metadata' end
    )) as review_payload
  from limited e
), items as (
  select coalesce(jsonb_agg(jsonb_build_object(
    'inbox_id', id,
    'original_name', original_name,
    'input_type', input_type,
    'mime_type', mime_type,
    'technical_status', technical_status,
    'phase', phase,
    'phase_label', case phase
      when 'received' then 'Recebido'
      when 'interpreted' then 'Interpretado'
      when 'reconciled' then 'Reconciliado'
      when 'needs_decision' then 'Precisa de decisão'
      when 'resolved' then 'Resolvido'
      else 'Em revisão'
    end,
    'updated_at', updated_at,
    'document_association', document_association,
    'entry_count', entry_count,
    'review_payload', review_payload,
    'evidence_truncated', entry_count > 25,
    'review_required', true,
    'write_allowed', false
  ) order by updated_at desc, id), '[]'::jsonb) as value
  from shaped
)
select jsonb_build_object(
  'version', 'document-interpretation-review-readonly-v1',
  'contract', 'v149-evidence-review-readonly-canonical-v1',
  'queue_documents', (select count(*) from eligible),
  'shown_documents', (select count(*) from limited),
  'items', (select value from items),
  'write_allowed', false,
  'financial_writer_called', false,
  'guardrail', 'Vínculo informado e leitura extraída permanecem separados. Esta RPC não aprova, reconcilia, classifica nem grava fatos financeiros.'
);
$function$;

create or replace function public.lts_browser_document_review_queue_v1(
  p_limit integer default 6
)
returns jsonb
language plpgsql
stable
security definer
set search_path to pg_catalog, public
as $function$
declare
  v_uid uuid;
begin
  v_uid := public.lts_browser_assert_user_v1();
  return public.lts_document_review_queue_v1(v_uid, p_limit);
end;
$function$;

revoke all on function public.lts_document_review_queue_v1(uuid, integer) from public, anon, authenticated;
revoke all on function public.lts_browser_document_review_queue_v1(integer) from public, anon;
grant execute on function public.lts_browser_document_review_queue_v1(integer) to authenticated, service_role;

comment on function public.lts_document_review_queue_v1(uuid, integer) is
  'Internal owner-scoped document evidence read model. Returns bounded review payloads and never writes.';
comment on function public.lts_browser_document_review_queue_v1(integer) is
  'Authenticated document evidence review queue. Uses lts_browser_assert_user_v1 and exposes no writer.';
