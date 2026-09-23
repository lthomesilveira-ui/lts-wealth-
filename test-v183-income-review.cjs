const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const source=fs.readFileSync('lts-v183-income-review.js','utf8');
function fn(name,context={}){
 const start=source.indexOf('function '+name+'(');
 assert.ok(start>=0);
 const end=source.indexOf('\n  }',start)+4;
 // Single-line helpers have their closing brace on the declaration line.
 const line=source.slice(start,source.indexOf('\n',start));
 const code=line.endsWith('}')?line:source.slice(start,end);
 return vm.runInNewContext('('+code+')',context);
}
const event={source:'current_event',source_ref:'fixture-1',event_date:'2026-09-01',account:'Itaú',signed_amount:12.34,category:'A classificar'};
test('receipt classification requires positive amount and unresolved category',()=>{
 const check=fn('isUnclassifiedReceipt');
 assert.equal(check(event),true);
 for(const signed_amount of [-12,0,null,undefined,'bad'])assert.equal(check({...event,signed_amount}),false);
 for(const category of ['Família','Reembolso','Salário'])assert.equal(check({...event,category}),false);
 for(const category of ['',null,'—','Classificação pendente'])assert.equal(check({...event,category}),true);
});
test('key separates same description/date by account, source, ref and amount',()=>{
 const key=fn('receiptKey');
 for(const field of ['source','source_ref','event_date','account','signed_amount'])assert.notEqual(key(event),key({...event,[field]:'different'}));
 assert.equal(key(event),key({...event,description:'Changed label'}));
 assert.notEqual(key({...event,source:'a|b',source_ref:'c'}),key({...event,source:'a',source_ref:'b|c'}));
});
test('preview payload carries exact identity and no mutation',()=>{
 const result=JSON.parse(JSON.stringify(fn('request')(event)));
 assert.deepEqual(result,{p_source:'current_event',p_source_ref:'fixture-1',p_event_date:'2026-09-01',p_account:'Itaú',p_amount:12.34});
 assert.equal('p_category' in result,false);
 assert.equal('p_user_id' in result,false);
});
test('successful category change invalidates in-flight monthly cache ownership',()=>{
 const monthly={token:9,key:'old',data:{},loading:true,error:'old',progress:'old'};
 fn('invalidateMonthly',{window:{__LTS_V175_STATE:{monthly}}})();
 assert.deepEqual(monthly,{token:10,key:'',data:null,loading:false,error:null,progress:''});
});
test('candidate loads module; protected entry does not',()=>{
 assert.match(fs.readFileSync('wip35-v183-candidate.html','utf8'),/lts-v183-income-review\.js/);
 assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-income-review/);
 assert.doesNotThrow(()=>new Function(source));
});
test('save is explicit, optimistic and source-keyed; no automatic retry or expense writer',()=>{
 assert.match(source,/save\.onclick=async/);
 assert.match(source,/p_expected:preview\.token/);
 assert.match(source,/p_category:select\.value/);
 assert.match(source,/matches\.length===1/);
 assert.match(source,/if\(!dialog\.isConnected\)return/);
 assert.doesNotMatch(source,/lts_browser_semantic_feedback|lts_browser_flow_mutate|p_description_key/);
});
test('SQL API is authenticated, category-only, and rejects ambiguity/stale snapshots',()=>{
 const sql=fs.readFileSync('supabase/migrations/20260923223926_v183_exact_income_category.sql','utf8');
 assert.match(sql,/security invoker/);
 assert.match(sql,/public\.lts_browser_assert_user_v1\(\)/);
 assert.match(sql,/into strict f/);
 assert.match(sql,/for update of e/);
 assert.match(sql,/p_expected <> token/);
 assert.match(sql,/update public\.financial_events set category=p_category where user_id=u and id=f\.id/);
 assert.match(sql,/revoke all on function public\.lts_browser_income_category_v183[^;]+from public,anon,authenticated/);
 assert.doesNotMatch(sql,/insert into public\.financial_events|delete from|update public\.lts_semantic_rule/);
});
