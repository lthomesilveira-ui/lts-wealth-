const fs = require('fs');

const files = [
  'index.html',
  'wip35-v137-candidate.html','wip35-v138-candidate.html','wip35-v138-cockpits.js',
  'wip35-v139-candidate.html','wip35-v140-candidate.html','wip35-v141-candidate.html',
  'wip35-v142-candidate.html','wip35-v142-ux.js','wip35-v142-planning-bridge-v2.js',
  'wip35-v142-dashboard-cockpit.js','wip35-v142-liquidity-ui-v2.js','wip35-v142-final-polish.js',
  'wip35-v143-candidate.html','wip35-v143-life-real.js','wip35-v143-feedback-polish.js','wip35-v143-ownership.js'
].filter(f => fs.existsSync(f));
const sources = files.map(f => ({file:f,text:fs.readFileSync(f,'utf8')}));
const all = sources.map(x=>`\n/* FILE:${x.file} */\n${x.text}`).join('\n');

function clean(v){return String(v||'').replace(/\\(["'])/g,'$1').replace(/^['"]|['"]$/g,'')}
function attrs(raw){
  const out={};
  const re=/([:\w-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g;
  let m; while((m=re.exec(raw))) out[m[1].toLowerCase()] = clean(m[2] ?? m[3] ?? m[4] ?? '');
  return out;
}
function escRe(s){return String(s).replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}
function classWired(cls){
  const c=escRe(cls);
  const patterns=[
    new RegExp(`querySelector(?:All)?\\(\\s*['\"][^'\"]*\\.${c}(?:[^\\w-]|$)`,'m'),
    new RegExp(`closest\\(\\s*['\"]\\.${c}(?:[^\\w-]|$)`,'m'),
    new RegExp(`matches\\(\\s*['\"]\\.${c}(?:[^\\w-]|$)`,'m'),
    new RegExp(`getElementsByClassName\\(\\s*['\"]${c}['\"]`,'m')
  ];
  return patterns.some(r=>r.test(all));
}
function idWired(id){
  const i=escRe(clean(id));
  if(!i)return false;
  return [
    new RegExp(`getElementById\\(\\s*['\"]${i}['\"]`,'m'),
    new RegExp(`querySelector(?:All)?\\(\\s*['\"]#${i}(?:[^\\w-]|$)`,'m'),
    new RegExp(`(?:^|[^\\w$])${i}\\.onclick\\s*=`,'m'),
    new RegExp(`(?:^|[^\\w$])${i}\\.on(?:change|input|submit|click|keydown|keyup)\\s*=`,'m'),
    new RegExp(`(?:^|[^\\w$])${i}\\.addEventListener\\s*\\(`,'m')
  ].some(r=>r.test(all));
}
function dataWired(name){
  const n=String(name).toLowerCase();
  const prop=n.replace(/^data-/,'').replace(/-([a-z])/g,(_,x)=>x.toUpperCase());
  const nr=escRe(n), pr=escRe(prop);
  return [
    new RegExp(`\\[${nr}(?:[=\\]])`,'m'),
    new RegExp(`dataset\\.${pr}(?:[^\\w]|$)`,'m'),
    new RegExp(`getAttribute\\(\\s*['\"]${nr}['\"]`,'m'),
    new RegExp(`hasAttribute\\(\\s*['\"]${nr}['\"]`,'m')
  ].some(r=>r.test(all));
}

const buttons=[];
for(const s of sources){
  const re=/<button\b([^>]*)>/gi; let m;
  while((m=re.exec(s.text))){
    const a=attrs(m[1]);
    const id=clean(a.id||'');
    const classes=clean(a.class||'').split(/\s+/).filter(Boolean).filter(x=>!x.includes('${'));
    const dataNames=Object.keys(a).filter(k=>k.startsWith('data-'));
    const inline=Object.keys(a).some(k=>k.startsWith('on') && String(a[k]).trim());
    const disabled=Object.prototype.hasOwnProperty.call(a,'disabled');
    const reasons=[];
    if(inline) reasons.push('inline-handler');
    if(id && idWired(id)) reasons.push(`id:${id}`);
    for(const c of classes) if(classWired(c)) reasons.push(`class:${c}`);
    for(const d of dataNames) if(dataWired(d)) reasons.push(`data:${d}`);
    const templateDynamic = m[1].includes('${');
    const identifiable = !!id || classes.length>0 || dataNames.length>0 || inline;
    const wired = disabled || inline || reasons.length>0 || templateDynamic;
    buttons.push({file:s.file,offset:m.index,id,classes,data:dataNames,disabled,templateDynamic,identifiable,wired,reasons,tag:m[0].slice(0,260)});
  }
}

const unresolved=buttons.filter(b=>b.identifiable && !b.wired);
const anonymous=buttons.filter(b=>!b.identifiable && !b.disabled);
const byFile={}; for(const b of buttons){byFile[b.file]=(byFile[b.file]||0)+1}
const result={
  version:'button-contract-audit-v3-v143-surface-census',
  files,
  buttonCount:buttons.length,
  identifiableCount:buttons.filter(b=>b.identifiable).length,
  wiredCount:buttons.filter(b=>b.wired).length,
  unresolvedCount:unresolved.length,
  anonymousCount:anonymous.length,
  byFile,
  unresolved,
  anonymous:anonymous.slice(0,50),
  note:'Static wiring census includes v143 candidate and feedback layers. It verifies identifiable button templates have inline/id/class/data/direct-global event wiring somewhere in the composed source. It does not replace runtime navigation, authenticated click-through or financial writer transaction QA.'
};
fs.writeFileSync('button-contract-audit-result.json',JSON.stringify(result,null,2));
console.log(JSON.stringify(result,null,2));
if(unresolved.length) process.exit(1);
