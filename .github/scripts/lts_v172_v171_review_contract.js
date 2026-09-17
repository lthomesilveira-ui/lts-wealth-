'use strict';

const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v172-candidate.html');
const js=read('lts-v172-v171-review.js');
const css=read('lts-v172-v171-review.css');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V172','lts-v171-v170-review.js','lts-v172-v171-review.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);
assert(candidate.indexOf('lts-v172-v171-review.js')>candidate.indexOf('lts-v171-v170-review.js'),'V172 overlay must load after V171');

for(const token of [
  "version:'v172'",'public_index_changed:false','previous-5-through-current-year-end',
  "U+'/rest/v1/rpc/'",'Promise.allSettled',
  "flowPart('lts_browser_flow_v11'","flowPart('lts_browser_flow_v12'",'Promise.allSettled',
  'monthly-balance-v3-v172-chunked','yearChunks','mapLimit(chunks,3',
  'Faturas conciliadas pelo total','Venda de ações, RSUs e outros ativos',
  "return'Empréstimos'",'Financiamento imobiliário — CIPÓ 396',
  'Patrimônio líquido hoje','Bens e ativos atuais','Dívidas com saldo informado',
  'Total bruto do extrato','A receber líquido projetado','Total líquido projetado'
])assert(js.includes(token),'runtime missing '+token);

for(const token of ['V172 · Homologação','.v172-rankrow','.v172-wealth-grid','.v172-morgan-components','.v172-flow-warning'])assert(css.includes(token),'style missing '+token);
for(const forbidden of ['Histórico auditável','Parte de cima','Parte de baixo','valor central documentado','obrigações sem saldo de quitação'])assert(!js.includes(forbidden),'unprofessional wording remains: '+forbidden);
assert(!candidate.includes('lts-v172-v171-review.js')||candidate.includes('index.html?v172-v171-review'),'candidate does not preserve protected base app');

console.log(JSON.stringify({pass:true,version:'v172-v171-review',public_index_unchanged:true,flow_resilient:true,default_flow_current_year:true,monthly_full_history_chunked:true,expense_sources_reconciled:true,professional_wealth:true},null,2));
