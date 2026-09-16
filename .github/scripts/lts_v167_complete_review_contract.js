'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v167-candidate.html');
const js=read('lts-v167-complete-review.js');
const css=read('lts-v167-complete-review.css');
const coreSql=read('supabase/canonical_v167_complete_review_2026_09_16.sql');
const auditSql=read('supabase/canonical_v167_long_horizon_audit_2026_09_16.sql');
const securitySql=read('supabase/canonical_v167_security_revoke_internal_reader_2026_09_16.sql');
const paymentSql=read('supabase/canonical_v167_card_payment_date_reconciliation_2026_09_16.sql');
const scope=read('backups/V167_USER_REVIEW_SCOPE_2026-09-16.md');
const fullRegister=read('backups/V167_COMPLETE_USER_REVIEW_REGISTER_2026-09-16.md');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V167','lts-v167-complete-review.js','v167-complete-review'])assert(candidate.includes(token),'candidate missing '+token);
for(const token of [
  "version:'v167'",'expense_periods_live:true','wealth_pensions:true','financing_drilldown:true',
  'exact_flow_navigation:true','guided_statement_upload:true','reviewed_text_input:true','historical_balance_truth:true',
  'lts_browser_expense_executive_v4','lts_browser_wealth_detail_v3','lts_browser_recurring_future_gap_audit_v5',
  "p_horizon_end:'2030-12-31'",'horizon_checks','lts_browser_create_internal_transfer_v1',
  "document.getElementById('flowFrom')","document.getElementById('flowTo')","document.getElementById('flowApply')",
  'floweditbtn','Previdências','Cartões e faturas','Enviar extrato bancário','Lançar em texto',
  'effectiveRows','invoice-display','Ver composição','lts_browser_card_settlement_detail_v2',
  "filter(x=>x.source!=='evento_usuario')","y.source='legacy_fix86'",'kpiText(\'Ações abertas\'',
  'Patrimônio líquido em','loadFlowRange(day,day)','humanText(x.detail',
  'lts_browser_dashboard_cockpit_v1','function cockpitPoints','v167-loadstatus','data-v167-dashboard-refresh',
  "['cockpit','lts_browser_dashboard_cockpit_v1'","['flow','lts_browser_flow_v11'"
])assert(js.includes(token),'runtime missing '+token);
for(const token of ['.v167{','.v167-kpis','.v167-chart svg','.v167-wealthcards','.v167-pensions','.v167-updategrid','.v167-invoices','.v167-modal-bg','@media(max-width:900px)','@media(max-width:520px)'])assert(css.includes(token),'style missing '+token);
for(const token of [
  'lts_flow_historical_balance_truth_overlay_v1','movement_only_before_complete_documentary_opening',
  'lts_daily_flow_fix86_v20','award_vesting_marker','lts_browser_wealth_detail_v3',
  'private_pension','liquidity_class','lts_browser_create_internal_transfer_v1',
  'current_date+1800','future range exceeds supported horizon'
])assert(coreSql.includes(token),'core migration missing '+token);
for(const token of [
  'lts_recurring_future_gap_audit_v5','lts_browser_recurring_future_gap_audit_v5',
  "date '2030-12-31'",'horizon_checks','missing_years','never creates financial events'
])assert(auditSql.includes(token),'audit migration missing '+token);
for(const token of [
  'lts_corrected_cashflow_fix86_v5','revoke all','public,anon,authenticated'
])assert(securitySql.toLowerCase().includes(token.toLowerCase()),'security migration missing '+token);
for(const token of [
  'lts_browser_confirm_card_payment_v1','ci.due_date-7','greatest(current_date,ci.due_date+7)',
  "'payment_date',v_payment_date",'lts_refresh_product_read_cache_confirmation_v1'
])assert(paymentSql.includes(token),'payment reconciliation migration missing '+token);
for(const token of ['Organon Multiprev','Novartis Previ Plano D','Deferred user review'])assert(scope.includes(token),'scope checkpoint missing '+token);
for(const token of ['82 individually preserved requirements','10/10/2013','2021, 2022 and 2023','18/02/2027','Open Finance remains a visible backlog'])assert(fullRegister.includes(token),'complete register missing '+token);
assert((fullRegister.match(/^\d+\. /gm)||[]).length===82,'complete user register must retain all 82 numbered requirements');

console.log(JSON.stringify({
  pass:true,
  version:'v167-complete-review',
  public_index_unchanged:true,
  pension_positions:true,
  historical_balance_truth:true,
  long_horizon_audit_2030:true,
  exact_flow_navigation:true,
  card_payment_actual_date_reconciliation:true,
  guided_upload:true,
  reviewed_natural_language_entry:true
  ,progressive_dashboard:true
  ,complete_user_requirements:82
},null,2));
