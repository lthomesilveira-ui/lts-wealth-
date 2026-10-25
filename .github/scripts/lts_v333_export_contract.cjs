'use strict';
const assert=require('node:assert/strict'),tools=require('../../releases/v333/lts-v268-read-tools.js');
const day={date:'2027-02-21',Consolidado:{bank_balance:1010},fix86_columns:{saldo_anterior:1000,saldo_final:1010,entradas:30,saidas:20,liq_d0_1_recurso:0,saldo_apos_d0_1:1010,rsus_vested:500,saldo_apos_rsu:1510,fgts:0,saldo_apos_fgts:1510}};
const events=[{event_date:day.date,account:'Itaú',signed_amount:30,source:'current_event',asset_movement:true},{event_date:day.date,account:'Itaú',signed_amount:-20,source:'current_event'},
 {event_date:day.date,account:'Corretora',signed_amount:500,source:'future_rsu_available'},
 {event_date:day.date,account:'Corretora',signed_amount:200,source:'future_cash_rsu_available'},
 {event_date:day.date,account:'Corretora',signed_amount:100,source:'future_award_vesting_marker'},
 {event_date:day.date,account:'Corretora',signed_amount:100,source:'future_other',category:'Cash RSU'},
 {event_date:day.date,account:'Itaú',signed_amount:900,source:'economic_withholding'},
 {event_date:day.date,account:'Itaú',signed_amount:300,source:'current_event',internal_transfer:true}];
const input={from:day.date,to:day.date,days:[day],events},before=JSON.stringify(input);
let r=tools.consolidatedTsv(input);assert(r.ok);assert.match(r.text,/2027-02-21\t1000,00\t30,00\t20,00\t1010,00/);assert.equal(JSON.stringify(input),before);
const fallback=structuredClone(input);delete fallback.days[0].fix86_columns.entradas;delete fallback.days[0].fix86_columns.saidas;
r=tools.consolidatedTsv(fallback);assert(r.ok);assert.match(r.text,/\t30,00\t20,00\t1010,00/,'Noncash awards cannot be bank receipts, actual bank asset movements remain cash');
const invalid=structuredClone(input);invalid.days[0].fix86_columns.entradas=530;r=tools.consolidatedTsv(invalid);assert.equal(r.ok,false);assert.match(r.message,/não fecham/);
const unknown=structuredClone(input);Object.assign(unknown.days[0],{historical:true,relative_balance_display:true});r=tools.consolidatedTsv(unknown);assert(r.ok);assert.match(r.text,/Não comprovado\t30,00\t20,00\tNão comprovado/);
assert.equal(tools.consolidatedTsv({...input,loading:true}).ok,false);assert.equal(tools.consolidatedTsv({...input,error:'unavailable'}).ok,false);
console.log(JSON.stringify({pass:true,shared_cash_award_boundary:true,bank_asset_cash_preserved:true,arithmetic_guard:true,unknown_balances_preserved:true,source_unchanged:true}));
