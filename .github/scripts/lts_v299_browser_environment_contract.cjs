'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const {VERSION, validateReports} = require('./lts_v299_browser_environment.cjs');
const {VERSION: NODE_VERSION, IMAGE, validateChromiumReport} = require('./lts_v299_chromium_environment.cjs');
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
const chromiumFixture = () => ({package_version: NODE_VERSION, image: IMAGE,
  name: 'chromium', smoke_pass: true, browser: 'fixture-1', executable: '/ms-playwright/chromium-fixture/browser'});
validateChromiumReport(chromiumFixture()); cases++;
for (const mutate of [
  r => {r.package_version = '1.58.1';}, r => {r.image += '-wrong';},
  r => {r.name = 'webkit';}, r => {r.smoke_pass = false;},
  r => {r.browser = '';}, r => {r.browser = 123;},
  r => {r.executable = '/tmp/browser';}, r => {delete r.executable;}
]) {
  const report = chromiumFixture(); mutate(report);
  assert.throws(() => validateChromiumReport(report)); cases++;
}
const legacy = ['v170-v169-review.yml', 'v171-v170-review.yml', 'v172-v171-review.yml',
  'v173-v172-feedback.yml', 'v174-v173-review.yml', 'v175-expense-financial-audit.yml',
  'v176-flow-expense-audit.yml', 'v177-expense-ux.yml'];
const modern = ['v242.yml', 'v257.yml', 'v258.yml', 'v259.yml', 'v260.yml', 'v261.yml', 'v262.yml'];
for (const file of [...legacy, ...modern]) {
  const isLegacy = legacy.includes(file);
  const version = isLegacy ? VERSION : NODE_VERSION;
  const image = isLegacy ? `mcr.microsoft.com/playwright/python:v${VERSION}-noble` : IMAGE;
  const source = fs.readFileSync('.github/workflows/' + file, 'utf8');
  assert.ok(source.includes('image: ' + image));
  assert.ok(source.includes('playwright@' + version));
  assert.ok(source.includes('PLAYWRIGHT_BROWSERS_PATH: /ms-playwright'));
  if (isLegacy) {
    assert.ok(source.includes('playwright==' + version));
    assert.ok(source.includes('run: node .github/scripts/lts_v299_browser_environment.cjs'));
    assert.ok(source.includes('v299-browser-environment-result.json'));
  } else {
    assert.ok(source.includes('actions/setup-python@v5'));
    assert.ok(source.includes('run: node .github/scripts/lts_v299_chromium_environment.cjs'));
  }
  assert.ok(!source.includes('playwright install'), `${file}: no dependency download`);
  assert.ok(!source.includes('continue-on-error'), `${file}: do not hide failures`);
}
console.log(JSON.stringify({pass: true, cases, workflows: legacy.length + modern.length, scope: 'environment-contract-only'}));
