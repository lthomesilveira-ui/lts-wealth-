'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const hash=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
function build(base='releases/v383'){
 const input=fs.readFileSync(base+'/app.html','utf8'),tags=[...input.matchAll(/<script\b[^>]*>[\s\S]*?<\/script>/g)],groups=[];
 let group=null;
 function flush(){if(group){groups.push(group);group=null;}}
 for(const tag of tags){
  const source=tag[0].match(/\bsrc="([^"]+)"/);
  if(!source){flush();continue;}
  if(group&&input.slice(group.end,tag.index).trim())flush();
  if(!group)group={start:tag.index,end:0,sources:[]};
  assert(!source[1].includes('://'));const file=source[1].split('?')[0];assert.equal(path.basename(file),file);
  const text=fs.readFileSync(base+'/'+file,'utf8');
  group.sources.push({url:source[1],file,text,sha256:hash(text)});group.end=tag.index+tag[0].length;
 }flush();
 assert.deepEqual(groups.map(g=>g.sources.length),[41,18]);
 const bundles=groups.map((g,i)=>({file:'lts-v384-startup-'+(i+1)+'.js',sources:g.sources.map(({url,file,sha256})=>({url,file,sha256})),content:g.sources.map(x=>';\n/* LTS V384: '+x.file+' */\n'+x.text+'\n;\n').join('')}));
 // Replace from the end so source offsets remain valid before changing the badge.
 let html=input;
 for(let i=groups.length-1;i>=0;i--)html=html.slice(0,groups[i].start)+'<script src="'+bundles[i].file+'"></script>'+html.slice(groups[i].end);
 html=html.replaceAll('V383','V384').replace('v383-flow-default-five-20261031','v384-startup-20261031');
 html=html.replace('</head>',bundles.map(x=>'<link rel="preload" href="'+x.file+'" as="script">').join('\n')+'\n</head>');
 return {html,bundles};
}
module.exports={build,hash};
if(require.main===module){
 const {html,bundles}=build(),root='releases/v384';fs.mkdirSync(root,{recursive:true});fs.writeFileSync(root+'/app.html',html);for(const b of bundles)fs.writeFileSync(root+'/'+b.file,b.content);
 console.log(JSON.stringify({pass:true,source_scripts:59,startup_bundles:bundles.length,ordered_source_hashes:bundles.flatMap(b=>b.sources).length}));
}
