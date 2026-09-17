'use strict';

const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v171-candidate.html');
const js=read('lts-v171-v170-review.js');
const css=read('lts-v171-v170-review.css');
const migrationFiles=fs.readdirSync('supabase/migrations').filter(file=>/^20260917\d{6}_v171_.*\.sql$/.test(file)).sort();
const sql=migrationFiles.map(file=>read('supabase/migrations/'+file)).join('\n');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V171','lts-v170-v169-review.js','lts-v171-v170-review.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);
assert(candidate.indexOf('lts-v171-v170-review.js')>candidate.indexOf('lts-v170-v169-review.js'),'V171 overlay must load after V170');

for(const token of [
  "version:'v171'",'public_index_changed:false','lts_browser_expense_executive_v6','lts_browser_monthly_balance_v2',
  "next.p_direction==='expense'",'next.p_direction=\'saida\'','Receitas operacionais','Entradas extraordinárias','Despesas por grupo',
  'Faturas e parcelas por banco e cartão','Parcelas já contratadas','Considerado no Fluxo',
  'flow_progressive_load:true','validated_flow_columns_restored:true','lts_browser_flow_v11','lts_browser_flow_v12'
])assert(js.includes(token),'runtime missing '+token);

for(const token of ['.v168-history-note{display:none!important}','RSU vested','Saldo c/ RSU','.v171-expense-total','.v171-cards','.v171-monthly'])assert(css.includes(token),'style missing '+token);
assert(!js.includes('Parte de cima')&&!js.includes('Parte de baixo'),'instructional wording leaked into professional UI');

for(const token of [
  'lts_expense_management_group_v1','lts_expense_management_subgroup_v1','lts_browser_expense_executive_v6','lts_browser_monthly_balance_v2',
  'Investimentos no imóvel — obra e reforma','Financiamento imobiliário','Empréstimos e consignado','Benjamin — Educação','Educação','Rafiki',
  'if v_works<1000000','if v_rafiki<20000',
  'grant execute on function public.lts_browser_expense_executive_v6(date,date) to authenticated',
  'grant execute on function public.lts_browser_monthly_balance_v2(date,date) to authenticated'
])assert(sql.includes(token),'migration missing '+token);
assert(!sql.includes('grant execute on function public.lts_expense_management_group_v1'),'internal group helper exposed');
assert(!sql.includes('grant execute on function public.lts_expense_management_subgroup_v1'),'internal subgroup helper exposed');

console.log(JSON.stringify({pass:true,version:'v171-v170-review',public_index_unchanged:true,professional_taxonomy:true,monthly_full_period:true,transaction_direction_fixed:true,flow_progressive:true,validated_flow_columns_restored:true,migrations:migrationFiles},null,2));
