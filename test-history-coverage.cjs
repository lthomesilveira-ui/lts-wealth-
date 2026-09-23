'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),crypto=require('node:crypto');
const policy=require('./lts-history-coverage-policy.js');
let checks=0;
function check(fn){fn();checks++}
check(()=>assert.equal(policy.expenseFrom,'2013-10-10'));
check(()=>assert.equal(policy.dayStatus('2015-01-01','Itaú',null),'uncertified'));
check(()=>assert.equal(policy.dayStatus('2018-09-10','Itaú',null),'uncertified'));
check(()=>assert.equal(policy.dayStatus('2026-07-08','Itaú',null),'operational'));
check(()=>assert.equal(policy.dayStatus('2026-09-23','Consolidado',null),'operational'));
check(()=>assert.equal(policy.canReplaceWithHistoricalSource('2026-07-08'),false));
check(()=>assert.equal(policy.canReplaceWithHistoricalSource('2026-07-09'),false));
check(()=>assert.equal(policy.canReplaceWithHistoricalSource('2026-07-07'),true));
check(()=>assert.equal(policy.dayStatus('2026-02-30','Itaú',null),'unavailable'));
check(()=>assert.equal(policy.dayStatus(null,'Itaú',null),'unavailable'));
check(()=>assert.equal(policy.verifiedRange({itau_first_documentary_opening:'2018-09-10'},'Itaú'),null));
const entry={from:'2020-01-01',through:'2026-07-07',status:'source_reconciled',contiguous:true,movements_compared:true,balances_compared:true,evidence_ref:'synthetic-test'};
const contract={reconciled_intervals:{'Itaú':entry}};
check(()=>assert.equal(policy.dayStatus('2021-01-01','Itaú',contract),'reconciled'));
check(()=>assert.equal(policy.dayStatus('2019-12-31','Itaú',contract),'uncertified'));
check(()=>assert.equal(policy.dayStatus('2021-01-01','Bradesco',contract),'uncertified'));
check(()=>assert.equal(policy.dayStatus('2021-01-01','Consolidado',contract),'uncertified'));
for(const key of ['contiguous','movements_compared','balances_compared','evidence_ref']){
  check(()=>assert.equal(policy.verifiedRange({reconciled_intervals:{'Itaú':{...entry,[key]:false}}},'Itaú'),null));
}
check(()=>assert.equal(policy.verifiedRange({reconciled_intervals:{'Itaú':{...entry,through:'2026-07-08'}}},'Itaú'),null));
check(()=>assert.match(policy.flowMessage('Itaú',null),/início conciliado ainda não estabelecido/));
check(()=>assert.doesNotMatch(policy.flowMessage('Itaú',null),/conciliado desde.*201[38]/));
check(()=>assert.match(policy.flowMessage('Itaú',contract),/01\/01\/2020 a 07\/07\/2026/));
check(()=>assert.match(policy.expenseMessage,/resultado do período não é saldo bancário/));
check(()=>assert.equal(crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex'),'cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b'));
check(()=>assert.equal(JSON.parse(fs.readFileSync('homologacao-current.json')).version,'wip35-v181'));
for(const file of ['lts-history-coverage-policy.js','lts-v183-historical-balance-guard.js','lts-v183-expense-history-candidate.js'])check(()=>assert.doesNotThrow(()=>new Function(fs.readFileSync(file,'utf8'))));
const html=fs.readFileSync('wip35-v183-candidate.html','utf8');
check(()=>assert.ok(html.indexOf('lts-history-coverage-policy.js')<html.indexOf('lts-v183-historical-balance-guard.js')));
console.log(checks+' history coverage checks passed; production and fixed homologation unchanged.');
