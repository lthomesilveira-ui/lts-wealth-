'use strict';
// Preserve the exact reviewed projection suite; inspect secondary error detail
// through Options while asserting that the material warning remains visible.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const filename=path.join(__dirname,'lts_v412_projection_browser.cjs');let source=fs.readFileSync(filename,'utf8');
const data=Buffer.from(source),sha=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+data.length+'\0'),data])).digest('hex');
assert.equal(sha,'be98ae7686fe0270c10e642c6bf75b3901dd7987','Review adapter when original acceptance changes');
const assertion="   assert.match(await panel().innerText(),/Não foi possível conferir/);assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model),null);}";
const replacement=`   if(optionsLayout){
    const notice=f.locator('#v425-flow-attention');
    assert(await notice.isVisible(),'failed projection remains visible in main Flow');
    assert.match(await notice.innerText(),/Projeções não verificadas/);
    await showFlowOptions(f);
   }
   assert.match(await panel().innerText(),/Não foi possível conferir/);
   assert.equal(await f.evaluate(()=>__LTS_V412_PROJECTION.model),null);
   if(optionsLayout)await f.locator('.v425-options>summary').click();
  }`;
assert.equal(source.split(assertion).length,2,'Only the initial Flow error inspection is adapted');
source=source.replace(assertion,replacement);
assert(source.includes("'old identity response cannot replace new identity data'"));
assert(source.includes("'refresh cannot change server amounts in the browser'"));
assert(source.includes("malformed_clear_values:true"));
console.log(JSON.stringify({suite:'v412-projection',error_details_in_options:true,main_warning_visible:true,financial_and_auth_assertions_retained:true}));
module._compile(source,filename);
