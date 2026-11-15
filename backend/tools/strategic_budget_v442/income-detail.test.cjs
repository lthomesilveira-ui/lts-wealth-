const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const c={Intl,Date,Number,Array,console,setTimeout:()=>{},FLOWEDIT:null,flowEditorInline:()=>'',flowClassificationBadge:e=>'original:'+e.category};
const doc={createElement:()=>({}),head:{append:s=>vm.runInContext(s.textContent,ctx)},getElementById:()=>shell};
const shell={contentWindow:c,contentDocument:doc,addEventListener:()=>{}};c.window=c;c.document=doc;c.__LTS_V337_MONTH=true;const ctx=vm.createContext(c);
vm.runInContext(fs.readFileSync(__dirname+'/income-composition.js','utf8'),ctx);
for(const description of ['Complemento de adiantamento do 13º','13o Salário','Décimo terceiro']){
 const e={event_date:'2050-11-19',signed_amount:101,description,category:null},before=JSON.stringify(e),s=c.flowClassificationBadge(e);assert.match(s,/13º previsto/);assert(!s.includes('v183-income-review'));assert.equal(JSON.stringify(e),before);
}
assert.match(c.flowClassificationBadge({event_date:'2050-11-19',signed_amount:101,description:'Outra previsão',category:null}),/Entrada prevista/);
assert.equal(c.flowClassificationBadge({event_date:'2001-11-19',signed_amount:101,category:null}),'original:null');
assert.equal(c.flowClassificationBadge({event_date:'2050-11-19',signed_amount:-101,category:'Saúde'}),'original:Saúde');
assert.equal(c.flowClassificationBadge({event_date:'',signed_amount:101,category:null}),'original:null');
console.log('PASS future income stays forecast; confirmed income keeps its category reviewer; no financial mutation');
