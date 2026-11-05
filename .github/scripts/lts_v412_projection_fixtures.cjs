'use strict';
// Fictional values and identities. No production owner data is included.
function policy() {
 const common={direction:'expense',account:'Itaú',method:'history_total_budget',reference_amount_brl:120,
  history_total_brl:1440,uses_history:true,reference_window:{from:'2025-11-01',to:'2026-10-31'},reference_stale:false,
  coverage_months:12,observed_months:12,months_with_spend:12,partial_months:0,expected_months:12,source_count:12,
  outlier_months:[],annual_rate:0,warnings:[],projected_occurrences:62,preserved_occurrences:0,unresolved_periods:0,
  annual_totals:[{year:2026,budget_total_brl:240,additional_brl:180,partial_year:true},
    {year:2031,budget_total_brl:1440,additional_brl:1440,partial_year:false}],due_day_basis:'history_modal_day_estimate'};
 return {version:'projection-policy-v412',schema_version:1,enabled:true,as_of:'2026-11-04',horizon_end:'2031-12-31',
  next_review_on:'2027-01-01',history_window:{from:'2025-11-01',to:'2026-10-31'},
  series:[{...structuredClone(common),series_key:'card_test',description:'Cartão de teste'},
   {...structuredClone(common),series_key:'health_test',description:'Saúde direta de teste',reference_amount_brl:90,
    history_total_brl:1080,months_with_spend:9,outlier_months:['2026-07-01']},
   {...structuredClone(common),series_key:'utility_test',description:'Energia de teste',method:'inflated_calendar',
    annual_rate:.05,template_source:'history_mean',due_day_basis:'confirmed_calendar'},
   {...structuredClone(common),series_key:'salary',description:'Salário de teste',direction:'income',method:'salary_net',
    reference_amount_brl:9000,uses_history:false,history_total_brl:null,coverage_months:0,observed_months:0,months_with_spend:0,
    source_count:0,due_day_basis:'confirmed_calendar'}],warnings:[],card_method:'total_budget_floor',
  outliers_excluded:false,missing_months_assumed_zero:false,financial_sources_modified:false,current_year_partial:true};
}
function stale(){const p=policy();p.as_of='2027-01-01';p.horizon_end='2032-12-31';p.next_review_on='2028-01-01';
 p.history_window={from:'2026-01-01',to:'2026-12-31'};p.current_year_partial=false;
 for(const r of p.series){r.annual_totals=[{year:2032,budget_total_brl:1440,additional_brl:1440,partial_year:false}];
  if(r.uses_history){r.reference_stale=true;r.coverage_months=11;r.observed_months=11;r.months_with_spend=Math.min(r.months_with_spend,11);r.warnings=['partial_history','previous_complete_window'];}}
 return p;
}
module.exports={policy,stale};
