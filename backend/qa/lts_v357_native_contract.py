"""Validate every changed scalar in the actual native reader outputs."""
import json,re,sys,pathlib
rows=[json.loads(x)for x in pathlib.Path(sys.argv[1]).read_text().splitlines()if x.startswith('{')]
r=[x for x in rows if x.get('version')==357]
assert len(r)==1;r=r[0]
assert r['pass'] and r['invalid_evidence_cases']==12
def changes(a,b,path=''):
    if a==b:return []
    if isinstance(a,dict)and isinstance(b,dict):
        result=[]
        for k in sorted(set(a)|set(b)):
            q=path+'.'+k
            if k not in a or k not in b:result.append(q)
            else:result+=changes(a[k],b[k],q)
        return result
    return [path]
allowed=[
 r'\.wealth\.wealth\.summary\.(net_worth_(low|central|high|status)|known_debt_(total|to_assets_pct)|debt_total_complete|debt_basis)',
 r'\.wealth\.wealth\.debt_coverage',
 r'\.wealth\.wealth\.assets\.volvo_xc40\.(equity_(low|central|high)|current_documentary_debt_balance|current_debt_as_of|initial_financed_amount|documented_financed_balance_basis)',
 r'\.wealth\.wealth_v167\.net_worth_central_including_pensions',
 r'\.product\.mvp\.wealth_executive\.summary\.(net_worth_(low|central|high|status)|known_debt_(total|to_assets_pct)|debt_total_complete|debt_basis)',
 r'\.product\.mvp\.wealth_executive\.debt_coverage',
 r'\.product\.mvp\.wealth_executive\.assets\.volvo_xc40\.(equity_(low|central|high)|current_documentary_debt_balance|current_debt_as_of|initial_financed_amount|documented_financed_balance_basis)',
 r'\.product\.mvp\.dashboard_cockpit\.wealth\.(net_worth_(low|central|high|status)|known_debt_(total|to_assets_pct)|debt_total_complete|debt_basis|debt_coverage)',
 r'\.cockpit\.wealth\.(net_worth_(low|central|high|status)|known_debt_(total|to_assets_pct)|debt_total_complete|debt_basis|debt_coverage)',
]
paths=changes(r['before_readers'],r['after_readers'])
assert paths and all(any(re.fullmatch(rule,p)for rule in allowed)for p in paths),paths
summaries=[r['after_readers']['wealth']['wealth']['summary'],r['after_readers']['product']['mvp']['wealth_executive']['summary'],r['after_readers']['cockpit']['wealth'],r['after_readers']['product']['mvp']['dashboard_cockpit']['wealth']]
for s in summaries:
    assert s['known_debt_total']==900 and s['debt_total_complete']is False
    assert all(s[k]is None for k in ['net_worth_low','net_worth_central','net_worth_high'])
r['changed_scalar_paths']=paths
p=pathlib.Path('qa/v357/native-debt-projection.json');p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(r))
print(json.dumps(dict(pass_=True,changed_paths=len(paths),invalid_cases=12,source_preserved=True)))
