'use strict';
// Retain the complete historical ranking/financial suite. The approved V423
// scoped-presentation alias changes one visible label, never its source key.
// The legacy fallback has no scoped presentation and retains its prior names.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const file=path.join(__dirname,'lts_v385_browser.cjs');let source=fs.readFileSync(file,'utf8');
const bytes=Buffer.from(source),hash=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+bytes.length+'\0'),bytes])).digest('hex');
assert.equal(hash,'ce00f1e52d809f81da8ffc6e1dbee444a6df443d','Review this adapter if the historical suite changes');
const previous='assert.deepEqual(geometry.map(x=>x.name),groups);';
const replacement="const visibleGroups=groups.map(name=>['/releases/v423/','/releases/v425/','/releases/v433/','/releases/v436/','/releases/v439/','/releases/v440/'].some(p=>new URL(f.url()).pathname.includes(p))&&variant!=='legacy'&&name==='Patrimônio e financiamentos'?'Financiamentos e empréstimos':name);assert.deepEqual(geometry.map(x=>x.name),visibleGroups);";
assert.equal(source.split(previous).length,2,'Exactly one visible-name assertion is adapted');
source=source.replace(previous,replacement);
const horizonVersions='421|423|425|433|436|439';
assert.equal(source.split(horizonVersions).length,2,'Exactly one full-horizon layout condition');
source=source.replace(horizonVersions,horizonVersions+'|440');
assert(source.includes('assert.equal(detailRequests.at(-1).args.p_scope.macrogroup,groups[0])'),'Original filter-key assertion is retained');
assert(source.includes('assert.deepEqual(geometry.map(x=>x.text),values.map(money))'),'Monetary assertions are retained');
console.log(JSON.stringify({suite:'v385-rankings',approved_display_alias:'Financiamentos e empréstimos',legacy_names_preserved:true,source_keys_and_financial_assertions_preserved:true}));
module._compile(source,file);
