"""Render a pure CTE/SELECT for PG17. Never connects to or executes SQL."""
import json
from pathlib import Path
ROOT=Path(__file__).parent

def scalar(e): return f"({e}#>>'{{}}')"
def sid(e): return f"(jsonb_typeof({e})='string' AND {scalar(e)} COLLATE \"C\" ~ '^[!-~]+$')"
def key(e): return "jsonb_build_object("+','.join(f"'{k}',{e}->'{k}'" for k in ('owner','institution','account','bill_id'))+")"
def vkey(e): return '('+' AND '.join(sid(f"{e}->'{k}'") for k in ('owner','institution','account','bill_id'))+')'
def dt(e):
    t=scalar(e)
    return f"(CASE WHEN jsonb_typeof({e})='string' AND {t} ~ '^[0-9]{{4}}-[0-9]{{2}}-[0-9]{{2}}$' THEN CASE WHEN pg_input_is_valid({t},'date') THEN {t}::date END END)"
def ts(e):
    t=scalar(e)
    pattern='^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-2][0-9]:[0-5][0-9]:[0-5][0-9]([.][0-9]{1,6})?(Z|[+-](0[0-9]|1[0-3]):[0-5][0-9]|[+-]14:00)$'
    # The [0-2][0-9] regex is tightened below; PostgreSQL accepts 24:00 unlike Python.
    pattern=pattern.replace('[0-2][0-9]:','(0[0-9]|1[0-9]|2[0-3]):',1)
    return f"(CASE WHEN jsonb_typeof({e})='string' AND {t} ~ '{pattern}' THEN CASE WHEN pg_input_is_valid({t},'timestamptz') THEN CASE WHEN extract(year FROM {t}::timestamptz AT TIME ZONE 'UTC') BETWEEN 1 AND 9999 THEN {t}::timestamptz END END END)"
def amt(e):
    t=scalar(e)
    return f"(CASE WHEN jsonb_typeof({e})='string' AND {t} ~ '^[0-9]{{1,18}}([.][0-9]{{1,2}})?$' THEN {t}::numeric END)"
def arr(e): return f"(CASE WHEN jsonb_typeof({e})='array' THEN {e} ELSE '[]'::jsonb END)"
def ids(e): return f"(jsonb_typeof({e})='array' AND NOT EXISTS(SELECT FROM jsonb_array_elements({arr(e)}) x(v) WHERE ({sid('x.v')}) IS NOT TRUE))"
source=(ROOT/'inputs.json').read_text()
assert '$overlay_inputs$' not in source
o_ref="o->'reference_month'";o_due="o->'due'";o_amount="o->'amount'";o_bill="(o->'bill_key')";l_ref="l->'reference_month'"
expressions={
'INPUT':source,
'ODATE':dt("o->'reference_month'"),'ODUE':dt("o->'due'"),'OTIME':ts("o->'source_updated'"),'OAMOUNT':amt("o->'amount'"),
'OVALID':' AND '.join([sid(f"o->'{k}'") for k in ('event_id','owner','institution','account','family','cycle_id')]+[f"{dt(o_ref)} IS NOT NULL",f"extract(day FROM {dt(o_ref)})=1",f"(o->'due' IS NULL OR o->'due'='null'::jsonb OR {dt(o_due)} IS NOT NULL)",f"{amt(o_amount)} IS NOT NULL",ids("o->'payment_ids'"),ids("o->'purchase_ids'"),f"(o->'bill_key' IS NULL OR o->'bill_key'='null'::jsonb OR {vkey(o_bill)})"]),
'BKEY':key('b'),'BKEYVALID':vkey('b'),'BTIME':ts("b->'source_updated'"),'BDUE':dt("b->'due'"),'BAMOUNT':amt("b->'amount'"),'BFAMILY':sid("b->'family'"),'BCLOSING':dt("b->'closing_date'"),
'LKEY':key('l'),'LVALID':' AND '.join([vkey('l')]+[sid(f"l->'{k}'") for k in ('event_id','cycle_id','method')]+[f"{dt(l_ref)} IS NOT NULL",f"extract(day FROM {dt(l_ref)})=1"]),
'PROTECTED':dt("p->'protected_through'"),'TODAY':dt("p->'today'"),'OBILLKEY':key("(o->'bill_key')"),
}
sql=r'''-- Synthetic algorithm only; PG17 execution must be separately authorized.
-- No relation lookup, DDL, helper, extension, DML, production adapter or consumer.
WITH cases AS MATERIALIZED (
 SELECT c->>'case_id' case_id,c->'input' p FROM jsonb_array_elements($overlay_inputs$__INPUT__$overlay_inputs$::jsonb) c
), params AS MATERIALIZED (
 SELECT case_id,p,__PROTECTED__ protected_through,__TODAY__ today FROM cases
), oraw AS MATERIALIZED (
 SELECT case_id,ord,o FROM cases CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(p->'obligations')='array' THEN p->'obligations' ELSE '[]'::jsonb END) WITH ORDINALITY x(o,ord)
), obs AS MATERIALIZED (
 SELECT *,o->>'event_id' event_id,__ODATE__ reference_month,__ODUE__ due,
 __OTIME__ source_time,__OAMOUNT__ amount,(__OVALID__) IS TRUE valid FROM oraw
), braw AS MATERIALIZED (
 SELECT case_id,b,__BKEY__ bk,(__BKEYVALID__) IS TRUE valid_key,
 __BTIME__ source_time,__BDUE__ due,__BAMOUNT__ amount,(__BFAMILY__) IS TRUE valid_family,
 (b->'closing_date' IS NULL OR b->'closing_date'='null'::jsonb OR __BCLOSING__ IS NOT NULL) valid_closing
 FROM cases CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(p->'bills')='array' THEN p->'bills' ELSE '[]'::jsonb END) b
), links AS MATERIALIZED (
 SELECT DISTINCT case_id,l,__LKEY__ bk,(__LVALID__) IS TRUE valid
 FROM cases CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(p->'bindings')='array' THEN p->'bindings' ELSE '[]'::jsonb END) l
), batches AS MATERIALIZED (
 SELECT case_id,CASE
 WHEN jsonb_typeof(p) IS DISTINCT FROM 'object' OR jsonb_typeof(p->'obligations') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'bills') IS DISTINCT FROM 'array' OR jsonb_typeof(p->'bindings') IS DISTINCT FROM 'array' OR today IS NULL OR protected_through IS NULL OR extract(day FROM protected_through)<>1 THEN 'invalid_envelope'
 WHEN EXISTS(SELECT FROM obs o WHERE o.case_id=p.case_id AND NOT o.valid) THEN 'invalid_obligation_input'
 WHEN (SELECT count(*)<>count(DISTINCT event_id) FROM obs o WHERE o.case_id=p.case_id) THEN 'duplicate_event_id'
 WHEN EXISTS(SELECT FROM braw b WHERE b.case_id=p.case_id AND NOT b.valid_key) THEN 'invalid_source_identity'
 WHEN EXISTS(SELECT FROM links l WHERE l.case_id=p.case_id AND NOT l.valid) THEN 'invalid_binding_input'
 ELSE 'valid' END batch_state FROM params p
), head_versions AS MATERIALIZED (
 SELECT case_id,bk,max(source_time) newest,bool_and(source_time IS NOT NULL) recency_valid
 FROM braw GROUP BY case_id,bk
), top_rows AS MATERIALIZED (
 SELECT b.* FROM braw b JOIN head_versions h USING(case_id,bk) WHERE b.source_time=h.newest
), head_states AS MATERIALIZED (
 SELECT h.case_id,h.bk,CASE
 WHEN NOT h.recency_valid THEN 'unknown_source_recency'
 WHEN EXISTS(SELECT FROM top_rows t WHERE t.case_id=h.case_id AND t.bk=h.bk AND jsonb_typeof(t.b->'deleted') IS DISTINCT FROM 'boolean') THEN 'unknown_source_state'
 WHEN (SELECT count(DISTINCT jsonb_build_array(t.b->'family',t.b->'due',t.b->'amount',t.b->'closing_date',t.b->'deleted')) FROM top_rows t WHERE t.case_id=h.case_id AND t.bk=h.bk)<>1 THEN 'conflicting_latest_revision'
 WHEN EXISTS(SELECT FROM top_rows t WHERE t.case_id=h.case_id AND t.bk=h.bk AND t.b->'deleted'='true'::jsonb) THEN 'latest_source_deleted_preserved'
 WHEN EXISTS(SELECT FROM top_rows t WHERE t.case_id=h.case_id AND t.bk=h.bk AND (NOT t.valid_family OR t.amount IS NULL OR NOT t.valid_closing)) THEN 'invalid_source_fields'
 ELSE NULL END code FROM head_versions h
), winners AS MATERIALIZED (
 SELECT DISTINCT ON (t.case_id,t.bk) t.* FROM top_rows t JOIN head_states h USING(case_id,bk)
 WHERE h.code IS NULL ORDER BY t.case_id,t.bk,t.b->>'source_updated' COLLATE "C"
), link_counts AS MATERIALIZED (
 SELECT case_id,bk,count(*) n FROM links GROUP BY case_id,bk
), mapped AS MATERIALIZED (
 SELECT w.*,l.l,o.ord,o.event_id,CASE WHEN coalesce(lc.n,0)<>1 THEN 'missing_or_ambiguous_cycle_binding'
 WHEN o.event_id IS NULL OR l.l->>'method' NOT IN('existing_bill_binding','explicit_issuer_cycle','linked_transaction_cycle_independent_of_due')
 OR (l.l->'cycle_id'=o.o->'cycle_id' AND l.l->'reference_month'=o.o->'reference_month'
 AND w.b->'owner'=o.o->'owner' AND w.b->'institution'=o.o->'institution'
 AND w.b->'account'=o.o->'account' AND w.b->'family'=o.o->'family'
 AND (o.o->'bill_key' IS NULL OR o.o->'bill_key'='null'::jsonb OR o.o->'bill_key' @> w.bk)) IS NOT TRUE
 THEN 'binding_identity_mismatch' ELSE NULL END code
 FROM winners w LEFT JOIN link_counts lc USING(case_id,bk)
 LEFT JOIN links l ON l.case_id=w.case_id AND l.bk=w.bk AND lc.n=1
 LEFT JOIN obs o ON o.case_id=w.case_id AND o.event_id=l.l->>'event_id'
), claims AS MATERIALIZED (
 -- Count claims before dropping absent/deleted/conflicting source heads.
 SELECT o.case_id,o.event_id,count(DISTINCT l.bk) n FROM obs o JOIN links l ON l.case_id=o.case_id
 AND l.l->>'event_id'=o.event_id AND l.l->'cycle_id'=o.o->'cycle_id' AND l.l->'reference_month'=o.o->'reference_month'
 AND l.l->'owner'=o.o->'owner' AND l.l->'institution'=o.o->'institution' AND l.l->'account'=o.o->'account'
 AND l.l->>'method' IN('existing_bill_binding','explicit_issuer_cycle','linked_transaction_cycle_independent_of_due')
 GROUP BY o.case_id,o.event_id
), matched_counts AS MATERIALIZED (
 SELECT case_id,event_id,count(*) n FROM mapped WHERE code IS NULL GROUP BY case_id,event_id
), decisions AS MATERIALIZED (
 SELECT o.*,m.b,m.bk,m.source_time new_time,m.due new_due,CASE
 WHEN o.reference_month<=p.protected_through THEN 'protected_cycle_preserved'
 WHEN (o.o->>'status' IN('open','projected')) IS NOT TRUE OR o.o->'payment_ids'<>'[]'::jsonb THEN 'fulfilled_or_unknown_status_preserved'
 WHEN c.n>1 THEN 'multiple_bills_for_one_obligation'
 WHEN m.b IS NULL THEN 'no_eligible_invoice'
 WHEN m.due IS NULL THEN 'missing_or_invalid_invoice_due'
 WHEN m.amount<>o.amount THEN 'amount_change_outside_date_only_scope'
 WHEN o.o->>'provenance'='issuer_invoice' THEN CASE
   WHEN o.source_time IS NULL THEN 'unknown_snapshot_recency'
   WHEN o.o->'bill_key' IS NULL OR o.o->'bill_key'='null'::jsonb THEN 'missing_snapshot_bill_identity'
   WHEN m.source_time<o.source_time THEN 'older_issuer_revision_preserved'
   WHEN m.source_time=o.source_time AND m.due IS DISTINCT FROM o.due THEN 'equal_revision_conflict'
   ELSE 'overlay_applied' END
 WHEN o.o->>'provenance' IS DISTINCT FROM 'estimate' THEN 'documentary_conflict_requires_reconciliation'
 ELSE 'overlay_applied' END code
 FROM obs o JOIN params p USING(case_id) LEFT JOIN claims c USING(case_id,event_id)
 LEFT JOIN matched_counts mc USING(case_id,event_id)
 LEFT JOIN mapped m ON m.case_id=o.case_id AND m.event_id=o.event_id AND m.code IS NULL AND mc.n=1
), output AS MATERIALIZED (
 SELECT d.*,CASE WHEN code='overlay_applied' THEN o||jsonb_build_object('due',b->'due','provenance','issuer_invoice',
 'source_updated',b->'source_updated','bill_key',bk,'due_basis','issuer_exact_cycle') ELSE o END after FROM decisions d
), findings AS MATERIALIZED (
 SELECT case_id,bk,code FROM head_states WHERE code IS NOT NULL
 UNION SELECT case_id,bk,code FROM mapped WHERE code IS NOT NULL
 UNION SELECT o.case_id,__OBILLKEY__,'previous_source_missing_preserved' FROM obs
 WHERE o->'bill_key' IS NOT NULL AND o->'bill_key'<>'null'::jsonb
 AND NOT EXISTS(SELECT FROM braw b WHERE b.case_id=obs.case_id AND b.bk=__OBILLKEY__)
), result AS (
 SELECT p.case_id,jsonb_build_object('version','temporal_date_overlay_pg17_v1','batch_state',s.batch_state,
 'obligations',CASE WHEN s.batch_state<>'valid' THEN coalesce(p.p->'obligations','[]'::jsonb) ELSE coalesce((SELECT jsonb_agg(after ORDER BY ord) FROM output o WHERE o.case_id=p.case_id),'[]'::jsonb) END,
 'decisions',CASE WHEN s.batch_state<>'valid' THEN '[]'::jsonb ELSE coalesce((SELECT jsonb_agg(jsonb_build_object('event_id',event_id,'code',code,'changed_due',after->'due' IS DISTINCT FROM o->'due') ORDER BY ord) FROM output o WHERE o.case_id=p.case_id),'[]'::jsonb) END,
 'source_findings',CASE WHEN s.batch_state<>'valid' THEN '[]'::jsonb ELSE coalesce((SELECT jsonb_agg(jsonb_build_object('key',bk,'code',code) ORDER BY bk->>'owner' COLLATE "C",bk->>'institution' COLLATE "C",bk->>'account' COLLATE "C",bk->>'bill_id' COLLATE "C",code COLLATE "C") FROM findings f WHERE f.case_id=p.case_id),'[]'::jsonb) END) r
 FROM params p JOIN batches s USING(case_id)
)
SELECT jsonb_agg(jsonb_build_object('case_id',case_id,'result',r) ORDER BY case_id COLLATE "C") FROM result;
'''
# Correct qualified aliases in the previous-source branch before substitution.
sql=sql.replace("SELECT o.case_id,__OBILLKEY__", "SELECT obs.case_id,__OBILLKEY__")
for name,value in expressions.items(): sql=sql.replace('__'+name+'__',value)
assert '__' not in sql
(ROOT/'overlay_contract.sql').write_text(sql)
print(json.dumps({'sql_prepared':True,'sql_executed':False,'input_cases':len(json.loads(source))}))
