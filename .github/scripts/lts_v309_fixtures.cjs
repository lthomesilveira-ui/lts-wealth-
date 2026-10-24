'use strict';
const base=require('./lts_v308_fixtures.cjs');
function contracts(data){
 const mortgage={id:'cipo_396',label:'Contrato imobiliário fictício',total_events:20,remaining_events:2,confirmed_paid_installments:6,current_documentary_debt_balance:900,current_debt_as_of:'2020-09-02',next_due:'2020-11-20',next_amount:70,remaining_scheduled_outflow_current_terms:130,unconfirmed_past_events:0};
 const vehicle={id:'volvo',label:'Veículo fictício',total_events:60,remaining_events:58,confirmed_paid_installments:0,remaining_scheduled_outflow:580,next_due:'2020-11-05',next_amount:10,unconfirmed_past_events:2,schedule_rows:[{installment_number:1,due_date:'2020-09-05',amount:10,status:'payment_unconfirmed'},{installment_number:2,due_date:'2020-10-05',amount:10,status:'payment_unconfirmed'},{installment_number:3,due_date:'2020-11-05',amount:10,status:'scheduled'}],realized_rows:[]};
 const payroll={id:'coopharma',label:'Consignado fictício',total_events:48,remaining_events:27,confirmed_paid_installments:19,remaining_economic_outflow:270,next_due:'2020-10-31',next_amount:10,unconfirmed_past_events:2,schedule_rows:[],realized_rows:[]};
 const parents={id:'pai_mae',label:'Empréstimo familiar fictício',remaining_events:2,confirmed_paid_installments:0,remaining_scheduled_outflow:50,next_due:'2021-03-01',next_amount:10,schedule_rows:[{due_date:'2021-03-01',amount:10,status:'scheduled'},{due_date:'2021-04-01',amount:40,status:'scheduled'}],realized_rows:[]};
 const documentary={items:[{commitment_id:'cipo_396',as_of_date:'2020-09-02',debt_balance:900,metadata:{paid_installments:4,total_installments:20},schedule_loaded:{future_loaded_count:2,future_loaded_total:130,unconfirmed_past_count:0,rows:[{installment_number:7,due_date:'2020-11-20',amount:70,status:'scheduled',balance_after:830},{installment_number:8,due_date:'2020-12-20',amount:60,status:'scheduled',balance_after:770}],realized_rows:[{installment_number:5,due_date:'2020-09-20',scheduled_amount:100,paid_date:'2020-09-21',paid_amount:101},{installment_number:6,due_date:'2020-10-20',scheduled_amount:90,paid_date:'2020-10-20',paid_amount:92}]}}]};
 data.financing={...(data.financing||{}),summary:{as_of:'2020-10-24',commitments:[mortgage,vehicle,payroll,parents]},documentary};
 data.commitments=data.financing.summary;data.documentary_commitments=documentary;
 return data;
}
module.exports={...base,contracts};
