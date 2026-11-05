'use strict';
const test=require('node:test'),assert=require('node:assert/strict');
const api=require('../../lts-v412-projection-policy.js'),fixtures=require('./lts_v412_projection_fixtures.cjs');
test('server amounts remain exact and never receive browser-side inflation or a second deduction',()=>{
 const p=fixtures.policy(),original=JSON.stringify(p),m=api.build(p);
 assert.equal(m.series[0].amount,12000);assert.equal(m.series[2].amount,12000);assert.equal(m.series[3].amount,900000);
 assert.equal(m.horizon,'2031-12-31');assert.equal(m.series[1].covered,12);assert.equal(m.series[1].spendingMonths,9);
 assert.deepEqual(m.series[1].outliers,['2026-07-01']);assert.equal(JSON.stringify(p),original);
});
test('a prior complete reference survives an incomplete January window and extends one full year',()=>{
 const m=api.build(fixtures.stale());assert.equal(m.horizon,'2032-12-31');assert.equal(m.series[0].amount,12000);
 assert.equal(m.series[0].referenceStale,true);assert.equal(m.series[0].historyWindow.to,'2026-10-31');
});
test('no owner namespace preserves the prior interface',()=>assert.equal(api.build({version:'projection-policy-v412',enabled:false}),null));
const cases={
 wrong_version:p=>p.version='other',missing_enabled:p=>delete p.enabled,
 horizon_one_year_short:p=>p.horizon_end='2030-12-31',horizon_extra_year:p=>p.horizon_end='2032-12-31',
 invalid_asof:p=>p.as_of='2026-02-30',review_in_past:p=>p.next_review_on='2026-01-01',
 wrong_card_method:p=>p.card_method='add_average_to_installments',silent_missing_zero:p=>p.missing_months_assumed_zero=true,
 outlier_removed:p=>p.outliers_excluded=true,source_changed:p=>p.financial_sources_modified=true,
 duplicate_series:p=>p.series.push(structuredClone(p.series[0])),missing_description:p=>p.series[0].description='',
 partial_mean:p=>p.series[0].coverage_months=7,partial_inflated_mean:p=>{p.series[2].coverage_months=7;p.series[2].months_with_spend=7;},
 uncovered_spend_months:p=>p.series[0].months_with_spend=13,
 fractional_cent:p=>p.series[0].reference_amount_brl=1.005,negative_amount:p=>p.series[0].reference_amount_brl=-1,
 unsafe_amount:p=>p.series[0].reference_amount_brl='99999999999999999',
 salary_inflation:p=>p.series[3].annual_rate=.05,unknown_method:p=>p.series[0].method='automatic',
 rate_outside_contract:p=>p.series[2].annual_rate=.26,invalid_history_date:p=>p.history_window.to='2026-11-31',
 reversed_history:p=>p.history_window.from='2027-01-01',invalid_outlier_month:p=>p.series[1].outlier_months=['not-a-date'],
 annual_outside_horizon:p=>p.series[0].annual_totals[0].year=2040,
 annual_fractional_cent:p=>p.series[0].annual_totals[0].budget_total_brl=2.001
};
for(const[name,mutate]of Object.entries(cases))test('rejects '+name,()=>{const p=fixtures.policy();mutate(p);assert.throws(()=>api.build(p));});
