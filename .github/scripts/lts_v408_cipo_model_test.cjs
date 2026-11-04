'use strict';
const test = require('node:test');
const assert = require('node:assert/strict');
const api = require('../../releases/v407/lts-v408-cipo-source.js');
const {synthetic}=require('../fixtures/lts_v408_cipo.cjs');
test('valid source groups preserve both dates and group-level components',()=>{
  const m=api.build(synthetic());assert.equal(m.groups.length,32);assert.equal(m.rowCount,43);assert.equal(m.residuals.length,5);assert.equal(m.dateDifferences,3);
  assert.equal(m.groups[0].scheduledDate,'2020-01-30');assert.equal(m.groups[0].cash[0].date,'2020-01-31');
  assert.equal(m.constructorCents+m.brokerCents,m.totalCents);assert.equal(m.groups[0].cash[0].constructorCents,undefined);
});
test('absent evidence stays absent',()=>assert.equal(api.build(null),null));
const cases={
  'duplicate cash identity':x=>{x.groups[1].cash_rows[0].source_ref=x.groups[0].cash_rows[0].source_ref;},
  'missing cash row':x=>{x.groups[0].cash_rows.pop();},
  'incorrect component total':x=>{x.groups[0].constructor_brl='99.99';},
  'one-cent cash mismatch':x=>{x.groups[0].cash_rows[0].amount='60.01';},
  'invented individual allocation':x=>{x.groups[0].individual_allocation={constructor:50,broker:10};},
  'hidden date difference':x=>{x.groups[0].date_difference=false;},
  'impossible date':x=>{x.groups[0].cash_rows[0].event_date='2020-02-31';},
  'third decimal':x=>{x.groups[0].cash_rows[0].amount='60.001';},
  'duplicate file identity':x=>{x.source_files[1].file=x.source_files[0].file;},
  'missing workbook source':x=>{x.groups[0].cash_rows[0].workbook_rows.pop();},
  'unidentified property source':x=>{x.groups[0].cash_rows[0].workbook_rows[0].property_label='';},
  'wrong source cell':x=>{x.groups[0].source_cells.constructor='Y999';},
  'missing documentary cutoff':x=>{delete x.verified_on;},
  'invalid documentary cutoff':x=>{x.verified_on='2026-02-31';},
  'missing residual':x=>{x.residuals.pop();},
  'residual duplicates documented source':x=>{x.residuals[0].source_ref=x.groups[0].cash_rows[0].source_ref;},
  'unrelated evidence schema':x=>{x.schema='other';}
};
for(const [name,change]of Object.entries(cases))test('rejects '+name,()=>{const x=synthetic();change(x);assert.throws(()=>api.build(x));});
module.exports={synthetic};
