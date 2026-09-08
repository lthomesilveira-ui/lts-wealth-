const { chromium, webkit } = require('playwright');
const { spawn } = require('child_process');

const port = process.env.LTS_CANONICAL_GATE_PORT || '4173';
const baseUrl = `http://127.0.0.1:${port}/canonical-app.html`;
const server = spawn('python3', ['-m', 'http.server', port, '--bind', '127.0.0.1'], { stdio: 'inherit' });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

function routeButton(page, route, mobile) {
  const root = mobile ? '.mobile-nav' : '.sidebar';
  return page.locator(`${root} [data-route="${route}"]`);
}

async function openRoute(page, route, mobile) {
  await routeButton(page, route, mobile).click();
  await page.waitForTimeout(250);
}

async function waitProduct(page, route) {
  await page.waitForFunction(expected => (
    window.__LTS_CANONICAL_PRODUCT_V157_STATUS?.ready === true
      && window.__LTS_CANONICAL_PRODUCT_V157_STATUS?.route === expected
  ), route);
}

async function assertUpdatesContract(page, label) {
  const title = (await page.locator('.page-title h1').textContent())?.trim();
  if (title !== 'Atualizações') throw new Error(`${label}: updates route ${title}`);
  if (await page.locator('.class-row').count() < 3) throw new Error(`${label}: classification queue missing`);
  if (await page.locator('.class-save:not([disabled])').count() !== 0) {
    throw new Error(`${label}: fixture classification writer unexpectedly enabled`);
  }

  const term = page.locator('#ledgerTerm');
  await term.fill('Mastercard');
  await page.waitForFunction(() => document.querySelector('#ledgerMeta')?.textContent?.includes('1 lançamento'));
  if (await page.locator('.search-result').count() !== 1) throw new Error(`${label}: transaction search result missing`);
  if (await page.locator('#ledgerExport').isDisabled()) throw new Error(`${label}: CSV export not enabled`);
  if (await page.getByText('Documentos', { exact: true }).count() < 1) throw new Error(`${label}: documents area missing`);

  await page.waitForSelector('#liquidityMovementCard');
  if (await page.locator('#liquidityMovementCard').count() !== 1) throw new Error(`${label}: liquidity card multiplicity`);
  await page.locator('#liqType').selectOption('application');
  await page.locator('#liqAccount').selectOption('fixture-itau');
  await page.locator('#liqAsset').selectOption('fixture-cofrinho');
  await page.locator('#liqAmount').fill('5 mil');
  await page.locator('#liqPreviewBtn').click();
  await page.waitForSelector('#liqPreview');
  if (!(await page.locator('#liqPreview').textContent()).includes('R$ 0,00')) {
    throw new Error(`${label}: liquidity neutral preview missing`);
  }
  if (await page.locator('#liqApply').count() !== 0) throw new Error(`${label}: fixture liquidity writer unexpectedly enabled`);
}

async function openManagementPane(page, pane) {
  await page.locator(`.mg-tab[data-mg-pane="${pane}"]`).click();
  await page.waitForFunction(expected => (
    window.__LTS_CANONICAL_CAPABILITIES_STATUS?.active === expected
      && document.querySelector('#managementDetail')?.textContent?.trim().length > 0
  ), pane);
}

async function assertManagementContract(page, label) {
  await page.waitForFunction(() => window.__LTS_CANONICAL_CAPABILITIES_STATUS?.loaded === true);
  const recovery = await page.evaluate(() => window.__LTS_CANONICAL_RECOVERY_STATUS);
  if (recovery?.capabilities_loaded !== true || recovery?.capability_contract !== 10) {
    throw new Error(`${label}: capability loader contract ${JSON.stringify(recovery)}`);
  }
  if (await page.locator('#management-panel').count() !== 1) throw new Error(`${label}: management hub multiplicity`);
  if (await page.locator('.mg-tab').count() !== 8) throw new Error(`${label}: management tabs missing`);
  const overview = await page.locator('#management-panel').innerText();
  for (const required of ['Planejamento', 'Entradas & compromissos', 'Recorrências', 'Simulações', 'Conciliação', 'Relatórios', 'Backup & restauração', 'Configurações & integrações', 'Financiamentos', 'Documentos']) {
    if (!overview.includes(required)) throw new Error(`${label}: management overview missing ${required}`);
  }

  await openManagementPane(page, 'planning');
  let text = await page.locator('#managementDetail').innerText();
  for (const required of ['Primeira insuficiência', 'Pior posição', 'FGTS', 'Fatos prevalecem sobre projeções']) {
    if (!text.includes(required)) throw new Error(`${label}: planning management detail missing ${required}`);
  }

  await openManagementPane(page, 'recurring');
  text = await page.locator('#managementDetail').innerText();
  for (const required of ['Séries recorrentes', 'Cobertas', 'Planejamento', 'Conciliação', 'Mensalidade exemplo']) {
    if (!text.includes(required)) throw new Error(`${label}: recurring management detail missing ${required}`);
  }

  await openManagementPane(page, 'scenario');
  await page.locator('[data-mg-award]').first().check();
  await page.locator('#mgRunScenario').click();
  await page.waitForFunction(() => document.querySelector('#managementDetail')?.textContent?.includes('Valor selecionado'));
  text = await page.locator('#managementDetail').innerText();
  if (!text.includes('somente leitura') || !text.includes('Pior posição no cenário')) throw new Error(`${label}: read-only scenario contract`);

  await openManagementPane(page, 'reconciliation');
  text = await page.locator('#managementDetail').innerText();
  if (!text.includes('diferença R$ 0,00') || !text.includes('Documentos reconciliados')) throw new Error(`${label}: reconciliation contract`);

  await openManagementPane(page, 'reports');
  if (await page.locator('#mgExportReport').count() !== 1 || await page.locator('#mgExportRecurring').count() !== 1) throw new Error(`${label}: reports export surface`);

  await openManagementPane(page, 'backup');
  if (!(await page.locator('#mgExportBackup').isDisabled())) throw new Error(`${label}: fixture backup export unexpectedly enabled`);
  if (!(await page.locator('#mgRestoreFile').isDisabled())) throw new Error(`${label}: fixture restore staging unexpectedly enabled`);
  text = await page.locator('#managementDetail').innerText();
  if (!text.includes('checksum SHA-256') || !text.includes('duas etapas') && !text.includes('prévia')) throw new Error(`${label}: backup guardrail missing`);

  await openManagementPane(page, 'settings');
  text = await page.locator('#managementDetail').innerText();
  for (const required of ['Arquitetura Open Finance', 'Provedor ativo', 'provider-neutral', 'decisão explícita']) {
    if (!text.includes(required)) throw new Error(`${label}: settings guardrail missing ${required}`);
  }
  await openManagementPane(page, 'overview');
}

async function run(browserType, label, viewport) {
  const mobile = viewport.width <= 820;
  const browser = await browserType.launch({ headless: true });
  const page = await browser.newPage({ viewport });
  const errors = [];
  page.on('pageerror', error => errors.push(`pageerror:${String(error)}`));
  page.on('console', message => {
    if (message.type() === 'error') errors.push(`console:${message.text()}`);
  });

  try {
    await page.goto(`${baseUrl}?fixture=1`, { waitUntil: 'networkidle' });
    await page.waitForFunction(() => window.__LTS_CANONICAL_STATUS?.ready === true);
    await page.waitForFunction(() => {
      const status = window.__LTS_CANONICAL_RECOVERY_STATUS;
      return status?.flow_loaded === true
        && status?.product_loaded === true
        && status?.presentation_loaded === true
        && status?.capabilities_loaded === true;
    });
    await page.waitForFunction(() => window.__LTS_V157_PRESENTATION_STATUS?.ready === true);
    await waitProduct(page, 'Dashboard');

    const canonicalStatus = await page.evaluate(() => window.__LTS_CANONICAL_STATUS);
    if (canonicalStatus.iframe_count !== 0 || !canonicalStatus.fixture || !canonicalStatus.data_ready) {
      throw new Error(`${label}: canonical readiness ${JSON.stringify(canonicalStatus)}`);
    }
    for (const flag of ['server_search', 'classification_lifecycle', 'expense_context_lens', 'wealth_detail', 'card_coverage', 'document_lifecycle']) {
      if (canonicalStatus[flag] !== true) throw new Error(`${label}: capability flag ${flag} missing`);
    }

    const labels = await page.locator('#dashboard-view .kpi label').allTextContents();
    const expected = ['Dinheiro em contas', 'Contas + curto prazo', 'RSUs vested', 'FGTS', 'Despesas (mês)'];
    if (JSON.stringify(labels) !== JSON.stringify(expected)) throw new Error(`${label}: Dashboard KPI contract ${JSON.stringify(labels)}`);
    if (await page.locator('iframe').count()) throw new Error(`${label}: iframe detected`);
    const dashboardText = await page.locator('#dashboard-view').innerText();
    for (const text of ['Evolução da Liquidez', 'Distribuição do Patrimônio', 'Posição por Banco', 'Fluxo de Caixa', 'Principais Despesas', 'Próximos Compromissos', 'Planejamento – Visão de Caixa', 'FGTS', 'Atualizações Pendentes']) {
      if (!dashboardText.includes(text)) throw new Error(`${label}: Dashboard hierarchy missing ${text}`);
    }
    await page.screenshot({ path: `canonical-dashboard-${label}.png`, fullPage: true });

    await openRoute(page, 'Fluxo Diário', mobile);
    await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_V157_STATUS?.ready === true);
    if (!(await page.locator('.fv-build').textContent()).includes('LTS v1.3')) throw new Error(`${label}: build marker missing`);
    if (await page.locator('[data-account]').count() !== 4) throw new Error(`${label}: four-bank tabs missing`);
    if (await page.locator('[data-preset]').count() !== 10) throw new Error(`${label}: period presets missing`);
    if (!mobile && await page.locator('.fv-table th').count() !== 14) throw new Error(`${label}: consolidated Flow columns`);
    const flowText = (await page.locator('.fv').innerText()).toLowerCase();
    for (const forbidden of ['baseline funcional', 'fix86', 'legacy']) {
      if (flowText.includes(forbidden)) throw new Error(`${label}: technical text leaked ${forbidden}`);
    }
    for (const required of ['histórico / período', 'rsus futuras', 'cash awards futuros']) {
      if (!flowText.includes(required)) throw new Error(`${label}: Flow layer missing ${required}`);
    }
    await page.locator('[data-expand]').first().click();
    if (!(await page.locator('.fv-detail').innerText()).includes('Movimentos do dia')) throw new Error(`${label}: Flow drilldown missing`);
    await page.locator('[data-account="Itaú"]').click();
    if (await page.locator('.fv-table tbody .fv-row').count() < 1) throw new Error(`${label}: bank Flow switch failed`);
    await page.screenshot({ path: `canonical-flow-${label}.png`, fullPage: true });

    await openRoute(page, 'Despesas', mobile);
    await waitProduct(page, 'Despesas');
    let text = await page.locator('.pv').innerText();
    for (const required of ['Quanto você gastou — e como isso evoluiu.', 'Mês a mês', 'Ano a ano', 'Cobertura do histórico']) {
      if (!text.includes(required)) throw new Error(`${label}: expense surface missing ${required}`);
    }
    await page.locator('[data-exp-month]').first().click();
    await page.waitForSelector('[data-close-month]');
    await page.screenshot({ path: `canonical-expenses-${label}.png`, fullPage: true });

    await openRoute(page, 'Patrimônio', mobile);
    await waitProduct(page, 'Patrimônio');
    text = await page.locator('.pv').innerText();
    for (const required of ['Quanto você tem, quanto deve e quanto é seu.', 'RSUs vested', 'RSUs futuras', 'Cash Awards futuros', 'CIPÓ 396', 'Volvo']) {
      if (!text.includes(required)) throw new Error(`${label}: wealth surface missing ${required}`);
    }
    await page.screenshot({ path: `canonical-wealth-${label}.png`, fullPage: true });

    await openRoute(page, 'Cartões', mobile);
    await waitProduct(page, 'Cartões');
    text = await page.locator('.pv').innerText();
    for (const required of ['Conferência de fatura, não análise de gasto.', 'Cobertura histórica', 'Histórico por cartão / ano', '12/09/2026']) {
      if (!text.includes(required)) throw new Error(`${label}: cards surface missing ${required}`);
    }
    await page.screenshot({ path: `canonical-cards-${label}.png`, fullPage: true });

    await openRoute(page, 'Atualizações', mobile);
    await page.waitForTimeout(350);
    await assertUpdatesContract(page, label);
    await assertManagementContract(page, label);
    await page.screenshot({ path: `canonical-updates-${label}.png`, fullPage: true });

    await openRoute(page, 'Dashboard', mobile);
    await waitProduct(page, 'Dashboard');
    const metrics = await page.evaluate(() => ({
      scrollWidth: document.documentElement.scrollWidth,
      clientWidth: document.documentElement.clientWidth,
      iframes: document.querySelectorAll('iframe').length,
      nav: [...document.querySelectorAll('.mobile-nav button')].map(button => {
        const rect = button.getBoundingClientRect();
        return { left: rect.left, right: rect.right, width: rect.width };
      })
    }));
    if (metrics.scrollWidth > metrics.clientWidth + 1) throw new Error(`${label}: horizontal overflow ${JSON.stringify(metrics)}`);
    if (metrics.iframes) throw new Error(`${label}: iframe after navigation`);
    if (mobile) {
      if (metrics.nav.length !== 6) throw new Error(`${label}: mobile navigation count`);
      if (metrics.nav.some(item => item.left < -0.5 || item.right > viewport.width + 0.5 || item.width <= 0)) {
        throw new Error(`${label}: clipped mobile navigation ${JSON.stringify(metrics.nav)}`);
      }
    }
    if (errors.length) throw new Error(`${label}: browser errors ${errors.join(' | ')}`);

    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(800);
    if (await page.locator('#loginForm').count() !== 1) throw new Error(`${label}: real login missing`);
    if (await page.locator('#dashboard-view .kpi').count()) throw new Error(`${label}: fake financial UI unauthenticated`);
    if (await page.getByText('FIXTURE DE TESTE', { exact: true }).count()) throw new Error(`${label}: fixture badge leaked`);
  } finally {
    await browser.close();
  }
}

async function runJwtClockRecovery(browserType) {
  const browser = await browserType.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  try {
    await page.route('https://tadhkamnwtsbdozwkyut.supabase.co/rest/v1/rpc/**', route => route.fulfill({
      status: 401,
      contentType: 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: JSON.stringify({ message: 'JWT issued at future' })
    }));
    await page.addInitScript(() => localStorage.setItem('lts_supabase_session_v1', JSON.stringify({
      access_token: 'future-token',
      expires_at: Math.floor(Date.now() / 1000) + 3600,
      user: { id: 'fixture-session-recovery' }
    })));
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#loginForm', { timeout: 12000 });
    const recovery = await page.evaluate(() => ({
      storedSession: localStorage.getItem('lts_supabase_session_v1'),
      status: window.__LTS_CANONICAL_SESSION_STATUS,
      body: document.body.innerText
    }));
    if (recovery.storedSession !== null) throw new Error('WebKit JWT recovery kept the invalid session');
    if (recovery.status?.reset !== true || recovery.status?.reason !== 'jwt-clock') {
      throw new Error(`WebKit JWT recovery status ${JSON.stringify(recovery.status)}`);
    }
    if (!recovery.body.includes('Sua sessão foi renovada por segurança. Entre novamente.')) {
      throw new Error('WebKit JWT recovery guidance missing');
    }
    if (recovery.body.includes('JWT issued at future')) throw new Error('raw JWT error leaked to the user');
  } finally {
    await browser.close();
  }
}

(async () => {
  try {
    await sleep(700);
    await run(chromium, 'desktop', { width: 1312, height: 1199 });
    await run(webkit, 'mobile', { width: 390, height: 844 });
    await runJwtClockRecovery(webkit);
    console.log('canonical V157+ permanent browser gate ok');
  } finally {
    server.kill('SIGTERM');
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
