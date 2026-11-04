'use strict';
function synthetic() {
  const source_files = [{file:'Fonte.xlsx',sha256:'a'.repeat(64),primary:true},{file:'Copia.xlsx',sha256:'b'.repeat(64),primary:false}];
  const groups = Array.from({length:32},(_,i)=>{
    const total=120+i, count=i<11?2:1, sourceRow=21+i;
    const cash_rows=Array.from({length:count},(_,j)=>{
      const ref=1000+i*2+j,n=2000+i*2+j;
      return {source_table:'evento_base',source_ref:String(ref),row_key:'event:'+ref,event_date:i<3?'2020-01-31':'2020-01-30',amount:(total/count).toFixed(2),workbook_rows:source_files.map(x=>({file:x.file,sheet:'Pagamentos e Recebimentos',row:n,description_cell:'A'+n,amount_cell:'B'+n,date_cell:'C'+n,property_cell:'G'+n,property_label:'Cipó 396'}))};
    });
    return {id:'group_'+i,source_sheet:'Sonho',source_row:sourceRow,source_cells:{schedule_date:'W'+sourceRow,constructor:'Y'+sourceRow,broker:'Z'+sourceRow,total:'AA'+sourceRow},scheduled_date:'2020-01-30',constructor_brl:(100+i).toFixed(2),broker_brl:'20.00',total_brl:total.toFixed(2),cash_rows,date_difference:i<3,individual_allocation:null};
  });
  const sum=key=>groups.reduce((s,g)=>s+Number(g[key]),0).toFixed(2);
  return {schema:'cipo-acquisition-documentary-v408',property_code:'cipo396',verified_on:'2026-11-04',evidence_kind:'workbook_acquisition_composition',source_files,groups,counts:{groups:32,documented_rows:43,residual_rows:5,date_difference_groups:3},documented_total_brl:sum('total_brl'),constructor_total_brl:sum('constructor_brl'),broker_total_brl:sum('broker_brl'),residual_total_brl:'50.00',residuals:Array.from({length:5},(_,i)=>({source_table:i<3?'evento_base':'financial_events',source_ref:String(9000+i),row_key:'residual:'+i,event_date:'2026-10-20',amount:'10.00',description:'Aquisição',reason:'Composição pendente.'}))};
}
module.exports={synthetic};
