'use strict';

// This is a test-runner check, not evidence of a private financial session.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const {execFileSync} = require('node:child_process');
const VERSION = '1.55.0';
const ENGINES = ['chromium', 'webkit'];

function validateReports(node, python) {
  for (const [language, report] of [['node', node], ['python', python]]) {
    assert.equal(report.package_version, VERSION, `${language}: client version`);
    assert.deepEqual(report.browsers.map(x => x.name).sort(), ENGINES,
      `${language}: both required browser engines`);
    for (const browser of report.browsers) {
      assert.equal(browser.smoke_pass, true, `${language}/${browser.name}: launch/render`);
      assert.ok(browser.version, `${language}/${browser.name}: browser version`);
      assert.ok(browser.executable.startsWith('/ms-playwright/'),
        `${language}/${browser.name}: use the image's baked browser`);
    }
  }
  for (const name of ENGINES) {
    const a = node.browsers.find(x => x.name === name);
    const b = python.browsers.find(x => x.name === name);
    assert.equal(a.executable, b.executable, `${name}: clients must share the browser build`);
    assert.equal(a.version, b.version, `${name}: browser versions must match`);
  }
}

async function probeNode() {
  const playwright = require('playwright');
  const report = {package_version: require('playwright/package.json').version, browsers: []};
  assert.equal(report.package_version, VERSION, 'node: client version');
  for (const name of ENGINES) {
    const engine = playwright[name];
    fs.accessSync(engine.executablePath(), fs.constants.X_OK);
    const browser = await engine.launch({headless: true});
    try {
      const page = await browser.newPage();
      await page.setContent('<title>LTS CI smoke</title><p>Ambiente de teste</p>');
      assert.equal(await page.title(), 'LTS CI smoke');
      assert.equal(await page.locator('p').isVisible(), true);
      report.browsers.push({name, executable: engine.executablePath(),
        version: browser.version(), smoke_pass: true});
    } finally {
      await browser.close();
    }
  }
  return report;
}

function probePython() {
  const code = `
import importlib.metadata, json, os
from playwright.sync_api import sync_playwright
report = {'package_version': importlib.metadata.version('playwright'), 'browsers': []}
assert report['package_version'] == '${VERSION}', 'python: client version'
with sync_playwright() as p:
    for name in ['chromium', 'webkit']:
        engine = getattr(p, name)
        assert os.access(engine.executable_path, os.X_OK), 'python: executable unavailable'
        browser = engine.launch(headless=True)
        try:
            page = browser.new_page()
            page.set_content('<title>LTS CI smoke</title><p>Ambiente de teste</p>')
            assert page.title() == 'LTS CI smoke'
            assert page.locator('p').is_visible()
            report['browsers'].append({'name': name, 'executable': engine.executable_path,
                'version': browser.version, 'smoke_pass': True})
        finally:
            browser.close()
print(json.dumps(report))
`;
  return JSON.parse(execFileSync('python', ['-c', code],
    {encoding: 'utf8', timeout: 60000, stdio: ['ignore', 'pipe', 'pipe']}));
}

async function main() {
  const result = {pass: false, scope: 'offline-browser-environment-only',
    image: 'mcr.microsoft.com/playwright/python:v1.55.0-noble'};
  try {
    assert.equal(process.env.PLAYWRIGHT_BROWSERS_PATH, '/ms-playwright');
    result.node = await probeNode();
    result.python = probePython();
    validateReports(result.node, result.python);
    result.pass = true;
  } catch (error) {
    result.error = String(error.stack || error);
    process.exitCode = 1;
  } finally {
    fs.writeFileSync('v299-browser-environment-result.json', JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result, null, 2));
  }
}

module.exports = {VERSION, validateReports};
if (require.main === module) main();
