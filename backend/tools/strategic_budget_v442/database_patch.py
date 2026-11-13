"""Guarded reporting-only corrections; preserve financial sources and writer APIs."""
from pathlib import Path
import hashlib
ROOT=Path(__file__).resolve().parents[3];P=ROOT/'backend/patches/v442'
def md5(s):return hashlib.md5(s.encode()).hexdigest()
def guarded(name,signature,source,candidate,previous_hash=None):
 h=md5(source);k=md5(candidate)
 allowed="md5(s) NOT IN('"+h+"','"+previous_hash+"')" if previous_hash else "md5(s)<>'"+h+"'"
 return "DO $guard$ DECLARE s text;a jsonb;BEGIN SELECT pg_get_functiondef(p.oid),to_jsonb(p)-'prosrc' INTO STRICT s,a FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure;IF md5(s)='"+k+"' THEN RETURN;END IF;IF "+allowed+" THEN RAISE EXCEPTION '"+name+" predecessor changed; review before applying';END IF;EXECUTE $candidate$"+candidate+"$candidate$;IF a IS DISTINCT FROM(SELECT to_jsonb(p)-'prosrc' FROM pg_proc p WHERE p.oid='"+signature+"'::regprocedure) OR md5(pg_get_functiondef('"+signature+"'::regprocedure))<>'"+k+"' THEN RAISE EXCEPTION '"+name+" attributes changed';END IF;END $guard$;\n"
def build():
 a=(P/'taxonomy_before.sql').read_text();assert md5(a)=='b51d96fe858c67d70c3f1b035b8c0af0'
 old="WHEN c='compromissos financeiros'AND m='emprestimos'THEN";assert a.count(old)==1
 b=a.replace(old,"WHEN c~'^emprestimos?$'OR m='emprestimos'THEN");assert b.replace("WHEN c~'^emprestimos?$'OR m='emprestimos'THEN",old)==a
 (P/'taxonomy_candidate.sql').write_text(b);sql=guarded('Loan grouping','public.lts_expense_taxonomy_v353(text,text,text)',a,b)
 a=(P/'budget_builder_before.sql').read_text();assert md5(a)=='8041add67e5f514c102754dfaa81cc66'
 changes=[
 ("(bonus|premio|ferias|13o|13º|13°|decimo terceiro)","(bonus|premio|ferias|(^|[^0-9])13([º°o]|[[:space:]])|decimo terceiro)"),
 ("~ '(bonus|premio)' bonus", "~ '(bonus|premio)' bonus,\n   public.lts_v178_norm(concat_ws(' ',x->>'category',x->>'description'))~'(^|[^0-9])13([º°o]|[[:space:]])|decimo terceiro' thirteenth"),
 ("round(coalesce(sum(amount)FILTER(WHERE coverage_mode='card_observed_pending'),0),2) pending", "round(coalesce(sum(amount)FILTER(WHERE coverage_mode='card_observed_pending'),0),2) pending,\n   round(coalesce(sum(amount)FILTER(WHERE coverage_mode LIKE 'card_%'),0),2) card_actual"),
 ("round(coalesce(sum(amount)FILTER(WHERE NOT regular AND bonus),0),2) bonus", "round(coalesce(sum(amount)FILTER(WHERE NOT regular AND bonus),0),2) bonus,\n   round(coalesce(sum(amount)FILTER(WHERE thirteenth),0),2) thirteenth"),
 ("coalesce(e.amount,0) actual,coalesce(e.pending,0) pending", "coalesce(e.amount,0) actual,coalesce(e.pending,0) pending,coalesce(e.card_actual,0) card_actual"),
 ("'pending',pending,'target_basis',target_basis", "'pending',pending,'card_actual',card_actual,'target_basis',target_basis"),
 ("coalesce(i.bonus,0) income_bonus", "coalesce(i.bonus,0) income_bonus,coalesce(i.thirteenth,0) income_thirteenth"),
 ("i.regular,i.extraordinary,i.bonus", "i.regular,i.extraordinary,i.bonus,i.thirteenth"),
 ("'income_bonus',income_bonus,", "'income_bonus',income_bonus,'income_thirteenth',income_thirteenth,"),
 ("'proposed',rev=0,", "'proposed',rev=0,'income_approvals',jsonb_build_object('year',cfg?'income_year','months',(SELECT coalesce(jsonb_object_agg(key,true),'{}'::jsonb) FROM jsonb_object_keys(coalesce(cfg->'income_months','{}'::jsonb))key)),"),
 ("'basis','canonical_consumption_not_card_payment'", "'category_aliases',coalesce((SELECT jsonb_object_agg(raw_category,category) FROM(SELECT b.raw_category,min(c.category)category FROM public.lts_category_binding_v290 b JOIN public.lts_category_catalog c USING(user_id,category_key) WHERE b.user_id=p_user GROUP BY b.raw_category HAVING count(DISTINCT b.category_key)=1)d),'{}'::jsonb),'basis','canonical_consumption_not_card_payment'")]
 b=a
 for old,new in changes:
  assert b.count(old)==1,old
  b=b.replace(old,new)
 restored=b
 for old,new in reversed(changes):restored=restored.replace(new,old)
 assert restored==a
 (P/'budget_builder_candidate.sql').write_text(b)
 previous=(P/'budget_builder_metadata_v1.sql').read_text();assert md5(previous)=='7f86141829a633859509f3e9457a23c4'
 sql+=guarded('Budget metadata and thirteenth separation','lts_budget_private_v441.build(uuid,integer,date)',a,b,md5(previous))
 a=(P/'flow_editor_before.sql').read_text()
 old='AS $function$ declare u uuid; begin u:=public.lts_browser_assert_user_v1(); return public.lts_flow_event_editor_v1(u,p_source,p_source_ref,p_event_date); end $function$'
 assert a.count(old)==1
 new="""AS $function$
 DECLARE u uuid:=public.lts_browser_assert_user_v1();r jsonb;original jsonb;parts jsonb;total numeric;
 BEGIN
  r:=public.lts_flow_event_editor_v1(u,p_source,p_source_ref,p_event_date);
  IF p_source='legacy_fix86' AND p_source_ref~'^evento_base:[0-9]+$' THEN
   SELECT jsonb_agg(dados)->0 INTO original FROM public.evento_base WHERE usuario_id=u AND 'evento_base:'||idx=p_source_ref HAVING count(*)=1;
   parts:=original->'composition';
   IF jsonb_typeof(parts)='array' AND jsonb_array_length(parts) BETWEEN 1 AND 12 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x WHERE NOT coalesce(jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$' AND nullif(trim(x->>'rubric'),'') IS NOT NULL,false)) THEN
    SELECT sum((x->>'amount')::numeric) INTO total FROM jsonb_array_elements(parts)x
    WHERE jsonb_typeof(x->'amount')='number' AND x->>'amount'~'^[0-9]+([.][0-9]+)?$';
    IF total=(r->>'amount')::numeric AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(parts)x
     WHERE nullif(trim(x->>'rubric'),'') IS NULL OR jsonb_typeof(x->'amount')<>'number') THEN
     r:=r||jsonb_build_object('composition',parts,'payroll_reference_date',original->>'payroll_reference_date',
      'composition_document_pending',coalesce(original#>'{evidence,statement_pending}'='true'::jsonb,false));
    END IF;
   END IF;
  END IF;
  RETURN r;
 END $function$"""
 b=a.replace(old,new);(P/'flow_editor_candidate.sql').write_text(b)
 sql+=guarded('Read-only income composition','public.lts_browser_flow_event_editor_v1(text,text,date)',a,b)
 (P/'strategic_reporting_install.sql').write_text(sql)
 print({'taxonomy_md5':md5((P/'taxonomy_candidate.sql').read_text()),'budget_builder_md5':md5((P/'budget_builder_candidate.sql').read_text()),'flow_editor_md5':md5(b)})
if __name__=='__main__':build()
