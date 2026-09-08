const { chromium, webkit } = require('playwright');
const { spawn } = require('child_process');
const { writeFileSync } = require('fs');

const port = process.env.LTS_CANONICAL_GATE_PORT || '4173';
const baseUrl = `http://127.0.0.1:${port}/canonical-app.html`;
const server = spawn('python3', ['-m', 'http.server', port, '--bind', '127.0.0.1'], { stdio: 'inherit' });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const containsText = (value, expected) => String(value).toLocaleLowerCase('pt-BR').includes(String(expected).toLocaleLowerCase('pt-BR'));
const receiptPath = 'canonical-definition-of-done-receipt.json';
const localChromiumExecutable = process.env.LTS_CHROMIUM_EXECUTABLE || '';
const localChromiumOnly = process.env.LTS_LOCAL_CHROMIUM_ONLY === '1';
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

function launchOptions(browserType) {
  const options = { headless: true };
  if (browserType === chromium && localChromiumExecutable) options.executablePath = localChromiumExecutable;
  return options;
}

function finalizeReceipt() {
  receipt.gate_status = 'PASS';
  receipt.delivery_status = 'AUTOMATED_GATE_PASS_REAL_E2E_OPEN';
  receipt.claim_boundary.deterministic_fixture = 'PASS';
  receipt.requirements = {
    architecture: { status: 'PASS', evidence: 'single canonical frontend; zero iframes' },
    dashboard: { status: 'PASS_AUTOMATED', evidence: 'approved hierarchy, four current-liquidity quadrants, layered fact/base/RSU/FGTS chart semantics, documentary commitments and approved 1312x1199 desktop single-screen density' },
    flow: { status: 'PASS_AUTOMATED', evidence: 'V150 interaction parity plus V157 liquidity layers: four account views, five-day horizon, semantic movements, inline invoice, append-only split and preserved scroll' },
    expenses: { status: 'PASS_AUTOMATED', evidence: 'single-owner month/year history, nature x context, unassigned semantics and item drilldown' },
    cards: { status: 'PASS_AUTOMATED', evidence: 'current/next invoice and certified historical coverage' },
    wealth: { status: 'PASS_AUTOMATED', evidence: 'RSU, CIPÓ, Volvo and debt/asset separation' },
    updates: { status: 'PASS_AUTOMATED', evidence: 'V147/V150-compatible classification-first hierarchy, reviewed text input, liquidity, server-side search and collapsed secondary actions' },
    document_intake: { status: 'PASS_AUTOMATED_PREVIEW', evidence: 'guided type/entity/period association, private intake controls, fixture writer prohibition and no automatic financial posting' },
    document_review: { status: 'PASS_AUTOMATED_READ_ONLY', evidence: 'V149 association-versus-extraction comparison, bounded evidence preview, missing-link warning, no controls and no financial writer' },
    reviewed_input: { status: 'PASS_AUTOMATED_PREVIEW', evidence: 'V150 launch-by-text restored with editable review, mandatory fields, explicit confirmation and fixture write prohibition' },
    recurrences: { status: 'PASS_AUTOMATED', evidence: 'historical evidence never auto-creates facts' },
    commitments: { status: 'PASS_AUTOMATED', evidence: 'documented product commitments plus card due date; review tasks remain in Updates' },
    simulations: { status: 'PASS_AUTOMATED_READ_ONLY', evidence: 'scenario calculation without fact mutation' },
    reconciliation: { status: 'PASS_AUTOMATED', evidence: 'R$ 0.00 acceptance rule and explicit review boundary' },
    reports: { status: 'PASS_AUTOMATED', evidence: 'executive JSON and recurrence CSV controls' },
    backup_restore: { status: 'PASS_CONTROLS_ONLY', evidence: 'checksum/stage/preview/confirmation controls; real apply remains open' },
    route_session_continuity: { status: 'PASS_AUTOMATED', evidence: 'deep link, refresh, pane restore, back/forward and safe JWT reset' },
    performance_ux: { status: 'PASS_AUTOMATED', evidence: 'bounded browser waits, no console/page errors, no horizontal overflow and no desktop dashboard vertical overflow at 1312x1199' },
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

async function waitFlowRange(page, from, to) {
  await page.waitForFunction(({ from, to }) => {
    const status = window.__LTS_CANONICAL_FLOW_V157_STATUS;
    return status?.ready === true && status?.from === from && status?.to === to;
  }, { from, to });
}

async function expandFlowDay(page, day) {
  const button = page.locator(`[data-expand="${day}"]`);
  if (await button.count() !== 1) throw new Error(`Flow day ${day} missing`);
  if (await button.getAttribute('aria-expanded') !== 'true') await button.click();
  await page.waitForSelector(`#fv-${day} + .fv-detail`);
  return page.locator(`#fv-${day} + .fv-detail`);
}

async function assertFlowParity(page, label, mobile) {
  const status = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_V157_STATUS);
  if (status?.contract !== 'v150-validated-flow-plus-v157-liquidity-v1'
      || status?.split_action !== true
      || status?.invoice_drilldown !== true
      || status?.semantic_labels !== true
      || status?.scroll_preservation !== true) {
    throw new Error(`${label}: Flow parity status ${JSON.stringify(status)}`);
  }
  if (!(await page.locator('.fv-build').textContent()).includes('LTS v1.9')) throw new Error(`${label}: build marker missing`);
  if (await page.locator('#fvToday').count() !== 1) throw new Error(`${label}: dedicated Hoje action missing`);
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

  await page.locator('[data-preset="next5"]').click();
  await waitFlowRange(page, '2026-09-07', '2026-09-11');
  if (await page.locator('.fv-table tbody .fv-row').count() !== 5) throw new Error(`${label}: Próximos 5 dias must show five days`);

  if (!mobile) {
    await page.evaluate(() => { document.querySelector('.fv-scroll').scrollLeft = 360; });
    await expandFlowDay(page, '2026-09-07');
    await page.waitForFunction(() => Math.abs(document.querySelector('.fv-scroll').scrollLeft - 360) < 2);
  }

  let detail = await expandFlowDay(page, '2026-09-09');
  if (!(await detail.innerText()).includes('Movimentos do dia')) throw new Error(`${label}: Flow drilldown missing`);
  await detail.locator('[data-card-detail]').click();
  await page.waitForSelector('[data-invoice-contract="inline-card-settlement-v150"]');
  let invoice = page.locator('[data-invoice-contract="inline-card-settlement-v150"]');
  let text = await invoice.innerText();
  for (const required of ['Resumo da fatura', 'Fatura conciliada', 'Créditos', 'Caixa × detalhe', 'Acessar fatura completa']) {
    if (!text.includes(required)) throw new Error(`${label}: inline invoice missing ${required}`);
  }
  await invoice.locator('[data-card-full]').click();
  invoice = page.locator('[data-invoice-contract="inline-card-settlement-v150"]');
  if (!(await invoice.innerText()).includes('Fatura completa') || await invoice.locator('.fv-purchase').count() !== 2) {
    throw new Error(`${label}: full inline invoice contract`);
  }
  await page.screenshot({ path: `canonical-flow-invoice-${label}.png`, fullPage: true });
  await invoice.locator('[data-card-summary]').click();
  await page.locator('[data-card-close]').click();

  detail = await expandFlowDay(page, '2026-09-10');
  text = await detail.innerText();
  if (!text.includes('Transferência própria') || !text.includes('neutra no consolidado')) {
    throw new Error(`${label}: internal transfer semantics missing`);
  }

  await page.locator('[data-preset="next30"]').click();
  await waitFlowRange(page, '2026-09-07', '2026-10-06');
  detail = await expandFlowDay(page, '2026-09-12');
  text = await detail.innerText();
  if (!text.includes('Salário líquido') || !text.includes('Coopharma')) throw new Error(`${label}: net salary semantics missing`);

  detail = await expandFlowDay(page, '2026-09-15');
  await detail.locator('[data-event-actions]').click();
  await page.waitForSelector('#fvModalBg');
  const tabs = await page.locator('#fvModalBg [data-fv-mode]').allTextContents();
  if (JSON.stringify(tabs) !== JSON.stringify(['Editar', 'Duplicar', 'Dividir / substituir'])) {
    throw new Error(`${label}: projection action tabs ${JSON.stringify(tabs)}`);
  }
  await page.locator('#fvModalBg [data-fv-mode="split"]').click();
  if (await page.locator('#fvModalBg [data-fv-part]').count() !== 2) throw new Error(`${label}: split starts with two parts`);
  await page.locator('#fvModalBg [data-fv-part-add]').click();
  if (await page.locator('#fvModalBg [data-fv-part]').count() !== 3) throw new Error(`${label}: split add part failed`);
  await page.locator('#fvModalBg [data-fv-part-remove="2"]').click();
  if (await page.locator('#fvModalBg [data-fv-part]').count() !== 2) throw new Error(`${label}: split remove part failed`);
  await page.locator('#fvModalBg [data-fv-part-amount="0"]').fill('7000');
  await page.locator('#fvModalBg [data-fv-part-amount="1"]').fill('7000');
  const splitSum = (await page.locator('#fvModalBg .fv-split-sum').innerText()).replace(/\s+/g, ' ');
  if (!splitSum.includes('R$ 14.000,00')) {
    throw new Error(`${label}: split sum feedback not updated`);
  }
  await page.screenshot({ path: `canonical-flow-split-${label}.png`, fullPage: true });
  await page.locator('#fvModalBg [data-fv-save]').click();
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE?.action === 'split');
  const mutation = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE);
  if (mutation.writer_called !== false || mutation.payload?.parts?.length !== 2) {
    throw new Error(`${label}: fixture split write boundary ${JSON.stringify(mutation)}`);
  }

  await page.locator('[data-account="Itaú"]').click();
  if (await page.locator('.fv-table tbody .fv-row').count() < 1) throw new Error(`${label}: bank Flow switch failed`);
  if (mobile) {
    const width = await page.evaluate(() => ({
      scroll: document.documentElement.scrollWidth,
      client: document.documentElement.clientWidth
    }));
    if (width.scroll > width.client + 1) throw new Error(`${label}: Flow horizontal overflow ${JSON.stringify(width)}`);
  }
}

async function assertUpdatesContract(page, label) {
  const title = (await page.locator('.page-title h1').textContent())?.trim();
  if (title !== 'Atualizações') throw new Error(`${label}: updates route ${title}`);
  if (await page.locator('#updates-view').getAttribute('data-updates-contract') !== 'classification-first-guided-document-intake-v1') {
    throw new Error(`${label}: updates hierarchy contract missing`);
  }
  if (await page.locator('.class-row').count() < 3) throw new Error(`${label}: classification queue missing`);
  if (await page.locator('.class-save:not([disabled])').count() !== 0) {
    throw new Error(`${label}: fixture classification writer unexpectedly enabled`);
  }

  await page.waitForSelector('#reviewedInputCard');
  await page.waitForSelector('#liquidityMovementCard');
  await page.waitForSelector('#management-panel');
  const hierarchy = await page.evaluate(() => {
    const selectors = ['#classification-panel', '#reviewedInputCard', '#liquidityMovementCard', '.search-box', '#updatesOtherActions', '#management-panel'];
    const nodes = selectors.map(selector => document.querySelector(selector));
    return {
      present: nodes.map(Boolean),
      ordered: nodes.every((node, index) => index === nodes.length - 1 || Boolean(node?.compareDocumentPosition(nodes[index + 1]) & Node.DOCUMENT_POSITION_FOLLOWING)),
      otherOpen: document.querySelector('#updatesOtherActions')?.open === true
    };
  });
  if (hierarchy.present.some(value => !value) || hierarchy.ordered !== true || hierarchy.otherOpen !== false) {
    throw new Error(`${label}: classification-first hierarchy ${JSON.stringify(hierarchy)}`);
  }
  const recovery = await page.evaluate(() => window.__LTS_CANONICAL_RECOVERY_STATUS);
  if (recovery?.build !== 'LTS v1.15' || recovery?.updates_contract !== 4 || recovery?.document_review_contract !== 4 || recovery?.dashboard_density_contract !== 1) {
    throw new Error(`${label}: v1.15 recovery contract ${JSON.stringify(recovery)}`);
  }
  const inputStatus = await page.evaluate(() => window.__LTS_CANONICAL_REVIEWED_INPUT_STATUS);
  if (inputStatus?.ready !== true
      || inputStatus?.contract !== 'review-before-explicit-apply-v1'
      || inputStatus?.fixture !== true
      || inputStatus?.writer !== 'lts_browser_apply_reviewed_input_v1'
      || inputStatus?.writer_called !== false
      || inputStatus?.requires_explicit_confirmation !== true) {
    throw new Error(`${label}: reviewed input status ${JSON.stringify(inputStatus)}`);
  }
  const phrase = page.locator('#riPhrase');
  await phrase.fill('paguei R$ 850 de pediatra do Benjamin no Aeternum hoje');
  await page.locator('#riPreviewButton').click();
  await page.waitForSelector('#reviewedInputPreview');
  if (await page.locator('#riAmount').inputValue() !== '850') throw new Error(`${label}: reviewed input amount parser`);
  if (await page.locator('#riNature').inputValue() !== 'expense') throw new Error(`${label}: reviewed input nature parser`);
  if (await page.locator('#riCard').inputValue() !== 'Visa Aeternum') throw new Error(`${label}: reviewed input card parser`);
  if (await page.locator('#riCategory').inputValue() !== 'Saúde') throw new Error(`${label}: reviewed input category proposal`);
  if (await page.locator('#riCost').inputValue() !== 'Benjamin') throw new Error(`${label}: reviewed input context proposal`);
  if (await page.locator('#riApply').count() !== 0) throw new Error(`${label}: fixture reviewed-input writer unexpectedly enabled`);
  const reviewedText = await page.locator('#reviewedInputPreview').innerText();
  for (const required of ['Revise antes de aprovar', 'Nada foi gravado', 'nenhuma gravação é permitida']) {
    if (!containsText(reviewedText, required)) throw new Error(`${label}: reviewed input guard missing ${required}`);
  }
  const amountCases = [
    ['paguei 5 mil no Itaú hoje', '5000'],
    ['paguei R$5.000 no Itaú hoje', '5000'],
    ['paguei 5000 no Itaú hoje', '5000'],
    ['recebi 3k no Bradesco amanhã', '3000'],
    ['paguei R$1.250,50 no C6 ontem', '1250.5']
  ];
  for (const [sample, expected] of amountCases) {
    await phrase.fill(sample);
    await page.locator('#riPreviewButton').click();
    await page.waitForSelector('#reviewedInputPreview');
    if (await page.locator('#riAmount').inputValue() !== expected) {
      throw new Error(`${label}: reviewed input amount case ${sample}`);
    }
  }
  const finalInputStatus = await page.evaluate(() => window.__LTS_CANONICAL_REVIEWED_INPUT_STATUS);
  if (finalInputStatus?.preview !== true || finalInputStatus?.writer_called !== false || finalInputStatus?.write_accepted !== false) {
    throw new Error(`${label}: reviewed input fixture boundary ${JSON.stringify(finalInputStatus)}`);
  }

  const term = page.locator('#ledgerTerm');
  await term.fill('Mastercard');
  await page.waitForFunction(() => document.querySelector('#ledgerMeta')?.textContent?.includes('1 lançamento'));
  if (await page.locator('.search-result').count() !== 1) throw new Error(`${label}: transaction search result missing`);
  if (await page.locator('#ledgerExport').isDisabled()) throw new Error(`${label}: CSV export not enabled`);
  const otherActions = page.locator('#updatesOtherActions');
  await otherActions.locator('summary').click();
  await page.waitForFunction(() => document.querySelector('#updatesOtherActions')?.open === true);
  if (await page.locator('#documents-panel').count() !== 1) throw new Error(`${label}: documents area missing`);
  if (await page.locator('#documentType').count() !== 1 || await page.locator('#documentFile').count() !== 1 || await page.locator('#documentUploadButton').count() !== 1) {
    throw new Error(`${label}: guided document intake controls missing`);
  }
  if (!(await page.locator('#documentFile').isDisabled()) || !(await page.locator('#documentUploadButton').isDisabled())) {
    throw new Error(`${label}: fixture document writer unexpectedly enabled`);
  }
  await page.locator('#documentType').selectOption('bank_statement');
  await page.locator('#documentTarget').fill('Itaú');
  await page.locator('#documentCompetence').fill('2026-08');
  const documentStatus = await page.evaluate(() => window.__LTS_CANONICAL_DOCUMENT_INTAKE_STATUS);
  if (documentStatus?.ready !== true
      || documentStatus?.contract !== 'classification-first-guided-document-intake-v1'
      || documentStatus?.fixture !== true
      || documentStatus?.association_valid !== true
      || documentStatus?.writer !== 'lts_browser_register_document_v2'
      || documentStatus?.storage_bucket !== 'lts-documents'
      || documentStatus?.writer_called !== false
      || documentStatus?.write_accepted !== false
      || documentStatus?.auto_posts_financial_facts !== false
      || documentStatus?.upload_enabled !== false) {
    throw new Error(`${label}: guided document intake status ${JSON.stringify(documentStatus)}`);
  }
  const documentGuard = await page.locator('#documents-panel').innerText();
  for (const required of ['Associação antes do upload', 'entra em revisão', 'não cria lançamento financeiro automaticamente', 'upload e registro estão bloqueados']) {
    if (!containsText(documentGuard, required)) throw new Error(`${label}: document intake guard missing ${required}`);
  }
  const review = page.locator('[data-document-review-contract="v149-evidence-review-readonly-canonical-v1"]');
  if (await review.count() !== 1 || await review.getAttribute('data-write-allowed') !== 'false') {
    throw new Error(`${label}: document review contract missing or writable`);
  }
  const reviewStatus = await page.evaluate(() => window.__LTS_CANONICAL_DOCUMENT_REVIEW_STATUS);
  if (reviewStatus?.ready !== true
      || reviewStatus?.contract !== 'v149-evidence-review-readonly-canonical-v1'
      || reviewStatus?.queue_documents !== 2
      || reviewStatus?.shown_documents !== 2
      || reviewStatus?.evidence_rows < 12
      || reviewStatus?.write_allowed !== false
      || reviewStatus?.writer_called !== false
      || reviewStatus?.rpc_calls !== 0
      || reviewStatus?.fixture !== true) {
    throw new Error(`${label}: document review status ${JSON.stringify(reviewStatus)}`);
  }
  if (await review.locator('button,input,select,textarea').count() !== 0 || await review.locator('.doc-review-item').count() !== 2) {
    throw new Error(`${label}: document review must be read-only with two fixture cases`);
  }
  const reviewText = await review.innerText();
  for (const required of ['Vínculo informado por você', 'Leitura extraída do arquivo', 'Itaú', '2026-09', 'Somente leitura', 'não aprova', 'não reconcilia', 'não classifica', 'não grava fatos financeiros', 'compromisso/financiamento', 'data da posição']) {
    if (!containsText(reviewText, required)) throw new Error(`${label}: document review evidence missing ${required}`);
  }
  const documentAnchor = page.locator('.sidebar [data-anchor="documents-panel"]');
  if (await documentAnchor.isVisible()) {
    await otherActions.evaluate(node => { node.open = false; });
    await documentAnchor.click();
    await page.waitForFunction(() => document.querySelector('#updatesOtherActions')?.open === true);
  }

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
  const densityContract = await page.locator('#dashboard-view').getAttribute('data-dashboard-density-contract');
  const status = await page.evaluate(() => window.__LTS_CANONICAL_DASHBOARD_STATUS);
  if (contract !== 'reference-layered-liquidity-commitments-v3'
      || densityContract !== 'approved-1312x1199-single-screen-v1'
      || status?.ready !== true
      || status?.contract !== contract
      || status?.reference !== 'approved-1312x1199-liquidity-first'
      || status?.density_contract !== densityContract
      || status?.projection_contract !== 'fact-before-asof-projection-after-asof-v1'
      || status?.liquidity_layer_contract !== 'current-base-scheduled-rsu-restricted-fgts-v1'
      || status?.current_anchor_source !== 'cockpit-liquidity-through-d3'
      || status?.commitment_source !== 'product-commitments-plus-card-due'
      || status?.observed_points !== 1
      || status?.projected_points !== 5
      || status?.conditional_points !== 5
      || status?.restricted_points !== 5
      || status?.commitment_rows !== 3
      || status?.update_rows !== 3) {
    throw new Error(`${label}: Dashboard fidelity status ${JSON.stringify({ contract, densityContract, status })}`);
  }

  const charts = page.locator('#dashboard-view [data-liquidity-chart="layered-fact-projection-v2"]');
  if (await charts.count() !== 2) throw new Error(`${label}: layered liquidity charts missing`);
  for (const chart of await charts.all()) {
    if (await chart.getAttribute('data-observed-points') !== '1'
        || await chart.getAttribute('data-projected-points') !== '5'
        || await chart.getAttribute('data-conditional-points') !== '5'
        || await chart.getAttribute('data-restricted-points') !== '5'
        || await chart.locator('.series.projected.base').count() !== 1
        || await chart.locator('.series.conditional').count() !== 1
        || await chart.locator('.series.restricted').count() !== 1
        || await chart.locator('.point.base.observed').count() !== 1
        || await chart.locator('.point.base.projected').count() !== 5
        || await chart.locator('.point.conditional').count() !== 5
        || await chart.locator('.point.restricted').count() !== 5) {
      throw new Error(`${label}: layered liquidity visual semantics missing`);
    }
  }
  const legends = page.locator('#dashboard-view .liquidity-legend');
  if (await legends.count() !== 2) throw new Error(`${label}: layered liquidity legends missing`);
  for (const legend of await legends.all()) {
    const legendText = await legend.innerText();
    for (const expected of ['Posição atual', 'Base operacional', 'Vestings programados', 'FGTS documental D+30']) {
      if (!containsText(legendText, expected)) throw new Error(`${label}: liquidity legend missing ${expected}`);
    }
  }
  const layerValues = await page.locator('#dashboard-view .liquidity-layer-values').innerText();
  for (const expected of ['Contas', 'D0/D1', 'RSUs vested', 'FGTS restrito']) {
    if (!containsText(layerValues, expected)) throw new Error(`${label}: current liquidity composition missing ${expected}`);
  }
  const liquidityPanelBox = await page.locator('#dashboard-view .grid-main > .panel').first().boundingBox();
  if (!liquidityPanelBox || liquidityPanelBox.height > (mobile ? 410 : 315)) {
    throw new Error(`${label}: liquidity panel height regression ${JSON.stringify(liquidityPanelBox)}`);
  }
  if (!mobile) {
    const desktopFit = await page.evaluate(() => ({
      scrollHeight: document.documentElement.scrollHeight,
      viewportHeight: window.innerHeight,
      dashboardBottom: Math.ceil(document.querySelector('#dashboard-view')?.getBoundingClientRect().bottom || 0)
    }));
    if (desktopFit.scrollHeight > desktopFit.viewportHeight || desktopFit.dashboardBottom > desktopFit.viewportHeight) {
      throw new Error(`${label}: approved 1312x1199 single-screen density regression ${JSON.stringify(desktopFit)}`);
    }
  }
  const commitmentText = await page.locator('#dashboard-view .commit-list').innerText();
  for (const expected of ['Próxima fatura', 'Parcela contratual', 'Compromisso documentado']) {
    if (!containsText(commitmentText, expected)) throw new Error(`${label}: documentary commitment missing ${expected}`);
  }
  for (const reviewTask of ['Revisar 5 lançamentos sem categoria', 'Confirmar despesas de cartão', 'Revisar planejamento 2027']) {
    if (containsText(commitmentText, reviewTask)) throw new Error(`${label}: review task leaked into commitments: ${reviewTask}`);
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
      && document.querySelector('#dashboard-view')?.dataset.dashboardContract === 'reference-layered-liquidity-commitments-v3'
  ), beforeReload + 1);
  await waitProduct(page, 'Dashboard');

  const commitmentCard = page.locator('#dashboard-view .panel').filter({ hasText: 'Próximos Compromissos' });
  const commitmentAction = commitmentCard.locator('.panel-title [data-route="Fluxo Diário"]');
  if (await commitmentAction.count() !== 1) throw new Error(`${label}: commitment Flow action missing`);
  await commitmentAction.click();
  await page.waitForTimeout(350);
  const commitmentRoute = await page.evaluate(() => ({
    hash: decodeURIComponent(location.hash.slice(1)),
    title: document.querySelector('.page-title h1')?.textContent?.trim(),
    route: window.__LTS_CANONICAL_ROUTE_STATUS?.current,
    product: window.__LTS_CANONICAL_PRODUCT_V157_STATUS?.route
  }));
  if (commitmentRoute.hash !== 'Fluxo Diário' || commitmentRoute.title !== 'Fluxo Diário') {
    throw new Error(`${label}: commitment Flow action failed ${JSON.stringify(commitmentRoute)}`);
  }
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_V157_STATUS?.ready === true);
  await openRoute(page, 'Dashboard', mobile);
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
  try {
    await page.waitForFunction(() => (
      document.querySelector('.pv-head h1')?.textContent?.trim() === 'Patrimônio'
        && window.__LTS_CANONICAL_ROUTE_STATUS?.current === 'Patrimônio'
        && window.__LTS_CANONICAL_PRODUCT_V157_STATUS?.route === 'Patrimônio'
    ), null, { timeout: 8000 });
  } catch {
    const forward = await page.evaluate(() => ({
      href: location.href,
      title: document.querySelector('.pv-head h1, .page-title h1')?.textContent?.trim() || null,
      route: window.__LTS_CANONICAL_ROUTE_STATUS || null,
      product: window.__LTS_CANONICAL_PRODUCT_V157_STATUS || null,
      body: document.body.innerText.slice(0, 500)
    }));
    throw new Error(`${label}: forward navigation did not restore Patrimônio ${JSON.stringify(forward)}`);
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
  const browser = await browserType.launch(launchOptions(browserType));
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
        && status?.capabilities_loaded === true
        && status?.reviewed_input_loaded === true;
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
    await assertFlowParity(page, label, mobile);
    await page.screenshot({ path: `canonical-flow-${label}.png`, fullPage: true });

    await openRoute(page, 'Despesas', mobile);
    await page.waitForFunction(() => window.__LTS_CANONICAL_EXPENSE_STATUS?.ready === true);
    await page.waitForSelector('#expenses-view .expense-insights', { state: 'visible' });
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
    const insightLabels = await page.locator('#expenses-view .expense-insights span').allTextContents();
    for (const required of ['Maior natureza', 'Maior contexto evidenciado', 'Cobertura de contexto', 'Variação mensal']) {
      if (!insightLabels.includes(required)) throw new Error(`${label}: expense insight missing ${required}; labels=${JSON.stringify(insightLabels)}`);
    }
    let text = await page.locator('#expenses-view').textContent();
    for (const required of ['Quanto você gasta — e para quem é cada gasto.', 'Natureza × contexto', 'Natureza do gasto', 'Contexto / pessoa / centro de custo', 'Não atribuído · o que realmente significa', 'Mês a mês', 'Ano a ano', 'Cobertura do histórico']) {
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
      engine: browserType.name(),
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
  const browser = await browserType.launch(launchOptions(browserType));
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
      engine: browserType.name(),
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
    const mobileEngine = localChromiumOnly ? chromium : webkit;
    await run(mobileEngine, 'mobile', { width: 390, height: 844 });
    await runJwtClockRecovery(mobileEngine);
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
