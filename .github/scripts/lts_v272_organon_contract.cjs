'use strict';
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const path=require('node:path');
const source=process.argv[2]||path.join(__dirname,'lts-category-display.js');
const context=vm.createContext({});
vm.runInContext(fs.readFileSync(source,'utf8'),context);
const display=context.LTSCategoryDisplay;
const cases=[
 ['Organon Despesas','Despesas Organon'],
 ['Despesas Organon','Despesas Organon'],
 ['Reembolso Organon','Reembolso Organon'],
 ['Organon','Organon'],
 ['organon despesas','organon despesas'],
 ['Organon Despesas extras','Organon Despesas extras'],
 ['Outra categoria desconhecida','Outra categoria desconhecida'],
 ['Imagem','Imagem'],
 ['Vestuário','Imagem e cuidados pessoais'],
 ['Rafiki','Rafiki'],
 ['Lucas — Organon Despesas','Despesas Organon'],
 ['Larissa — Organon Despesas','Larissa — Despesas Organon'],
 ['Benjamin — Organon Despesas','Benjamin — Despesas Organon'],
 ['Rafiki — Organon Despesas','Rafiki — Despesas Organon'],
 ['Larissa — Reembolso Organon','Larissa — Reembolso Organon'],
 ['Benjamin — Outra categoria','Benjamin — Outra categoria'],
 ['', ''],
 [null, ''],
];
for(const [input,expected] of cases)assert.equal(display.category(input),expected,String(input));
for(const person of ['Larissa','Benjamin','Rafiki']) {
 assert.equal(display.flow('Organon Despesas',person),person+' — Despesas Organon');
 assert.equal(display.flow(person+' — Organon Despesas',person),person+' — Despesas Organon');
 assert.equal(display.flow('Reembolso Organon',person),person+' — Reembolso Organon');
}
assert.equal(display.flow('Organon Despesas','Lucas'),'Despesas Organon');
assert.equal(display.flow('Organon Despesas',null),'Despesas Organon');
const row=Object.freeze({category:'Organon Despesas',source_id:'synthetic-source',amount:12.34,date:'2026-01-01',beneficiary:'Larissa'});
const before=JSON.stringify(row);
assert.equal(display.flow(row.category,row.beneficiary),'Larissa — Despesas Organon');
assert.equal(JSON.stringify(row),before,'Presentation must not mutate stored key or financial fields');
assert(Object.isFrozen(display));
console.log('PASS: exact alias, unchanged unknowns/reimbursement, explicit people, technical Lucas and immutable source fields');
