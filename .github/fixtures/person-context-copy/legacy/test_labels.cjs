'use strict';
const fs=require('fs'),vm=require('vm'),path=require('path'),assert=require('assert'),crypto=require('crypto'),cp=require('child_process');
const ROOT=process.cwd(),BASE=path.join(ROOT,'releases/v282'),C=path.join(process.cwd(),'releases/v283');
const checks=[];function check(name,pass){checks.push({name,pass:!!pass});assert(pass,name)}
const read=(dir,name)=>fs.readFileSync(path.join(dir,name),'utf8');
function ctx(helper){const c={};c.window=c;vm.createContext(c);vm.runInContext(read(helper,'lts-category-display.js'),c);return c}
const before=ctx(BASE),after=ctx(C),display=after.LTSCategoryDisplay,old=before.LTSCategoryDisplay;
const examples=[
 ['Assinatura','Assinaturas'],['Assinaturas','Assinaturas'],['Lucas — Assinatura','Assinaturas'],['Larissa - Assinatura','Larissa — Assinaturas'],
 ['estacionamento e pedágio','Estacionamento e Pedágio'],['Estacionamento E Pedágio','Estacionamento e Pedágio'],['Estacionamento e Pedágio','Estacionamento e Pedágio'],
 ['Tarifas bancárias','Tarifas Bancárias'],['Tarifas Bancárias','Tarifas Bancárias'],['farmácia','farmácia'],['Farmácia','Farmácia'],
 ['Benjamin — Benjamin - Estrutura e manutenção','Benjamin — Estrutura e manutenção'],['Benjamin - Estrutura e manutenção','Benjamin — Estrutura e manutenção'],
 ['Benjamin — Benjamin – Benjamin - Vestuário','Benjamin — Imagem e cuidados pessoais'],
 ['Vestuário','Imagem e cuidados pessoais'],['Imagem','Imagem'],['Organon Despesas','Despesas Organon'],['Reembolso Organon','Reembolso Organon'],
 ['Tarifas e Juros','Tarifas e Juros'],['Estacionamento','Estacionamento'],['Veículos - Estacionamento','Veículos - Estacionamento'],['Restaurantes e Lazer','Restaurantes e Lazer'],
 ['Rafiki','Rafiki'],['Organon','Organon'],['Nome & <desconhecido>','Nome & <desconhecido>'],['Benjamin — Larissa - Saúde','Benjamin — Larissa - Saúde']
];
for(const [input,expected]of examples)check('display:'+input,display.category(input)===expected);
check('all_examples_idempotent',examples.every(([v])=>display.category(display.category(v))===display.category(v)));
check('flow_person_not_duplicated',display.flow(examples[11][0],'Benjamin')==='Benjamin — Estrutura e manutenção');
check('flow_keeps_explicit_conflict',display.flow('Benjamin — Saúde','Larissa')==='Larissa · Benjamin — Saúde');
check('flow_idempotent_without_conflicting_explicit_people',examples.every(([v])=>['','Lucas','Benjamin','Larissa','Rafiki','Não atribuído'].filter(p=>!(/^(Larissa|Benjamin|Rafiki)/.test(v))||!p||p==='Lucas'||p==='Não atribuído'||v.startsWith(p)).every(p=>display.flow(display.flow(v,p),p)===display.flow(v,p))));
check('conflicting_flow_people_keep_existing_v282_behavior',display.flow(display.flow('Benjamin — Saúde','Larissa'),'Larissa')===old.flow(old.flow('Benjamin — Saúde','Larissa'),'Larissa'));
check('original_reproduces_benjamin_bug',old.category(examples[11][0])===examples[11][0]);
check('original_reproduces_assinatura_gap',old.category('Assinatura')==='Assinatura');
// Synthetic aggregate partitions only. No user row IDs, values or receipts in this gate.
const groups=[
 {category:'Assinatura',management_group:'Assinatura',management_subgroup:'Assinatura',row_count:1,amount_total:7},
 {category:'Assinaturas',management_group:'Assinaturas',management_subgroup:'Assinaturas',row_count:1,amount_total:11},
 {category:'Tarifas bancárias',management_group:'Tarifas bancárias',management_subgroup:'Tarifas bancárias',row_count:1,amount_total:0},
 {category:'Tarifas Bancárias',management_group:'Tarifas Bancárias',management_subgroup:'Tarifas Bancárias',row_count:1,amount_total:-2},
 {category:'Estacionamento E Pedágio',management_group:'Estacionamento E Pedágio',management_subgroup:'Estacionamento E Pedágio',row_count:1,amount_total:5},
 {category:'Farmácia',management_group:'Farmácia',management_subgroup:'Farmácia',row_count:1,amount_total:3},
 {category:'Imagem',management_group:'Imagem',management_subgroup:'Imagem',row_count:1,amount_total:6},
 {category:'Vestuário',management_group:'Vestuário',management_subgroup:'Vestuário',row_count:1,amount_total:4}
];
const frozen=JSON.stringify(groups);groups.forEach(r=>display.category(r.category));
check('synthetic_data_not_mutated',JSON.stringify(groups)===frozen);
check('only_benjamin_duplicate_rule_expanded',display.category('Larissa — Larissa - Saúde')===old.category('Larissa — Larissa - Saúde'));
check('no_new_pharmacy_case_or_semantic_mapping',display.category('farmácia')===old.category('farmácia')&&display.category('Farmácia')==='Farmácia');
check('semantic_exclusions_unchanged',['Saúde','Farmácia','Imagem','Vestuário','Tarifas e Juros','Estacionamento','Veículos - Estacionamento','Reembolso Organon','Organon','Organon Despesas'].every(v=>display.category(v)===old.category(v)));
const escape=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const normalize=v=>String(v??'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim().replace(/\s+/g,' ');
function section(dir,file,start,end){const s=read(dir,file),a=s.indexOf(start),b=s.indexOf(end,a);assert(a>=0&&b>a,'extract '+start);return s.slice(a,b)}
function review(dir){const c=ctx(dir);Object.assign(c,{arr:v=>Array.isArray(v)?v:[],finite:v=>v==null?null:Number(v),sum:vs=>vs.reduce((n,v)=>n+Number(v),0),escape,normalize,money:v=>Number(v).toFixed(2),state:{review:{drafts:new Map(),data:{beneficiary_options:[]}},categoryView:'nature'}});vm.runInContext(section(dir,'lts-v181-regression-closure.js','  function optionRows(','  async function ensureReview(')+section(dir,'lts-v181-regression-closure.js','  function reviewFields(','  function reviewPanel(')+section(dir,'lts-v181-regression-closure.js','  function categorySourceRows(','  function decorateCategories('),c);return c}
const r0=review(BASE),r1=review(C),values=['Assinatura','Assinaturas','Tarifas bancárias','Tarifas Bancárias','Imagem','Vestuário','Farmácia','Saúde','Nome & <desconhecido>'];
const parseOptions=html=>[...html.matchAll(/<option value="([^"]*)"([^>]*)>([^<]*)<\/option>/g)].map(m=>({value:m[1],selected:m[2].includes('selected'),label:m[3]}));
const a=parseOptions(r0.optionRows(values,'Selecione','Assinatura')),b=parseOptions(r1.optionRows(values,'Selecione','Assinatura',display.category));
check('review_option_raw_values_selection_preserved',JSON.stringify(a.map(({value,selected})=>({value,selected})))===JSON.stringify(b.map(({value,selected})=>({value,selected}))));
check('review_does_not_deduplicate_by_display',b.filter(x=>x.label==='Assinaturas').length===2&&b.filter(x=>x.label==='Tarifas Bancárias').length===2);
check('review_escapes_display_after_formatting',b.find(x=>x.value==='Nome &amp; &lt;desconhecido&gt;').label==='Nome &amp; &lt;desconhecido&gt;');
check('noncategory_options_unchanged',r0.optionRows(['Lucas','Larissa','Casa'],'Pessoa','Lucas')===r1.optionRows(['Lucas','Larissa','Casa'],'Pessoa','Lucas'));
const reviewData={beneficiary_options:['Lucas','Larissa'],property_options:['Casa'],category_options:['Farmácia','Saúde','Assinatura','Assinaturas']};
r0.state.review.drafts.set('occurrence',{category:'Farmácia'});r1.state.review.drafts.set('occurrence',{category:'Farmácia'});
const draftRow={key:'occurrence',question_kind:'property_purpose',suggestion:{category:'Saúde'}};
const d0=parseOptions(r0.reviewFields(draftRow,reviewData)),d1=parseOptions(r1.reviewFields(draftRow,reviewData));
check('explicit_draft_preferred_to_suggestion',d1.find(x=>x.selected)?.value==='Farmácia'&&d0.find(x=>x.selected)?.value==='Farmácia');
const rawGroups={management_groups:groups.map(r=>({name:r.management_group,total:r.amount_total,subgroups:[{name:r.management_subgroup,total:r.amount_total}]}))};
check('semantic_dimensions_function_unchanged',section(BASE,'lts-v181-regression-closure.js','  function categorySourceRows(','  function categorySections(')===section(C,'lts-v181-regression-closure.js','  function categorySourceRows(','  function categorySections('));
const html0=r0.categorySections(rawGroups),html1=r1.categorySections(rawGroups),attrs=html=>[...html.matchAll(/data-v181-detail-(?:group|subgroup)="[^"]*"/g)].map(m=>m[0]);
check('dimension_drilldown_keys_and_order_unchanged',JSON.stringify(attrs(html0))===JSON.stringify(attrs(html1)));
check('dimension_rendering_same_button_and_header_count',(html0.match(/<button/g)||[]).length===(html1.match(/<button/g)||[]).length&&(html0.match(/<h3>/g)||[]).length===(html1.match(/<h3>/g)||[]).length);
function rank(dir){const c=ctx(dir);Object.assign(c,{arr:v=>Array.isArray(v)?v:[],escape,money:v=>Number(v).toFixed(2)});vm.runInContext(section(dir,'lts-v179-cash-recovery.js','  function reportRank(','  function dashboard178('),c);return c.reportRank(rawGroups,999,true)}
const p0=rank(BASE),p1=rank(C),rankKeys=s=>[...s.matchAll(/data-group="[^"]*"/g)].map(m=>m[0]);
check('rank_raw_drilldown_keys_and_order_unchanged',JSON.stringify(rankKeys(p0))===JSON.stringify(rankKeys(p1)));
check('rank_uniform_display_keeps_duplicate_raw_groups',p1.includes('data-group="Assinatura">Assinaturas</button>')&&p1.includes('data-group="Assinaturas">Assinaturas</button>'));
function monthly(dir,label,text){const c=ctx(dir);Object.assign(c,{safe:escape,monthText:v=>v});vm.runInContext(section(dir,'lts-v183-v182-feedback-safe.js','    function detailButton(','    function detailRange('),c);return c.detailButton(label,100,'2026-10',text)}
check('monthly_raw_key_preserved_and_caption_uniform',monthly(C,'Assinatura','Assinatura').includes('data-group="Assinatura"')&&monthly(C,'Assinatura','Assinatura').endsWith('>Assinaturas</button>'));
check('monthly_money_text_unchanged',monthly(C,'Assinatura','R$ 100,00').endsWith('>R$ 100,00</button>'));
const manifest=JSON.parse(read(__dirname,'manifest.json'));
for(const asset of manifest.assets){check('base_release_unmodified:'+asset.asset,crypto.createHash('sha256').update(read(BASE,asset.asset)).digest('hex')===asset.base_sha256);cp.execFileSync(process.execPath,['--check',path.join(C,asset.asset)]);check('syntax:'+asset.asset,true)}
const result={scope:'Local source/receipt/VM tests. No SQL, external mutation, browser QA or release.',assertion_count:checks.length,all_pass:true,checks};
fs.writeFileSync(path.join(__dirname,'test-results.json'),JSON.stringify(result,null,2)+'\n');
console.log('PASS '+checks.length+' local labels/precedence/invariants checks');
