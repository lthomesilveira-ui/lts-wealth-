'use strict';
// Execute the real docFinDetail in a VM with synthetic globals. No DOM/browser.
const fs = require('fs'), path = require('path'), vm = require('vm');
const assert = require('assert/strict'), crypto = require('crypto');
const sha = s => crypto.createHash('sha256').update(s).digest('hex');
const frozen = fs.readFileSync(path.join(__dirname, 'documentary_renderer_source.cjs'), 'utf8');
const expectedHash = '491674a4ecb4b8f721e2d030ea1739bca96b321f51cd066a81f1d895f58ff63f';
assert.equal(sha(frozen), expectedHash, 'Frozen real renderer changed; renew source review');
let source = frozen;
const sourceArg = process.argv.indexOf('--ui-source');
if (sourceArg >= 0) {
  const file = process.argv[sourceArg + 1];
  assert(file, '--ui-source requires an actual v271 HTML path');
  const html = fs.readFileSync(file, 'utf8');
  const a = html.indexOf('function docFinDetail(){');
  const b = html.indexOf('\nfunction financiamentos()', a);
  assert(a >= 0 && b > a, 'Cannot locate exact real docFinDetail boundary');
  source = html.slice(a, b);
  assert.equal(sha(source), expectedHash, 'Repository renderer differs from reviewed source');
  const financing = html.slice(b, html.indexOf('\nfunction ', b + 1));
  assert(financing.includes('posição ${fmt(today())}'), 'Financiamentos no longer declares current position');
}
assert(source.includes('.find(x=>x.commitment_id===id)'), 'First matching position is the UI contract');
const input = JSON.parse(fs.readFileSync(0, 'utf8'));
const before = JSON.stringify(input.payload);
const context = vm.createContext({
  D: {documentary_commitments: input.payload}, FINSEL: input.selection || 'cipo_396',
  num: Number, fmt: value => String(value ?? ''), brl: value => `BRL(${value})`,
  esc: value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])),
  financingDetail: () => '<synthetic-fallback>'
});
vm.runInContext(source, context, {timeout: 1000});
const rendered = vm.runInContext('docFinDetail()', context, {timeout: 1000});
assert.equal(JSON.stringify(context.D.documentary_commitments), before, 'Renderer mutated reader result');
if (input.fallback) {
  assert.equal(rendered, '<synthetic-fallback>');
} else {
  const expected = input.expected;
  assert(expected, 'Expected fields required');
  assert(rendered.includes(expected.source_label), 'Wrong documentary source/TR label');
  assert(rendered.includes(`posição ${expected.as_of_date}`), 'Wrong documentary date');
  assert(rendered.includes(`Saldo devedor BRL(${expected.debt_balance})`), 'Wrong debt balance');
  for (const forbidden of input.forbidden_sources || []) {
    assert(!rendered.includes(forbidden), `Ineligible/other source rendered: ${forbidden}`);
  }
  if (expected.tr_count != null) {
    assert.equal((rendered.match(/cronograma sujeito à TR/g) || []).length, expected.tr_count);
  }
}
console.log(JSON.stringify({passed: true, renderer_sha256: sha(source), actual_ui_source_checked: sourceArg >= 0, browser_test: false}));
