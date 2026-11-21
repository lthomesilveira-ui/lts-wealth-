from pathlib import Path
import hashlib,json
root=Path(__file__).parent
expected='ae48a8c0dd8b1771090beaad96f4b46fd68c651ebe117682e99ec757b0b1f00b'
def predicate(s):
 a=s.index('(CASE WHEN p_contract');b=s.index(' END)',a)+5
 return s[a:b]
economic=predicate((root/'economic-guard-reference.sql').read_text());presentation=predicate((root/'payment-refresh-annotation.sql').read_text())
assert economic==presentation
assert hashlib.sha256(economic.encode()).hexdigest()==expected
s=(root/'synthetic-presentation-test.sql').read_text()
start=s.index('CREATE TEMP TABLE annotation_cases')
# The cases table is generated from synthetic-only inputs. Reuse it without
# recreating a second invoice interpretation or any economics/coverage assertion.
selection="label='valid refreshed evidence' OR label='current invoice hash changed' OR label LIKE 'raw %' OR label LIKE '%root timestamp%' OR label LIKE 'invalid updatedAt %' OR label LIKE 'unknown policy %' OR label LIKE 'canonical malformed %' OR label IN('new unknown root field','array order exact','object key order ignored')"
shared='''
CREATE FUNCTION pg_temp.economic_invoice_predicate(p_invoice jsonb,p_contract jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO '' AS $policy$ SELECT coalesce('''+economic+''',false) $policy$;
CREATE FUNCTION pg_temp.presentation_invoice_predicate(p_invoice jsonb,p_contract jsonb) RETURNS boolean LANGUAGE sql IMMUTABLE SET search_path TO '' AS $policy$ SELECT coalesce('''+presentation+''',false) $policy$;
DO $shared$ DECLARE c record;e boolean;p boolean;BEGIN
 FOR c IN SELECT * FROM pg_temp.annotation_cases WHERE '''+selection+''' LOOP
 e:=pg_temp.economic_invoice_predicate(c.args->'invoice',c.args->'contract');
 p:=pg_temp.presentation_invoice_predicate(c.args->'invoice',c.args->'contract');
 IF e IS DISTINCT FROM p OR p IS DISTINCT FROM (c.expected IS DISTINCT FROM 'null'::jsonb) THEN RAISE EXCEPTION 'shared policy failure: %',c.label; END IF;
 END LOOP;
END $shared$;
SELECT jsonb_build_object('stage','shared_policy','cases',count(*),'passed',count(*),'predicate_sha256','''+"'"+expected+"'"+''') FROM pg_temp.annotation_cases WHERE '''+selection+''';
'''
s=s.replace('DO $tests$',shared+'\nDO $tests$',1)
(root/'synthetic-presentation-test.sql').write_text(s)
(root/'shared-policy-proof.json').write_text(json.dumps({'equal':True,'sha256':expected,'source':'Exact installed economic CASE, published generic reference','ignored_path':'root updatedAt only'},indent=2)+'\n')
