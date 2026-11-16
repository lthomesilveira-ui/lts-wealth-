CREATE OR REPLACE FUNCTION public.lts_browser_expense_review_queue_v229(p_from date, p_to date, p_offset integer DEFAULT 0, p_limit integer DEFAULT 25, p_query text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
 SET "TimeZone" TO 'America/Sao_Paulo'
AS $function$
declare
  v_uid uuid:=public.lts_browser_assert_user_v1();
  v_result jsonb;
begin
  if p_from is null or p_to is null or p_from>p_to or p_from<date '2013-10-10'
     or p_to>current_date or p_offset<0 or p_limit not between 1 and 100 then
    raise exception 'invalid review queue range';
  end if;

  with pending as materialized (
    select r.*,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'person'
        when r.management_group='Moradia — imóvel a confirmar' then 'property'
        when r.property_component='A revisar' then 'property_purpose'
        else 'classification'
      end question_kind,
      case
        when r.beneficiary is null and r.category ~* 'saúde|saude|educa|vestu' then 'De quem é esta despesa?'
        when r.management_group='Moradia — imóvel a confirmar' then 'A que imóvel se refere?'
        when r.property_component='A revisar' then 'Qual é a finalidade deste gasto no imóvel?'
        else 'Qual é a pessoa ou classificação correta?'
      end review_question
    from public.lts_v229_review_rows(v_uid,p_from,p_to) r
    where r.identity_status='pending'
  ), filtered as materialized (
    select * from pending
    where nullif(trim(p_query),'') is null
       or strpos(public.lts_v178_norm(concat_ws(' ',description,account_source,category,management_group,raw_reference)),public.lts_v178_norm(trim(p_query)))>0
  ), page as materialized (
    select * from filtered
    order by event_date desc,amount desc,row_key
    offset p_offset limit p_limit
  ), suggestions AS MATERIALIZED (
    SELECT * FROM public.lts_review_suggestions_v231(v_uid,coalesce((SELECT jsonb_agg(to_jsonb(page)) FROM page),'[]'))
  ), options as (
    select public.lts_browser_card_category_options_v226()->'categories' categories
  )
  select jsonb_build_object(
    'version','expense-review-queue-v229',
    'from',p_from,'to',p_to,
    'row_count',(select count(*) from pending),
    'pending_projections',public.lts_pending_projections_v233(v_uid),
    'queue_breakdown',jsonb_build_object(
     'historical_context',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) NOT IN ('a classificar','sem categoria','nao identificado')),
     'classification_needed',(SELECT count(*) FROM pending WHERE public.lts_v178_norm(category) IN ('a classificar','sem categoria','nao identificado')),
     'classification',(SELECT count(*) FROM pending WHERE question_kind='classification'),
     'person',(SELECT count(*) FROM pending WHERE question_kind='person'),
     'property',(SELECT count(*) FROM pending WHERE question_kind IN ('property','property_purpose'))),
    'matched_count',(select count(*) from filtered),
    'offset',p_offset,
    'next_offset',case when p_offset+p_limit<(select count(*) from filtered) then p_offset+p_limit end,
    'category_options',coalesce((select categories from options),'[]'::jsonb),
    'beneficiary_options',jsonb_build_array(
      jsonb_build_object('value','Lucas','label','Minha / sem prefixo'),
      jsonb_build_object('value','Benjamin','label','Benjamin'),
      jsonb_build_object('value','Larissa','label','Larissa'),
      jsonb_build_object('value','Rafiki','label','Rafiki')
    ),
    'property_options',jsonb_build_array(
      jsonb_build_object('value','cipo396','label','Apartamento · CIPÓ 396'),
      jsonb_build_object('value','other_property','label','Outro imóvel'),
      jsonb_build_object('value','not_property','label','Não é gasto de imóvel')
    ),
    'rows',coalesce((select jsonb_agg(jsonb_build_object(
      'key',row_key,'source_table',source_table,'source_ref',source_ref,
      'date',event_date,'period',competence_month,'description',description,
      'account_source',account_source,'amount',amount,'category',category,
      'beneficiary',beneficiary,'management_group',management_group,
      'question_kind',question_kind,'review_question',review_question,
      'suggestion',(SELECT s.suggestion FROM suggestions s WHERE s.source_table=page.source_table AND s.source_ref=page.source_ref)
    ) order by event_date desc,amount desc,row_key) from page),'[]'::jsonb)
  ) into v_result;

  return v_result;
end
$function$

