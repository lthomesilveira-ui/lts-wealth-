'use strict';

const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v169-candidate.html');
const js=read('lts-v169-v168-feedback-closure.js');
const css=read('lts-v169-v168-feedback-closure.css');
const sql=read('supabase/canonical_v169_v168_feedback_2026_09_16.sql');
const auditSql=read('supabase/canonical_v169_flow_audit_contract_fix_2026_09_16.sql');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V169','lts-v168-feedback-package.js','lts-v169-v168-feedback-closure.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);

for(const token of [
  "version:'v169'",'public_index_changed:false','dashboard_total_emphasis:true',
  'Total disponível hoje','Total de posições futuras','Total em previdências','Total de despesas do período',
  'Faturas históricas sem compras individualizadas','Empréstimo consignado · Coopharma',
  'data-v168-exp-tab="monthly"','Balanço mensal','Receitas mês a mês','Principais grupos de despesa',
  'Transferências internas, aplicações e pagamentos de fatura não entram como consumo',
  'Todos os bancos','Valores futuros mês a mês','Valor usado no Fluxo',
  'Obrigações sem saldo de quitação informado','Empréstimo familiar · Pai e Mãe',
  "source==='internal_transfer'",'lts_browser_internal_transfer_editor_v1',
  'lts_browser_internal_transfer_mutate_v1','Salvar transferência','Excluir transferência',
  'Operação atômica','V169 · Homologação'
])assert(js.includes(token),'runtime missing '+token);

for(const token of [
  'justify-content:flex-start!important','gap:13px!important','.v169-coverage',
  '.v169-card-months','.v169-balance-section','.v169-matrix-wrap','.v169-passives',
  '.v169-transfer-editor','@media(max-width:900px)','@media(max-width:520px)'
])assert(css.includes(token),'style missing '+token);

for(const token of [
  'lts_internal_transfer_editor_v1','lts_internal_transfer_mutate_v1',
  'lts_browser_internal_transfer_editor_v1','lts_browser_internal_transfer_mutate_v1',
  'lts_internal_transfer_legs_fix86_v1','lts_monthly_balance_v1',
  'lts_browser_monthly_balance_v1','lts_flow_civil_day_audit_v1',
  'financial_events:','transfer_group','pg_advisory_xact_lock','idempotency key required',
  "p_action not in ('edit','cancel')",'historical_invoice_aggregate',
  'excluded_internal_or_investment_inflows','internal_transfers_excluded',
  'card_bill_payments_excluded_from_consumption','card_purchases_counted_once',
  'generate_series(0,p_to-p_from)'
])assert(sql.includes(token),'migration missing '+token);

assert(!sql.includes("generate_series(p_from::timestamp"),'timestamp day series reintroduced');
assert(!sql.includes("generate_series(p_from,p_to,interval '1 day')"),'timezone-sensitive day series reintroduced');
assert(sql.includes('grant execute on function public.lts_browser_monthly_balance_v1(date,date) to authenticated'),'monthly browser grant missing');
assert(sql.includes('revoke all on function public.lts_internal_transfer_mutate_v1(uuid,text,text,jsonb,text) from public,anon,authenticated'),'internal transfer mutator exposed');
for(const token of ['post_position_operational_carry','unsupported_balance_leaks','critical_years','all_ok'])assert(auditSql.includes(token),'audit patch missing '+token);

console.log(JSON.stringify({
  pass:true,
  version:'v169-v168-feedback-closure',
  public_index_unchanged:true,
  dashboard_total_emphasis:true,
  monthly_balance:true,
  future_cards_by_bank:true,
  paired_transfer_crud:true,
  civil_day_audit:true,
  explicit_passive_layers:true
},null,2));
