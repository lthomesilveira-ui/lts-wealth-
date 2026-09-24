const {test}=require('node:test');
const assert=require('node:assert/strict');
const fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-award-provenance.js','utf8');
const finite=x=>x==null||x===''?null:Number.isFinite(Number(x))?Number(x):null;
function helper(name,extra={}){
 const start=source.indexOf('function '+name+'('),end=source.indexOf('\n  }',start)+4;
 return vm.runInNewContext('('+source.slice(start,end)+')',{finite,arr:x=>Array.isArray(x)?x:[],...extra});
}
const rows=[{asset_type:'RSU',quantity:3,gross_value_brl:31.01,net_value_brl:null},
 {asset_type:'Cash RSU',quantity:5,gross_value_brl:45,net_value_brl:31.5}];
test('agenda total uses its rows, not the statement total',()=>{
 const result=JSON.parse(JSON.stringify(helper('scheduleSummary')(rows)));
 assert.deepEqual(result,{regular:31.01,cash:31.5,total:62.51,regularQuantity:3,cashQuantity:5});
});
test('missing amounts or unknown types fail closed, not partial or zero',()=>{
 const summary=helper('scheduleSummary');
 for(const input of [[],null,[...rows,{asset_type:'RSU',quantity:1,gross_value_brl:null}],
  [{...rows[1],net_value_brl:undefined}],[{...rows[0],asset_type:'Retention'}],[{...rows[0],quantity:''}]])assert.equal(summary(input),null);
});
test('cents round per row and preserve recorded cent differences',()=>{
 assert.equal(helper('scheduleSummary')([{...rows[0],gross_value_brl:0.1},{...rows[0],gross_value_brl:0.2}]).total,0.3);
});
const row={group_key:'rsu:2030-01-01',asset_type:'RSU',quantity:3,gross_value_brl:30,unit_price_usd:2,fx_rate:5};
const group={group_key:row.group_key,quantity:3,gross_value_brl:30,considered_value_brl:30,components:[{unit_price_usd:2,fx_rate:5}]};
test('provenance must match exact group, quantities, values and quote pair',()=>{
 const matches=helper('matches');assert.equal(matches(row,group),true);
 for(const change of [{group_key:'rsu:2031-01-01'},{quantity:4},{gross_value_brl:31},{considered_value_brl:31},{components:[]},
  {components:[{unit_price_usd:5,fx_rate:2}]}])assert.equal(matches(row,{...group,...change}),false);
});
test('mixed source prices are preserved without a false single quote',()=>{
 const mixed={...group,components:[{unit_price_usd:1,fx_rate:5},{unit_price_usd:3,fx_rate:5}]};
 assert.equal(helper('matches')({...row,unit_price_usd:null},mixed),true);
 assert.equal(helper('matches')(row,mixed),false);
});
test('historical update timestamp is not promoted to a market as-of date',()=>{
 const origin=helper('origin',{date:x=>x||'não informada'});
 assert.match(origin({provenance:'historical_assumption',source_updated_at:'2030-01-01'}),/data da cotação não informada/);
 assert.match(origin({provenance:'manual',assumption_recorded_at:'2030-01-01'}),/Premissa manual.*2030-01-01/);
});
test('SQL is authorized, private, read-only and does not expose raw metadata',()=>{
 const sql=fs.readFileSync('supabase/migrations/20260924143922_v183_award_provenance.sql','utf8');
 assert.match(sql,/u uuid := public\.lts_browser_assert_user_v1\(\)/);
 assert.match(sql,/where s\.user_id=u and s\.active/);
 assert.match(sql,/public\.lts_browser_award_provenance_v183\(\)[\s\S]*security invoker/);
 assert.match(sql,/revoke all on function public\.lts_browser_award_provenance_v183\(\) from public,anon,authenticated/);
 assert.doesNotMatch(sql,/\b(insert into|update public|delete from)\b/i);
 assert.match(sql,/'market_quote_as_of',null/);
});
test('candidate is isolated and refresh observes successful explicit writes only',()=>{
 assert.doesNotThrow(()=>new Function(source));
 assert.match(fs.readFileSync('wip35-v183-candidate.html','utf8'),/lts-v183-award-provenance\.js/);
 assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-award-provenance/);
 assert.match(source,/if\(!writers\.has\(name\)\)return result/);
 assert.match(source,/if\(!response\.error&&response\.data\?\.ok\)/);
 assert.match(source,/if\(token!==state\.token\)return/);
 assert.match(source,/SIGNED_OUT.*invalidate/);
 assert.doesNotMatch(source,/save_all_award_assumptions_v1['"],\s*\{/);
});
