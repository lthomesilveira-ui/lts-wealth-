'use strict';
// Integrator hook only. Call inside the existing isolated synthetic full-stack gate.
// This module does not start a browser, server, session, transport or release.
const assert=require('node:assert/strict');
function synthetic(args){assert.equal(args.syntheticOnly,true,'Run only against routed synthetic fixtures');}
async function canonicalLedger(frame,args){
 synthetic(args);const saved=await frame.evaluate(()=>JSON.stringify(window.__LTS_V168_STATE.transactions.rows));
 for(const expected of args.visibleRows){
  const tr=frame.locator('[data-v281-expense-row-key]').filter({has:frame.locator('td')});
  const match=await tr.evaluateAll((els,key)=>els.findIndex(el=>el.dataset.v281ExpenseRowKey===key),expected.key);assert(match>=0,'Raw row key exists');const row=tr.nth(match);
  assert.equal(await row.locator('td').nth(2).innerText(),expected.categoryLabel);
  assert.equal(await row.locator('td').nth(3).innerText(),expected.account);
  assert.equal(await row.locator('td').nth(4).innerText(),expected.beneficiaryLabel);
  for(let cycle=0;cycle<2;cycle++){
   await row.locator('[data-v281-expense-transaction-detail]').click();
   const modal=frame.locator('[data-v281-expense-transaction-modal]');await modal.waitFor({state:'visible'});
   for(const [field,label] of Object.entries(expected.modalFields)){
    const stat=modal.locator('.v168-stat').filter({has:frame.locator('span',{hasText:new RegExp('^'+field+'$')})});assert.equal(await stat.locator('b').innerText(),label);
   }
   await modal.locator('[data-v168-close]').click();await modal.waitFor({state:'detached'});
  }
 }
 assert.equal(await frame.evaluate(()=>JSON.stringify(window.__LTS_V168_STATE.transactions.rows)),saved,'Rendering/open/close preserves raw rows');
 return {checked:args.visibleRows.length,cycles:2};
}
async function naturalOptions(frame,args){
 synthetic(args);const select=frame.locator('#v168NlCategory'),before=await select.locator('option').evaluateAll(opts=>opts.map(o=>o.value));
 for(const expected of args.options){
  const options=await select.locator('option').evaluateAll(opts=>opts.map(o=>({value:o.value,label:o.textContent})));assert(options.some(o=>o.value===expected.value&&o.label===expected.label));
  await select.selectOption(expected.value);assert.equal(await select.inputValue(),expected.value);
  assert.equal(await frame.evaluate(()=>window.__LTS_V168_STATE.nl.preview.category),expected.value);
 }
 assert.deepEqual(await select.locator('option').evaluateAll(opts=>opts.map(o=>o.value)),before,'Never deduplicate by visible text');
 return {checked:args.options.length,writerInvoked:false};
}
async function monthlyKeys(frame,args){
 synthetic(args);
 const matrix=frame.locator('.v182-matrix').filter({has:frame.locator('h2',{hasText:/^Despesas por categoria$/})});
 const rows=matrix.locator('tr[data-lts-category-key]');
 for(const expected of args.rows){const index=await rows.evaluateAll((els,key)=>els.findIndex(el=>el.dataset.ltsCategoryKey===key),expected.rawGroup);assert(index>=0);const row=rows.nth(index);assert.equal(await row.locator('th').innerText(),expected.label);
  const keys=await row.locator('button[data-group]').evaluateAll(buttons=>buttons.map(b=>b.dataset.group));assert(keys.every(k=>k===expected.rawGroup));
  for(const zeroIndex of expected.zeroMonthColumns||[])assert.equal(await row.locator('td').nth(zeroIndex).locator('button').count(),0,'Zero month cannot inherit alias group detail');
 }
 return {checked:args.rows.length};
}
module.exports={canonicalLedger,naturalOptions,monthlyKeys};
