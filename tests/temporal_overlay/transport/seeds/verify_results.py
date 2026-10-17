"""Exact, typed JSON oracle plus independent preservation and conservation gates."""
import argparse
from collections import defaultdict
from datetime import date,timedelta
from decimal import Decimal
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).parent
CHANGING={'due','provenance','source_updated','bill_key','due_basis'}
class VerificationError(ValueError): pass

def unique_object(pairs):
    out={}
    for k,v in pairs:
        if k in out: raise VerificationError('duplicate JSON key: '+k)
        out[k]=v
    return out

def strict_load(s):
    try:
        return json.loads(s,object_pairs_hook=unique_object,parse_float=Decimal,parse_constant=lambda x: (_ for _ in ()).throw(VerificationError('nonfinite JSON constant')))
    except (json.JSONDecodeError,UnicodeDecodeError) as e:
        raise VerificationError('invalid or multiple JSON documents') from e

def exact(a,b,path='$'):
    if type(a) in (int,Decimal) and type(b) in (int,Decimal):
        if a!=b: raise VerificationError(path+': exact numeric value mismatch')
        return
    if type(a) is not type(b): raise VerificationError(path+': JSON type mismatch')
    if isinstance(a,dict):
        if a.keys()!=b.keys(): raise VerificationError(path+': field set mismatch')
        for k in a: exact(a[k],b[k],path+'.'+k)
    elif isinstance(a,list):
        if len(a)!=len(b): raise VerificationError(path+': cardinality mismatch')
        for i,(x,y) in enumerate(zip(a,b)): exact(x,y,path+f'[{i}]')
    elif a!=b: raise VerificationError(path+': exact value mismatch')

def index(rows):
    if not isinstance(rows,list) or not rows: raise VerificationError('empty or malformed result set')
    out={}
    for r in rows:
        if not isinstance(r,dict) or set(r)!={'case_id','result'} or not isinstance(r['case_id'],str): raise VerificationError('result row schema')
        if r['case_id'] in out: raise VerificationError('duplicate case_id')
        out[r['case_id']]=r['result']
    return out

def totals(rows):
    amounts=defaultdict(Decimal)
    for o in rows: amounts[tuple(o[x] for x in ('owner','institution','account','cycle_id','reference_month'))]+=Decimal(o['amount'])
    return dict(amounts)

def daily(rows):
    out=defaultdict(Decimal)
    for o in rows:
        if o.get('status') in ('open','projected') and o['payment_ids']==[] :
            out[o.get('due') or '__undated__']+=Decimal(o['amount'])
    return dict(out)

def metrics(rows,today):
    amounts=daily(rows);start=date.fromisoformat(today);end=start+timedelta(days=30)
    return {'daily':{d:str(v) for d,v in sorted(amounts.items())},'d30':str(sum((v for d,v in amounts.items() if d!='__undated__' and start<date.fromisoformat(d)<=end),Decimal(0)))}

def verify(actual,inputs,expected):
    actual=index(actual);expected=index(expected)
    if actual.keys()!=expected.keys(): raise VerificationError('missing or extra cases')
    if not isinstance(inputs,list) or not inputs: raise VerificationError('empty inputs')
    if any(not isinstance(c,dict) or set(c)!={'case_id','input'} or not isinstance(c['case_id'],str) for c in inputs): raise VerificationError('input row schema')
    ip={c['case_id']:c['input'] for c in inputs}
    if len(ip)!=len(inputs): raise VerificationError('duplicate input case_id')
    if actual.keys()!=ip.keys(): raise VerificationError('input/oracle cases differ')
    summary=[]
    for cid in sorted(actual):
        a=actual[cid];e=expected[cid];p=ip[cid]
        exact(a,e,cid)
        before=p.get('obligations',[]);after=a['obligations']
        if a['batch_state']!='valid':
            exact(before,after,cid+'.invalid_batch_preserved');continue
        if len(before)!=len(after): raise VerificationError(cid+': lost or duplicated obligation')
        if len(a['decisions'])!=len(before): raise VerificationError(cid+': incomplete decision cardinality')
        if len({o['event_id'] for o in after})!=len(after): raise VerificationError(cid+': duplicate event')
        for old,new,d in zip(before,after,a['decisions']):
            if type(d['changed_due']) is not bool: raise VerificationError('changed_due must be boolean')
            exact({k:v for k,v in old.items() if k not in CHANGING},{k:v for k,v in new.items() if k not in CHANGING},cid+'.non_date_fields')
            if d['code']!='overlay_applied': exact(old,new,cid+'.blocked_obligation')
            if old['reference_month']<=p['protected_through'] or old.get('status') not in ('open','projected') or old['payment_ids']:
                exact(old,new,cid+'.protected_obligation')
        if totals(before)!=totals(after): raise VerificationError(cid+': totals by obligation scope changed')
        # Distribution may change, never its total. D30 convention is synthetic only.
        if sum(daily(before).values(),Decimal(0))!=sum(daily(after).values(),Decimal(0)): raise VerificationError(cid+': daily total changed')
        if metrics(after,p['today'])!=metrics(e['obligations'],p['today']): raise VerificationError(cid+': exact daily/D30 mismatch')
        summary.append({'case_id':cid,'changed_dates':sum(d['changed_due'] for d in a['decisions']),'metrics':metrics(after,p['today'])})
    return {'verified':True,'cases':len(actual),'full_json_exact':True,'deep_preservation':True,'scope_totals_conserved':True,'daily_and_synthetic_d30_exact':True,'case_metrics':summary}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('result_file',type=Path);args=ap.parse_args()
    try:
        r=verify(strict_load(args.result_file.read_text()),strict_load((ROOT/'inputs.json').read_text()),strict_load((ROOT/'expected.json').read_text()))
    except (VerificationError,OSError) as e:
        print(json.dumps({'verified':False,'error':str(e)}));return 1
    print(json.dumps(r,indent=2));return 0
if __name__=='__main__': raise SystemExit(main())
