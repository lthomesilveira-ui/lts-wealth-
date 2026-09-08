const { chromium, webkit } = require('playwright');
const { spawn } = require('child_process');
const { writeFileSync } = require('fs');

const port = process.env.LTS_CANONICAL_GATE_PORT || '4173';
const baseUrl = `http://127.0.0.1:${port}/canonical-app.html`;
const server = spawn('python3', ['-m', 'http.server', port, '--bind', '127.0.0.1'], { stdio: 'inherit' });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const containsText = (value, expected) => String(value).toLocaleLowerCase('pt-BR').includes(String(expected).toLocaleLowerCase('pt-BR'));
const receiptPath = 'canonical-definition-of-done-receipt.json';
const receipt = {
  schema_version: 1,
  contract: 'lts-canonical-definition-of-done-receipt-v1',
  generated_at: new Date().toISOString(),
  source_sha: process.env.GITHUB_SHA || null,
  gate_status: 'RUNNING',
  delivery_status: 'NOT_COMPLETE',
  suites: {},
  requirements: {},
  claim_boundary: {
    deterministic_fixture: 'IN_PROGRESS',
    authenticated_real_data: 'NOT_CLAIMED',
    authenticated_writes: 'NOT_CLAIMED',
    physical_iphone: 'NOT_CLAIMED',
    public_root: 'NOT_PROMOTED'
  }
};

function saveReceipt() {
  writeFileSync(receiptPath, JSON.stringify(receipt, null, 2) + '\n', 'utf8');
}

function finalizeReceipt() {
  receipt.gate_status = 'PASS';
  receipt.delivery_status = 'AUTOMATED_GATE_PASS_REAL_E2E_OPEN';
  receipt.claim_boundary.deterministic_fixture = 'PASS';
  receipt.requirements = {
    architecture: { status: 'PASS', evidence: 'single canonical frontend; zero iframes' },
    dashboard: { status: 'PASS_AUTOMATED', evidence: 'approved hierarchy and liquidity-first contract on desktop/mobile' },
    flow: { status: 'PASS_AUTOMATED', evidence: 'past/today/future layers, four account views and movement drilldown' },
    expenses: { status: 'PASS_AUTOMATED', evidence: 'single-owner month/year history, nature x context, unassigned semantics and item drilldown' },
    cards: { status: 'PASS_AUTOMATED', evidence: 'current/next invoice and certified historical coverage' },
    wealth: { status: 'PASS_AUTOMATED', evidence: 'RSU, CIPÓ, Volvo and debt/asset separation' },
    updates: { status: 'PASS_AUTOMATED', evidence: 'priority queue, server-search surface, classification and documents' },
    recurrences: { status: 'PASS_AUTOMATED', evidence: 'historical evidence never auto-creates facts' },
    commitments: { status: 'PASS_AUTOMATED', evidence: 'Dashboard and Flow-linked commitments' },
    simulations: { status: 'PASS_AUTOMATED_READ_ONLY', evidence: 'scenario calculation without fact mutation' },
    reconciliation: { status: 'PASS_AUTOMATED', evidence: 'R$ 0.00 acceptance rule and explicit review boundary' },
    reports: { status: 'PASS_AUTOMATED', evidence: 'executive JSON and recurrence CSV controls' },
    backup_restore: { status: 'PASS_CONTROLS_ONLY', evidence: 'checksum/stage/preview/confirmation controls; real apply remains open' },
    route_session_continuity: { status: 'PASS_AUTOMATED', evidence: 'deep link, refresh, pane restore, back/forward and safe JWT reset' },
    performance_ux: { status: 'PASS_AUTOMATED', evidence: 'bounded browser waits, no console/page errors, no horizontal overflow' },
    authenticated_real_data: { status: 'OPEN', evidence: 'not executed by fixture browser gate' },
    authenticated_write_lifecycles: { status: 'OPEN', evidence: 'financial writes remain disabled in fixture' },
    physical_iphone: { status: 'OPEN', evidence: 'not executed by CI WebKit' },
    public_root_promotion: { status: 'BLOCKED_USER_DECISION', evidence: 'index.html remains protected' }
  };
  saveReceipt();
}

saveReceipt();

function routeButton(page, route, mobile) {
  const root = mobile ? '.mobile-nav' : '.sidebar';
  return page.locator(`${root} [data-route="${route}"]:not([data-nav-alias])`);
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
  await openManagementPane(page, 'overview');
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
  await page.screenshot({ path: `canonical-management-planning-${label}.png`, fullPage: true });
  for (const required of ['Primeira insuficiência', 'Pior posição', 'FGTS', 'Fatos prevalecem sobre projeções']) {
    if (!containsText(text, required)) {
      const state = await page.evaluate(() => window.__LTS_CANONICAL_CAPABILITIES_STATUS);
      throw new Error(`${label}: planning management detail missing ${required}; state=${JSON.stringify(state)}; detail=${JSON.stringify(text.slice(0, 1000))}`);
    }
  }

  await openManagementPane(page, 'recurring');
  text = await page.locator('#managementDetail').innerText();
  for (const required of ['Séries recorrentes', 'Cobertas', 'Planejamento', 'Conciliação', 'Mensalidade exemplo']) {
    if (!containsText(text, required)) throw new Error(`${label}: recurring management detail missing ${required}`);
  }

  await openManagementPane(page, 'scenario');
  await page.locator('[data-mg-award]').first().check();
  await page.locator('#mgRunScenario').click();
  await page.waitForFunction(() => document.querySelector('#managementDetail')?.textContent?.includes('Valor selecionado'));
  text = await page.locator('#managementDetail').innerText();
  if (!containsText(text, 'read-only') || !containsText(text, 'Pior posição no cenário')) throw new Error(`${label}: read-only scenario contract`);

  await openManagementPane(page, 'reconciliation');
  text = await page.locator('#managementDetail').innerText();
  if (!containsText(text, 'diferença R$ 0,00') || !containsText(text, 'Documentos reconciliados')) throw new Error(`${label}: reconciliation contract`);

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
    if (!containsText(text, required)) throw new Error(`${label}: settings guardrail missing ${required}`);
  }
  await openManagementPane(page, 'overview');
}

async function assertDashboardContract(page, label, mobile) {
  const contract = await page.locator('#dashboard-view').getAttribute('data-dashboard-contract');
  const status = await page.evaluate(() => window.__LTS_CANONICAL_DASHBOARD_STATUS);
  if (contract !== 'reference-toolbar-signals-drilldowns-v1'
      || status?.ready !== true
      || status?.contract !== contract
      || status?.reference !== 'approved-1312x1199-liquidity-first') {
    throw new Error(`${label}: Dashboard fidelity status ${JSON.stringify({ contract, status })}`);
  }

  if (await page.locator('#dashboard-view [data-dashboard-reload]').count() !== 1) {
    throw new Error(`${label}: Dashboard Hoje control missing`);
  }
  if (await page.locator('#dashboard-view .kpi-signal').count() !== 5
      || await page.locator('#dashboard-view .kpi-evidence').count() !== 5) {
    throw new Error(`${label}: Dashboard evidence signals missing`);
  }
  const signals = await page.locator('#dashboard-view .kpi-signal').allTextContents();
  for (const expected of ['3 contas evidenciadas', 'D0', 'D+3', 'D+30', '4,9% vs mês anterior']) {
    if (!signals.some(value => containsText(value, expected))) {
      throw new Error(`${label}: Dashboard evidence signal missing ${expected}; signals=${JSON.stringify(signals)}`);
    }
  }
  if (await page.locator('#dashboard-view .bank-row[data-route="Fluxo Diário"]').count() !== 3) {
    throw new Error(`${label}: Dashboard bank drilldowns missing`);
  }
  for (const route of ['Fluxo Diário', 'Despesas', 'Patrimônio', 'Atualizações']) {
    if (await page.locator(`#dashboard-view [data-route="${route}"]`).count() < 1) {
      throw new Error(`${label}: Dashboard action missing ${route}`);
    }
  }
  if (!mobile) {
    const labels = await page.locator('.sidebar .nav > button > span').allTextContents();
    const expected = ['Dashboard', 'Fluxo Diário', 'Despesas', 'Receitas', 'Cartões', 'Patrimônio', 'Planejamento', 'Atualizações', 'Relatórios', 'Documentos', 'Configurações'];
    if (JSON.stringify(labels) !== JSON.stringify(expected)) {
      throw new Error(`${label}: reference navigation contract ${JSON.stringify(labels)}`);
    }
    const revenueAlias = page.locator('.sidebar [data-nav-alias="Receitas"]');
    if (await revenueAlias.getAttribute('data-route') !== 'Fluxo Diário') {
      throw new Error(`${label}: Receitas must resolve to the evidenced Flow`);
    }
  }

  const beforeReload = Number(status?.reload_count || 0);
  await page.locator('#dashboard-view [data-dashboard-reload]').click();
  await page.waitForFunction(expected => (
    window.__LTS_CANONICAL_DASHBOARD_STATUS?.reload_count === expected
      && document.querySelector('#dashboard-view')?.dataset.dashboardContract === 'reference-toolbar-signals-drilldowns-v1'
  ), beforeReload + 1);
  await waitProduct(page, 'Dashboard');

  await page.locator('#dashboard-view [data-mg-shortcut="planning"]').click();
  await page.waitForFunction(() => (
    document.querySelector('.page-title h1')?.textContent?.trim() === 'Atualizações'
      && window.__LTS_CANONICAL_CAPABILITIES_STATUS?.active === 'planning'
      && document.querySelector('#managementDetail')?.textContent?.includes('Primeira insuficiência')
  ));
  await openRoute(page, 'Dashboard', mobile);
  await waitProduct(page, 'Dashboard');
}

async function assertRouteContinuity(page, label, mobile) {
  await openRoute(page, 'Atualizações', mobile);
  await page.waitForFunction(() => (
    document.querySelector('.page-title h1')?.textContent?.trim() === 'Atualizações'
      && window.__LTS_CANONICAL_CAPABILITIES_STATUS?.loaded === true
  ));
  await openManagementPane(page, 'reports');
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForFunction(() => (
    window.__LTS_CANONICAL_STATUS?.ready === true
      && window.__LTS_CANONICAL_ROUTE_STATUS?.current === 'Atualizações'
      && window.__LTS_CANONICAL_CAPABILITIES_STATUS?.loaded === true
      && window.__LTS_CANONICAL_CAPABILITIES_STATUS?.active === 'reports'
  ));

  let continuity = await page.evaluate(() => ({
    route: window.__LTS_CANONICAL_ROUTE_STATUS,
    pane: window.__LTS_CANONICAL_CAPABILITIES_STATUS,
    title: document.querySelector('.page-title h1')?.textContent?.trim(),
    routeStore: sessionStorage.getItem('lts_canonical_route_v1'),
    paneStore: sessionStorage.getItem('lts_canonical_management_pane_v1')
  }));
  if (continuity.route?.contract !== 'canonical-route-session-continuity-v1'
      || continuity.route?.ready !== true
      || continuity.route?.current !== 'Atualizações'
      || continuity.title !== 'Atualizações'
      || continuity.routeStore !== 'Atualizações'
      || continuity.pane?.pane_contract !== 'session-persisted-management-pane-v1'
      || continuity.pane?.pane_persisted !== true
      || continuity.paneStore !== 'reports') {
    throw new Error(`${label}: route/pane refresh continuity ${JSON.stringify(continuity)}`);
  }

  await openRoute(page, 'Patrimônio', mobile);
  await waitProduct(page, 'Patrimônio');
  await page.goBack();
  await page.waitForFunction(() => (
    document.querySelector('.page-title h1')?.textContent?.trim() === 'Atualizações'
      && window.__LTS_CANONICAL_ROUTE_STATUS?.current === 'Atualizações'
      && window.__LTS_CANONICAL_CAPABILITIES_STATUS?.active === 'reports'
  ));
  await page.goForward();
  await waitProduct(page, 'Patrimônio');
  if ((await page.locator('.page-title h1').textContent())?.trim() !== 'Patrimônio') {
    throw new Error(`${label}: forward navigation did not restore Patrimônio`);
  }

  await page.goto(`${baseUrl}?fixture=1#${encodeURIComponent('Cartões')}`, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => window.__LTS_CANONICAL_STATUS?.ready === true);
  await waitProduct(page, 'Cartões');
  if (await page.evaluate(() => window.__LTS_CANONICAL_ROUTE_STATUS?.current) !== 'Cartões') {
    throw new Error(`${label}: direct deep link did not restore Cartões`);
  }

  await page.goto(`${baseUrl}?fixture=1#rota-invalida`, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => (
    window.__LTS_CANONICAL_STATUS?.ready === true
      && window.__LTS_CANONICAL_ROUTE_STATUS?.current === 'Dashboard'
      && document.querySelector('.page-title h1')?.textContent?.trim() === 'Dashboard'
  ));
  continuity = await page.evaluate(() => ({
    hash: location.hash,
    route: window.__LTS_CANONICAL_ROUTE_STATUS,
    title: document.querySelector('.page-title h1')?.textContent?.trim()
  }));
  if (decodeURIComponent(continuity.hash.slice(1)) !== 'Dashboard'
      || continuity.route?.current !== 'Dashboard'
      || continuity.title !== 'Dashboard') {
    throw new Error(`${label}: invalid route fallback ${JSON.stringify(continuity)}`);
  }

  return {
    refresh_route: 'Atualizações',
    restored_pane: 'reports',
    back_forward: true,
    direct_deep_link: 'Cartões',
    invalid_route_fallback: 'Dashboard'
  };
}

async function run(browserType, label, viewport) {
  const startedAt = Date.now();
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
    await assertDashboardContract(page, label, mobile);
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
    await page.waitForFunction(() => window.__LTS_CANONICAL_EXPENSE_STATUS?.ready === true);
    const expenseStatus = await page.evaluate(() => window.__LTS_CANONICAL_EXPENSE_STATUS);
    if (expenseStatus.owner !== 'canonical-app'
        || expenseStatus.contract !== 'single-owner-history-nature-context-v1'
        || expenseStatus.history_months < 3
        || expenseStatus.history_years < 3
        || expenseStatus.nature_rows < 1
        || expenseStatus.context_rows < 1
        || expenseStatus.errors.length) {
      throw new Error(`${label}: expense contract ${JSON.stringify(expenseStatus)}`);
    }
    let text = await page.locator('#expenses-view').innerText();
    for (const required of ['Quanto você gasta — e para quem é cada gasto.', 'Maior natureza', 'Maior contexto evidenciado', 'Cobertura de contexto', 'Variação mensal', 'Natureza × contexto', 'Natureza do gasto', 'Contexto / pessoa / centro de custo', 'Não atribuído · o que realmente significa', 'Mês a mês', 'Ano a ano', 'Cobertura do histórico']) {
      if (!text.includes(required)) throw new Error(`${label}: expense surface missing ${required}`);
    }
    await page.locator('[data-lens-kind="nature"]').first().click();
    if (!(await page.locator('.drill-card').innerText()).includes('Onde aparece')) throw new Error(`${label}: nature drilldown missing`);
    await page.locator('[data-lens-kind="context"]').first().click();
    if (!(await page.locator('.drill-card').innerText()).includes('Do que é composto')) throw new Error(`${label}: context drilldown missing`);
    await page.locator('[data-expense-month]').first().click();
    await page.waitForSelector('[data-expense-month-close]');
    text = await page.locator('.expense-month-detail').innerText();
    for (const required of ['Detalhe do mês', 'Moradia', 'Casa', 'Campo ausente continua ausente']) {
      if (!text.includes(required)) throw new Error(`${label}: expense month detail missing ${required}`);
    }
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

    const routeContinuity = await assertRouteContinuity(page, label, mobile);

    await page.goto(baseUrl, { waitUntil: 'domcontentloaded' });
    await page.waitForTimeout(800);
    if (await page.locator('#loginForm').count() !== 1) throw new Error(`${label}: real login missing`);
    if (await page.locator('#dashboard-view .kpi').count()) throw new Error(`${label}: fake financial UI unauthenticated`);
    if (await page.getByText('FIXTURE DE TESTE', { exact: true }).count()) throw new Error(`${label}: fixture badge leaked`);
    receipt.suites[label] = {
      status: 'PASS',
      engine: label === 'mobile' ? 'webkit' : 'chromium',
      viewport,
      duration_ms: Date.now() - startedAt,
      route_continuity: routeContinuity,
      coverage: ['Dashboard', 'Fluxo Diário', 'Despesas', 'Patrimônio', 'Cartões', 'Atualizações', 'Central de Gestão', 'truthful unauthenticated state']
    };
    saveReceipt();
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
    await page.goto(`${baseUrl}#${encodeURIComponent('Patrimônio')}`, { waitUntil: 'domcontentloaded' });
    await page.waitForSelector('#loginForm', { timeout: 12000 });
    const recovery = await page.evaluate(() => ({
      storedSession: localStorage.getItem('lts_supabase_session_v1'),
      status: window.__LTS_CANONICAL_SESSION_STATUS,
      route: window.__LTS_CANONICAL_ROUTE_STATUS,
      hash: location.hash,
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
    if (recovery.route?.contract !== 'canonical-route-session-continuity-v1'
        || recovery.route?.current !== 'Patrimônio'
        || decodeURIComponent(recovery.hash.slice(1)) !== 'Patrimônio') {
      throw new Error(`WebKit JWT recovery lost intended route ${JSON.stringify(recovery.route)}`);
    }
    receipt.suites.session_recovery = {
      status: 'PASS',
      engine: 'webkit',
      viewport: { width: 390, height: 844 },
      future_jwt_reset: true,
      raw_error_hidden: true,
      intended_route_preserved: 'Patrimônio'
    };
    saveReceipt();
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
    finalizeReceipt();
    console.log('canonical V157+ permanent browser gate ok');
  } catch (error) {
    receipt.gate_status = 'FAIL';
    receipt.delivery_status = 'BLOCKED_BY_AUTOMATED_GATE';
    receipt.failure = String(error?.message || error).replace(/Bearer\s+[^\s]+/gi, 'Bearer [redacted]');
    saveReceipt();
    throw error;
  } finally {
    server.kill('SIGTERM');
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
