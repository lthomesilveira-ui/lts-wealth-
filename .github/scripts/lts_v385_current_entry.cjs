'use strict';
// Retain the complete historical ranking/financial suite. The approved V423
// scoped-presentation alias changes one visible label, never its source key.
// The legacy fallback has no scoped presentation and retains its prior names.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const file=path.join(__dirname,'lts_v385_browser.cjs');let source=fs.readFileSync(file,'utf8');
const bytes=Buffer.from(source),hash=crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+bytes.length+'\0'),bytes])).digest('hex');
assert.equal(hash,'313cf57f091f62269781735cb4d6583512b059d8','Review this adapter if the historical suite changes');
const previous='assert.deepEqual(geometry.map(x=>x.name),groups);';
const replacement="const visibleGroups=groups.map(name=>new URL(f.url()).pathname.includes('/releases/v423/')&&variant!=='legacy'&&name==='Patrimônio e financiamentos'?'Financiamentos e empréstimos':name);assert.deepEqual(geometry.map(x=>x.name),visibleGroups);";
assert.equal(source.split(previous).length,2,'Exactly one visible-name assertion is adapted');
source=source.replace(previous,replacement);
assert(source.includes('assert.equal(detailRequests.at(-1).args.p_scope.macrogroup,groups[0])'),'Original filter-key assertion is retained');
assert(source.includes('assert.deepEqual(geometry.map(x=>x.text),values.map(money))'),'Monetary assertions are retained');
console.log(JSON.stringify({suite:'v385-rankings',approved_display_alias:'Financiamentos e empréstimos',legacy_names_preserved:true,source_keys_and_financial_assertions_preserved:true}));
module._compile(source,file);
