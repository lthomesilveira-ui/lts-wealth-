'use strict';

const fs=require('node:fs');
const crypto=require('node:crypto');
const read=file=>fs.readFileSync(file,'utf8');
const assert=(value,message)=>{if(!value)throw new Error(message)};

const candidate=read('wip35-v173-candidate.html');
const js=read('lts-v173-v172-feedback.js');
const css=read('lts-v173-v172-feedback.css');
const register=read('backups/V173_V172_USER_FEEDBACK_REGISTER_2026-09-18.md');
const indexHash=crypto.createHash('sha256').update(fs.readFileSync('index.html')).digest('hex');

assert(indexHash==='cca36731258680cc15a73fbad61c90ddf803358b741fd3ef58fefe5419eb688b','protected index.html changed');
for(const token of ['V173','lts-v172-v171-review.js','lts-v173-v172-feedback.js','noindex,nofollow'])assert(candidate.includes(token),'candidate missing '+token);
assert(candidate.indexOf('lts-v173-v172-feedback.js')>candidate.indexOf('lts-v172-v171-review.js'),'V173 overlay must load after V172');
for(const token of [
  "version:'v173'","base_version:'v172'",'public_index_changed:false',
  'category_select:true','canonical_category_inference:true','redundant_composition_suppressed:true',
  "'Família'","'Volvo XC40'",'classificad[oa]','Selecione uma categoria',
  "p==='financiamento imobiliario'","p==='financiamento de veiculo'","unique.length<=1"
])assert(js.includes(token),'runtime missing '+token);
for(const forbidden of ['S.rpc=','lts_browser_apply_reviewed_input_v1','financial_events','insert into','update public.'])assert(!js.includes(forbidden),'V173 overlay must stay read/presentation-only: '+forbidden);
for(const token of ['V173 · Homologação','.v173-category-select','.v173-category-hint'])assert(css.includes(token),'style missing '+token);
for(const token of ['F01','F02','F03','F04','F05','YES: V172 remains the stable homologation baseline'])assert(register.includes(token),'feedback register missing '+token);
console.log(JSON.stringify({pass:true,version:'v173-v172-feedback',public_index_unchanged:true,read_only_overlay:true,category_select:true,meaningful_composition:true},null,2));
