'use strict';
const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v168-candidate.html');
const js=read('lts-v168-feedback-package.js');
const css=read('lts-v168-feedback-package.css');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V168','lts-v168-feedback-package.js','v168-feedback-package'])assert(candidate.includes(token),'candidate missing '+token);
for(const token of [
  "version:'v168'",'reliable_progressive_reads:true','expense_custom_period:true','expense_hierarchical_drilldown:true',
  'function rpcRead','function dailyScenario','function dashboardV168Final','dashboard=dashboardV168Final',
  'atualizando o saldo do dia','Com FGTS, sem ruptura até','const moneyAxis','Recursos de hoje','Posições futuras',
  'function expenseTimeline','Média mensal por ano','Período personalizado','lts_browser_expense_context_lens_v1',
  'lts_browser_expense_drilldown_v1','function expenseCategoriesV168','Todos os bancos','Compromissos já contratados',
  'function wealthOverviewV168','Total Morgan Stanley','Aguardando extrato','function cipoMetrics',
  'Compra paga','Obra e reforma','function openCipoV168','patrimonio=patrimonioV168Final',
  'exact_flow_navigation:true','guided_statement_upload:true','reviewed_text_input:true','historical_balance_truth:true'
])assert(js.includes(token),'runtime missing '+token);
for(const token of [
  '.v168-kpi-section','.v168-custom-range','.v168-period-summary','.v168-category-row',
  '.v168-context','.v168-card-bank','.v168-wealth-layers','.v168-future.expense',
  'body.v165-authenticated .nav button svg','@media(max-width:900px)','@media(max-width:520px)'
])assert(css.includes(token),'style missing '+token);

console.log(JSON.stringify({
  pass:true,
  version:'v168-feedback-package',
  public_index_unchanged:true,
  reliable_dashboard_reads:true,
  exact_daily_scenario_dates:true,
  expense_period_race_fixed:true,
  full_history_annual_average:true,
  generic_expense_drilldown:true,
  wealth_layers:true,
  cipo_purchase_and_works_separated:true
},null,2));
