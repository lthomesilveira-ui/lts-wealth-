'use strict';const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict');
const path=require('node:path');const read=n=>fs.readFileSync(path.join(process.env.LTS_RELEASE_DIR||'releases/v270',n),'utf8');const ctx={window:{},flowDisplayDescription:e=>e.description||'Synthetic',isCardSettlement:()=>false};vm.createContext(ctx);vm.runInContext(read('lts-category-display.js'),ctx);
const helper=ctx.window.LTSCategoryDisplay,idx=read('index.html');vm.runInContext(idx.slice(idx.indexOf('function flowSemanticTitle(e){'),idx.indexOf('function flowSemanticMeta(e){')),ctx);
const src=read('lts-v183-personal-image-labels.js');vm.runInContext(src.slice(src.indexOf('  const displayName='),src.indexOf('  function decorate')),ctx);
const card=read('lts-v226-card-composition.js').split('\n').find(l=>l.includes('const category=x=>'));const cardLabel=vm.runInNewContext(card+';category',{window:ctx.window});
for(const person of ['Lucas','Larissa','Benjamin','Rafiki']){
 const want=person==='Lucas'?'Imagem e cuidados pessoais':person+' — Imagem e cuidados pessoais';
 assert.equal(ctx.flowSemanticTitle({category:'Vestuário',center_cost:person}),want);
 for(const sep of ['-','—','–','·']){
  const raw=person+' '+sep+' Vestuário';assert.equal(cardLabel(raw),want);assert.equal(ctx.label(raw),want);assert.equal(helper.category(raw),want);assert.equal(ctx.flowSemanticTitle({category:raw,center_cost:person}),want);
 }
}
assert.equal(ctx.flowSemanticTitle({category:'Vestuário',center_cost:'Lucas'}),'Imagem e cuidados pessoais');
assert.equal(ctx.flowSemanticTitle({category:'Benjamin — Saúde',center_cost:'Benjamin'}),'Benjamin — Saúde');
assert.equal(ctx.flowSemanticTitle({category:'Saúde',center_cost:'Lucas'}),'Saúde');
assert.equal(helper.flow('Larissa — Saúde','Benjamin'),'Benjamin · Larissa — Saúde','conflicting explicit people are not silently merged');
for(const raw of ['Imagem','Vestuário infantil','Vestuário e acessórios','Despesas Organon','Reembolso Organon','Company Car','Presentes','Saúde','Farmácia','Supermercado','Grupo Vestuário','Todos'])assert.equal(helper.category(raw),raw,'do not merge taxonomy: '+raw);
for(const raw of ['Compra de Vestuário','Rafiki comprou Vestuário','Vestuário · C6 · lançamento individual','Lucas — Presentes'])assert.equal(ctx.label(raw),raw,'generic decorator must not rewrite free text: '+raw);
assert(read('lts-expense-screen-alignment.js').includes('LTSCategoryDisplay.category(r.category)'));assert(read('lts-v225-open-finance.js').includes("LTSCategoryDisplay.category(r.category||'A classificar')"));
assert(read('lts-v226-card-composition.js').includes("'<option value=\"'+esc(x)+'\">'+esc(category(x))"),'raw option keys retained');
const expense=read('lts-expense-screen-alignment.js');
assert(expense.includes("esc(window.LTSCategoryDisplay.category(d.scope.category))"));
assert(expense.includes("esc(window.LTSCategoryDisplay.category(c.name))"));
assert(expense.includes("d.scope.category===c.name"),'category selection keys unchanged');
ctx.flowInternalTransferTitle=()=> 'Transferência entre contas';
assert.equal(ctx.flowSemanticTitle({internal_transfer:true,category:'Vestuário'}),'Transferência entre contas');
ctx.isCardSettlement=()=>true;assert.equal(ctx.flowSemanticTitle({description:'Fatura sintética',category:'Vestuário'}),'Fatura sintética');ctx.isCardSettlement=()=>false;
assert.equal(ctx.flowSemanticTitle({counterparty:'Reembolso plano de saúde',category:'Vestuário'}),'Reembolso plano de saúde');
assert.equal(ctx.flowSemanticTitle({description:'Apartamento CIPÓ 396',category:'Vestuário'}),'Apartamento CIPÓ 396');
assert(idx.indexOf('lts-category-display.js')<idx.indexOf('supabase.createClient'),'helper loaded before runtime');
console.log('PASS: exact category formatter; four people and four separators; repeated person; technical owner; intentional category boundaries; raw option keys. Synthetic only.');

vm.runInContext(idx.slice(idx.indexOf('function flowSemanticMeta(e){'),idx.indexOf('function fluxo(){')),ctx);
ctx.isCardSettlement=e=>e.syntheticInvoice===true;
assert.equal(ctx.flowClassificationBadge({syntheticInvoice:true,category:'A classificar'}).includes('flow-unclassified-link'),false);
assert.match(ctx.flowClassificationBadge({syntheticInvoice:true}),/Classificação nos itens da fatura/);
assert.match(ctx.flowSemanticMeta({syntheticInvoice:true}),/composição e eventuais pendências/);
assert.match(ctx.flowClassificationBadge({category:'A classificar'}),/A classificar · revisar/);
assert.equal(ctx.flowSemanticMeta({category:'A classificar'}),'Classificação pendente');
assert.equal(cardLabel(null),'A classificar','unknown purchases remain unresolved');
assert(read('lts-v226-card-composition.js').includes('sem composição conciliada'),'missing composition warning preserved');
console.log('PASS: invoice aggregate directs to item review; actual unknown purchases and missing composition remain visible.');
