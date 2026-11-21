#!/usr/bin/env python3
"""Validate only the synthetic suite's output. No SQL/network/credentials."""
import argparse,collections,hashlib,json,re
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--output',required=True);a=p.parse_args()
base=Path(__file__).resolve().parent;out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
expected=json.loads((base/'EXPECTED_RESULTS.json').read_text());lines=Path(a.log).read_text().splitlines()
records=[json.loads(x.removeprefix('FIXTURE_RESULT ')) for x in lines if x.startswith('FIXTURE_RESULT ')]
labels=[x['label'] for x in records]
assert len(records)==expected['count'],(len(records),expected['count'])
assert len(labels)==len(set(labels)),'duplicate result labels'
assert sorted(labels)==expected['labels'],'result set differs'
assert all(x.get('passed') is True and set(x)=={'label','passed'} for x in records)
assert lines.count(expected['cleanup_marker'])==1,'cleanup missing/duplicate'
compiled_lines=[x[len('COMPILED_DEFINITIONS '):] for x in lines if x.startswith('COMPILED_DEFINITIONS ')]
pin_lines=[x[len('CANONICAL_PIN '):] for x in lines if x.startswith('CANONICAL_PIN ')]
scalar_lines=[x[len('CANONICAL_SCALARS '):] for x in lines if x.startswith('CANONICAL_SCALARS ')]
assert len(compiled_lines)==len(pin_lines)==len(scalar_lines)==1
compiled=json.loads(compiled_lines[0]);pin=json.loads(pin_lines[0]);assert re.fullmatch('[0-9a-f]{64}',pin)
assert len(compiled)==expected['compiled_body_count']
seen=set();mapped=[]
for c in compiled:
 name=c['signature'].split('(')[0].split('.')[-1]
 short={'lts_v229_expense_rows':'expense_rows','lts_browser_card_detail_v226':'card_detail'}[name]
 key=(short,c['variant']);assert key not in seen;seen.add(key)
 variant='candidate' if c['variant']=='candidate_unbound' else c['variant']
 source=(base/(short+'_'+variant+'.sql')).read_text()
 assert source.count('$function$')==2
 body=source.split('$function$')[1]
 if c['variant']=='candidate':
  assert body.count('UNBOUND_CANONICAL_SHA256_REQUIRES_PG17_REVIEW')==2
  body=body.replace('UNBOUND_CANONICAL_SHA256_REQUIRES_PG17_REVIEW',pin)
 assert c['prosrc']==body,('compiled prosrc differs',key)
 assert hashlib.md5(c['definition'].encode()).hexdigest()==c['definition_md5']
 assert c['owner']=='fixture_owner'
 assert c['language']==('sql' if short=='expense_rows' else 'plpgsql')
 assert c['volatility']==('s' if short=='expense_rows' else 'v')
 assert c['security_definer']==(short=='card_detail')
 assert c['config']==(['search_path=""'] if short=='expense_rows' else ['search_path=""','TimeZone=America/Sao_Paulo'])
 mapped.append({'body':short,'variant':c['variant'],'prosrc_exact':True,'canonical_definition_md5':c['definition_md5'],'canonical_definition_sha256':hashlib.sha256(c['definition'].encode()).hexdigest()})
for short in ['expense_rows','card_detail']:
 pair=[c for c in compiled if short=='expense_rows' and 'lts_v229_expense_rows(' in c['signature'] or short=='card_detail' and 'lts_browser_card_detail_v226(' in c['signature']]
 assert len(pair)==3
 for field in ['signature','result','language','security_definer','volatility','config','owner','acl']:assert pair[0][field]==pair[1][field]==pair[2][field],field
result={'passed':True,'results':len(records),'unique_results':len(set(labels)),'cleanup':True,'compiled_bodies_exact':6,'canonical_pin_computed_in_pg':pin,'mapping':mapped,'limits':['Full two consumers on synthetic ancestor contracts only.','Not production dependency graph, cache lifecycle, migration envelope, concurrency or production authentication.']}
(out/'compiled-public-definitions.json').write_text(json.dumps(compiled,ensure_ascii=False,indent=2)+'\n')
(out/'canonical-scalars.json').write_text(json.dumps(json.loads(scalar_lines[0]),ensure_ascii=False,indent=2)+'\n')
(out/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'passed':True,'results':len(records),'compiled_bodies':6,'cleanup':True}))
