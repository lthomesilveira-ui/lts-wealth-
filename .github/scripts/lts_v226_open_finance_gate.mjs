import assert from 'node:assert/strict';
import {makeHandler} from '../../supabase/functions/lts-open-finance-itau/handler.mjs';

const owner='fixture-owner';
const env=k=>({SUPABASE_URL:'https://fixture.supabase.test',SUPABASE_SERVICE_ROLE_KEY:'fixture-service',PLUGGY_CLIENT_ID:'fixture-client',PLUGGY_CLIENT_SECRET:'fixture-secret',PLUGGY_ITAU_ITEM_ID:'00000000-0000-4000-8000-000000000001'}[k]);
const json=(data,status=200)=>new Response(JSON.stringify(data),{status,headers:{'Content-Type':'application/json'}});
async function test(bank,failSource=false){
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
 else assert(calls.some(c=>c.name==='lts_open_finance_sources_v226'));
}
const unauthorized=await makeHandler(env,()=>{throw Error('unauthorized request made network call')})(new Request('https://fixture.test',{method:'POST',body:'{}'}));
assert.equal(unauthorized.status,401);
for(const bank of ['341','237','336']){await test(bank,true);await test(bank,false);}
console.log(JSON.stringify({pass:true,checks:['anonymous denied','source reader is bounded','all banks finalize through their own function','timeouts have redacted diagnostics','all banks stage and finish']}));
