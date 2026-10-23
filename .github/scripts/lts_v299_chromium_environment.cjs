'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const VERSION = '1.58.2';
const IMAGE = `mcr.microsoft.com/playwright:v${VERSION}-noble`;

function validateChromiumReport(report) {
  assert.equal(report.package_version, VERSION);
  assert.equal(report.image, IMAGE);
  assert.equal(report.name, 'chromium');
  assert.equal(report.smoke_pass, true);
  assert.ok(typeof report.browser === 'string' && report.browser.length > 0);
  assert.ok(typeof report.executable === 'string' && report.executable.startsWith('/ms-playwright/'));
}

async function main() {
  const result = {pass: false, scope: 'offline-browser-environment-only', image: IMAGE};
  try {
    const {chromium} = require('playwright');
    result.package_version = require('playwright/package.json').version;
    assert.equal(result.package_version, VERSION);
    assert.equal(process.env.PLAYWRIGHT_BROWSERS_PATH, '/ms-playwright');
    const browser = await chromium.launch({headless: true});
    try {
      const page = await browser.newPage();
      await page.setContent('<title>LTS CI smoke</title><p>Ambiente de teste</p>');
      assert.equal(await page.title(), 'LTS CI smoke');
      assert.equal(await page.locator('p').isVisible(), true);
      Object.assign(result, {name: 'chromium', browser: browser.version(),
        executable: chromium.executablePath(), smoke_pass: true});
      validateChromiumReport(result);
      result.pass = true;
    } finally { await browser.close(); }
  } catch (error) {
    result.error = String(error.stack || error);
    process.exitCode = 1;
  } finally {
    fs.mkdirSync('qa', {recursive: true});
    fs.writeFileSync('qa/v299-browser-environment.json', JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result, null, 2));
  }
}

module.exports = {VERSION, IMAGE, validateChromiumReport};
if (require.main === module) main();
