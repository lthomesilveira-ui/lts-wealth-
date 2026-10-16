'use strict';
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const sourcePath=path.resolve('releases/v282/lts-v183-v168-feedback-safe.js');
const source=fs.readFileSync(sourcePath,'utf8');
const readerCode=source.slice(source.indexOf('    const v233Formatters='),source.indexOf('    function planningReviewCount('));
const uiCode=source.slice(source.indexOf('    function expenseTransactionDate('),source.indexOf('    function despesasV168('));
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return{promise,resolve,reject}}
const plain=x=>JSON.parse(JSON.stringify(x));
const baseRow={key:'of:iptu',date:'2026-10-16',event_date:'2026-10-16',transaction_date:'2026-10-16',period:'2026-10-01',date_kind:'day',description:'IPTU fixture',account_source:'Itaú',beneficiary:null,reference:'fixture reference',amount:100,category:'Impostos do imóvel',current_category:'IPTU',component:'Impostos',subgroup:'IPTU',status:'identified',property_code:null,source_table:'lts_open_finance_staging',source_ref:'of:iptu',coverage_mode:'bank_observed',can_classify:true};
const adjustment={...baseRow,key:'card:adjustment',source_ref:'card:adjustment',date:null,date_kind:'month',description:'Ajuste negativo fixture',amount:-20,account_source:'Mastercard Itaú',current_category:'Assinaturas',category:'Consumo',source_table:'lts_card_workbook_evidence_v226',coverage_mode:'card_workbook_signed_adjustment_v235',source_audit:{note:'Ajuste negativo documentado.'}};
async function tick(){for(let i=0;i<16;i++)await Promise.resolve()}
function button(index){return {dataset:{v281ExpenseTransactionDetail:String(index)},isConnected:true,onclick:null}}
function setup(initial='2026-10-16'){
 const calls=[],requests=[],events=[],modals=[],controls={details:[],retry:null,pages:[]};
 const fixedDate=class extends Date{constructor(...args){super(...(args.length?args:['2026-10-16T20:00:00Z']))}static now(){return Date.parse('2026-10-16T20:00:00Z')}};
 const context={window:{__LTS_V166_FEEDBACK:{installed:true}},BOOT:{generation:1},D:{},V:'Despesas',Date:fixedDate,Intl,console,setTimeout,clearTimeout,
  document:{getElementById:()=>null,querySelector:s=>s==='[data-v281-expense-transactions-retry]'?controls.retry:null,querySelectorAll:s=>s==='[data-v281-expense-transaction-detail]'?controls.details:s==='[data-v281-expense-transactions-page]'?controls.pages:[]},render:()=>{},renderNav:()=>{},
  modal:(title,subtitle,body)=>{const m={title,subtitle,body,removed:false,attributes:{},remove(){this.removed=true},setAttribute(k,v){this.attributes[k]=v}};modals.push(m);return m},
  S:{auth:{onAuthStateChange:fn=>events.push(fn)},rpc:async(name,args)=>{calls.push({name,args:plain(args)});if(name==='lts_browser_expense_detail_v229'){const d=deferred();requests.push({args:plain(args),...d});return await d.promise}return {data:{fixture:true,rows:[],period:{from:args.p_from,to:args.p_to}},error:null}}}
 };
 vm.createContext(context);
 vm.runInContext('(function(){'+readerCode+uiCode+'\nthis.test={st,ensureTransactions,ensureInvoices,ensureExpense,openExpenseDraft,applyExpenseDraft,selectExpensePeriod,effectiveRows,syncExpenseReaders,expenseRange,expenseTransactions,expenseTransactionDate,expenseTransactionDetailBody,bindExpenseTransactionActions,setDraft:(from,to)=>{const d=openExpenseDraft();d.from=from;d.to=to;return d;}};}).call(this);',context);
 const test=context.test;Object.assign(test.st.expense,{key:'custom',customFrom:initial,customTo:initial,tab:'transactions',data:{fixture:true}});
 context.render=()=>{if(context.V==='Despesas'&&test.st.expense.tab==='transactions'&&!(test.st.expense.loading&&!test.st.expense.data))test.ensureTransactions()};
 return {context,test,calls,requests,events,modals,controls};
}
function payload(request,rows,opts={}){const total=rows.reduce((s,r)=>s+Number(r.amount),0);return{version:'expense-detail-v178',from:request.args.p_from,to:request.args.p_to,group:null,subgroup:null,total,row_count:rows.length,matched_count:rows.length,matched_total:total,offset:request.args.p_offset,next_offset:null,revision:'fixture-revision',rows,...opts}}
function respond(e,i,rows,opts={}){e.requests[i].resolve({data:payload(e.requests[i],rows,opts),error:null})}
async function commit(e,from,to=from){e.test.setDraft(from,to);e.test.applyExpenseDraft();await tick()}
module.exports={setup,commit,tick,plain,baseRow,adjustment,button,payload,respond,source,sourcePath};
