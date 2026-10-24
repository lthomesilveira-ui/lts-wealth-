"""Build leased DDL from explicitly supplied, reviewed function definitions on stdin.

The input remains private. The emitted patch contains hashes and generic body
transformations, never the original definitions or a financial operation payload.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
definitions = json.load(sys.stdin)
helpers = (ROOT / 'backend/patches/v309/contract_read_state.sql').read_text()
targets = {
    'public.lts_commitments_summary_v1(uuid,date)': ('summary', 'public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload)'),
    'public.lts_documentary_commitments_v1(uuid)': ('documentary', "public.lts_commitment_documentary_overlay_v309(p_user_id,(current_timestamp AT TIME ZONE 'America/Sao_Paulo')::date,payload)"),
    'public.lts_browser_wealth_detail_v242()': ('wealth', None),
}
assert set(definitions) == set(targets)
assert '--volatile-marker' not in helpers
hashes = []
for signature, (kind, expression) in targets.items():
    definition = definitions[signature]
    source = re.search(r'AS \$function\$([\s\S]*?)\$function\$', definition).group(1)
    if kind != 'wealth':
        new_source = '\n-- v309-dated-contract-state\nWITH v309_previous(payload) AS MATERIALIZED (\n' + source.strip().rstrip(';') + '\n)\nSELECT ' + expression + ' FROM v309_previous;\n'
    else:
        marker = ' RETURN public.lts_card_read_finish_v269('
        assert source.count(marker) == 1
        overlay = """ -- v309-dated-contract-state: compatibility fields share the current canonical contract view.
 j:=jsonb_set(j,'{commitments}',coalesce(j#>'{financing,summary}','null'::jsonb));
 j:=jsonb_set(j,'{documentary_commitments}',coalesce(j#>'{financing,documentary}','null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,documentary_contractual_outflow_brl}',coalesce(j#>'{cipo_detail,contractual_outflow_current_terms_brl}','null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,contractual_outflow_current_terms_brl}',coalesce((SELECT c->'remaining_scheduled_outflow_current_terms' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>'{financing,summary,commitments}')='array' THEN j#>'{financing,summary,commitments}' ELSE '[]'::jsonb END) c WHERE c->>'id'='cipo_396'),'null'::jsonb));
 j:=j||jsonb_build_object('contract_schedule_revision','v309-dated-contract-state');
"""
        new_source = source.replace(marker, overlay + marker)
    assert definition.count(source) == 1
    after = definition.replace(source, new_source)
    hashes.append((signature, hashlib.md5(definition.encode()).hexdigest(), hashlib.md5(after.encode()).hexdigest(), kind))

helper_hashes=[]
for match in re.finditer(r'CREATE OR REPLACE FUNCTION public\.(\w+)\(([^\n]+)\)\nRETURNS [\s\S]*?AS \$fn\$([\s\S]*?)\$fn\$;', helpers):
    name,args,source=match.groups()
    types=','.join(part.strip().split()[-1] for part in args.split(','))
    helper_hashes.append((f'public.{name}({types})',hashlib.md5(source.encode()).hexdigest()))
assert len(helper_hashes)==3

def literal(value):
    return "'" + value.replace("'", "''") + "'"

print('-- V309: current contract schedules from dated sources and existing verified payments.')
print('DO $guard$ DECLARE r record;p record; BEGIN')
print("IF md5(pg_get_functiondef('public.lts_realized_bank_sources_v238(uuid)'::regprocedure)) <> '02696060487b81ddf0592be23a2e044f' THEN RAISE EXCEPTION 'V309 realized-source dependency changed';END IF;")
print('FOR r IN SELECT * FROM(VALUES ' + ','.join('('+literal(a)+','+literal(b)+','+literal(c)+')' for a,b,c,_ in hashes) + ') v(signature,before_md5,after_md5) LOOP')
print("IF md5(pg_get_functiondef(to_regprocedure(r.signature))) IS NULL OR md5(pg_get_functiondef(to_regprocedure(r.signature))) NOT IN(r.before_md5,r.after_md5) THEN RAISE EXCEPTION 'V309 target lease changed: %',r.signature;END IF;END LOOP;")
print('FOR r IN SELECT * FROM(VALUES ' + ','.join('('+literal(a)+','+literal(b)+')' for a,b in helper_hashes) + ') v(signature,source_md5) LOOP')
print("SELECT * INTO p FROM pg_proc WHERE oid=to_regprocedure(r.signature);IF FOUND AND (md5(p.prosrc)<>r.source_md5 OR p.prosecdef OR p.proowner<>current_user::regrole::oid OR p.provolatile<>'s' OR p.proconfig IS DISTINCT FROM ARRAY['search_path=\"\"']::text[] OR has_function_privilege('anon',p.oid,'EXECUTE') OR has_function_privilege('authenticated',p.oid,'EXECUTE')) THEN RAISE EXCEPTION 'V309 helper lease changed: %',r.signature;END IF;END LOOP;END $guard$;")
print(helpers)
print('DO $patch$ DECLARE r record;d text;s text;n text;attrs jsonb;BEGIN')
print('FOR r IN SELECT * FROM(VALUES ' + ','.join('('+','.join(literal(v) for v in row)+')' for row in hashes) + ') v(signature,before_md5,after_md5,kind) LOOP')
print("SELECT pg_get_functiondef(p.oid),p.prosrc,jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) INTO d,s,attrs FROM pg_proc p WHERE p.oid=to_regprocedure(r.signature);IF md5(d)=r.after_md5 THEN CONTINUE;END IF;")
print("IF r.kind='summary' THEN n:=E'\\n-- v309-dated-contract-state\\nWITH v309_previous(payload) AS MATERIALIZED (\\n'||rtrim(btrim(s,chr(32)||chr(10)||chr(13)||chr(9)),';')||E'\\n)\\nSELECT public.lts_commitment_summary_overlay_v309(p_user_id,p_as_of,payload) FROM v309_previous;\\n';")
print("ELSIF r.kind='documentary' THEN n:=E'\\n-- v309-dated-contract-state\\nWITH v309_previous(payload) AS MATERIALIZED (\\n'||rtrim(btrim(s,chr(32)||chr(10)||chr(13)||chr(9)),';')||E'\\n)\\nSELECT public.lts_commitment_documentary_overlay_v309(p_user_id,(current_timestamp AT TIME ZONE ''America/Sao_Paulo'')::date,payload) FROM v309_previous;\\n';")
wealth_overlay = """ -- v309-dated-contract-state: compatibility fields share the current canonical contract view.
 j:=jsonb_set(j,'{commitments}',coalesce(j#>'{financing,summary}','null'::jsonb));
 j:=jsonb_set(j,'{documentary_commitments}',coalesce(j#>'{financing,documentary}','null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,documentary_contractual_outflow_brl}',coalesce(j#>'{cipo_detail,contractual_outflow_current_terms_brl}','null'::jsonb));
 j:=jsonb_set(j,'{cipo_detail,contractual_outflow_current_terms_brl}',coalesce((SELECT c->'remaining_scheduled_outflow_current_terms' FROM jsonb_array_elements(CASE WHEN jsonb_typeof(j#>'{financing,summary,commitments}')='array' THEN j#>'{financing,summary,commitments}' ELSE '[]'::jsonb END) c WHERE c->>'id'='cipo_396'),'null'::jsonb));
 j:=j||jsonb_build_object('contract_schedule_revision','v309-dated-contract-state');
"""
print("ELSE IF length(s)-length(replace(s,' RETURN public.lts_card_read_finish_v269(',''))<>length(' RETURN public.lts_card_read_finish_v269(') THEN RAISE EXCEPTION 'V309 wealth insertion point changed';END IF;n:=replace(s,' RETURN public.lts_card_read_finish_v269(',"+literal(wealth_overlay)+"||' RETURN public.lts_card_read_finish_v269(');END IF;")
print("IF position(s in d)=0 THEN RAISE EXCEPTION 'V309 source not found';END IF;EXECUTE replace(d,s,n);IF md5(pg_get_functiondef(to_regprocedure(r.signature)))<>r.after_md5 THEN RAISE EXCEPTION 'V309 output definition changed: %',r.signature;END IF;")
print("IF attrs IS DISTINCT FROM(SELECT jsonb_build_object('oid',p.oid,'owner',p.proowner,'acl',p.proacl,'config',p.proconfig,'definer',p.prosecdef,'volatility',p.provolatile) FROM pg_proc p WHERE p.oid=to_regprocedure(r.signature)) THEN RAISE EXCEPTION 'V309 existing attributes changed';END IF;END LOOP;END $patch$;")
