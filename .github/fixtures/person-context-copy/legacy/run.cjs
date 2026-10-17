'use strict';
const fs=require('node:fs'),path=require('node:path'),cp=require('node:child_process'),assert=require('node:assert/strict');
assert(fs.existsSync(path.join(process.cwd(),'releases/v282/manifest.json')),'Run from package/repository root containing releases/v282');
assert(fs.existsSync(path.join(process.cwd(),'releases/v283/lts-category-display.js')),'Run against the real release assets in releases/v283; no fixture overlay');
const scripts=[['test_labels.cjs',65],['test_natural_input.cjs',28],['test_v282_roundtrip.cjs',26],['test-canonical.cjs',69],['test_legacy_drilldown.cjs',5],['test_monthly_collision.cjs',5]];
for(const [name] of scripts)cp.execFileSync(process.execPath,[path.join(__dirname,name)],{cwd:process.cwd(),stdio:'inherit'});
cp.execFileSync(process.execPath,['--check',path.join(__dirname,'playwright-label-assertions.cjs')],{stdio:'inherit'});
console.log(JSON.stringify({pass:true,assertions:scripts.reduce((sum,[,n])=>sum+n,0),browserRun:false,sqlRun:false,fixtureData:'synthetic only'}));
