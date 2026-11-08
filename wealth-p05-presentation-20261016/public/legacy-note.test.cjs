'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
let note;
if(process.argv[2]){const src=fs.readFileSync(process.argv[2],'utf8');const a=src.indexOf('function documentaryPaymentNote('),b=src.indexOf('    const v233Formatters',a);assert(a>=0&&b>a);note=vm.runInNewContext('('+src.slice(a,b).trim()+')');}
else ({documentaryPaymentNote:note}=require('./documentary-payment-note.cjs'));
const esc=s=>String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
const date=s=>s.split('-').reverse().join('/');
const e={status:'identified_in_statement',payment_date:'2030-10-14',amount:100,currency:'BRL',cash_effect:'none'};
for(const payment_status of ['payment_not_reported','payment_reported','paid']){
 const c={amount:100,payment_status,documentary_payment_evidence:{...e}};
 const before=JSON.stringify(c); const html=note(c,esc,date);
 assert.match(html,/Pagamento identificado no extrato em 14\/10\/2030/);
 assert.match(html,/emissor.*separadamente/);assert.equal(JSON.stringify(c),before);
}
assert.equal(note({amount:100},esc,date),'');
assert.match(note({documentary_payment_evidence:{status:'source_changed'}},esc,date),/precisa ser conferida novamente/);
for(const patch of [{currency:'USD'},{cash_effect:'new_debit'},{payment_date:'<img>'},{amount:0},{status:'paid'}])assert.equal(note({documentary_payment_evidence:{...e,...patch}},esc,date),'');
console.log('PASS: 10 documentary presentation cases; inputs unchanged');
