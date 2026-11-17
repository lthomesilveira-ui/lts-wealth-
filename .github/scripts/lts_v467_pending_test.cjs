'use strict';
const assert=require('node:assert/strict'),model=require('../../releases/v467/lts-v333-actions-model.js');
const legacy='Classificação conhecida; o pagamento desta obrigação ainda requer correspondência documental.';
for(const value of [120,-120]){const input={recurring:{items:[],horizon_checks:[]},cockpit:{work:{top_actions:[{action_key:'invented',title:'Movimentação fictícia',detail:legacy,impact_amount:value}]}},cards:{cards:[]},asOf:'2026-11-17'},before=JSON.stringify(input),result=model.build(input);assert.equal(result.items.length,1);assert.equal(result.items[0].detail,'Movimentação ainda sem confirmação no banco.');assert.equal(result.items[0].impact_amount,value);assert.equal(JSON.stringify(input),before);}
const input={recurring:{items:[],horizon_checks:[]},cockpit:{work:{top_actions:[{action_key:'warning',title:'Teste',detail:'Saldo indisponível; confira o extrato.',impact_amount:120}]}},cards:{cards:[]},asOf:'2026-11-17'};assert.equal(model.build(input).items[0].detail,input.cockpit.work.top_actions[0].detail);
console.log(JSON.stringify({pass:true,incoming_and_outgoing_unchanged:true,unrelated_material_warning_preserved:true,financial_writes:0}));
