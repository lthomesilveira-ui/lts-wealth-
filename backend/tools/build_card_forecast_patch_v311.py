"""Build a leased patch from supplied current definitions; no financial records."""
from pathlib import Path
import hashlib,json,sys

ROOT=Path(__file__).resolve().parents[2]
LEASES={
 'lts_card_cycles_v226':'58b393f8b4b6c6c2958b1599b54786d2',
 'lts_card_projection_rows_v290':'1188e11530c8183a4efb14907dd5d232',
 'lts_card_projected_invoice_records_v290':'208fbed6da3dcf55f51d66fef7c73c5c',
 'lts_card_invoices_effective_v226':'8bc63c1bd55908819c981d57860c6242',
}
def once(value,old,new):
 if value.count(old)!=1:raise ValueError('Required definition fragment changed')
 return value.replace(old,new,1)

def build(records):
 definitions={name:entry['definition'] for name,entry in records.items()}
 cycles=definitions['lts_card_cycles_v226']
 cycles=once(cycles,'public.lts_card_due_overlay_v290(p_user_id,result)',
  'public.lts_card_due_overlay_v290(p_user_id,public.lts_card_forecast_overlay_v311(p_user_id,result))')
 # An exact closed documentary bill replaces a leftover past-cycle projection.
 cycles=once(cycles,"AND open_cycle.status IN('open','projected')\n AND open_cycle.reference_month=b.reference_month",
  "AND (open_cycle.status IN('open','projected') OR (b.family='c6' AND open_cycle.status='closed'\n AND open_cycle.metadata->>'bank_statement_full_composition'='true' AND open_cycle.amount=b.amount))\n AND open_cycle.reference_month=b.reference_month")
 cycles=once(cycles,"AND (i.status NOT IN('open','projected') OR i.due_date IS DISTINCT FROM b.due_date",
  "AND ((i.status NOT IN('open','projected') AND NOT(b.family='c6' AND i.status='closed'\n AND i.metadata->>'bank_statement_full_composition'='true' AND i.amount=b.amount)) OR i.due_date IS DISTINCT FROM b.due_date")
 projection=definitions['lts_card_projection_rows_v290']
 projection=once(projection,'WHERE g.amount>=0 AND g.reference_month+g.due_day-1>=current_date',
  """WHERE g.amount>=0 AND g.reference_month+g.due_day-1>=current_date
UNION ALL
SELECT p_user_id,ci.card_name,f.reference_month,f.due_date,'projected'::text,f.amount,'received_card_composition_v290'::text
FROM public.lts_aeternum_forecast_cycles_v311(p_user_id) f
JOIN LATERAL(SELECT i.card_name FROM public.card_invoices i WHERE i.user_id=p_user_id
 AND public.lts_card_family_v226(i.card_name,i.card_name)='aeternum'
 ORDER BY i.reference_month DESC,i.due_date DESC LIMIT 1)ci ON true""")
 records_def=definitions['lts_card_projected_invoice_records_v290']
 records_def=once(records_def,"'items',coalesce((SELECT", "'items',coalesce((SELECT f.items FROM public.lts_aeternum_forecast_cycles_v311(p_user_id)f\n WHERE public.lts_card_family_v226(p.card_name,p.card_name)='aeternum' AND f.reference_month=p.reference_month),(SELECT")
 effective=definitions['lts_card_invoices_effective_v226']
 effective=once(effective,"jsonb_build_object('amount',a.amount,'source',a.source,'due_date',a.due_date,'status',a.status) ELSE '{}'::jsonb END)",
  """jsonb_build_object('amount',a.amount,'source',a.source,'due_date',a.due_date,'status',a.status)
 ||CASE WHEN forecast.reference_month IS NOT NULL THEN jsonb_build_object('metadata',
 coalesce(e.value->'metadata','{}')||jsonb_build_object('items',forecast.items,'projection_only',true,'official_invoice_received',false,
 'received_amount',forecast.received_amount,'projected_amount',forecast.projected_amount)) ELSE '{}'::jsonb END
 ELSE '{}'::jsonb END)""")
 effective=once(effective," cross join lateral jsonb_populate_record(null::public.card_invoices,",
  " LEFT JOIN public.lts_aeternum_forecast_cycles_v311(p_user_id)forecast ON public.lts_card_family_v226(e.value->>'card_name',e.value->>'card_name')='aeternum' AND forecast.reference_month=(e.value->>'reference_month')::date\n cross join lateral jsonb_populate_record(null::public.card_invoices,")
 updated={'lts_card_cycles_v226':cycles,'lts_card_projection_rows_v290':projection,
  'lts_card_projected_invoice_records_v290':records_def,'lts_card_invoices_effective_v226':effective}
 helper_parts=[]
 for name in ['aeternum_forecast_cycles.sql','card_cycle_overlay.sql']:
  definition=(ROOT/'backend/patches/v311'/name).read_text()
  sig='public.lts_aeternum_forecast_cycles_v311(uuid)' if name.startswith('aeternum') else 'public.lts_card_forecast_overlay_v311(uuid,jsonb)'
  body_hash=hashlib.md5(definition.split('$function$')[1].encode()).hexdigest()
  helper_parts.append(f"DO $helper_lease$ BEGIN IF to_regprocedure('{sig}') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM pg_proc WHERE oid=to_regprocedure('{sig}') AND md5(prosrc)='{body_hash}' AND NOT prosecdef AND provolatile='s') THEN RAISE EXCEPTION 'V311 helper lease changed'; END IF; END $helper_lease$;\n"+definition)
 blocks=[]
 for name,new in updated.items():
  old=definitions[name];old_hash=hashlib.md5(old.encode()).hexdigest()
  if name in LEASES and old_hash!=LEASES[name]:raise ValueError('Unexpected input definition: '+name+' '+old_hash)
  new_hash=hashlib.md5(new.encode()).hexdigest();signature=f'public.{name}(uuid)'
  blocks.append(f"""DO $lease$
DECLARE before_attrs jsonb;
BEGIN
 IF md5(pg_get_functiondef('{signature}'::regprocedure))='{new_hash}' THEN RETURN; END IF;
 IF md5(pg_get_functiondef('{signature}'::regprocedure))<>'{old_hash}' THEN RAISE EXCEPTION 'V311 reader lease changed: {name}'; END IF;
 SELECT to_jsonb(p)-ARRAY['prosrc','probin'] INTO before_attrs FROM pg_proc p WHERE oid='{signature}'::regprocedure;
 EXECUTE $definition${new}$definition$;
 IF before_attrs IS DISTINCT FROM(SELECT to_jsonb(p)-ARRAY['prosrc','probin'] FROM pg_proc p WHERE oid='{signature}'::regprocedure)
 THEN RAISE EXCEPTION 'V311 changed reader attributes: {name}'; END IF;
END $lease$;
""")
 grants="\n".join(f'REVOKE ALL ON FUNCTION public.{n}({args}) FROM PUBLIC,anon,authenticated;\nGRANT EXECUTE ON FUNCTION public.{n}({args}) TO service_role;'
  for n,args in [('lts_aeternum_forecast_cycles_v311','uuid'),('lts_card_forecast_overlay_v311','uuid,jsonb')])
 return "SET LOCAL lock_timeout='2s';\n"+'\n'.join(helper_parts)+'\n'+grants+'\n'+'\n'.join(blocks)

if __name__=='__main__':print(build(json.load(sys.stdin)))
