'use strict';
const assert = require('node:assert/strict');
const {chromium, webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const fixtures = require('./lts_v379_fixtures.cjs');
const release = require('../../mobile/current.json').release;
const {historicalConsolidatedCash, consolidatedTsv} = require('../../releases/' + release + '/lts-v268-read-tools.js');
const date = '2026-10-12';
const bank = (opening_balance, cash_entries, cash_exits) => ({
  opening_balance, cash_entries, cash_exits, balance: opening_balance + cash_entries - cash_exits,
  net: cash_entries - cash_exits, movements_complete: true, documentary_reconstruction: true,
  documentary_anchor_ref:'test', balance_basis:'observed_bank_position_and_recent_movements'
});
const example = {
  date, historical:true, movements_complete:true,
  'Itaú': bank(100, 125, 0), C6:bank(300, 180, 132), Bradesco:{...bank(0,0,0), balance_certified:false,reconciliation_gap:0.07},
  Consolidado:{documentary_reconstruction:true, bank_balance:573, balance_basis:'sum_of_documented_account_positions'},
  summary:{events:4, entries:180, exits:7, Consolidado:{entries:180,exits:7}},
  v170_cash_arithmetic:{version:'account-positions-plus-effective-cash-v237', balanced:true},
  fix86_columns:{saldo_anterior:400,saldo_anterior_operacional:400,saldo_final:573,saldo_final_operacional:573,
    entradas:305,saidas:132,entradas_operacionais:180,saidas_operacionais:7}
};
function event(id,account,description,signed_amount,internal_transfer,peer) {
  return {source:'open_finance',source_ref:id,open_finance_id:id,event_date:date,account,description,
    signed_amount,internal_transfer,bank_confirmed:true,category:internal_transfer?'Movimentação interna':'Tarifas',
    ...(peer?{own_transfer_counterparty_id:peer,classification_confirmed:true}:{})};
}
const events=[
  event('credit','Itaú','Transferência entre contas — C6 → Itaú',125,true,'debit'),
  event('debit','C6','Transferência entre contas — C6 → Itaú',-125,true,'credit'),
  event('receipt','C6','RETORNO CONTA GLOBAL',180,true),
  event('fee','C6','Tarifa',-7,false)
];
assert.deepEqual(historicalConsolidatedCash(example,events),{entries:180,exits:7});
const old=structuredClone(example);delete old.fix86_columns.entradas_operacionais;
assert.deepEqual(historicalConsolidatedCash(old,events),{entries:305,exits:132});
const partial=structuredClone(example);partial.summary.Consolidado.entries=10;
assert.deepEqual(historicalConsolidatedCash(partial,events),{entries:305,exits:132});
const zero=structuredClone(example);
Object.assign(zero.fix86_columns,{entradas:125,saidas:125,entradas_operacionais:0,saidas_operacionais:0,saldo_final_operacional:400});
zero.summary.Consolidado={entries:0,exits:0};
assert.deepEqual(historicalConsolidatedCash(zero,events),{entries:0,exits:0});
const unrelated=structuredClone(events);
delete unrelated[0].own_transfer_counterparty_id;
delete unrelated[1].own_transfer_counterparty_id;
assert.deepEqual(historicalConsolidatedCash(example,unrelated),{entries:305,exits:132});
assert.deepEqual(historicalConsolidatedCash(example,events.slice(1)),{entries:305,exits:132});
const duplicate=[...events,events[0]];
assert.deepEqual(historicalConsolidatedCash(example,duplicate),{entries:305,exits:132});
const exported=consolidatedTsv({from:date,to:date,days:[example],events});
assert.equal(exported.ok,true);
function cents(text){return Math.round(Number(text.replace(/[^\d,.-]/g,'').replace(/\./g,'').replace(',','.'))*100);}
assert.deepEqual(exported.text.split('\n')[1].split('\t').slice(1,5).map(cents),[40000,18000,700,57300]);
async function verify(browser,width){
  const h=await setup(browser,width,width===390?844:900,'2026-11-21T18:00:00Z');
  try {
    let observationReads=0;
    await h.ctx.route('**/rpc/lts_browser_flow_bank_observation_v495',route=>{
      assert.deepEqual(route.request().postDataJSON(),{p_date:date,p_bank:'Bradesco'});
      observationReads++;
      return route.fulfill({json:{date,bank:'Bradesco',source_at:date+'T18:00:00Z',balance:.07,automatically_invested:.07}});
    });
    await h.ctx.route('**/rpc/lts_browser_flow_v242',route=>{
      const args=route.request().postDataJSON();
      const payload=fixtures.response('lts_browser_flow_v242',args);
      if(args.p_from<=date && date<=args.p_to){
        const flow=payload.flow;
        for(const part of [flow.historical,flow.current_future]){
          part.days=part.days.filter(day=>day.date!==date);
          part.events=part.events.filter(e=>e.event_date!==date);
        }
        flow.historical.days.push(example);flow.historical.events.push(...events);
      }
      return route.fulfill({json:payload});
    });
    const base=process.env.LTS_BROWSER_BASE||'http://127.0.0.1:8788';
    await h.page.goto(base+'/releases/'+release+'/app.html');
    const app=h.page.frameLocator('#shell');
    const nav=app.locator('#nav [data-v="Fluxo Diário"]:visible,#dx1MobileNav [data-mobile-route="Fluxo Diário"]:visible');
    await nav.first().click();
    await app.locator('.v382-period summary').click();
    await app.getByLabel('Data inicial do Fluxo',{exact:true}).fill(date);
    await app.getByLabel('Data final do Fluxo',{exact:true}).fill(date);
    await app.locator('#flowApply').click();
    const row=app.locator('#d-'+date);
    await row.waitFor();
    const amounts=()=>row.locator(':scope > .fx87-cell').allTextContents().then(x=>x.slice(1,5).map(cents));
    assert.deepEqual(await amounts(),[40000,18000,700,57300]);
    await row.locator('[data-d]').click();
    const details=app.locator('#d-'+date+' + .fx89-details');
    await details.getByText('Retorno da Conta Global',{exact:true}).waitFor();
    assert.equal(await details.getByText('Entre contas do consolidado',{exact:true}).count(),2);
    const evidence=details.locator('[data-history-bank="Bradesco"]');
    assert.equal(observationReads,0);
    await evidence.locator('summary').click();
    await evidence.getByText(/A diferença é R\$\s*0,07/).waitFor();
    assert.equal(observationReads,1);
    assert.deepEqual(await amounts(),[40000,18000,700,57300]);
    for(const [account,expected] of [['Itaú',[10000,12500,0,22500]],['C6',[30000,18000,13200,34800]]]){
      await app.locator('[data-a="'+account+'"]:visible').first().click();
      assert.deepEqual(await amounts(),expected);
    }
    assert.deepEqual(h.errors,[]);
    console.log(browser.browserType().name(),width,'consolidated amounts, both bank legs and expanded detail passed');
  } finally {await h.ctx.close();}
}
(async()=>{
  for(const engine of [chromium,webkit]){
    const b=await engine.launch({executablePath:engine===chromium?process.env.LTS_TEST_CHROMIUM:undefined});
    try{for(const width of [390,1366])await verify(b,width);}finally{await b.close();}
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
