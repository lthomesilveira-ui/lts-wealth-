'use strict';
// Preserve the exact reviewed projection suite; inspect secondary error detail
// through Options while asserting that the material warning remains visible.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const filename=path.join(__dirname,'lts_v412_projection_browser.cjs');let source=fs.readFileSync(filename,'utf8');
const data=Buffer.from(source),sha=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+data.length+'\0'),data])).digest('hex');
assert.equal(sha,'6f9e7b13e55a1319da2b4a3dfe878554ec4b1413','Review adapter when original acceptance changes');
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
// V440 preserves the same Options layout; keep the frozen historical suite intact.
const conciseVersions='417|421|423|425|433|436|439';
const optionsVersion="'/releases/v439/'";
assert.equal(source.split(conciseVersions).length,2);
assert.equal(source.split(optionsVersion).length,2);
source=source.replace(conciseVersions,conciseVersions+'|440|441|442');
source=source.replace(optionsVersion,optionsVersion+",'/releases/v440/','/releases/v441/','/releases/v442/'");
assert(source.includes("'old identity response cannot replace new identity data'"));
assert(source.includes("'refresh cannot change server amounts in the browser'"));
assert(source.includes("malformed_clear_values:true"));
console.log(JSON.stringify({suite:'v412-projection',error_details_in_options:true,main_warning_visible:true,financial_and_auth_assertions_retained:true}));
module._compile(source,filename);
