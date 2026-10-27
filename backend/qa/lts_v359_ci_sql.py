"""Extend the signed-source native contract with synthetic property comparison metadata."""
from contextlib import redirect_stdout
from io import StringIO
from pathlib import Path
import json,re,runpy
R=Path(__file__).resolve().parents[2]
out=StringIO()
with redirect_stdout(out):runpy.run_path(str(R/'backend/qa/lts_v358_ci_sql.py'))
sql=out.getvalue()
pattern=r'INSERT INTO v358_manifest VALUES\(\$fixture\$(.*?)\$fixture\$\);'
m=re.search(pattern,sql);assert m
manifest=json.loads(m.group(1))
def rows(data):
    return[dict(file=f'Synthetic.{ext}',sha256=h*64,sheet='Pagamentos e Recebimentos',row=row,cell=f'B{row}',date=date,description=desc,signed_amount=value,original_value=str(value))for ext,h in[('xlsm','a'),('xlsx','b')]for row,date,desc,value in data]
cells=dict(D3=20,D4=-2,D13=13,D14=90,D41=5,J4=108,J5=126,J31=50.0043333333333)
manifest['snapshot_scope']=dict(version='cipo-scope-source-v358',source_file='Synthetic.xlsm',source_sheet='Investimento Cipó 396',source_paid_cutoff='2020-06-30',source_loan_paid=20,loan_source_cell='D3',
 source_cash_rows=rows([(4,'2020-04-17','Consórcio - O Parque - Itaú',30),(7,'2020-05-12','Consórcio - O Parque - Itaú',35),(8,'2020-05-15','Consórcio - O Parque - Itaú',-5),(9,'2020-06-12','Consórcio - O Parque - Itaú',30),(10,'2020-04-19','Consórcio - O Parque - Itaú',0),(11,'2020-02-12','Consórcio - O Parque',13)]),
 source_card_consortium_rows=rows([(20,'2020-01-20','Consórcio - O Parque',5)]),
 works_unlinked_source_rows=rows([(30,'2020-01-14','Espelhos e Box - O Parque',2),(31,'2020-01-14','Serviços e Mão de Obra - O Parque',2)]),
 investment_summary=[dict(file=f'Synthetic.{ext}',sha256=h*64,sheet='Investimento Cipó 396',cells=cells)for ext,h in[('xlsm','a'),('xlsx','b')]],duplicate_formula_cells=['D10','D16','J23','J31'])
sql=sql[:m.start(1)]+json.dumps(manifest)+sql[m.end(1):]
sql=sql.replace("'itau_ledger',amount,'itau_source',90,'itau_delta'","'source_total',108,'itau_ledger',amount,'itau_source',90,'itau_delta'")
sql=sql.replace("'untouched_market',1234,'untouched_cash',567,", "'untouched_market',1234,'untouched_cash',567,'source_internal_consistency',jsonb_build_object('duplicate_row_amount',10,'improvement_detail_total',40.0043333333333),")
sql=sql.replace("'evidence_note','Old summary inference')))FROM ledger;", "'evidence_note','Old summary inference'),jsonb_build_object('id','works-a','class','improvement','description','Móveis fictícios','origin','conta corrente','source_paid',30),jsonb_build_object('id','works-b','class','improvement','description','Serviços fictícios','origin','cartão','source_paid',10.0043333333333)))FROM ledger;")
assert "'works-a'"in sql
print(sql)
