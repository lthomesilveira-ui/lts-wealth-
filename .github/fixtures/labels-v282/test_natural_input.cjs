'use strict';
const fs=require('fs'),vm=require('vm'),crypto=require('crypto'),assert=require('assert'),path=require('path');
const basePath=path.join(process.cwd(),'releases/v282/lts-v183-v173-feedback-safe.js');
const helperPath=path.join(__dirname,'candidate/lts-category-display.js');
const candidatePath=path.join(__dirname,'candidate/lts-v183-v173-feedback-safe.js');
const before=fs.readFileSync(basePath,'utf8'),after=fs.readFileSync(candidatePath,'utf8');
const old="options.map(label=>'<option value=\"'+esc(label)+'\">'+esc(label)+'</option>').join('')";
const revised="options.map(label=>'<option value=\"'+esc(label)+'\">'+esc(window.LTSCategoryDisplay.category(label))+'</option>').join('')";
const checks=[];function check(name,pass){checks.push({name,pass});assert(pass,name)}
check('baseline_matches_verified_release_asset',crypto.createHash('sha256').update(before).digest('hex')==='dd75d9e5b5583c44e809586531f5fa07fa20ccb47942017a5d381359e0f2ca35');
check('only_display_expression_changes',after===before.replace(old,revised)&&before.split(old).length===2);
function run(source,initial,phrase=''){
 let select=null;
 const data=JSON.parse(JSON.stringify(initial));
 const field={tagName:'INPUT',value:'Organon Despesas',className:'',replaceWith(node){select=node}};
 const document={getElementById(id){return id==='v168NlCategory'?field:id==='v168NlPhrase'?{value:phrase}:null},createElement(tag){return {tagName:tag.toUpperCase(),handlers:{},setAttribute(){},addEventListener(kind,fn){this.handlers[kind]=fn},closest(){return null},innerHTML:'',value:''}}};
 const context={document,v168:data};context.window=context;vm.createContext(context);vm.runInContext(fs.readFileSync(helperPath,'utf8'),context);
 vm.runInContext(source.split('\n').slice(9,77).join('\n')+'\nglobalThis.options=categoryOptions();globalThis.mentions=mentionedCategory;decorateNatural();',context);
 const options=[...select.innerHTML.matchAll(/<option value="([^"]*)">([^<]*)<\/option>/g)].map(m=>({value:m[1],label:m[2]}));
 return {data,options,values:options.map(o=>o.value),selected:select.value,mention:p=>context.mentions(p,context.options),choose(value){select.value=value;select.handlers.change();return data.nl?.preview?.category}};
}
const basic={nl:{preview:{category:'initial',missing:[]}}};
const a=run(before,basic),b=run(after,basic);
const label=(r,key)=>r.options.find(x=>x.value===key)?.label;
check('all_seed_option_values_unchanged',JSON.stringify(a.values)===JSON.stringify(b.values));
check('seed_option_count_unchanged',a.options.length===b.options.length);
check('selection_keeps_raw_key',a.selected===b.selected&&b.selected==='Organon Despesas');
check('organon_label_is_approved_display',label(a,'Organon Despesas')==='Organon Despesas'&&label(b,'Organon Despesas')==='Despesas Organon');
check('organon_change_handler_preserves_write_value',a.choose('Organon Despesas')===b.choose('Organon Despesas')&&b.choose('Organon Despesas')==='Organon Despesas');
check('vestuario_label_uses_existing_helper',label(b,'Vestuário')==='Imagem e cuidados pessoais');
check('vestuario_change_handler_preserves_stored_key',a.choose('Vestuário')===b.choose('Vestuário')&&b.choose('Vestuário')==='Vestuário');
check('reimbursement_stays_distinct',label(b,'Reembolso Organon')==='Reembolso Organon');
check('rafiki_legacy_preserved',label(b,'Rafiki')==='Rafiki');
check('unknown_pharmacy_not_reclassified',label(b,'Farmácia')==='Farmácia');
check('empty_option_unchanged',JSON.stringify(a.options[0])===JSON.stringify(b.options[0]));
const dynamic={nl:{preview:{category:'initial',missing:[]}},expense:{data:{management_groups:[{source_categories:[{name:'Despesas Organon'},{name:'Company Car'},{name:'Imagem'},{name:'Larissa — Vestuário'},{name:'Nome & desconhecido'},{name:'Assinatura'},{name:'Assinaturas'},{name:'Estacionamento E Pedágio'},{name:'Tarifas bancárias'},{name:'Benjamin — Benjamin - Estrutura e manutenção'}]}]}}};
const c=run(before,dynamic),d=run(after,dynamic);
check('all_dynamic_option_values_unchanged',JSON.stringify(c.values)===JSON.stringify(d.values));
check('aliases_not_merged_by_display',d.values.includes('Organon Despesas')&&d.values.includes('Despesas Organon')&&label(d,'Organon Despesas')===label(d,'Despesas Organon'));
check('company_car_preserved_when_dynamic',label(d,'Company Car')==='Company Car');
check('imagem_key_and_display_distinct_from_vestuario',label(d,'Imagem')==='Imagem'&&d.values.includes('Imagem')&&d.values.includes('Vestuário'));
check('explicit_person_displayed_once',label(d,'Larissa — Vestuário')==='Larissa — Imagem e cuidados pessoais');
check('unknown_name_still_html_escaped',label(d,'Nome &amp; desconhecido')==='Nome &amp; desconhecido');
check('existing_natural_alias_normalizer_unchanged',!d.values.includes('Assinatura')&&!c.values.includes('Assinatura')&&d.values.includes('Assinaturas')&&label(d,'Assinaturas')==='Assinaturas');
check('duplicate_display_does_not_remove_benjamin_option_keys',d.values.includes('Benjamin - Estrutura e manutenção')&&d.values.includes('Benjamin — Benjamin - Estrutura e manutenção')&&label(d,'Benjamin - Estrutura e manutenção')===label(d,'Benjamin — Benjamin - Estrutura e manutenção'));
for(const raw of ['Assinaturas','Estacionamento E Pedágio','Tarifas Bancárias','Benjamin — Benjamin - Estrutura e manutenção'])check('new_label_roundtrip_preserves_raw_'+raw,d.choose(raw)===raw&&c.choose(raw)===raw);
const phrases=['categoria Organon Despesas','categoria Despesas Organon','categoria Imagem e cuidados pessoais','categoria Company Car'];
check('natural_language_inference_unchanged',phrases.every(p=>c.mention(p)===d.mention(p)));
for(const phrase of ['categoria Organon Despesas','categoria Vestuário']){
 const original=run(before,dynamic,phrase),candidate=run(after,dynamic,phrase);
 check('inferred_preview_unchanged_'+phrase,JSON.stringify(original.data.nl.preview)===JSON.stringify(candidate.data.nl.preview)&&original.selected===candidate.selected);
}
const result={mode:'original_and_candidate_exact_functions_with_minimal_synthetic_DOM',sql_executed:false,browser_qa:false,live_write_executed:false,assertion_count:checks.length,checks,all_pass:true,limitations:['No authenticated production DOM verified.','No server writer called; raw select values and actual preview change handler compared.','Same displayed name can occur twice when distinct raw alias keys are supplied; keys were intentionally not merged.','Bare Organon remains unchanged by the existing helper; this proposal does not expand semantic aliases.']};
fs.writeFileSync(path.join(__dirname,'natural-input-test-results.json'),JSON.stringify(result,null,2)+'\n');console.log('PASS '+checks.length+' original/candidate presentation invariants');
