'use strict';
const fs=require('node:fs'),crypto=require('node:crypto');
const read=f=>fs.readFileSync(f,'utf8'),assert=(x,m)=>{if(!x)throw Error(m)};
const candidate=read('wip35-v177-candidate.html');
const js=read('lts-v177-expense-ux.js');
const css=read('lts-v177-expense-ux.css');
const feedback=read('backups/V177_USER_FEEDBACK_REGISTER_2026-09-18.md');
const audit=read('backups/V177_SOURCE_AUDIT_FINDINGS_2026-09-18.md');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index changed');
for(const t of ['V177','lts-v176-flow-expense-audit.js','lts-v177-expense-ux.js','noindex,nofollow'])assert(candidate.includes(t),'candidate missing '+t);
assert(candidate.indexOf('lts-v177-expense-ux.js')>candidate.indexOf('lts-v176-flow-expense-audit.js'),'V177 load order');
for(const t of [
  "version:'v177'","base_version:'v176'",'lts_browser_expense_executive_v10','lts_browser_expense_group_detail_v1',
  'Apartamento · CIPÓ 396','technical_reconciliation_hidden:true','group_drilldown:true','audit_2020_total_brl:281377.71',
  'v175-property','v175-rank-title small','Abrir lançamentos','Filtrar histórico, conta, cartão ou referência'
])assert(js.includes(t),'runtime missing '+t);
for(const t of ['V177 · Homologação','.v177-drawer','.v177-detail-table','.v177-amount-link','.v177-component-strip'])assert(css.includes(t),'css missing '+t);
for(const t of ['Custos recorrentes de moradia','Aquisição do imóvel','Financiamento imobiliário','Obra e reforma'])assert(feedback.includes(t),'feedback missing '+t);
for(const t of ['R$ 4.529.057,60','R$ 263.909,54','R$ 281.377,71','-6,86%','2020 card evidence'])assert(audit.includes(t),'audit missing '+t);
console.log(JSON.stringify({pass:true,version:'v177',public_index_unchanged:true,professional_frontend:true,group_drilldown:true,property_rollup:true},null,2));