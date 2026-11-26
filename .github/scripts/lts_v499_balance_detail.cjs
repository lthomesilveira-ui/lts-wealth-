'use strict';
const assert = require('node:assert/strict');
const {chromium, webkit} = require('playwright');
const {setup} = require('./lts_v382_browser.cjs');
const {monthly} = require('./lts_v379_fixtures.cjs');
const base = process.env.LTS_BROWSER_BASE || 'http://127.0.0.1:8788';

async function verify(browser, width) {
  const {ctx, page} = await setup(browser, width, 850);
  try {
    await ctx.route('**/rpc/lts_browser_expenses_v229', route => {
      const {p_from:from,p_to:to} = route.request().postDataJSON();
      return route.fulfill({json:{version:'expense-executive-v229-consistent-comparisons',
        period:{from,to,last_available:'2026-10-16'},summary:{selected_total:monthly(from,to).totals.expenses},
        management_groups:[],monthly_detail:[],yearly_detail:[]}});
    });
    const ranges=[];
    await ctx.route('**/rpc/lts_browser_expense_detail_v374',async route=>{
      const args=route.request().postDataJSON();
      ranges.push([args.p_from,args.p_to,args.p_group]);
      const amount=monthly(args.p_from,args.p_to).totals.expenses;
      await new Promise(resolve=>setTimeout(resolve,200));
      await route.fulfill({json:{total:amount,row_count:1,matched_count:1,offset:0,next_offset:null,revision:'test',
        components:[],rows:[{key:'sample',date:args.p_from,date_kind:'day',description:'Compra de teste',amount}]}});
    });
    await page.goto(base+'/releases/v499/app.html');
    const app=page.frameLocator('#shell');
    await app.locator('#nav [data-v="Despesas"]:visible,#dx1MobileNav [data-mobile-route="Despesas"]:visible').first().click();
    await app.getByRole('tab',{name:'Balanço mensal'}).click();
    await app.getByRole('heading',{name:'Acumulado do período'}).waitFor();
    await app.getByText('Último lançamento em 16/10/2026',{exact:true}).waitFor();
    for (const [selector, month] of [['.v168-kpis [data-expense-total]',''],['.v182-months [data-month="2026-10"]','2026-10'],['.v182-months .v182-total [data-expense-total]','']]) {
      const link=app.locator(selector);
      const value=(await link.innerText()).trim();
      await link.click();
      const drawer=app.getByRole('dialog');
      await drawer.waitFor();
      assert.equal((await drawer.locator('.v178-detail-summary b').first().innerText()).trim(),value);
      await drawer.getByText('Compra de teste',{exact:true}).first().waitFor();
      assert.ok(ranges.some(([from,to,group])=>from===(month?month+'-01':'2026-01-01')&&to==='2026-10-30'&&group===null),selector+' range '+JSON.stringify(ranges));
      await drawer.getByRole('button',{name:'Fechar'}).click();
    }
    console.log('verified monthly, period and first paint at width',width);
  } finally { await ctx.close(); }
}
(async()=>{
  for(const engine of (process.env.LTS_CHROMIUM_PATH?[chromium]:[chromium,webkit])){
    const browser=await engine.launch(engine===chromium && process.env.LTS_CHROMIUM_PATH?{executablePath:process.env.LTS_CHROMIUM_PATH}:{});
    try { for(const width of [390,1366]) await verify(browser,width); } finally { await browser.close(); }
  }
})().catch(e=>{console.error(e);process.exitCode=1;});
