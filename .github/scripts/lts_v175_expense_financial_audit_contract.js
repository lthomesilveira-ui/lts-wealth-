'use strict';
const fs=require('node:fs'),crypto=require('node:crypto');
const read=f=>fs.readFileSync(f,'utf8'),assert=(x,m)=>{if(!x)throw Error(m)};
const candidate=read('wip35-v175-candidate.html');
const js=read('lts-v175-expense-financial-audit.js');
const css=read('lts-v175-expense-financial-audit.css');
const scope=read('backups/V175_DEEP_FINANCIAL_EXPENSE_AUDIT_SCOPE_2026-09-18.md');
const audit=read('backups/V175_SOURCE_AUDIT_FINDINGS_2026-09-18.md');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V175','lts-v174-v173-review.js','lts-v175-expense-financial-audit.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);
assert(candidate.indexOf('lts-v175-expense-financial-audit.js')>candidate.indexOf('lts-v174-v173-review.js'),'V175 overlay must load after V174');
for(const token of [
  "version:'v175'","base_version:'v174'",'lts_browser_expense_executive_v8','lts_browser_monthly_balance_v5',
  'lts_browser_card_flow_schedule_v2','full_history_monthly_bounded_render:true','historical_card_inventory:true',
  'april_stock_sale_open_source_issue:true','shellForHeavyTab','annualTable','Escolha o ano','Venda de ações, RSUs e outros ativos',
  'Todos os cartões documentados','Mastercard Black Itaú','Visa · final ','—* não significa zero'
])assert(js.includes(token),'runtime missing '+token);
for(const forbidden of ['lts_browser_apply_reviewed_input_v1','insert into','update public.','delete from'])assert(!js.toLowerCase().includes(forbidden.toLowerCase()),'V175 UI must remain read-only: '+forbidden);
for(const token of ['V175 · Homologação','.v175-rank','.v175-yearbar','.v175-inventory-grid','.v175-tablewrap'])assert(css.includes(token),'css missing '+token);
for(const token of ['stock_sale_2026_04_missing_source','R$ 267.441,25','R$ 2.174.777,52','Visa Infinite Prime','C6 Carbon'])assert(audit.includes(token),'audit receipt missing '+token);
for(const token of ['Historical card inventory','Monthly balance full history','Itaú / Coopharma loans','Expense universe'])assert(scope.includes(token),'scope missing '+token);
console.log(JSON.stringify({pass:true,version:'v175-expense-financial-audit',public_index_unchanged:true,read_only_ui:true,bounded_full_history:true},null,2));