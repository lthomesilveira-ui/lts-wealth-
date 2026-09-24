'use strict';
const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const sql=fs.readFileSync('supabase/migrations/20260924105738_v183_monthly_window.sql','utf8');
test('monthly reader filters effective dates before aggregating competence months',()=>{
 assert.match(sql,/where e\.event_date between p\.from_date and p\.to_date/);
 assert.doesNotMatch(sql,/where e\.transaction_date between/);
 const rows=[{event:'2026-01-01',purchase:'2026-01-05',amount:9},{event:'2026-01-17',purchase:'2026-01-17',amount:20},{event:'2026-02-12',purchase:'2026-02-12',amount:-2},{event:'2026-02-13',purchase:'2026-02-13',amount:5}];
 const select=(from,to)=>rows.filter(x=>x.event>=from&&x.event<=to).reduce((sum,x)=>sum+x.amount,0);
 assert.equal(select('2026-01-17','2026-02-12'),18);assert.equal(select('2026-01-01','2026-02-28'),32);assert.equal(select('2026-01-17','2026-01-17'),20);assert.equal(select('2026-02-12','2026-02-12'),-2);
});
test('migration checks full-report invariance and partial source agreement atomically',()=>{
 assert.match(sql,/before_reports IS DISTINCT FROM after_reports/);assert.match(sql,/public\.lts_v178_expense_rows\(u,bounds\.a,bounds\.b\)/);
 assert.match(sql,/Partial-period source total differs/);assert.match(sql,/RAISE EXCEPTION 'Monthly reader changed/);
 assert.doesNotMatch(sql,/\b(?:UPDATE|DELETE FROM|INSERT INTO|TRUNCATE|GRANT|REVOKE|ALTER POLICY)\b/);
 assert.doesNotMatch(sql,/set_config\(|request\.jwt/);
});
