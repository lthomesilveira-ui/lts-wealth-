'use strict';

const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v170-candidate.html');
const js=read('lts-v170-v169-review.js');
const css=read('lts-v170-v169-review.css');
const sqlFiles=fs.readdirSync('supabase/migrations').filter(file=>/^20260917\d{6}_v170_.*\.sql$/.test(file)).sort();
const sql=sqlFiles.map(file=>read('supabase/migrations/'+file)).join('\n');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V170','lts-v169-v168-feedback-closure.js','lts-v170-v169-review.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);
assert(candidate.indexOf('lts-v170-v169-review.js')>candidate.indexOf('lts-v169-v168-feedback-closure.js'),'V170 overlay must load after V169');

for(const token of [
  "version:'v170'",'public_index_changed:false','lts_browser_flow_v12','lts_browser_wealth_detail_v4','lts_browser_expense_executive_v5',
  'previous-5-through-next-year-end','Top 15 · grupos gerenciais','Educação','Obra e reforma · O Parque / CIPÓ 396',
  'Total bruto do extrato','Total considerado após reserva','Reserva fiscal projetada','Aplicar a todos os vestings','Cotação individual',
  'morgan_statement_reconciled:true','global_award_assumption:true','management_groups:true',
  'Morgan disponível','base zero em 09/10/2013','trackedBankEvent','historicalCashParts','tracked-bank-cash-arithmetic-v1',
  'Mov. interna líquida','não é receita nem despesa'
])assert(js.includes(token),'runtime missing '+token);

for(const token of ['.v170-rank','.v170-audit','.v170-morgan-components','.v170-global-award','.v170-wealth-guide','.v170-passive-card','.v170-internal-net','Morgan disponível','V170 · Homologação'])assert(css.includes(token),'style missing '+token);

for(const token of [
  'lts_brokerage_position_snapshots','1745784.67','15913.44','1729871.23','1142654.04','587217.19',
  'lts_flow_historical_relative_balance_overlay_v1','relative_movement_ledger','opening_basis_date','2013-10-09',
  'lts_flow_morgan_available_overlay_v1','morgan_available_total_brl','lts_browser_flow_v12',
  'lts_browser_wealth_detail_v4','considered_total_after_reserve_brl','statement_and_assumption_model_kept_separate',
  'lts_browser_save_all_award_assumptions_v1','all_active_rsu_and_cash_rsu_vestings',
  'lts_browser_expense_executive_v5','management_groups','source_categories','Consignado · Coopharma',
  'Obra e reforma · O Parque / CIPÓ 396','education_split_by_person'
])assert(sql.includes(token),'migration missing '+token);

for(const token of [
  'same_effective_ledger_as_expense_executive_v4','lts_expense_effective_read_cache','r.dt,r.consolidated_close',
  'generate_series(0,v_max_date-v_origin)','historical_upper_boundary_inclusive',
  'historical-tracked-bank-ledger-v2','relative_tracked_bank_ledger',
  'lts_flow_historical_cash_arithmetic_overlay_v1','tracked-bank-cash-arithmetic-v1',
  'operating_entries_brl','internal_transfer_net_brl','arithmetic_gap_brl',
  'lts_flow_historical_cash_audit_summary_v1','tracked-bank-cash-audit-v1'
])assert(sql.includes(token),'follow-up migration missing '+token);

assert(sql.includes('force row level security'),'snapshot RLS is not forced');
assert(sql.includes('revoke all on table public.lts_brokerage_position_snapshots from public, anon, authenticated'),'snapshot table privileges are not closed');
assert(!sql.includes('grant execute on function public.lts_flow_historical_relative_balance_overlay_v1'),'internal historical overlay exposed');
assert(!sql.includes('grant execute on function public.lts_flow_morgan_available_overlay_v1'),'internal Morgan overlay exposed');
for(const signature of [
  'grant execute on function public.lts_browser_flow_v12(date,date) to authenticated',
  'grant execute on function public.lts_browser_wealth_detail_v4() to authenticated',
  'grant execute on function public.lts_browser_save_all_award_assumptions_v1(numeric,numeric)',
  'grant execute on function public.lts_browser_expense_executive_v5(date,date) to authenticated'
])assert(sql.includes(signature),'authenticated grant missing '+signature);

console.log(JSON.stringify({pass:true,version:'v170-v169-review',public_index_unchanged:true,historical_balances:true,historical_cash_audit:true,morgan_reconciled:true,global_award_assumption:true,management_groups:true,migrations:sqlFiles},null,2));
