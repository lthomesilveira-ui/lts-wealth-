not exists(select 1 from public.lts_projection_replacement_rule r where r.user_id=p_user_id and r.active=true and r.source_table='evento_base'
      and (r.description_exact is null or r.description_exact=eb.dados->>'desc') and (r.account_exact is null or r.account_exact=eb.dados->>'conta')
      and (r.date_from is null or (eb.dados->>'dia')::date>=r.date_from) and (r.date_to is null or (eb.dados->>'dia')::date<=r.date_to))
