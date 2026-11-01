'use strict';
// Invented source cells and financial values; no account or session fixtures.
const f=require('./lts_v359_fixtures.cjs');
const copies=[['Synthetic.xlsm','a'],['Synthetic.xlsx','b']];
const sourceRows=data=>copies.flatMap(([file,h])=>data.map(([row,date,description,signed_amount])=>({file,sha256:h.repeat(64),sheet:'Pagamentos e Recebimentos',row,cell:'B'+row,date,description,signed_amount})));
function sample(){
 const rows=f.rows(),unique=40.0043333333333;
 const cells={D3:20,D4:-2,D13:13,D14:90,D41:5,J4:108,J5:126,J31:unique+10};
 const explanation={status:'verified_workbook_cash_coverage',amount:2,date:'2020-01-14',component_id:'invented-glass',description:'Espelhos fictícios',file:'Synthetic.xlsm',sha256:'a'.repeat(64),payment_sheet:'Pagamentos e Recebimentos',payment_row:30,services_payment_row:31,services_description:'Serviços fictícios',cash_sheet:'Fluxo de Caixa',cash_column:'AB',cash_services_row:10,cash_services_amount:7,cash_label_absent:true,cash_open:100,cash_income:0,cash_outflow:20,cash_close:80,bank_payment_confirmed:false,ledger_reclassification_allowed:false,new_cash_event_allowed:false};
 const snapshot_scope={source_file:'Synthetic.xlsm',source_sheet:'Investimento Cipó 396',source_paid_cutoff:'2020-06-30',source_loan_paid:20,
  source_cash_rows:sourceRows([[4,'2020-04-17','Consórcio fictício',30],[7,'2020-05-12','Consórcio fictício',35],[8,'2020-05-15','Consórcio fictício',-5],[9,'2020-06-12','Consórcio fictício',30],[10,'2020-04-19','Consórcio fictício',0],[11,'2020-02-12','Consórcio fictício',13]]),
  source_card_consortium_rows:sourceRows([[20,'2020-01-20','Consórcio fictício',5]]),
  works_unlinked_source_rows:sourceRows([[30,'2020-01-14',explanation.description,2],[31,'2020-01-14',explanation.services_description,2]]),
  investment_summary:copies.map(([file,h])=>({file,sha256:h.repeat(64),cells:{...cells}})),duplicate_formula_cells:['D10','D16','J23','J31'],works_cash_coverage_explanation:explanation};
 const native={source_internal_consistency:{duplicate_row_amount:10,improvement_detail_total:unique},
  consortium:{itau_ledger:90,itau_source_audit:{status:'verified_original_signed_rows',snapshot_scope}},
  components:[{id:'invented-other',class:'improvement',source_paid:unique-2,description:'Outros componentes fictícios',origin:'cartão'},
   {id:explanation.component_id,class:'improvement',source_paid:2,description:explanation.description,origin:'conta corrente',status:'source_only',method:'source_workbook_unmapped_ledger'}]};
 return{wealth:f.wealth(native),page:{rows,row_count:rows.length,total:f.total(rows)},range:{from:'2013-10-10',to:'2026-11-01'}};
}
module.exports={sample};
