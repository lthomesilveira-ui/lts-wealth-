#!/usr/bin/env python3
"""Reconstruct the frozen 339-result suite from readable public SQL and synthetic fixtures.

No database, network, compression, binary codec, private mapping or source snapshot is used.
The generated output must match every frozen byte/hash before any file is emitted.
"""
import argparse,copy,hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent
SHA=lambda b:hashlib.sha256(b).hexdigest()
def load(name):return json.loads((ROOT/name).read_text())
def compact(value):return json.dumps(value,ensure_ascii=False,separators=(',',':'),allow_nan=False)

def fixtures():
    seed=load('fixtures/base_rows.json')
    representative=copy.deepcopy(seed['representative_card'])
    prior=copy.deepcopy(seed['prior_card'])
    expense_base=copy.deepcopy(seed['representative_expense'])
    staging=[copy.deepcopy(seed[k]) for k in ['representative_staging','prior_staging','invoice_staging']]
    card_rows=[representative,prior]
    expense_rows=[expense_base]
    # 112 distinct non-target synthetic purchases: 105 posted, then 7 pending.
    # Their IDs, labels and values are explicit synthetic fixture relationships.
    for index in range(112):
        source_id=f'88888888-8888-4888-8888-{index+1:012d}'
        status='POSTED' if index<105 else 'PENDING'
        description=f'Synthetic other item {index:03d}'
        item=dict(representative,source_id=source_id,provider_status=status,amount=1,
                  installment_number=1,total_installments=1,last4='5678',description=description,
                  category='Fixture other',category_basis='fixture_label',
                  bill_id=representative['bill_id'] if status=='POSTED' else None)
        card_rows.append(item)
        source=copy.deepcopy(staging[0])
        source.update(id=source_id,description_raw=description,signed_amount=-1,
                      provider_record_id='synthetic:'+source_id)
        source['raw_payload'].update(id=source_id,amount=1,status=status)
        source['normalized_payload'].update(provider_id=source_id,amount=-1,status=status)
        staging.append(source)
        if status=='POSTED':
            expense_rows.append(dict(expense_base,source_ref=source_id,row_key='fixture:'+source_id,
                                     amount=1,category='Fixture other',description=description,
                                     beneficiary=None,management_group='Fixture other',management_subgroup='Fixture other'))
    # Independent cycle JSON deliberately omits fixture-only owner plumbing.
    def card_item(row):return {key:value for key,value in row.items() if key!='fixture_owner'}
    current_items=[card_item(row) for row in card_rows if row['provider_status']=='POSTED']
    future=[card_item(dict(prior,reference_month='2020-11-01',provider_status='PROJECTED',
                           installment_number=3,due_date='2020-11-25'))]
    future += [card_item(dict(card_rows[2+index],reference_month='2020-11-01',
                             provider_status='PROJECTED',amount=index+1,due_date='2020-11-25')) for index in range(6)]
    core={'cards':[{'family':'aeternum','cycles':[
        {'reference_month':'2020-10-01','amount':117.34,'detail_total':117.34,'items':current_items},
        {'reference_month':'2020-11-01','amount':99.99,'detail_total':33.34,'items':future}]}]}
    items=[card_item(row) for row in card_rows]
    alternative=[dict(family='aeternum',reference_month='2020-10-01',source='workbook',
                      amount=117.34,detail_total=136.68,difference=0,item_count=114,items=items)]
    wrong_month=copy.deepcopy(alternative)
    wrong_month[0]['items'].append(dict(wrong_month[0]['items'][1],reference_month='2020-11-01',amount=99))
    wrong_month[0]['item_count']=115
    wrong_month[0]['detail_total']=235.68
    malformed={}
    for name,extra in [('alternative_scalar_item',17),('alternative_null_item',None),
                       ('alternative_numeric_string_item',dict(items[1],source_id='66666666-6666-4666-8666-666666666666',amount='1'))]:
        case=copy.deepcopy(alternative)
        case[0]['items'].append(extra)
        case[0]['item_count']=115
        malformed[name]=case
    document=load('fixtures/document_case.json')
    assert document['metadata']['existing_source_items']=='@SYNTHETIC_CARD_ITEMS@'
    document['metadata']['existing_source_items']=items
    return dict(staging_rows=staging,expense_rows=expense_rows,card_rows=card_rows,
                relationship_evidence_rows=[seed['relationship_evidence']],core_cycles=core,
                alternative_normal=alternative,alternative_duplicate_prior_wrong_month=wrong_month,
                matched_document_rows=[document],**malformed)

def build():
    source_manifest=load('SOURCE_MANIFEST.json')
    for entry in source_manifest['files']:
        body=(ROOT/entry['name']).read_bytes()
        if len(body)!=entry['bytes'] or SHA(body)!=entry['sha256']:
            raise SystemExit('source package checksum mismatch: '+entry['name'])
    expected=load('OUTPUT_CONTRACT.json')
    rendered_fixtures={name:compact(value) for name,value in fixtures().items()}
    bodies={name:(ROOT/'frozen_files'/(name+'.sql')).read_text().rstrip(';\n')+';'
            for name in ['expense_rows_original','expense_rows_candidate','card_detail_original','card_detail_candidate']}
    sql=(ROOT/'consumer_suite.template.sql').read_text()
    seen=[]
    def expand(match):
        kind,name=match.groups();seen.append((kind,name))
        return (rendered_fixtures if kind=='FIXTURE' else bodies)[name]
    sql=re.sub(r'@@(FIXTURE|BODY):([a-z_]+)@@',expand,sql)
    if '@@FIXTURE:' in sql or '@@BODY:' in sql:raise SystemExit('unexpanded readable template slot')
    if len(seen)!=15 or len(set(seen))!=15:raise SystemExit('template slot coverage changed')
    outputs={p.name:p.read_bytes() for p in (ROOT/'frozen_files').iterdir() if p.is_file()}
    outputs['option_a_full_consumers.sql']=sql.encode('utf-8')
    if set(outputs)!=set(expected['files']):raise SystemExit('frozen output filename set changed')
    for name,body in outputs.items():
        contract=expected['files'][name]
        if len(body)!=contract['bytes'] or SHA(body)!=contract['sha256']:
            raise SystemExit('frozen output mismatch: '+name)
    return outputs,expected

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='New empty directory; reconstruction never executes SQL')
    args=parser.parse_args()
    outputs,expected=build()  # all checks finish before writing output files
    if args.output.exists() and any(args.output.iterdir()):raise SystemExit('output directory must be empty')
    args.output.mkdir(parents=True,exist_ok=True)
    for name,body in sorted(outputs.items()):(args.output/name).write_bytes(body)
    print(json.dumps({'files_reconstructed':len(outputs),'all_bytes_match':True,
                      'sql_sha256':expected['expected_sql_sha256'],'expected_results':expected['expected_results'],
                      'sql_executed':False},sort_keys=True))
if __name__=='__main__':main()
