from pathlib import Path
import hashlib,json,re,sys
p=Path(__file__).parent
files=json.loads((p/'PUBLIC_FILES.json').read_text())['files']
assert len(files)==len(set(files))
for name in files:
 assert name==Path(name).name and (p/name).is_file()
 text=(p/name).read_text()
 assert set(re.findall(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',text,re.I)) <= {'11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333'}
s=(p/'build_envelope.py').read_text()
assert 'DROP FUNCTION {PROJECTOR} RESTRICT' in s and 'CASCADE' not in s.replace('-- Never CASCADE.','')
assert "position('lts_card_payment_refresh_annotation_v273' in p.prosrc)>0" in s
assert "set_config('search_path','pg_catalog',true)" in s
assert "interval '10 minutes'" in s and '::oid' not in s
assert 'GRANT EXECUTE ON FUNCTION {PROJECTOR} TO %I,service_role' in s
assert "'documentary-payment-presentation.sql':'e3b5e3732cffbeb03f9e9cd3cca43bb68678daaf3c5cd392e45ba0fd0900e091'" in s
private=p.parent/'private/envelope/build_envelope.py'
if private.exists():assert private.read_bytes()==(p/'build_envelope.py').read_bytes()
r={'status':'passed','files':len(files),'renderer_sha256':hashlib.sha256(s.encode()).hexdigest(),'no_private_evidence':True,'private_renderer_equal_if_present':True}
(p/'STATIC_VALIDATION.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
