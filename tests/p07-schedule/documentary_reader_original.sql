CREATE OR REPLACE FUNCTION public.lts_documentary_commitments_v1(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
with s as (
 select commitment_id,
        count(*) filter(where status='scheduled') remaining_loaded,
        coalesce(sum(amount_total) filter(where status='scheduled'),0) future_loaded_total,
        min(due_date) filter(where status='scheduled') next_date,
        max(due_date) filter(where status='scheduled') last_loaded_date,
        (array_agg(amount_total order by due_date) filter(where status='scheduled'))[1] next_amount,
        coalesce(jsonb_agg(jsonb_build_object('installment_number',installment_number,'due_date',due_date,'amount',amount_total,'principal',principal,'interest',interest,'balance_after',balance_after,'status',status) order by due_date) filter(where status='scheduled'),'[]'::jsonb) rows
 from public.lts_commitment_documentary_schedule
 where user_id=p_user_id
 group by commitment_id
), d as (
 select commitment_id,as_of_date,institution,contract_ref,debt_balance,status,source_label,metadata
 from public.lts_debt_position where user_id=p_user_id
)
select jsonb_build_object(
 'version','documentary-commitments-v2-schedule-rows',
 'items',coalesce((select jsonb_agg(jsonb_build_object(
   'commitment_id',d.commitment_id,'as_of_date',d.as_of_date,'institution',d.institution,'contract_ref',d.contract_ref,
   'debt_balance',d.debt_balance,'status',d.status,'source_label',d.source_label,'metadata',d.metadata,
   'schedule_loaded',case when s.commitment_id is null then null else jsonb_build_object('remaining_loaded',s.remaining_loaded,'future_loaded_total',s.future_loaded_total,'next_date',s.next_date,'next_amount',s.next_amount,'last_loaded_date',s.last_loaded_date,'rows',s.rows) end
 ) order by d.commitment_id) from d left join s using(commitment_id)),'[]'::jsonb),
 'guardrail','Saldo devedor só aparece quando documentado. Total de parcelas futuras não substitui estoque de dívida. Em CIPÓ, rows carregadas são trecho operacional; metadata.remaining_installments/final_due descrevem o contrato completo.'
);
$function$;
