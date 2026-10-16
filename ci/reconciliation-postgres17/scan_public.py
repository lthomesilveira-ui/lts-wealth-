"""Source-only privacy guard for invented public CI fixtures (stdlib only)."""
import pathlib,re,sys
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
FILES=[p for p in HERE.iterdir() if p.is_file() and p.suffix in {'.sql','.py','.md','.json'}]
FILES.append(ROOT/'.github/workflows/ci-reconciliation-postgres17.yml')
UUID=re.compile(r'\b[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\b',re.I)
DATE=re.compile(r'\b20\d{2}-\d{2}-\d{2}(?:T\d{2}:\d{2}:\d{2}[^\s\"\']*)?')
RULES=[('connection URL',re.compile(r'(?:postgres(?:ql)?://|https?://[^\s\"\']+\.supabase\.co)',re.I)),('JWT-shaped token',re.compile(r'eyJ[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}\.[A-Za-z0-9_-]{15,}')),('private key block',re.compile(r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')),('private workspace path',re.compile(r'/workspace/scratch/[a-z0-9]+/'))]
errors=[]
for p in FILES:
 if not p.exists():errors.append((str(p.relative_to(ROOT)),'missing source file'));continue
 s=p.read_text()
 for token in UUID.findall(s):
  if not re.fullmatch(r'00000000-0000-4000-8000-0000000000[0-9a-f]{2}',token,re.I):errors.append((str(p.relative_to(ROOT)),'non-fixture UUID'))
 for token in DATE.findall(s):
  if not token.startswith('2030-'):errors.append((str(p.relative_to(ROOT)),'non-fixture date'))
 for label,pattern in RULES:
  if pattern.search(s):errors.append((str(p.relative_to(ROOT)),label))
if errors:
 for p,label in sorted(set(errors)):print(f'FAIL {p}: {label}')
 sys.exit(1)
print(f'PASS privacy source guard: {len(FILES)} files; UUIDs/dates belong to the synthetic allowlist; no connection URLs, JWTs, keys or private workspace paths.')
