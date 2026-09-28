import assert from 'node:assert/strict';
import {makeHandler} from '../../supabase/functions/lts-open-finance-itau/handler.mjs';

const owner='fixture-owner';
const env=k=>({SUPABASE_URL:'https://fixture.supabase.test',SUPABASE_SERVICE_ROLE_KEY:'fixture-service',PLUGGY_CLIENT_ID:'fixture-client',PLUGGY_CLIENT_SECRET:'fixture-secret',PLUGGY_ITAU_ITEM_ID:'00000000-0000-4000-8000-000000000001'}[k]);
const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json'}});
async function test(bank,failSource=false,longHistory=false){
 const calls=[];const item={id:'00000000-0000-4000-8000-000000000001',status:'UPDATED',executionStatus:'SUCCESS',lastUpdatedAt:'2026-09-28T12:00:00Z',connector:{name:'MeuPluggy'}};
 const fetcher=async(url,options={})=>{
  const u=new URL(url),name=u.pathname.split('/').pop(),body=options.body?JSON.parse(options.body):{};calls.push({path:u.pathname,name,body});
  if(u.pathname==='/auth/v1/user')return json({id:owner});
  if(u.pathname==='/rest/v1/lts_open_finance_connection')return json([{provider_connection_ref:'00000000-0000-4000-8000-000000000001'}]);
  if(name==='lts_open_finance_pilot_owner_v1')return json(owner);
  if(/lts_open_finance_begin_/.test(name))return json({run_id:'run-fixture',connection_id:'connection-fixture'});
  if(name==='lts_open_finance_sources_v226')return failSource?json({code:'57014',message:'PRIVATE_SQL_MUST_NEVER_BE_RETURNED'},500):json({complete_for_consulted_sources:true,rows:[],source_as_of:'2026-09-22'});
  if(/lts_open_finance_stage_batch/.test(name))return json({ok:true});
  if(/lts_open_finance_finish_/.test(name))return json({status:body.p_status});
  if(u.pathname==='/auth')return json({apiKey:'fixture-pluggy-key'});
  if(u.pathname==='/items/00000000-0000-4000-8000-000000000001')return json(item);
  if(u.pathname==='/accounts')return json({page:1,total:1,totalPages:1,results:[{id:'account-test',type:'BANK',subtype:'CHECKING_ACCOUNT',name:bank==='336'?'C6':bank==='237'?'Bradesco':'Itaú',balance:10,currencyCode:'BRL',updatedAt:item.lastUpdatedAt,bankData:{transferNumber:bank+'/0001'}}]});
  if(u.pathname==='/v2/transactions' && longHistory)return json({results:['2024-02-29','2026-09-28'].map((date,i)=>({id:'transaction-'+i,accountId:'account-test',date:date+'T12:00:00Z',amount:10,type:'DEBIT',currencyCode:'BRL',description:'Synthetic purchase'})),next:null});
  if(['/v2/transactions','/investments','/loans'].includes(u.pathname))return json({results:[],total:0,totalPages:0,next:null});
  throw Error('Unexpected fixture request '+u.pathname);
 };
 const handler=makeHandler(env,fetcher);
 const result=await handler(new Request('https://fixture.test',{method:'POST',headers:{Authorization:'Bearer fixture-user-token'},body:JSON.stringify({action:'sync',institution_code:bank})}));
 const data=await result.json();
 assert.equal(data.status,failSource?undefined:'success',JSON.stringify(data));
 const final=calls.findLast(c=>/lts_open_finance_finish_/.test(c.name));
 assert(final,JSON.stringify({bank,data,paths:calls.map(c=>c.path)}));
 assert.equal(final.name,bank==='341'?'lts_open_finance_finish_itau_v1':'lts_open_finance_finish_bank_v1');
 if(failSource){assert.equal(data.error,'DATABASE_TIMEOUT');assert.equal(final.body.p_metadata.failure_stage,'lts_open_finance_sources_v226');assert.equal(final.body.p_metadata.sqlstate,'57014');assert(!JSON.stringify(data).includes('PRIVATE_SQL'));}
 else {
  const windows=calls.filter(c=>c.name==='lts_open_finance_sources_v226').map(c=>c.body);
  assert(windows.length>0);
  if(longHistory){
   assert.equal(windows.length,3,'multiple years need three bounded source reads, not monthly rebuilding');
   assert.equal(windows[0].p_from,'2024-02-29');assert.equal(windows.at(-1).p_to,'2026-09-28');
   windows.forEach((w,i)=>{const start=Date.parse(w.p_from),end=Date.parse(w.p_to);assert(end>=start && end-start<=365*86400000);if(i)assert.equal(start-Date.parse(windows[i-1].p_to),86400000,'source windows have no gaps or overlaps, including leap day');});
   const staged=calls.filter(c=>/lts_open_finance_stage_batch/.test(c.name)).flatMap(c=>c.body.p_records);
   assert.equal(staged.filter(c=>c.resource_type==='transaction').length,2,'both boundary transactions are retained');
  }
 }
}
const unauthorized=await makeHandler(env,()=>{throw Error('unauthorized request made network call')})(new Request('https://fixture.test',{method:'POST',body:'{}'}));
assert.equal(unauthorized.status,401);
for(const bank of ['341','237','336']){await test(bank,true);await test(bank,false);}
await test('341',false,true);
console.log(JSON.stringify({pass:true,checks:['anonymous denied','source reader is bounded','all banks finalize through their own function','timeouts have redacted diagnostics','all banks stage and finish']}));
