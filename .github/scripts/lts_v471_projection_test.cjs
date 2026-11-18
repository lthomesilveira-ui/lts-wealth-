'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { createHash } = require('node:crypto');
const reader = require('../../releases/v471/lts-v412-projection-policy.js');

function fixture() {
  const row = {
    series_key: 'owner_sample', description: 'Orçamento de teste', account: 'Conta de teste',
    method: 'fixed', direction: 'expense', reference_amount_brl: 64.25, expected_months: 12,
    coverage_months: 24, uses_history: true, reference_stale: false,
    reference_window: {from: '2024-11-01', to: '2026-10-31'}, warnings: [],
    coverage: [{event_date: '2026-12-03', budget_total_brl: 64.25, known_brl: 24.20, additional_brl: 40.05, trusted: true}],
    annual_totals: [{year: 2026, partial_year: true, budget_total_brl: 64.25, additional_brl: 40.05}]
  };
  return {
    as_of: '2026-11-17', horizon_end: '2031-12-31', next_review_on: '2026-12-01',
    version: 'projection-policy-v412', enabled: true, schema_version: 1, current_year_partial: true,
    history_window: {from: '2025-11-01', to: '2026-10-31'}, warnings: [], card_method: 'total_budget_floor',
    outliers_excluded: false, missing_months_assumed_zero: false, financial_sources_modified: false,
    series: [row, {...structuredClone(row), series_key: 'recurring_sample_97', description: 'Valor combinado de teste',
      reference_window: null, uses_history: false, coverage_months: null}]
  };
}
module.exports = {fixture};

if (require.main === module) {
  const root = path.resolve(__dirname, '../..');
  const current = path.join(root, 'releases/v471'), previous = path.join(root, 'releases/v467');
  const hash = file => createHash('sha256').update(fs.readFileSync(file)).digest('hex');
  const manifest = JSON.parse(fs.readFileSync(path.join(current, 'manifest.json')));
  const priorManifest = JSON.parse(fs.readFileSync(path.join(previous, 'manifest.json')));
  assert.equal(manifest.release, 'v471');
  assert.equal(manifest.protected_manifest.sha256, hash(path.join(previous, 'manifest.json')));
  assert.deepEqual(Object.keys(manifest.files), Object.keys(priorManifest.files));
  assert.deepEqual(Object.keys(manifest.files).filter(name => manifest.files[name] !== priorManifest.files[name]).sort(),
    ['app.html', 'lts-v412-projection-policy.js', 'provenance.json']);
  for (const [name, digest] of Object.entries(manifest.files)) assert.equal(hash(path.join(current, name)), digest, name);
  const document = fixture(), original = JSON.stringify(document);
  const [average, fixed] = reader.build(document).series;
  assert.equal(JSON.stringify(document), original);
  assert.equal(average.expected, 24);
  assert.equal(average.spendingMonths, null);
  assert.equal(average.amount, 6425);
  assert.equal(average.annual[0].additional, 4005);
  assert.equal(fixed.historyWindow, null);
  assert.equal(fixed.usesHistory, false);
  for (const [from, count] of [['2026-08-01', 3], ['2025-11-01', 12]]) {
    const example = fixture();
    example.series[0].reference_window.from = from;
    example.series[0].coverage_months = count;
    assert.equal(reader.build(example).series[0].expected, count);
  }
  const incomplete = fixture(), row = incomplete.series[0];
  Object.assign(row.coverage[0], {trusted:false, known_brl:null, additional_brl:null});
  Object.assign(row.annual_totals[0], {additional_brl:null, budget_total_brl:null});
  row.warnings = ['unreconciled_periods'];
  assert.equal(reader.build(incomplete).series[0].annual[0].additional, null);
  const broken = [
    s => {s[0].series_key = s[1].series_key;}, s => {s[0].coverage_months = 12;},
    s => {s[0].reference_window.to = '2026-10-12';}, s => {s[0].coverage[0].known_brl = null;},
    s => {s[0].coverage[0].additional_brl = 64.25;}, s => {s[1].uses_history = true;},
    s => {s[1].method = 'history_total_budget';}, s => {s[1].coverage.push(s[1].coverage[0]);},
    s => {s[0].series_key = 'unrelated';}
  ];
  for (const corrupt of broken) {
    const example = fixture(); corrupt(example.series); assert.throws(() => reader.build(example));
  }
  console.log('Verified preserved release assets, fixed budgets, 3/12/24-month averages, unknown commitments and invalid data.');
}
