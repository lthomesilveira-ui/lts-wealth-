"""Real two-connection cache contention using synthetic records only."""
import json
import subprocess
import time

U='00000000-0000-4000-8000-000000000001'
def sql(query):
    return subprocess.check_output(['psql','-X','-v','ON_ERROR_STOP=1','-At','-c',query],text=True).strip()
cases=[
 ('corrected_cash_v1_v268',f"public.lts_corrected_cashflow_fix86_v1('{U}',current_date,current_date)",
  "least(current_date,date '2013-10-10')","make_date(extract(year from current_date)::integer+1,12,31)",42),
 ('lts_card_invoice_amounts_v230_v243',f"public.lts_card_invoice_amounts_v230('{U}')",'current_date','current_date',17),
 ('lts_payroll_bank_matches_v231_v243',f"public.lts_payroll_bank_matches_v231('{U}')",'current_date','current_date',11),
]
results=[]
for kind,call,start,end,amount in cases:
    sql(f"SELECT count(*) FROM {call};UPDATE public.lts_v229_read_cache SET refreshed_at=now()-interval '10 minutes' WHERE user_id='{U}' AND kind='{kind}';")
    locker=subprocess.Popen(['psql','-X','-v','ON_ERROR_STOP=1','-At'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
    locker.stdin.write(f"BEGIN; UPDATE public.lts_v229_read_cache SET refreshed_at=refreshed_at WHERE user_id='{U}' AND kind='{kind}'; SELECT 'held'; SELECT pg_sleep(2); COMMIT;\n")
    locker.stdin.close()
    while True:
        line=locker.stdout.readline()
        if not line: raise AssertionError('lock holder failed: '+locker.stderr.read())
        if line.strip()=='held': break
    began=time.monotonic()
    # The source is still returned when optional persistence cannot take its lock.
    field='signed_amount' if kind=='corrected_cash_v1_v268' else 'amount' if kind.startswith('lts_card') else 'actual_amount'
    observed=sql(f"SET statement_timeout='1500ms'; SELECT sum({field}) FROM {call};").splitlines()[-1]
    elapsed=time.monotonic()-began
    assert float(observed)==amount,(kind,observed)
    assert elapsed<1.3,(kind,elapsed)
    locker.wait(timeout=5)
    assert locker.returncode==0,locker.stderr.read()
    results.append({'kind':kind,'elapsed_ms':round(elapsed*1000,1),'source_output_preserved':True})
print(json.dumps({'pass':True,'two_real_database_connections':True,'synthetic_only':True,'cases':results}))
