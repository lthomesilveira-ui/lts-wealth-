"""Guarded parity for an existing received invoice that becomes due today."""
import hashlib,json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
MARK_OLD=""" SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND x->>'source'='current_event' AND (x->>'event_date')::date=current_date
  AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
   AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
   AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric)
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;"""
MARK_NEW=""" WITH due_invoices AS MATERIALIZED (
  SELECT inv.* FROM public.lts_current_received_card_bills_v263(u) inv
  WHERE inv.due_date=current_date AND inv.amount>0
   AND inv.payment_status='payment_not_reported' AND inv.reported_payment_amount=0
 )
 SELECT coalesce(jsonb_agg(x||CASE WHEN NOT coalesce((x->>'bank_confirmed')::boolean,false)
  AND (x->>'event_date')::date=current_date
  AND ((x->>'source'='current_event'
   AND EXISTS(SELECT 1 FROM public.financial_events fe WHERE fe.user_id=u AND fe.is_projection AND NOT fe.is_suppressed
    AND (fe.id::text=x->>'source_ref' OR fe.legacy_id=x->>'source_ref')
    AND fe.event_date=(x->>'event_date')::date AND fe.amount=(x->>'signed_amount')::numeric))
   OR (x->>'source'='card_invoice' AND (x->>'signed_amount')::numeric<0
    AND 1=(SELECT count(*) FROM due_invoices inv JOIN public.card_invoices ci
     ON ci.user_id=u AND ci.reference_month=inv.reference_month
      AND public.lts_card_family_v226(ci.card_name,ci.card_name)=inv.family
     WHERE x->>'source_ref'=ci.card_name||'|'||to_char(ci.reference_month,'YYYY-MM')
      AND ci.status IN('open','projected') AND inv.invoice_source_id IS NOT NULL
      AND x->>'account'=public.lts_card_invoice_account_v181(ci.card_name)
      AND (x->>'signed_amount')::numeric=-inv.amount
      AND NOT public.lts_card_invoice_settled_v290(u,ci.card_name,ci.reference_month,inv.due_date,inv.amount))))
  THEN jsonb_build_object('unposted_current_projection',true) ELSE '{}'::jsonb END),'[]') INTO recent FROM jsonb_array_elements(recent) x;"""
KEEP_OLD="""  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))"""
KEEP_NEW="""  WHERE coalesce((x->>'bank_confirmed')::boolean,false)
  OR (x->>'source'='card_invoice' AND coalesce((x->>'unposted_current_projection')::boolean,false) AND (x->>'event_date')::date=current_date)
  OR (coalesce(x->>'confidence','') NOT IN ('legacy_projection_adjusted','documented_scheduled','documented_expected','documented_open','documented_projected_snapshot') AND NOT coalesce((x->>'unposted_past_projection')::boolean,false))"""
ARRAY_CHANGES=[
 ('d jsonb; dt date; c jsonb; outdays jsonb; part text; dayev jsonb;',
  'd jsonb; dt date; c jsonb; outdays jsonb; out_day_rows jsonb[]; part text; dayev jsonb;'),
 ("  outdays:='[]';", "  outdays:='[]';out_day_rows:=ARRAY[]::jsonb[];"),
 ('   outdays:=outdays||jsonb_build_array(d);','   out_day_rows:=array_append(out_day_rows,d);'),
 ("  END LOOP;\n  f:=jsonb_set(f,ARRAY[part],", "  END LOOP;\n  outdays:=to_jsonb(out_day_rows);\n  f:=jsonb_set(f,ARRAY[part],")
]
TARGETS=[
 {'file':'cache-original.sql','signature':'public.lts_flow_cache_pre_v240(uuid,date,date)','md5':'271550df3c19df4f3e04ea04cf37c4b8','array':True},
 {'file':'browser-original.sql','signature':'public.lts_browser_flow_pre_v238(date,date)','md5':'4caa05ad348ad817df9491b451dc87ea','array':False}
]
def md5(text):return hashlib.md5(text.encode()).hexdigest()
def patch(text,array=False):
    for old,new in [(MARK_OLD,MARK_NEW),(KEEP_OLD,KEEP_NEW)]+(ARRAY_CHANGES if array else []):
        assert text.count(old)==1,old[:90]
        text=text.replace(old,new)
    return text
def block(text):
    start=text.index(' -- A scheduled event for today')
    end=text.index(' SELECT coalesce(jsonb_agg(x||CASE WHEN k.c',start)
    return text[start:end]
def dollar(text,tag):
    assert '$'+tag+'$' not in text
    return '$'+tag+'$'+text+'$'+tag+'$'
def lifecycle(reverse=False):
    checks=[];changes=[]
    for target in TARGETS:
        original=(ROOT/target['file']).read_text();assert md5(original)==target['md5']
        replacement=patch(original,target['array'])
        before,after=(replacement,original) if reverse else (original,replacement)
        signature=target['signature'];old_hash,new_hash=md5(before),md5(after)
        checks.append(f""" p:='{signature}'::regprocedure;
 SELECT md5(pg_get_functiondef(p)),proacl::text,proconfig,prosecdef,pg_get_userbyid(proowner)
 INTO actual_hash,actual_acl,actual_config,actual_definer,actual_owner FROM pg_proc WHERE oid=p;
 IF actual_hash NOT IN('{old_hash}','{new_hash}') OR actual_acl IS DISTINCT FROM '{{postgres=X/postgres,service_role=X/postgres}}'
 OR actual_owner<>'postgres' OR actual_config IS DISTINCT FROM ARRAY['search_path=""','TimeZone=America/Sao_Paulo','statement_timeout=18s']
 OR actual_definer IS DISTINCT FROM {'true' if not target['array'] else 'false'} THEN
  RAISE EXCEPTION 'due-today reader changed concurrently: %',p;
 END IF;""")
        pairs=[(MARK_OLD,MARK_NEW),(KEEP_OLD,KEEP_NEW)]+(ARRAY_CHANGES if target['array'] else [])
        if reverse:pairs=[(new,old) for old,new in reversed(pairs)]
        replacements='\n'.join(" next_sql:=replace(next_sql,"+dollar(old,'before_fragment')+","+dollar(new,'after_fragment')+");" for old,new in pairs)
        changes.append(f""" p:='{signature}'::regprocedure;
 IF md5(pg_get_functiondef(p))='{old_hash}' THEN
  next_sql:=pg_get_functiondef(p);
{replacements}
  IF md5(next_sql)<>'{new_hash}' THEN RAISE EXCEPTION 'due-today patch reconstruction differs';END IF;
  EXECUTE next_sql;
  IF md5(pg_get_functiondef(p))<>'{new_hash}' THEN RAISE EXCEPTION 'due-today installed definition differs';END IF;
 END IF;""")
    return """BEGIN;
SET LOCAL lock_timeout='2s';
DO $due_today_install$
DECLARE p regprocedure;actual_hash text;actual_acl text;actual_config text[];actual_definer boolean;actual_owner text;next_sql text;
BEGIN
"""+'\n'.join(checks+changes)+"\nEND $due_today_install$;\nCOMMIT;\n"
if __name__=='__main__':
    manifest=[]
    for target in TARGETS:
        before=(ROOT/target['file']).read_text();after=patch(before,target['array'])
        assert md5(before)==target['md5']
        manifest.append({'signature':target['signature'],'before':md5(before),'after':md5(after),
         'source_writes':False,'security_changed':False,'array_assembly_aligned_with_existing_browser':target['array']})
    (ROOT/'install.sql').write_text(lifecycle())
    (ROOT/'rollback.sql').write_text(lifecycle(True))
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps({'pass':True,'targets':manifest}))
