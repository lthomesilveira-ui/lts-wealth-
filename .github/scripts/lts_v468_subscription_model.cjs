'use strict';
const fs=require('node:fs'),assert=require('node:assert/strict');
const api=require('../../releases/v467/lts-v412-projection-policy.js');
const input=JSON.parse(fs.readFileSync('v468-synthetic-model.json','utf8'));
const before=JSON.stringify(input);
const model=api.build(input);
assert.equal(model.series.length,1);
assert.equal(model.series[0].amount,1234);
assert.equal(model.series[0].usesHistory,false);
assert.equal(JSON.stringify(input),before);
const uncertain=JSON.parse(before);
uncertain.series[0].warnings=['unreconciled_periods'];
uncertain.series[0].annual_totals[0].budget_total_brl=null;
uncertain.series[0].annual_totals[0].additional_brl=null;
const warningModel=api.build(uncertain);
assert.equal(warningModel.series[0].annual[0].total,null);
assert.deepEqual(warningModel.series[0].warnings,['unreconciled_periods']);
console.log(JSON.stringify({pass:true,existing_consumer:'v467',amount_unchanged:true,missing_not_zero:true,synthetic:true,private_owner_session:false,physical_device:false}));

