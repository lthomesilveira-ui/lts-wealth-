'use strict';
// The original V441 placement is historical. Keep every financial, save-race
// and Flow assertion on that immutable app; V442 has its own current-entry suite.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const file=path.join(__dirname,'lts_v441_browser.cjs');let s=fs.readFileSync(file,'utf8');
const b=Buffer.from(s);assert.equal(crypto.createHash('sha1').update(Buffer.concat([Buffer.from('blob '+b.length+'\0'),b])).digest('hex'),'4c8b61450fe38dcc39ae2d13020493418da4ed59');
const old="f=await open(h,'v441',true);";assert.equal(s.split(old).length,2);
s=s.replace(old,"f=await open(h,'v441',false);");module._compile(s,file);
