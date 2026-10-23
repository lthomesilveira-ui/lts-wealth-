'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const {VERSION, validateReports} = require('./lts_v299_browser_environment.cjs');
const fixture = () => ({package_version: VERSION, browsers: ['chromium', 'webkit'].map(name =>
  ({name, executable: `/ms-playwright/${name}-fixture/browser`, version: 'fixture-1', smoke_pass: true}))});
let cases = 0;
validateReports(fixture(), fixture()); cases++;
for (const language of ['node', 'python']) {
  for (const mutate of [
    r => {r.package_version = '1.55.1';},
    r => {r.browsers.pop();},
    r => {r.browsers[1] = {...r.browsers[0]};},
    r => {r.browsers[0].smoke_pass = false;},
    r => {r.browsers[0].executable = '/tmp/unverified-browser';},
    r => {r.browsers[0].executable += '-different-build';},
    r => {r.browsers[0].version = '';},
    r => {r.browsers[0].version = 'different-version';}
  ]) {
    const reports = {node: fixture(), python: fixture()};
    mutate(reports[language]);
    assert.throws(() => validateReports(reports.node, reports.python)); cases++;
  }
}
const workflow = fs.readFileSync('.github/workflows/v177-expense-ux.yml', 'utf8');
assert.ok(workflow.includes(`image: mcr.microsoft.com/playwright/python:v${VERSION}-noble`));
assert.ok(workflow.includes(`playwright@${VERSION}`));
assert.ok(workflow.includes(`playwright==${VERSION}`));
assert.ok(!workflow.includes('playwright install'), 'No per-run browser/system dependency download');
assert.ok(!workflow.includes('continue-on-error'), 'Do not turn a failed check into success');
for (const gate of ['lts_v177_expense_ux_gate.js', 'lts_v176_flow_expense_audit_contract.js',
  'lts_v175_expense_financial_audit_contract.js', 'lts_v174_v173_review_contract.js',
  'lts_v173_v172_feedback_contract.js', 'lts_v172_v171_review_contract.js',
  'lts_integrated_flow_gate.py', 'lts_flow_bank_scope_gate.py',
  'lts_invoice_reading_order_gate.py', 'lts_flow_documentary_rollforward_gate.py']) {
  assert.ok(workflow.includes(gate), `Keep protected gate ${gate}`);
}
for (const [file, version, image] of [
  ['v174-v173-review.yml', VERSION, `mcr.microsoft.com/playwright/python:v${VERSION}-noble`],
  ['v260.yml', '1.58.2', 'mcr.microsoft.com/playwright:v1.58.2-noble']
]) {
  const source = fs.readFileSync('.github/workflows/' + file, 'utf8');
  assert.ok(source.includes('image: ' + image));
  assert.ok(source.includes('playwright@' + version));
  assert.ok(source.includes('PLAYWRIGHT_BROWSERS_PATH: /ms-playwright'));
  assert.ok(!source.includes('playwright install'), `${file}: no dependency download`);
  assert.ok(!source.includes('continue-on-error'), `${file}: do not hide failures`);
}
console.log(JSON.stringify({pass: true, cases, workflows: 3, scope: 'environment-contract-only'}));
