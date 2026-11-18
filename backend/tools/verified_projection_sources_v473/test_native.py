"""Run the migration and both guarded paths in an isolated database with invented records."""
import json
import re
import subprocess
from pathlib import Path

def sql(statement):
    done = subprocess.run(['psql','-XAtq','-v','ON_ERROR_STOP=1'], input=statement,
                          text=True, capture_output=True, check=False)
    if done.returncode:
        raise RuntimeError(done.stderr)
    return done.stdout.strip()

def literal(value):
    return "'" + str(value).replace("'","''") + "'"

def digest(value):
    return sql('SELECT md5(' + literal(json.dumps(value)) + '::jsonb::text)')

def function_hash(signature):
    return sql("SET search_path=''; SELECT md5(pg_get_functiondef(" + literal(signature) + "::regprocedure))")

schema = 'lts_product_refresh_private_v415'
owner = '00000000-0000-4000-8000-000000000001'
other = '00000000-0000-4000-8000-000000000002'
review = schema + '.review_guard_v450(uuid)'
long_guard = schema + '.long_flow_guard_v450(uuid)'
profile = schema + '.review_profile_v450()'

sql(f"""
CREATE SCHEMA {schema};
CREATE TABLE public.lts_read_cache_epoch_v242(singleton boolean,epoch bigint);
INSERT INTO public.lts_read_cache_epoch_v242 VALUES(true,1);
CREATE TABLE public.lts_card_due_rule_v290(user_id uuid,day integer);
CREATE TABLE public.lts_card_due_transition_v370(user_id uuid,month integer);
CREATE TABLE public.legacy_namespace(usuario_id uuid,chave text,sha256 text,valor_bruto text);
CREATE TABLE public.fixture_cards(user_id uuid,amount numeric);
CREATE VIEW public.fixture_calendar AS SELECT 1 AS month;
CREATE FUNCTION public.lts_card_cycles_v226(u uuid) RETURNS jsonb LANGUAGE sql AS $$ SELECT jsonb_build_object(
 'computed_at',clock_timestamp(),'cards',(SELECT jsonb_agg(amount ORDER BY amount) FROM public.fixture_cards WHERE user_id=u)) $$;
CREATE FUNCTION public.lts_flow_read_source_key_v247(uuid) RETURNS text LANGUAGE sql AS $$SELECT 'source'::text$$;
CREATE FUNCTION {schema}.review_input_contract_ok_v465(jsonb) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION public.fixture_budget() RETURNS int LANGUAGE sql AS $$SELECT 1$$;
CREATE FUNCTION public.fixture_inputs() RETURNS int LANGUAGE sql AS $$SELECT 4$$;
""")
old_producer = 'public.fixture_budget()'
new_producer = 'public.fixture_inputs()'
base = {'producers':[{'signature':old_producer, 'md5':function_hash(old_producer)}],
        'tables':[], 'epoch_tables':[], 'views':[{'signature':'public.fixture_calendar',
        'md5':sql("SET search_path=''; SELECT md5(pg_get_viewdef('public.fixture_calendar'::regclass,true))")}]}
prior_hash = digest(base)
sql(f"""CREATE FUNCTION {profile} RETURNS jsonb LANGUAGE sql IMMUTABLE SET search_path='' AS $$ SELECT {literal(json.dumps(base))}::jsonb $$;
CREATE FUNCTION {review} RETURNS jsonb LANGUAGE sql AS $$ SELECT to_jsonb('{prior_hash}'::text) $$;
CREATE FUNCTION {schema}.long_flow_guard_v450(p_user_id uuid) RETURNS text LANGUAGE sql AS $$ SELECT 'before'::text $$;
CREATE OR REPLACE FUNCTION public.fixture_budget() RETURNS int LANGUAGE sql AS $$ SELECT 2 $$;""")
pins = [{'signature':s,'md5':function_hash(s)} for s in [old_producer,new_producer]]
target_hash = digest(dict(base,producers=pins))
migration = (Path(__file__).parent/'install.sql').read_text()
fixture_hashes = {
    '3344fae485b34b6cf29a939801ab492e':prior_hash, '3a941712276413c8dc88ef621e7d0f66':target_hash,
    '21e3ec09d2322aeb876d1136f9bbe2e2':function_hash(profile),
    '02d895675e35f70ae4fb11c6a1b2176f':function_hash(review), '62ee97b13bcaa0632612ecb7953cb17c':function_hash(long_guard)
}
for actual, synthetic in fixture_hashes.items():
    assert actual in migration
    migration = migration.replace(actual, synthetic)
migration = re.sub(r'\$pins\$.*?\$pins\$', lambda _: '$pins$'+json.dumps(pins)+'$pins$', migration, flags=re.S)
sql('BEGIN;'+migration+'COMMIT;')
assert sql(f"SELECT md5({profile}::text)") == target_hash
assert json.loads(sql(f"SELECT {schema}.review_guard_v450('{owner}')")) == target_hash

def key():
    return sql(f"SELECT {schema}.long_flow_guard_v450('{owner}')")

first = key()
assert first and key() == first, 'computation timestamps are not financial input'
sql(f"INSERT INTO public.fixture_cards VALUES('{other}',79)")
assert key() == first
sql(f"INSERT INTO public.fixture_cards VALUES('{owner}',23)")
second = key(); assert second != first
sql(f"INSERT INTO public.legacy_namespace VALUES('{owner}','lts_owner_recurring_plan_v469','test','updated')")
third = key(); assert third != second
sql(f"INSERT INTO public.lts_card_due_transition_v370 VALUES('{owner}',7)")
assert key() != third
sql("CREATE OR REPLACE FUNCTION public.fixture_inputs() RETURNS int LANGUAGE sql AS $$SELECT 5$$")
assert key() == '', 'an unknown producer disables reuse'
sql("CREATE OR REPLACE FUNCTION public.fixture_inputs() RETURNS int LANGUAGE sql AS $$SELECT 4$$")
assert key()
sql("CREATE OR REPLACE VIEW public.fixture_calendar AS SELECT 2 AS month")
assert key() == '', 'an unknown view disables reuse'
print('Checked upgraded graph, original read guards, changed input, owner separation, and unknown sources.')
