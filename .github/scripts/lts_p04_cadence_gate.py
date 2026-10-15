from pathlib import Path
p=Path(__file__).resolve().parents[2]
new=(p/'sql/diagnostics/lts_recurring_future_gap_audit_v6_candidate.sql').read_text()
def expr(s):
 a=s.index("CASE WHEN public.lts_forecast_series_key_v1(x->>'description')='property_tax_cipo'")
 b=s.index(' cadence\n FROM base',a)
 return s[a:b].replace("public.lts_forecast_series_key_v1(x->>'description')","(x->>'description')")
fixture="""WITH specs(series_key,pattern,expected) AS (VALUES
 ('annual3','annual_or_seasonal','annual'),('annual6','annual_or_seasonal','annual'),
 ('annual10','annual_or_seasonal','annual'),('monthly6','annual_or_seasonal','monthly'),
 ('boundary6','annual_or_seasonal','monthly'),('sparse5','annual_or_seasonal','annual'),
 ('duplicate_one_month','annual_or_seasonal','annual'),('property_tax_cipo','annual_or_seasonal','annual'),
 ('unknown_pattern',NULL,'monthly'),('annual_empty','annual_or_seasonal','annual'),
 ('separate_a','annual_or_seasonal','annual'),('separate_b','annual_or_seasonal','annual')),
 future(series_key,event_date) AS (
 SELECT 'annual3',make_date(y,3,31) FROM generate_series(2027,2029)y
 UNION ALL SELECT 'annual6',make_date(y,3,31) FROM generate_series(2027,2032)y
 UNION ALL SELECT 'annual10',make_date(y,3,31) FROM generate_series(2027,2036)y
 UNION ALL SELECT 'monthly6',d::date FROM generate_series(date '2027-01-01',date '2027-06-01',interval '1 month')d
 UNION ALL SELECT 'boundary6',d::date FROM generate_series(date '2027-10-01',date '2028-03-01',interval '1 month')d
 UNION ALL SELECT 'sparse5',d::date FROM generate_series(date '2027-01-01',date '2027-05-01',interval '1 month')d
 UNION ALL SELECT 'duplicate_one_month',date '2027-03-01' FROM generate_series(1,20)
 UNION ALL SELECT 'separate_a',make_date(y,1,1) FROM generate_series(2027,2029)y
 UNION ALL SELECT 'separate_b',make_date(y,6,1) FROM generate_series(2027,2029)y
 UNION ALL SELECT 'property_tax_cipo',d::date FROM generate_series(date '2027-02-01',date '2027-11-01',interval '1 month')d
 ), input AS (SELECT series_key,expected,jsonb_build_object('description',series_key,'recurrence_pattern',pattern) x FROM specs),
 classified AS (SELECT series_key,expected, CANDIDATE AS candidate FROM input)
 SELECT *, candidate=expected AS passed FROM classified ORDER BY series_key;
"""
q=fixture.replace('CANDIDATE',expr(new))
# The fixture uses the CASE extracted from the proposed function, not a hand-written equivalent.
import subprocess,json
q=q.replace("SELECT *, candidate=expected AS passed FROM classified ORDER BY series_key;", "SELECT json_agg(row_to_json(t)) FROM (SELECT *, candidate=expected AS passed FROM classified ORDER BY series_key)t;")
result=subprocess.run(['psql','-X','-A','-t','-v','ON_ERROR_STOP=1'],input=q,text=True,capture_output=True,check=True)
rows=json.loads(result.stdout)
assert len(rows)==12, rows
assert all(r['passed'] for r in rows), rows
print(json.dumps({'status':'PASS','cases':len(rows),'rows':rows}))
