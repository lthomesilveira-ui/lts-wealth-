const { chromium } = require('playwright');
const fs = require('fs');

const MARK='guided-document-association-v1';
const BRIDGE='v144-lexical-state-bridge-v1';

async function deepest(page){
  const chain=[];let f=page.mainFrame();
  for(let i=0;i<14;i++){
    chain.push(f.url());
    const kids=f.childFrames();if(!kids.length)break;f=kids[0];
  }
  return {f,chain};
}
async function state(f){return await f.evaluate(()=>window.__LTS_V147_READ_DOCUMENT_ASSOCIATION?.())}
async function context(f){return await f.evaluate(()=>window.inputTaskContext?.())}

async function run(viewport,label){
  let stage='launch',f=null,chain=[];
  const browser=await chromium.launch({headless:true});
  const page=await browser.newPage({viewport});
  const errors=[];page.on('pageerror',e=>errors.push('pageerror:'+e.message));page.on('console',m=>{if(m.type()==='error')errors.push('console:'+m.text())});
  try{
    await page.goto('http://127.0.0.1:8773/wip35-v147-candidate.html',{waitUntil:'domcontentloaded',timeout:30000});
    await page.waitForTimeout(4800);
    stage='resolve-frame';
    ({f,chain}=await deepest(page));
    const expected=['wip35-v147-candidate.html','wip35-v146-candidate.html','wip35-v142-candidate.html','wip35-v141-candidate.html','wip35-v140-candidate.html','wip35-v139-candidate.html','wip35-v138-candidate.html','wip35-v137-candidate.html','index.html'];
    const chainOk=expected.every((x,i)=>chain[i]&&chain[i].includes(x));
    if(!chainOk)throw new Error('candidate chain mismatch: '+JSON.stringify(chain));
    stage='wait-v147';
    await f.waitForFunction(m=>window.LTS_V147_DOCUMENT_ASSOCIATION===m,MARK,{timeout:10000});
    await f.waitForFunction(m=>window.LTS_V144_LEXICAL_BRIDGE===m,BRIDGE,{timeout:10000});

    stage='seed-updates';
    await f.evaluate(()=>{
      window.D={
        input:{queue:[]},
        wealth:{accounts:[{institution:'Itaú'},{institution:'Bradesco'},{institution:'C6'}]},
        flow:{accounts:[]},
        card_operating:{open_cycles:[{card_name:'Visa Aeternum'},{card_name:'Personnalite Black Pontos final 5546'}]},
        card_history:{units:[],cards:[]},
        commitments:{commitments:[{id:'cipo_396',label:'CIPÓ 396'},{id:'volvo',label:'Volvo XC40'}]},
        documentary_commitments:{items:[]},
        updates:{items:[{id:'document_test',type:'document_request',title:'Posição documental',detail:'Teste sintético de associação',priority:1}],maintenance_checks:[]},
        card_classification_review:{pending_groups:0,items:[],category_options:[]},
        semantic_review:{pending_groups:0,items:[]}
      };
      window.V='Atualizações';
      window.renderNav?.();
      window.render();
    });

    stage='open-document-action';
    const docAction=f.locator('.updinput[data-update="document_test"]');
    await docAction.waitFor({state:'attached',timeout:5000});
    const actionSection=docAction.locator('xpath=ancestor::details[1]');
    if(await actionSection.count()){
      const summary=actionSection.locator(':scope > summary');
      await summary.waitFor({state:'visible',timeout:5000});
      await summary.click({timeout:5000});
    }
    await docAction.waitFor({state:'visible',timeout:5000});
    await docAction.click({timeout:5000});
    await f.waitForFunction(()=>String(window.V)==='Entradas',{timeout:5000});
    await f.waitForSelector('#file',{state:'attached',timeout:5000});
    await f.waitForSelector('#v147DocAssociation',{state:'attached',timeout:5000});

    stage='guardrail-status';
    const status=await f.evaluate(()=>window.__LTS_V147_DOCUMENT_ASSOCIATION_STATUS);
    if(!status||status.financial_writer_changed!==false||status.filename_inference!==false||status.permanent_polling!==false)throw new Error('guardrail status invalid: '+JSON.stringify(status));

    stage='bank-association';
    await f.selectOption('#v147DocType','bank_statement');
    await f.fill('#v147DocCompetence','2026-08');
    let s=await state(f);
    if(s.valid||!s.missing.includes('conta/instituição'))throw new Error('bank missing identity was not blocked: '+JSON.stringify(s));
    await f.click('#ubtn');
    let counters=await f.evaluate(()=>({base:window.__LTS_V147_BASE_UPLOAD_CALLS,blocked:window.__LTS_V147_BLOCKED_UPLOADS,msg:document.getElementById('v147DocAssocMsg')?.textContent||''}));
    if(counters.base!==0||counters.blocked<1||!counters.msg.includes('conta/instituição'))throw new Error('blocked upload contract failed: '+JSON.stringify(counters));
    await f.fill('#v147DocTarget','Itaú');s=await state(f);if(!s.valid)throw new Error('valid bank association rejected: '+JSON.stringify(s));
    let ctx=await context(f);
    if(ctx.update_id!=='document_test'||ctx.document_type!=='bank_statement'||ctx.document_association?.entity_type!=='bank_account'||ctx.document_association?.entity_label!=='Itaú'||ctx.document_association?.competence!=='2026-08')throw new Error('bank task_context mismatch: '+JSON.stringify(ctx));

    stage='card-association';
    await f.selectOption('#v147DocType','card_statement');
    await f.fill('#v147DocTarget','Visa Aeternum');
    await f.fill('#v147DocCompetence','2026-09');
    s=await state(f);ctx=await context(f);
    if(!s.valid||ctx.document_association?.entity_type!=='card'||ctx.document_association?.entity_label!=='Visa Aeternum'||ctx.document_association?.competence!=='2026-09')throw new Error('card association mismatch: '+JSON.stringify({s,ctx}));

    stage='financing-association';
    await f.selectOption('#v147DocType','financing_statement');
    await f.fill('#v147DocTarget','CIPÓ 396');
    s=await state(f);if(s.valid||!s.missing.includes('data da posição'))throw new Error('financing missing as-of was not blocked: '+JSON.stringify(s));
    await f.fill('#v147DocAsOf','2026-08-31');s=await state(f);ctx=await context(f);
    if(!s.valid||ctx.document_association?.entity_type!=='financial_commitment'||ctx.document_association?.entity_label!=='CIPÓ 396'||ctx.document_association?.as_of_date!=='2026-08-31')throw new Error('financing context mismatch: '+JSON.stringify({s,ctx}));

    stage='other-document';
    await f.selectOption('#v147DocType','other_financial_document');s=await state(f);ctx=await context(f);
    if(!s.valid||ctx.document_association?.entity_type!=='other'||ctx.document_association?.entity_label!==null)throw new Error('other document guardrail mismatch: '+JSON.stringify({s,ctx}));

    stage='association-history';
    await f.evaluate(()=>{
      window.D.input.queue=[{id:'q1',original_name:'posicao.pdf',status:'needs_review',interpretation:{task_context:{document_association:{version:'guided-document-association-v1',document_type:'financing_statement',entity_type:'financial_commitment',entity_label:'CIPÓ 396',as_of_date:'2026-08-31',review_required:true}}}}];
      window.render();
    });
    await f.waitForSelector('#v147DocAssociation .v147-history',{timeout:3000});
    const hist=await f.locator('#v147DocAssociation .v147-history').innerText();
    if(!hist.includes('CIPÓ 396')||!hist.includes('needs_review'))throw new Error('association history missing: '+hist);

    const result={label,viewport,chain,chainOk,status,blocked:counters,history:hist,errors};
    if(errors.some(x=>/v147|document association/i.test(x)))throw new Error('relevant browser errors: '+JSON.stringify(errors));
    stage='complete';
    return result;
  }catch(err){
    let snapshot=null;
    try{
      snapshot=await f?.evaluate(()=>({
        V:window.V,
        association:window.__LTS_V147_READ_DOCUMENT_ASSOCIATION?.(),
        context:window.inputTaskContext?.(),
        inputctx:window.INPUTCTX||null,
        queue:window.D?.input?.queue||null,
        panel:document.getElementById('v147DocAssociation')?.innerText||null,
        app:(document.getElementById('A')?.innerText||document.body?.innerText||'').slice(0,4000)
      }));
    }catch(snapshotError){snapshot={snapshot_error:String(snapshotError?.stack||snapshotError)}}
    const failure={version:'v147-guided-document-association',marker:MARK,pass:false,label,viewport,stage,chain,snapshot,errors,fatal:String(err?.stack||err)};
    try{fs.writeFileSync('v147-document-association-smoke-result.json',JSON.stringify(failure,null,2))}catch(_){}
    throw err;
  }finally{await browser.close()}
}

(async()=>{
  const desktop=await run({width:1440,height:900},'desktop');
  const mobile=await run({width:390,height:844},'mobile');
  const out={version:'v147-guided-document-association',marker:MARK,desktop,mobile,pass:true};
  fs.writeFileSync('v147-document-association-smoke-result.json',JSON.stringify(out,null,2));
  console.log('v147_document_association_smoke=PASS');
})().catch(err=>{console.error(err);process.exit(1)});
