const { chromium, webkit } = require('playwright');
const { spawn } = require('child_process');
const { writeFileSync } = require('fs');

const port = process.env.LTS_CANONICAL_GATE_PORT || '4173';
const baseUrl = `http://127.0.0.1:${port}/canonical-app.html`;
const server = spawn('python3', ['-m', 'http.server', port, '--bind', '127.0.0.1'], { stdio: 'inherit' });
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const containsText = (value, expected) => String(value).toLocaleLowerCase('pt-BR').includes(String(expected).toLocaleLowerCase('pt-BR'));
async function assertNoTechnicalVersionLeak(page, label, route) {
  const surface = await page.locator('body').innerText();
  const leak = surface.match(/\b(?:LTS|CANONICAL|WIP35)[ \t]+v?\d+(?:\.\d+)*/i);
  if (leak) throw new Error(`${label}: ${route} exposes internal version ${leak[0]}`);
  if (await page.locator('.fv-build,.pv-build').count()) {
    throw new Error(`${label}: ${route} exposes a technical build badge`);
  }
}
async function assertUxClosure(page, label, mobile) {
  await page.waitForFunction(() => window.__LTS_CANONICAL_UX_STATUS?.ready === true);
  const state = await page.evaluate(({ mobile }) => {
    const root = mobile ? '.mobile-nav' : '.sidebar';
    const active = document.querySelector(`${root} [data-route].active`);
    const authMessage = window.__LTS_SAFE_USER_ERROR?.(new Error('JWT issued at future'), 'Falha genérica', 'gate-auth');
    const genericMessage = window.__LTS_SAFE_USER_ERROR?.(new Error('PGRST technical detail 404'), 'Não foi possível concluir agora.', 'gate-generic');
    const navFont = mobile ? Number.parseFloat(getComputedStyle(document.querySelector('.mobile-nav button')).fontSize) : null;
    return {
      contract: window.__LTS_CANONICAL_UX_STATUS?.contract,
      appContract: window.__LTS_CANONICAL_STATUS?.ux_closure_contract,
      recoveryContract: window.__LTS_CANONICAL_RECOVERY_STATUS?.ux_closure_contract,
      activeCurrent: active?.getAttribute('aria-current'),
      authMessage,
      genericMessage,
      diagnosticRecorded: Array.isArray(window.__LTS_CANONICAL_DIAGNOSTICS) && window.__LTS_CANONICAL_DIAGNOSTICS.length >= 2,
      navFont,
      body: document.body.innerText
    };
  }, { mobile });
  if (state.contract !== 'safe-errors-accessible-controls-readable-mobile-v1'
      || state.appContract !== state.contract
      || state.recoveryContract !== state.contract) {
    throw new Error(`${label}: UX closure contract ${JSON.stringify(state)}`);
  }
  if (state.activeCurrent !== 'page') throw new Error(`${label}: active navigation lacks aria-current`);
  if (state.authMessage !== 'Sua sessão precisa ser renovada. Entre novamente.' || state.authMessage.includes('JWT')) {
    throw new Error(`${label}: authentication error is not safely translated ${state.authMessage}`);
  }
  if (state.genericMessage !== 'Não foi possível concluir agora.' || !state.diagnosticRecorded) {
    throw new Error(`${label}: safe diagnostic boundary ${JSON.stringify(state)}`);
  }
  if (/PGRST technical detail 404|JWT issued at future/.test(state.body)) throw new Error(`${label}: raw technical error reached the UI`);
  if (mobile && state.navFont < 8) throw new Error(`${label}: mobile navigation text below readability floor ${state.navFont}`);
}
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
    dashboard: { status: 'PASS_AUTOMATED', evidence: 'approved hierarchy, four current-liquidity quadrants, layered fact/base/RSU/FGTS chart semantics, V151 first-negative versus management-point decision cue, documentary commitments, approved 1312x1199 single-screen density and responsive readability profiles' },
    flow: { status: 'PASS_AUTOMATED', evidence: 'V150 interaction parity plus V157 liquidity layers: compact historical rows, expandable movements, mobile progressive disclosure, open/closed invoice semantics, edit/postpone/duplicate/split/cancel lifecycle and preserved scroll' },
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
    performance_ux: { status: 'PASS_AUTOMATED', evidence: 'bounded browser waits, no console/page errors, no horizontal overflow, no desktop dashboard vertical overflow at 1312x1199, readable 1366x900/1024x900 density, safe user errors, accessible control states, visible focus and readable mobile controls' },
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
      || status?.build !== 'LTS v1.23'
      || status?.historical_opening_contract !== 'historical-opening-from-close-and-net-v1'
      || status?.historical_collapse_contract !== 'historical-closed-date-label-close-only-v1'
      || status?.action_contract !== 'projection-edit-postpone-duplicate-split-cancel-v1'
      || status?.today_marker_contract !== 'today-marker-without-row-band-v1'
      || status?.future_horizon_contract !== 'future-through-2029-plus-d30-v1'
      || status?.daily_use_contract !== 'mobile-layer-disclosure-open-closed-invoice-actions-v1'
      || status?.edit_action !== true
      || status?.postpone_action !== true
      || status?.duplicate_action !== true
      || status?.split_action !== true
      || status?.cancel_action !== true
      || status?.invoice_drilldown !== true
      || status?.open_invoice_cycle !== true
      || status?.mobile_liquidity_disclosure !== true
      || status?.semantic_labels !== true
      || status?.scroll_preservation !== true) {
    throw new Error(`${label}: Flow parity status ${JSON.stringify(status)}`);
  }
  if (await page.locator('.fv-build').count()) throw new Error(`${label}: technical Flow build marker leaked`);
  if (await page.locator('#fvToday').count() !== 1) throw new Error(`${label}: dedicated Hoje action missing`);
  if (await page.locator('[data-account]').count() !== 4) throw new Error(`${label}: four-bank tabs missing`);
  if (await page.locator('[data-preset]').count() !== 9) throw new Error(`${label}: period presets missing or duplicated`);
  if (await page.locator('[data-preset="today"]').count()) throw new Error(`${label}: duplicate Hoje preset returned`);
  if (!mobile && await page.locator('.fv-table th').count() !== 14) throw new Error(`${label}: consolidated Flow columns`);
  if (await page.locator('.fv').getAttribute('data-daily-use-contract') !== 'mobile-layer-disclosure-open-closed-invoice-actions-v1') {
    throw new Error(`${label}: daily-use Flow contract missing`);
  }

  // Mobile liquidity layers intentionally start collapsed; textContent keeps the
  // semantic contract test independent from their visual disclosure state.
  const flowText = (await page.locator('.fv').textContent()).toLowerCase();
  for (const forbidden of ['baseline funcional', 'fix86', 'legacy', 'lts v1.', 'canonical v', 'wip35']) {
    if (flowText.includes(forbidden)) throw new Error(`${label}: technical text leaked ${forbidden}`);
  }
  for (const required of ['histórico / período', 'rsus futuras', 'cash awards futuros']) {
    if (!flowText.includes(required)) throw new Error(`${label}: Flow layer missing ${required}`);
  }

  await page.locator('[data-preset="next5"]').click();
  await waitFlowRange(page, '2026-09-07', '2026-09-11');
  if (await page.locator('.fv-table tbody .fv-row').count() !== 5) throw new Error(`${label}: Próximos 5 dias must show five days`);
  if (await page.locator('#fv-2026-09-07 .fv-today').count() !== 1) throw new Error(`${label}: discrete Hoje marker missing`);
  if (mobile) {
    const toggles = page.locator('.fv-layer-toggle');
    if (await toggles.count() !== 5 || await page.locator('.fv-layers.open').count()) {
      throw new Error(`${label}: mobile liquidity layers must start collapsed`);
    }
    const todayToggle = page.locator('#fv-2026-09-07 [data-layer-toggle="2026-09-07"]');
    await todayToggle.click();
    const layerState = {
      expanded: await todayToggle.getAttribute('aria-expanded'),
      values: await page.locator('#fv-layers-2026-09-07.open > div').count(),
      text: (await page.locator('#fv-layers-2026-09-07').textContent()).toLowerCase()
    };
    if (layerState.expanded !== 'true'
        || layerState.values !== 9
        || !layerState.text.includes('posição econômica total')) {
      throw new Error(`${label}: mobile liquidity disclosure failed ${JSON.stringify(layerState)}`);
    }
    await todayToggle.click();
    if (await todayToggle.getAttribute('aria-expanded') !== 'false' || await page.locator('.fv-layers.open').count()) {
      throw new Error(`${label}: mobile liquidity disclosure did not collapse`);
    }
  }
  if (!mobile) {
    const todayBackgrounds = await page.locator('#fv-2026-09-07 > td').evaluateAll(cells => cells.map(cell => getComputedStyle(cell).backgroundColor));
    const rejectedHojeBand = todayBackgrounds.filter(color => color === 'rgb(255, 250, 240)' || color === 'rgba(255, 250, 240, 1)');
    if (rejectedHojeBand.length) {
      throw new Error(`${label}: rejected full-row Hoje band returned ${JSON.stringify(todayBackgrounds)}`);
    }
  }

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
  if (await invoice.getAttribute('data-invoice-cycle') !== 'closed') throw new Error(`${label}: closed invoice state missing`);
  for (const required of ['Resumo da fatura', 'Fatura fechada', 'Fatura conciliada', 'Créditos', 'Caixa × detalhe', 'Acessar fatura completa']) {
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

  detail = await expandFlowDay(page, '2026-09-11');
  await detail.locator('[data-card-detail]').click();
  await page.waitForSelector('[data-invoice-cycle="open"]');
  invoice = page.locator('[data-invoice-cycle="open"]');
  text = await invoice.innerText();
  for (const required of ['Fatura aberta', 'Valor atual no Fluxo', 'Após fechamento', 'só consolidam em Despesas após o fechamento']) {
    if (!text.includes(required)) throw new Error(`${label}: open invoice semantics missing ${required}`);
  }
  if (await invoice.locator('.fv-purchase').count() || await invoice.locator('[data-card-full]').count()) {
    throw new Error(`${label}: open invoice exposed unclosed purchase detail`);
  }
  await page.screenshot({ path: `canonical-flow-open-invoice-${label}.png`, fullPage: true });
  await invoice.locator('[data-card-close]').click();

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
  const quickActions = await detail.locator('[data-event-action]').allTextContents();
  if (JSON.stringify(quickActions) !== JSON.stringify(['Editar', 'Postergar', 'Duplicar', 'Dividir'])) {
    throw new Error(`${label}: projection quick actions ${JSON.stringify(quickActions)}`);
  }
  await detail.locator('[data-event-action="edit"]').click();
  await page.waitForSelector('#fvModalBg');
  const tabs = await page.locator('#fvModalBg [data-fv-mode]').allTextContents();
  if (JSON.stringify(tabs) !== JSON.stringify(['Editar', 'Postergar', 'Duplicar', 'Dividir / substituir'])) {
    throw new Error(`${label}: projection action tabs ${JSON.stringify(tabs)}`);
  }
  const dialog = page.locator('#fvModalBg [role="dialog"]');
  if (await dialog.getAttribute('aria-labelledby') !== 'fvModalTitle'
      || await dialog.getAttribute('aria-describedby') !== 'fvModalDesc'
      || await page.locator('#fvModalBg [data-fv-mode="edit"]').getAttribute('aria-selected') !== 'true') {
    throw new Error(`${label}: accessible projection editor contract`);
  }
  await page.locator('#fvModalBg #fvEditAmount').fill('0');
  await page.locator('#fvModalBg [data-fv-save]').click();
  if (!(await page.locator('#fvEditorError').innerText()).includes('Preencha data') || await page.locator('#fvModalBg').count() !== 1) {
    throw new Error(`${label}: inline editor validation missing`);
  }
  await page.locator('#fvModalBg #fvEditDate').fill('2026-09-17');
  await page.locator('#fvModalBg #fvEditAmount').fill('13500');
  await page.locator('#fvModalBg #fvEditDesc').fill('Condomínio ajustado');
  await page.locator('#fvModalBg #fvEditAccount').selectOption({ label: 'Bradesco' });
  await page.locator('#fvModalBg [data-fv-save]').click();
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE?.intent === 'edit');
  const editMutation = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE);
  if (editMutation.action !== 'edit' || editMutation.writer_called !== false
      || editMutation.payload?.event_date !== '2026-09-17'
      || editMutation.payload?.amount !== 13500
      || editMutation.payload?.description !== 'Condomínio ajustado'
      || editMutation.payload?.account !== 'Bradesco') {
    throw new Error(`${label}: fixture edit boundary ${JSON.stringify(editMutation)}`);
  }

  await detail.locator('[data-event-action="postpone"]').click();
  await page.waitForSelector('#fvModalBg [data-fv-mode="postpone"].active');
  if (!(await page.locator('#fvModalBg .fv-editor-hint').innerText()).includes('Somente a data prevista')) {
    throw new Error(`${label}: postpone-specific form missing`);
  }
  await page.locator('#fvModalBg #fvEditDate').fill('2026-09-16');
  await page.locator('#fvModalBg [data-fv-save]').click();
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE?.intent === 'postpone');
  const postponeMutation = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE);
  if (postponeMutation.action !== 'edit' || postponeMutation.writer_called !== false || postponeMutation.payload?.event_date !== '2026-09-16') {
    throw new Error(`${label}: fixture postpone write boundary ${JSON.stringify(postponeMutation)}`);
  }

  await detail.locator('[data-event-action="duplicate"]').click();
  await page.waitForSelector('#fvModalBg [data-fv-mode="duplicate"].active');
  if (await page.locator('#fvModalBg [data-fv-cancel]').count()) throw new Error(`${label}: duplicate must not cancel the source`);
  await page.locator('#fvModalBg #fvEditDate').fill('2026-09-22');
  await page.locator('#fvModalBg #fvEditDesc').evaluate((field, value) => {
    field.value = value;
    field.dispatchEvent(new Event('input', { bubbles: true }));
  }, 'Condomínio duplicado');
  await page.locator('#fvModalBg [data-fv-save]').click();
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE?.intent === 'duplicate');
  const duplicateMutation = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE);
  if (duplicateMutation.action !== 'duplicate' || duplicateMutation.writer_called !== false
      || duplicateMutation.payload?.event_date !== '2026-09-22'
      || duplicateMutation.payload?.description !== 'Condomínio duplicado') {
    throw new Error(`${label}: fixture duplicate boundary ${JSON.stringify(duplicateMutation)}`);
  }

  await detail.locator('[data-event-action="split"]').click();
  await page.waitForSelector('#fvModalBg [data-fv-mode="split"].active');
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

  await detail.locator('[data-event-action="edit"]').click();
  await page.waitForSelector('#fvModalBg');
  page.once('dialog', async confirmation => confirmation.accept());
  await page.locator('#fvModalBg [data-fv-cancel]').click();
  await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE?.intent === 'cancel');
  const cancelMutation = await page.evaluate(() => window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURE);
  if (cancelMutation.action !== 'cancel' || cancelMutation.writer_called !== false) {
    throw new Error(`${label}: fixture cancel boundary ${JSON.stringify(cancelMutation)}`);
  }

  const mutationIntents = await page.evaluate(() => (window.__LTS_CANONICAL_FLOW_MUTATION_FIXTURES || []).map(x => x.intent));
  if (JSON.stringify(mutationIntents) !== JSON.stringify(['edit', 'postpone', 'duplicate', 'split', 'cancel'])) {
    throw new Error(`${label}: complete append-only action lifecycle ${JSON.stringify(mutationIntents)}`);
  }

  await detail.locator('[data-event-action="edit"]').click();
  await page.waitForSelector('#fvModalBg');
  await page.keyboard.press('Escape');
  await page.waitForSelector('#fvModalBg', { state: 'detached' });
  await page.waitForFunction(() => document.activeElement?.getAttribute('data-event-action') === 'edit');
  if (await page.evaluate(() => document.activeElement?.getAttribute('data-event-action')) !== 'edit') {
    throw new Error(`${label}: projection editor did not restore focus`);
  }

  await page.locator('#fvFrom').fill('2026-01-01');
  await page.locator('#fvTo').fill('2026-01-01');
  await page.locator('#fvApply').click();
  await waitFlowRange(page, '2026-01-01', '2026-01-01');
  const historicalClosed = page.locator('#fv-2026-01-01');
  const closedCells = (await historicalClosed.locator(':scope > td').allTextContents()).map(value => value.replace(/\s+/g, ' ').trim());
  if (await historicalClosed.getAttribute('data-history-state') !== 'closed'
      || !closedCells[0]?.includes('01/01/2026')
      || !closedCells[0]?.includes('Histórico')
      || closedCells[1] !== ''
      || closedCells[2] !== ''
      || closedCells[3] !== ''
      || !closedCells[4]?.includes('R$ 15.194,43')
      || closedCells.slice(5).some(Boolean)) {
    throw new Error(`${label}: compact historical row regression ${JSON.stringify(closedCells)}`);
  }
  const historicalDetail = await expandFlowDay(page, '2026-01-01');
  const yearBoundaryCells = (await page.locator('#fv-2026-01-01 > td').allTextContents()).map(value => value.replace(/\s+/g, ' ').trim());
  if (await page.locator('#fv-2026-01-01').getAttribute('data-history-state') !== 'open'
      || !yearBoundaryCells[1]?.includes('R$ 15.794,43')
      || !yearBoundaryCells[3]?.includes('R$ 600,00')
      || !yearBoundaryCells[4]?.includes('R$ 15.194,43')
      || !(await historicalDetail.innerText()).includes('Histórico / movimentos')
      || !(await historicalDetail.innerText()).includes('Fato histórico protegido')
      || await historicalDetail.locator('[data-event-action]').count()) {
    throw new Error(`${label}: expanded historical detail regression ${JSON.stringify(yearBoundaryCells.slice(0, 5))}`);
  }

  await page.locator('#fvFrom').fill('2029-12-31');
  await page.locator('#fvTo').fill('2029-12-31');
  await page.locator('#fvApply').click();
  await waitFlowRange(page, '2029-12-31', '2029-12-31');
  if (await page.locator('#fv-2029-12-31').count() !== 1) throw new Error(`${label}: 31/12/2029 horizon missing`);

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
  if (recovery?.build !== 'LTS v1.24' || recovery?.updates_contract !== 4 || recovery?.document_review_contract !== 4 || recovery?.dashboard_density_contract !== 1 || recovery?.planning_decision_contract !== 1 || recovery?.dashboard_visual_contract !== 'executive-cockpit-readable-density-v1' || recovery?.dashboard_responsive_contract !== 'executive-readable-breakpoints-v1' || recovery?.product_language_contract !== 'user-facing-product-language-v1' || recovery?.ux_closure_contract !== 'safe-errors-accessible-controls-readable-mobile-v1') {
    throw new Error(`${label}: v1.19 recovery contract ${JSON.stringify(recovery)}`);
  }
  const reportsTab = page.locator('[data-mg-pane="reports"]');
  await reportsTab.click();
  await page.waitForSelector('[data-report-contract="evidence-backed-executive-report-v1"]');
  const reportsStatus = await page.evaluate(() => window.__LTS_CANONICAL_CAPABILITIES_STATUS);
  if (reportsStatus?.build !== 'LTS v1.21'
      || reportsStatus?.reports_contract !== 'evidence-backed-executive-report-v1'
      || reportsStatus?.contracts?.reports_executive !== true) {
    throw new Error(`${label}: executive reports status ${JSON.stringify(reportsStatus)}`);
  }
  const reportText = await page.locator('[data-report-contract="evidence-backed-executive-report-v1"]').innerText();
  for (const required of ['Relatório executivo', 'Hoje e curto prazo', 'Caixa projetado', 'Evolução das despesas', 'Patrimônio e compromissos', 'Qualidade, controle e rastreabilidade']) {
    if (!containsText(reportText, required)) throw new Error(`${label}: executive report section missing ${required}`);
  }
  if (await page.locator('.mg-report-bar').count() < 3) throw new Error(`${label}: expense history chart missing`);
  if (await page.locator('.mg-report-link').count() !== 4) throw new Error(`${label}: report drill-down navigation incomplete`);
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
  if (recovery?.capabilities_loaded !== true || recovery?.capability_contract !== 12) {
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

async function assertDashboardReadability(page, label, profile) {
  const metrics = await page.evaluate(() => {
    const node = selector => document.querySelector(selector);
    const font = selector => {
      const element = node(selector);
      return element ? Number.parseFloat(getComputedStyle(element).fontSize) : null;
    };
    const rect = selector => {
      const element = node(selector);
      if (!element) return null;
      const box = element.getBoundingClientRect();
      return { width: box.width, height: box.height, top: box.top, left: box.left };
    };
    const boxes = selector => [...document.querySelectorAll(selector)].map(element => {
      const box = element.getBoundingClientRect();
      return { width: box.width, height: box.height, top: box.top, left: box.left };
    });
    const gridTracks = selector => {
      const element = node(selector);
      return element ? getComputedStyle(element).gridTemplateColumns.split(' ').filter(Boolean).length : 0;
    };
    const actionHeights = boxes('#dashboard-view .action-link').map(box => box.height);
    return {
      contract: node('#dashboard-view')?.dataset.dashboardResponsiveContract,
      statusContract: window.__LTS_CANONICAL_DASHBOARD_STATUS?.responsive_contract,
      viewport: { width: window.innerWidth, height: window.innerHeight },
      page: {
        scrollWidth: document.documentElement.scrollWidth,
        clientWidth: document.documentElement.clientWidth,
        scrollHeight: document.documentElement.scrollHeight
      },
      tracks: {
        kpis: gridTracks('#dashboard-view .kpis'),
        main: gridTracks('#dashboard-view .grid-main'),
        three: gridTracks('#dashboard-view .grid-three'),
        bottom: gridTracks('#dashboard-view .grid-bottom')
      },
      boxes: {
        kpis: boxes('#dashboard-view .kpi'),
        main: rect('#dashboard-view .grid-main'),
        liquidity: rect('#dashboard-view .grid-main > .panel:first-child'),
        bottom: rect('#dashboard-view .grid-bottom'),
        planning: rect('#planning-panel'),
        chart: rect('#dashboard-view .grid-main .chart'),
        planningChart: rect('#planning-panel .chart'),
        actionMinHeight: actionHeights.length ? Math.min(...actionHeights) : 0
      },
      planningPosition: getComputedStyle(node('#planning-panel .planning-decision')).position,
      fonts: {
        kpiLabel: font('#dashboard-view .kpi label'),
        kpiMeta: font('#dashboard-view .kpi .meta'),
        kpiSignal: font('#dashboard-view .kpi-signal'),
        panelTitle: font('#dashboard-view .panel-title h2'),
        panelMeta: font('#dashboard-view .panel-title small'),
        action: font('#dashboard-view .action-link'),
        bank: font('#dashboard-view .bank-row'),
        bankMeta: font('#dashboard-view .bank-row span'),
        rank: font('#dashboard-view .rank-row b'),
        rankMeta: font('#dashboard-view .rank-row span'),
        commitment: font('#dashboard-view .commit-row strong'),
        commitmentMeta: font('#dashboard-view .commit-row small'),
        update: font('#dashboard-view .update-row b'),
        updateMeta: font('#dashboard-view .update-row span'),
        legend: font('#dashboard-view .liquidity-legend'),
        layer: font('#dashboard-view .liquidity-layer-values > span'),
        layerValue: font('#dashboard-view .liquidity-layer-values b'),
        planningNote: font('#planning-panel .planning-decision small'),
        mobileNav: font('.mobile-nav button')
      }
    };
  });

  if (metrics.contract !== 'executive-readable-breakpoints-v1' || metrics.statusContract !== metrics.contract) {
    throw new Error(`${label}: responsive Dashboard contract ${JSON.stringify(metrics)}`);
  }
  if (metrics.page.scrollWidth > metrics.page.clientWidth + 1) {
    throw new Error(`${label}: responsive Dashboard horizontal overflow ${JSON.stringify(metrics.page)}`);
  }

  const floors = {
    reference: { kpiLabel: 12, kpiMeta: 9.5, kpiSignal: 8.5, panelTitle: 15.8, panelMeta: 9, action: 10, bank: 10.3, bankMeta: 8.2, rank: 10.3, rankMeta: 8.4, commitment: 10.2, commitmentMeta: 8.4, update: 10.2, updateMeta: 8.4, legend: 8.2, layer: 7.8, layerValue: 8.5, planningNote: 7.4 },
    laptop: { kpiLabel: 12.5, kpiMeta: 10.5, kpiSignal: 10, panelTitle: 16.5, panelMeta: 10.5, action: 11, bank: 11.2, bankMeta: 9.5, rank: 11.2, rankMeta: 9.5, commitment: 11, commitmentMeta: 9.5, update: 11, updateMeta: 9.5, legend: 9.5, layer: 9.5, layerValue: 10.5, planningNote: 9 },
    intermediate: { kpiLabel: 12.5, kpiMeta: 10.5, kpiSignal: 10, panelTitle: 17, panelMeta: 11, action: 11.5, bank: 11.5, bankMeta: 10, rank: 11.5, rankMeta: 10, commitment: 11.5, commitmentMeta: 10, update: 11.5, updateMeta: 10, legend: 10.5, layer: 10, layerValue: 11, planningNote: 9.5 },
    mobile: { kpiLabel: 12, kpiMeta: 10, kpiSignal: 10, panelTitle: 16, panelMeta: 10.5, action: 10.5, bank: 11.5, bankMeta: 10, rank: 11.5, rankMeta: 10, commitment: 11.5, commitmentMeta: 10, update: 11.5, updateMeta: 10, legend: 10, layer: 9.8, layerValue: 10.8, planningNote: 10, mobileNav: 9 }
  }[profile];
  if (!floors) throw new Error(`${label}: unknown Dashboard readability profile ${profile}`);
  for (const [key, floor] of Object.entries(floors)) {
    const actual = metrics.fonts[key];
    if (actual == null || actual + 0.05 < floor) {
      throw new Error(`${label}: ${key} readability floor ${actual} < ${floor}; metrics=${JSON.stringify(metrics)}`);
    }
  }

  if (metrics.boxes.kpis.length !== 5 || metrics.boxes.kpis.some(box => box.width <= 0 || box.height <= 0)) {
    throw new Error(`${label}: responsive KPI geometry ${JSON.stringify(metrics.boxes.kpis)}`);
  }
  if (profile === 'reference') {
    if (metrics.boxes.chart?.height > 185 || metrics.boxes.planningChart?.height > 168) {
      throw new Error(`${label}: 1312x1199 compact chart profile ${JSON.stringify(metrics.boxes)}`);
    }
  } else if (profile === 'laptop') {
    if (metrics.boxes.chart?.height < 210 || metrics.boxes.planningChart?.height < 198 || metrics.tracks.main !== 3) {
      throw new Error(`${label}: height-aware laptop profile ${JSON.stringify(metrics)}`);
    }
  } else if (profile === 'intermediate') {
    const minKpiWidth = Math.min(...metrics.boxes.kpis.map(box => box.width));
    const liquidityRatio = metrics.boxes.liquidity.width / metrics.boxes.main.width;
    const planningRatio = metrics.boxes.planning.width / metrics.boxes.bottom.width;
    if (minKpiWidth < 195 || liquidityRatio < 0.98 || planningRatio < 0.98 || metrics.boxes.chart?.height < 220) {
      throw new Error(`${label}: intermediate hierarchy profile ${JSON.stringify({ minKpiWidth, liquidityRatio, planningRatio, metrics })}`);
    }
  } else if (profile === 'mobile') {
    const minKpiWidth = Math.min(...metrics.boxes.kpis.map(box => box.width));
    if (minKpiWidth < 165 || metrics.planningPosition !== 'static' || metrics.boxes.actionMinHeight < 35.5 || metrics.boxes.planningChart?.height > 170) {
      throw new Error(`${label}: mobile readable profile ${JSON.stringify({ minKpiWidth, metrics })}`);
    }
  }
  return metrics;
}

async function assertDashboardContract(page, label, mobile) {
  const contract = await page.locator('#dashboard-view').getAttribute('data-dashboard-contract');
  const densityContract = await page.locator('#dashboard-view').getAttribute('data-dashboard-density-contract');
  const responsiveContract = await page.locator('#dashboard-view').getAttribute('data-dashboard-responsive-contract');
  const status = await page.evaluate(() => window.__LTS_CANONICAL_DASHBOARD_STATUS);
  if (contract !== 'reference-layered-liquidity-commitments-v3'
      || densityContract !== 'approved-1312x1199-single-screen-v1'
      || status?.ready !== true
      || status?.contract !== contract
      || status?.reference !== 'approved-1312x1199-liquidity-first'
      || status?.density_contract !== densityContract
      || responsiveContract !== 'executive-readable-breakpoints-v1'
      || status?.responsive_contract !== responsiveContract
      || status?.decision_hierarchy_contract !== 'today-commitments-direction-v1'
      || status?.visual_hierarchy_contract !== 'executive-cockpit-readable-density-v1'
      || status?.projection_contract !== 'fact-before-asof-projection-after-asof-v1'
      || status?.liquidity_layer_contract !== 'current-base-scheduled-rsu-restricted-fgts-v1'
      || status?.planning_decision_contract !== 'v151-first-negative-management-separation-v1'
      || status?.planning_first_negative_date !== '2027-01-12'
      || status?.planning_management_point_date !== '2026-12-01'
      || status?.planning_management_before_negative !== true
      || status?.planning_marker_source !== 'exact-horizon'
      || status?.current_anchor_source !== 'cockpit-liquidity-through-d3'
      || status?.commitment_source !== 'product-commitments-plus-card-due'
      || status?.observed_points !== 1
      || status?.projected_points !== 5
      || status?.conditional_points !== 5
      || status?.restricted_points !== 5
      || status?.commitment_rows !== 3
      || status?.update_rows !== 3) {
    throw new Error(`${label}: Dashboard fidelity status ${JSON.stringify({ contract, densityContract, responsiveContract, status })}`);
  }

  await assertDashboardReadability(page, label, mobile ? 'mobile' : 'reference');

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
  const overviewChart = page.locator('#dashboard-view .grid-main [data-liquidity-chart="layered-fact-projection-v2"]');
  const planningChart = page.locator('#planning-panel [data-liquidity-chart="layered-fact-projection-v2"]');
  if (await overviewChart.getAttribute('data-first-negative-marker') !== 'none'
      || await planningChart.getAttribute('data-first-negative-marker') !== 'exact-horizon'
      || await planningChart.getAttribute('data-first-negative-date') !== '2027-01-12'
      || await planningChart.locator('.planning-negative-guide').count() !== 1
      || await planningChart.locator('.planning-negative-marker').count() !== 1) {
    throw new Error(`${label}: V151 first-negative chart marker missing`);
  }
  const planningDecision = page.locator('#planning-panel [data-planning-decision-contract="v151-first-negative-management-separation-v1"]');
  const planningDecisionText = await planningDecision.innerText();
  if (await planningDecision.count() !== 1
      || await planningDecision.getAttribute('data-first-negative-date') !== '2027-01-12'
      || await planningDecision.getAttribute('data-management-point-date') !== '2026-12-01'
      || await planningDecision.getAttribute('data-management-before-negative') !== 'true'
      || !containsText(planningDecisionText, 'Primeiro caixa negativo')
      || !containsText(planningDecisionText, '12/01/2027')
      || !containsText(planningDecisionText, 'Ponto de gestão: 01/12/2026')
      || !containsText(planningDecisionText, 'ocorre antes do saldo negativo')) {
    throw new Error(`${label}: V151 planning decision separation ${JSON.stringify(planningDecisionText)}`);
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
  const planningPanelBox = await page.locator('#planning-panel').boundingBox();
  if (!planningPanelBox || planningPanelBox.height > (mobile ? 430 : 315)) {
    throw new Error(`${label}: planning panel height regression ${JSON.stringify(planningPanelBox)}`);
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
    await assertNoTechnicalVersionLeak(page, label, 'Dashboard');
    await page.screenshot({ path: `canonical-dashboard-${label}.png`, fullPage: true });

    await openRoute(page, 'Fluxo Diário', mobile);
    await page.waitForFunction(() => window.__LTS_CANONICAL_FLOW_V157_STATUS?.ready === true);
    await assertFlowParity(page, label, mobile);
    await assertUxClosure(page, label, mobile);
    await assertNoTechnicalVersionLeak(page, label, 'Fluxo Diário');
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
    await assertNoTechnicalVersionLeak(page, label, 'Despesas');
    await page.screenshot({ path: `canonical-expenses-${label}.png`, fullPage: true });

    await openRoute(page, 'Patrimônio', mobile);
    await waitProduct(page, 'Patrimônio');
    text = await page.locator('.pv').innerText();
    for (const required of ['Quanto você tem, quanto deve e quanto é seu.', 'RSUs vested', 'RSUs futuras', 'Cash Awards futuros', 'CIPÓ 396', 'Volvo']) {
      if (!text.includes(required)) throw new Error(`${label}: wealth surface missing ${required}`);
    }
    await assertNoTechnicalVersionLeak(page, label, 'Patrimônio');
    await page.screenshot({ path: `canonical-wealth-${label}.png`, fullPage: true });

    await openRoute(page, 'Cartões', mobile);
    await waitProduct(page, 'Cartões');
    text = await page.locator('.pv').innerText();
    for (const required of ['Conferência de fatura, não análise de gasto.', 'Cobertura histórica', 'Histórico por cartão / ano', '12/09/2026']) {
      if (!text.includes(required)) throw new Error(`${label}: cards surface missing ${required}`);
    }
    await assertNoTechnicalVersionLeak(page, label, 'Cartões');
    await page.screenshot({ path: `canonical-cards-${label}.png`, fullPage: true });

    await openRoute(page, 'Atualizações', mobile);
    await page.waitForTimeout(350);
    await assertUpdatesContract(page, label);
    await assertManagementContract(page, label);
    await assertNoTechnicalVersionLeak(page, label, 'Atualizações');
    await page.screenshot({ path: `canonical-updates-${label}.png`, fullPage: true });

    await openRoute(page, 'Dashboard', mobile);
    await waitProduct(page, 'Dashboard');
    await assertUxClosure(page, label, mobile);
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
    if (await page.locator('label[for="email"],label[for="password"]').count() !== 2) throw new Error(`${label}: login labels are not associated`);
    if (await page.locator('#loginMsg[aria-live="polite"]').count() !== 1) throw new Error(`${label}: login feedback is not announced`);
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

async function runResponsiveDashboard(browserType, label, viewport, profile) {
  const startedAt = Date.now();
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
    await page.waitForFunction(() => window.__LTS_CANONICAL_RECOVERY_STATUS?.product_loaded === true);
    await waitProduct(page, 'Dashboard');
    const metrics = await assertDashboardReadability(page, label, profile);
    const labels = await page.locator('#dashboard-view .kpi label').allTextContents();
    if (JSON.stringify(labels) !== JSON.stringify(['Dinheiro em contas', 'Contas + curto prazo', 'RSUs vested', 'FGTS', 'Despesas (mês)'])) {
      throw new Error(`${label}: responsive KPI truth contract ${JSON.stringify(labels)}`);
    }
    if (errors.length) throw new Error(`${label}: browser errors ${errors.join(' | ')}`);
    await page.screenshot({ path: `canonical-dashboard-${label}.png`, fullPage: true });
    receipt.suites[label] = {
      status: 'PASS',
      engine: browserType.name(),
      viewport,
      profile,
      duration_ms: Date.now() - startedAt,
      metrics,
      coverage: ['Dashboard responsive readability', 'liquidity-first hierarchy', 'no horizontal overflow']
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
    await runResponsiveDashboard(chromium, 'laptop', { width: 1366, height: 900 }, 'laptop');
    await runResponsiveDashboard(chromium, 'intermediate', { width: 1024, height: 900 }, 'intermediate');
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
