'use strict';
// Independent synthetic review. Executes exact final source functions, no real records.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const path=process.argv[2]||'releases/v269/lts-v226-card-composition.js';
const source=fs.readFileSync(path,'utf8');
function extract(name,next){const a=source.indexOf('    function '+name+'('),b=source.indexOf('    '+next,a);assert(a>=0&&b>a);return source.slice(a,b);}
const ctx={};vm.createContext(ctx);vm.runInContext(extract('compositionEvidence','function detailBody'),ctx);
let n=0;function check(label,data,cycle,total,want){const actual=ctx.compositionEvidence(data,cycle,total);for(const [k,v]of Object.entries(want))assert.equal(actual[k],v,label+' '+k);n++;}
check('mere equal sum',{invoice_amount:100},null,100,{complete:false,coverage:'composição parcial'});
check('no independent total',{document_items_matched:true},{amount:100},100,{complete:false,independentTotal:false});
check('explicit document identity',{invoice_amount:100,document_items_matched:true},null,100,{complete:true,coverage:'itens conferidos com o documento'});
check('provider arithmetic wording',{}, {amount:100,invoice_source_id:'synthetic',invoice_composition_complete:true},100,{complete:true,coverage:'total confere com os itens recebidos'});
check('document conflict beats provider', {invoice_amount:100,document_items_matched:false}, {invoice_composition_complete:true},100,{complete:false});
check('provider conflict beats document', {invoice_amount:100,document_items_matched:true}, {invoice_composition_complete:false},100,{complete:false});
check('incomplete detail beats equal document', {invoice_amount:100,document_items_matched:true,detail_complete:false},null,100,{complete:false});
check('legacy detailcomplete is not identity',{invoice_amount:100,detail_complete:true},null,100,{complete:false});
check('cent discrepancy document',{invoice_amount:100,document_items_matched:true},null,100.06,{complete:false,coverage:'composição parcial'});
check('bank zero without identity',{invoice_amount:0},null,0,{complete:false,independentTotal:true});
check('bank zero identity',{invoice_amount:0,document_items_matched:true},null,0,{complete:true});
check('signed credit identity',{invoice_amount:-20,document_items_matched:true},null,-20,{complete:true});
check('projection is estimate',{}, {amount:100,basis:'derived_current_installments'},100,{complete:false,label:'Valor previsto do ciclo'});
check('mixed sources not bank total',{}, {amount:100,basis:'bank_document_composition'},100,{complete:false,independentTotal:false,label:'Compras recebidas do ciclo'});
check('numeric string', {invoice_amount:'100.00',document_items_matched:true},null,100,{complete:true,expected:100});
for(const bad of [null,undefined,'',' ',[],{},false,true,NaN,Infinity,-Infinity,'NaN','Infinity'])check('invalid amount '+String(bad),{invoice_amount:bad,document_items_matched:true},null,0,{complete:false,independentTotal:false,expected:null});
for(const flag of [undefined,null,'true',1])check('strict flag '+String(flag),{invoice_amount:100,document_items_matched:flag},null,100,{complete:false});
check('nonfinite detail',{invoice_amount:0,document_items_matched:true},null,NaN,{complete:false});
assert(source.includes('cycle?.items?.length?{...cycle,items:cycle.items,basis:cycle.basis}:'),'fast path drops provenance');
// Execute the real render function with harmless wrappers; not a browser/layout test.
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
Object.assign(ctx,{sum:xs=>xs.reduce((s,x)=>s+Number(x||0),0),esc,money:n=>n==null?'—':Number(n).toFixed(2),grouped:()=>[],category:x=>x,categoryCell:r=>esc(r.category),descriptionCell:r=>esc(r.description),formulaSource:()=>'',alternativeSource:()=>'',date:x=>x,month:x=>x});
vm.runInContext(extract('detailBody','async function openDetail'),ctx);
const rows=Array.from({length:20},(_,i)=>({source_id:'synthetic-'+i,amount:i<13?10:5,description:'Synthetic '+i,category:'Synthetic',last4:'0000',provider_status:i<13?'PENDING':'DOCUMENTED'}));
let html=ctx.detailBody({items:rows,basis:'bank_document_composition'}, {amount:165,basis:'bank_document_composition'});
assert.equal((html.match(/<tr data-v226-item>/g)||[]).length,20);assert(html.includes('7 parcelas comprovadas'));assert(!html.includes('itens conferidos com o documento'));assert(html.includes('total da fatura não recebido'));
html=ctx.detailBody({items:[{amount:100,description:'<script>bad</script>',category:'Synthetic'}],invoice_amount:100,document_items_matched:true},null);
assert(!html.includes('<script>'));assert(html.includes('&lt;script&gt;'));assert(html.includes('itens conferidos com o documento'));
console.log('PASS '+n+' composition cases; 20-item mixed-source rendering, provenance, and escaping. Synthetic function/render tests, not browser QA or financial validation.');
vm.runInContext(extract('descriptionCell','function formulaSource'),ctx);
const mismatchHtml=ctx.descriptionCell({description:'Synthetic',amount:80.06,source_document:{amount:80.00,page:1}});
assert(mismatchHtml.includes('80.00')&&mismatchHtml.includes('80.06')&&mismatchHtml.includes('Diferença preservada'),'nominal source disagreement must be visible');
assert(!ctx.descriptionCell({description:'Synthetic',amount:80.00,source_document:{amount:80.00,page:1}}).includes('Diferença preservada'));
assert(!ctx.descriptionCell({description:'Synthetic',amount:80.00}).includes('Diferença preservada'));
console.log('PASS nominal source disagreement preserved; matching and absent evidence produce no false warning.');
