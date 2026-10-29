'use strict';
const {chromium}=require('playwright'),fs=require('node:fs'),assert=require('node:assert/strict'),crypto=require('node:crypto');
(async()=>{
 const root='http://127.0.0.1:8788',output='qa/v377-mobile';
 fs.mkdirSync(output,{recursive:true});
 const manifest=JSON.parse(fs.readFileSync('mobile/manifest.webmanifest','utf8'));
 assert.equal(manifest.display,'standalone');assert.equal(manifest.id,'/lts-wealth-/mobile/');
 assert.equal(manifest.scope,'./');assert.equal(manifest.start_url,'./?source=home-screen');
 for(const[n,size]of[['apple-touch-icon.png',180],['icon-192.png',192],['icon-512.png',512]]){
  const b=fs.readFileSync('mobile/'+n);assert.equal(b.readUInt32BE(16),size);assert.equal(b.readUInt32BE(20),size);
 }
 // Verify every existing financial UI asset against its sealed release manifest.
 const sealed=JSON.parse(fs.readFileSync('releases/v374/manifest.json','utf8'));
 for(const[n,hash]of Object.entries(sealed.files))assert.equal(crypto.createHash('sha256').update(fs.readFileSync('releases/v374/'+n)).digest('hex'),hash,n);
 const browser=await chromium.launch({headless:true});
 for(const width of[1440,390,360]){
  const page=await browser.newPage({viewport:{width,height:850}});
  await page.route('**/releases/v374/app.html',route=>route.fulfill({contentType:'text/html',body:'<!doctype html><html lang="pt-BR"><meta name="viewport" content="width=device-width,initial-scale=1"><body><main><h1>Wealth · teste controlado</h1></main></body></html>'}));
  await page.goto(root+'/mobile/');
  await page.getByRole('heading',{name:'Seu Wealth na tela inicial.'}).waitFor();
  assert(await page.getByText('Adicionar à Tela de Início',{exact:true}).isVisible());
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);
  await page.screenshot({path:output+'/install-'+width+'.png',fullPage:true});
  await page.getByRole('button',{name:'Abrir Wealth'}).click();
  await page.frameLocator('#wealth').getByRole('heading',{name:'Wealth · teste controlado'}).waitFor();
  assert.equal(await page.locator('#install').isVisible(),false);
  const rect=await page.locator('#wealth').boundingBox();assert.equal(Math.round(rect.width),width);assert.equal(Math.round(rect.height),850);
  await page.context().setOffline(true);
  await page.getByRole('heading',{name:'Conecte-se à internet'}).waitFor();
  await page.context().setOffline(false);
  await page.getByRole('heading',{name:'Conecte-se à internet'}).waitFor({state:'hidden'});
  await page.close();
 }
 const installed=await browser.newPage({viewport:{width:390,height:850}});
 await installed.addInitScript(()=>Object.defineProperty(navigator,'standalone',{get:()=>true}));
 await installed.route('**/releases/v374/app.html',route=>route.fulfill({contentType:'text/html',body:'<h1>Instalado · teste controlado</h1>'}));
 await installed.goto(root+'/mobile/?source=home-screen');
 await installed.frameLocator('#wealth').getByRole('heading',{name:'Instalado · teste controlado'}).waitFor();
 assert.equal(await installed.locator('#install').isVisible(),false);
 await installed.close();
 const bad=await browser.newPage();
 await bad.route('**/mobile/current.json',r=>r.fulfill({contentType:'application/json',body:'{"release":"v374","entry":"https://example.invalid/phishing"}'}));
 await bad.goto(root+'/mobile/');await bad.getByRole('button',{name:'Abrir Wealth'}).click();
 await bad.getByRole('alert').waitFor();assert.equal(await bad.locator('#wealth').isVisible(),false);
 await bad.close();await browser.close();
 fs.writeFileSync(output+'/result.json',JSON.stringify({version:377,pass:true,widths:[1440,390,360],
  public_portal:true,manifest_and_icons:true,online_offline:true,standalone_simulated:true,
  arbitrary_destination_rejected:true,financial_ui_assets_preserved:true,
  private_ui_verified:false,physical_iphone_verified:false},null,2));
})().catch(error=>{console.error(error);process.exit(1)});
