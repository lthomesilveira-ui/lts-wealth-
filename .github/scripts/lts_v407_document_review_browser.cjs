'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium,webkit}=require('playwright');
const release=process.env.LTS_DOC_RELEASE||'v407';process.env.LTS_FLOW_RELEASE=release;
const {setup,open}=require('./lts_v382_browser.cjs'),fixture=require('./lts_v379_fixtures.cjs');
const repo=path.resolve(__dirname,'../..'),out=process.env.LTS_DOC_OUTPUT||path.join(repo,'qa/v407-documents');fs.mkdirSync(out,{recursive:true});
const uid='00000000-0000-4000-8000-000000000001';
const pdf=Buffer.from('%PDF-1.4\n% Synthetic document for an isolated browser test.\n%%EOF');
function queueItem(id,args){return {inbox_id:id,original_name:args.p_original_name,input_type:args.p_input_type||'file',mime_type:args.p_mime_type,phase:'received',updated_at:'2026-11-04T15:00:00Z',document_association:{institution:'Banco fictício',reference_date:'2026-11-04'},entry_count:args.p_interpretation?.entries?.length||0,review_payload:{entries:args.p_interpretation?.entries||[]},evidence_truncated:false,review_required:true,write_allowed:false};}
async function goUpdates(frame){await frame.locator('#nav [data-v="Atualizações"]:visible,#dx1MobileNav [data-mobile-route="Atualizações"]:visible').click();await frame.waitForFunction(()=>V==='Atualizações');}
async function run(browser,engine,width,height){
 const h=await setup(browser,width,height,'2026-11-04T15:00:00Z');
 const calls={user:0,uploads:0,register:0,structured:0,deletes:0,queue:0,meta:0,downloads:0,financial:[]},objects=new Map(),rows=[],byId=new Map(),registrations=[];
 let mode='lost',queueError=false,productError=false,authError=true,downloadError=false;
 await h.ctx.route('**/*',async route=>{
  const req=route.request(),url=new URL(req.url());if(url.origin!=='https://tadhkamnwtsbdozwkyut.supabase.co')return route.fallback();
  const name=url.pathname.split('/').pop(),send=x=>route.fulfill({status:200,contentType:'application/json',body:JSON.stringify(x)});
  if(url.pathname==='/auth/v1/user'){calls.user++;assert.equal(req.headers().authorization,'Bearer synthetic-only-access','getUser uses the existing session token');if(authError)return route.fulfill({status:401,contentType:'application/json',body:'{"message":"synthetic expired token"}'});return send({id:uid,email:'viewer@example.invalid'});}
  if(url.pathname.startsWith('/storage/v1/object/')){
   if(req.method()==='DELETE'){calls.deletes++;return send([]);}
   const marker='/lts-documents/',at=url.pathname.indexOf(marker),key=decodeURIComponent(url.pathname.slice(at+marker.length));
   assert(key.startsWith(uid+'/'),'Storage path uses the Auth-server owner');assert.equal(req.headers().authorization,'Bearer synthetic-only-access','Storage uses the existing authenticated session');
   if(req.method()==='POST'){assert.equal(req.headers()['x-upsert'],'false');calls.uploads++;objects.set(key,pdf);return send({Key:'lts-documents/'+key});}
   if(req.method()==='GET'){assert(url.pathname.startsWith('/storage/v1/object/authenticated/lts-documents/'),'download uses authenticated route');calls.downloads++;if(downloadError)return route.fulfill({status:401,body:'synthetic expired token'});if(!objects.has(key))return route.fulfill({status:404,body:'not found'});return route.fulfill({status:200,contentType:'application/pdf',body:objects.get(key)});}
  }
  if(name==='lts_browser_product_v1'){
   if(productError)return route.fulfill({status:503,contentType:'application/json',body:'{"message":"synthetic refresh failure"}'});
   const product=fixture.product();product.input={queue:rows.map(x=>({id:x.inbox_id,original_name:x.original_name,input_type:x.input_type,status:'needs_review',interpretation:{entries:x.review_payload.entries},created_at:x.updated_at}))};return send({ok:true,mvp:product});
  }
  if(name==='lts_browser_document_review_queue_v1'){
   calls.queue++;if(queueError)return route.fulfill({status:503,contentType:'application/json',body:'{"message":"synthetic read failure"}'});
   return send({contract:'v149-evidence-review-readonly-canonical-v1',queue_documents:rows.length,shown_documents:Math.min(rows.length,6),items:rows.slice(0,6),write_allowed:false,financial_writer_called:false});
  }
  if(name==='lts_browser_document_meta_v1'){
   calls.meta++;const args=JSON.parse(req.postData()||'{}'),record=byId.get(args.p_inbox_id);assert(record,'metadata selects a known owner-scoped fixture ID');return send({ok:true,storage_path:record.p_storage_path,original_name:record.p_original_name,mime_type:record.p_mime_type});
  }
  if(name==='lts_browser_register_document_v2'||name==='lts_browser_register_structured_text_v2'){
   if(name.includes('structured'))calls.structured++;else calls.register++;
   const args=JSON.parse(req.postData()||'{}'),id='00000000-0000-4000-8000-'+String(calls.register+calls.structured).padStart(12,'0');assert(objects.has(args.p_storage_path),'uploaded bytes precede registration');
   registrations.push({name,args});byId.set(id,args);rows.unshift(queueItem(id,args));
   if(mode==='lost')return route.abort('timedout');return send({ok:true,inbox_id:id,status:'needs_review'});
  }
  if(/apply_document|prepare_manual_document|approve|financial.*(create|update|delete)/.test(name)){calls.financial.push(name);return route.abort();}
  return route.fallback();
 });
 try{
  const frame=await open(h,release);if(process.env.LTS_DOC_INJECT==='1')await h.page.addScriptTag({content:fs.readFileSync(path.join(repo,'lts-v407-document-review.js'),'utf8')});
  await frame.waitForFunction(()=>window.__LTS_V407_DOCUMENTS?.installed);
  await goUpdates(frame);await h.page.waitForLoadState('networkidle');assert.equal(calls.queue,0,'document reader does not slow initial loading');
  const panel=frame.locator('#v407Documents');assert.equal(await panel.count(),1);assert.equal(await panel.getAttribute('open'),null,'documents are initially collapsed');
  await frame.evaluate(()=>{const s=JSON.parse(localStorage.getItem('lts_supabase_session_v1'));s.user.id='00000000-0000-4000-8000-000000000099';localStorage.setItem('lts_supabase_session_v1',JSON.stringify(s));});
  await frame.locator('[data-v168-upload]').first().click();await frame.locator('#v168UpFile').setInputFiles({name:'Extrato fictício de novembro.pdf',mimeType:'application/pdf',buffer:pdf});
  await frame.locator('#v168UpSend').click();await frame.locator('#v168ModalMsg').filter({hasText:'Sessão expirada. Entre novamente.'}).waitFor();assert.equal(calls.user,1);assert.equal(calls.uploads,0);assert.equal(calls.register,0,'rejected identity cannot upload or register');authError=false;
  await frame.locator('#v168UpSend').click();await frame.locator('#v168UpSend').filter({hasText:'Registro a conferir'}).waitFor();
  assert.deepEqual([calls.uploads,calls.register,calls.deletes],[1,1,0],'existing guided upload preserves an uncertain registered source');
  // Dismiss the current modal using its existing control, then use the new read-only entry.
  await frame.locator('[data-v168-close]').click();
  await panel.locator(':scope>summary').click();await frame.getByRole('heading',{name:'Extrato fictício de novembro.pdf',exact:true}).waitFor();
  assert.equal(calls.queue,1);assert.equal(await frame.locator('#v407Documents input').count(),0,'review introduces no approval inputs');
  const first=panel.locator('.v407-document').first();await first.getByRole('button',{name:'Ver arquivo',exact:true}).click();await first.getByRole('link',{name:'Baixar arquivo',exact:true}).waitFor();
  assert.equal(calls.meta,1);assert.equal(calls.downloads,1);assert((await first.getByRole('link',{name:'Baixar arquivo'}).getAttribute('href')).startsWith('blob:'),'file uses authenticated private download');
  downloadError=true;await first.getByRole('button',{name:'Ver arquivo',exact:true}).click();await first.getByText('Não foi possível abrir o arquivo. Consulte novamente antes de reenviar.',{exact:true}).waitFor();assert.equal(await first.getByRole('link',{name:'Baixar arquivo'}).count(),0,'expired token does not expose a download');downloadError=false;
  await first.getByText('Conferir informações',{exact:true}).click();assert((await first.innerText()).includes('Banco fictício'));
  queueError=true;await panel.getByRole('button',{name:'Atualizar documentos',exact:true}).click();await panel.getByText('Não foi possível atualizar os documentos. Tente consultar novamente.',{exact:true}).waitFor();assert.equal(await panel.locator('.v407-document').count(),1,'failed read preserves previously shown evidence');
  queueError=false;await panel.getByRole('button',{name:'Atualizar documentos',exact:true}).click();await frame.waitForFunction(()=>!document.querySelector('#v407DocumentsBody button').disabled);
  // Existing legacy input is still protected when reached by its retained route.
  await frame.evaluate(()=>u133GoEntries());await frame.locator('#file').setInputFiles({name:'Linhas fictícias.csv',mimeType:'text/csv',buffer:Buffer.from('data;descricao;valor;conta\n04/11/2026;Linha de teste;-123,45;Banco fictício\n')});
  await frame.locator('#ubtn').click();await frame.getByText('Não foi possível confirmar o envio. O arquivo foi preservado se recebido. Consulte Documentos enviados antes de reenviar.',{exact:true}).waitFor();
  const before={uploads:calls.uploads,register:calls.register,structured:calls.structured};await frame.evaluate(()=>upload());
  assert.deepEqual({uploads:calls.uploads,register:calls.register,structured:calls.structured},before,'uncertain operation is not retried');assert.equal(calls.structured,1);assert.equal(calls.deletes,0);
  const interpretation=registrations.find(x=>x.name.includes('structured')).args.p_interpretation;assert.equal(interpretation.entries[0].amount,-123.45);assert.equal(interpretation.entries[0].event_date,'2026-11-04');assert.equal(interpretation.entries[0].write_allowed,false);
  await goUpdates(frame);await panel.getByRole('button',{name:'Atualizar documentos',exact:true}).click();await panel.getByRole('heading',{name:'Linhas fictícias.csv',exact:true}).waitFor();
  await panel.locator('.v407-document').first().getByRole('button',{name:'Ver arquivo',exact:true}).click();await panel.locator('.v407-document').first().getByRole('link',{name:'Baixar arquivo',exact:true}).waitFor();
  assert.equal(calls.deletes,0);assert.equal(calls.uploads,2);assert.equal(calls.register+calls.structured,2);
  // Success followed by a failed product refresh must not erase the confirmed source.
  mode='ok';productError=true;await frame.evaluate(()=>u133GoEntries());await frame.locator('#file').setInputFiles({name:'Confirmação fictícia.pdf',mimeType:'application/pdf',buffer:pdf});await frame.locator('#ubtn').click();
  await frame.waitForFunction(()=>document.getElementById('up')?.textContent.includes('Arquivo recebido')||document.getElementById('v407Documents'));
  await h.page.waitForLoadState('networkidle');assert.equal(calls.deletes,0);assert.equal(calls.register,2);productError=false;
  await goUpdates(frame);await frame.waitForFunction(()=>document.querySelector('#v407Documents'));
  // Count limits and source escaping remain visible; no full-queue claim for six rows.
  while(rows.length<7){const n=rows.length+1;rows.push(queueItem('00000000-0000-4000-8000-'+String(n).padStart(12,'0'),{p_original_name:'Documento fictício '+n+'.pdf',p_mime_type:'application/pdf'}));}
  rows[0].original_name='Extrato fictício com nome longo <img src=x onerror=alert(1)> para conferir a quebra de linhas.pdf';rows[0].entry_count=30;rows[0].evidence_truncated=true;rows[0].review_payload.entries=Array.from({length:25},(_,i)=>({description:'Linha fictícia '+(i+1),event_date:'2026-11-04',amount:i===0?null:12.34,account:'Banco fictício'}));
  await panel.getByRole('button',{name:'Atualizar documentos',exact:true}).click();await panel.getByText('Mostrando 6 documentos recentes de 7 aguardando revisão.',{exact:true}).waitFor();
  await panel.locator('.v407-document').first().getByText('Conferir informações',{exact:true}).click();assert.equal(await panel.locator('h3 img').count(),0);assert.equal(await panel.locator('.v407-document').first().locator('.v407-doc-entry').count(),25);await panel.getByText('Mostrando 25 de 30 linhas. Consulte o arquivo para conferir o conteúdo completo.',{exact:true}).waitFor();await panel.getByText('Valor a confirmar',{exact:true}).waitFor();
  const geometry=await panel.evaluate(e=>({left:e.getBoundingClientRect().left,right:e.getBoundingClientRect().right,width:innerWidth,scroll:document.documentElement.scrollWidth,buttons:[...e.querySelectorAll('button')].filter(b=>b.getClientRects().length).map(b=>b.getBoundingClientRect().height)}));assert(geometry.right<=width+2&&geometry.left>=-2&&geometry.scroll<=width+2,'document panel fits viewport');assert(geometry.buttons.every(h=>h>=44),'document controls are touch sized');
  await h.page.screenshot({path:path.join(out,engine+'-'+width+'.png')});
  await frame.evaluate(()=>render());assert.equal(await panel.count(),1);assert.equal(await panel.getAttribute('open'),'','open disclosure survives app render');assert.equal(calls.deletes,0);assert.deepEqual(calls.financial,[]);assert.deepEqual(h.writes,[]);assert.deepEqual(h.errors,[]);
  await frame.evaluate(()=>S.auth.signOut());assert.equal(await panel.locator('.v407-document').count(),0,'sign-out clears cached document data');assert.equal(await panel.getAttribute('open'),null,'sign-out closes document disclosure');
  return {pass:true,engine,width,height,initial_reader_calls:0,auth_server_validates_identity:true,expired_token_rejected:true,auth_server_owner_used_for_storage:true,guided_upload_uncertain_source_preserved:true,private_read_and_download:true,structured_parser_preserved:true,no_retry_on_uncertain_registration:true,refresh_failure_preserves_source:true,queue_and_line_limits_explicit:true,escaped_names:true,unknown_amount_not_zero:true,signout_clears_document_cache:true,geometry,calls,synthetic_http:true,private_session:false,physical_iphone:false};
 }catch(error){const frames=[];for(const f of h.page.frames()){if(!/\/index\.html/.test(f.url()))continue;try{frames.push({url:f.url(),body:(await f.locator('body').innerText()).slice(-2200),state:await f.evaluate(()=>({view:V,message:document.querySelector('#v168ModalMsg')?.textContent,upload:document.querySelector('#v168UpSend')?.outerHTML}))});}catch{}}fs.writeFileSync(path.join(out,engine+'-'+width+'-failure.json'),JSON.stringify({calls,errors:h.errors,writes:h.writes,reads:h.reads.slice(-8),frames,error:error.stack},null,2));throw error;}
 finally{await h.ctx.close();}
}
module.exports={run};
if(require.main===module)(async()=>{const results=[];for(const[engine,type]of [['chromium',chromium],['webkit',webkit]])for(const[width,height]of [[320,740],[393,852],[1366,900]]){const browser=await type.launch({headless:true});try{const result=await run(browser,engine,width,height);results.push(result);console.log(JSON.stringify(result));}catch(error){results.push({pass:false,engine,width,error:error.stack});process.exitCode=1;}finally{await browser.close();fs.writeFileSync(path.join(out,'result.json'),JSON.stringify({pass:results.length===6&&results.every(x=>x.pass),results},null,2));}}})().catch(error=>{console.error(error);process.exitCode=1;});
