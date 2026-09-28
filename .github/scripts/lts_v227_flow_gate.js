const fs=require('fs'),vm=require('vm'),assert=require('assert/strict');
const source=fs.readFileSync('releases/'+(process.env.LTS_RELEASE||'v227-2')+'/lts-v172-v171-review.js','utf8');
const start=source.indexOf('    async function flowPart('),end=source.indexOf('    loadFlowRange=function',start);
assert(start>=0&&end>start);
async function scenario(failures){
 const calls=[],state={flowSequence:0},attempts={};let active=0,maxActive=0;
 const scope={state,today:()=> '2026-09-28',shift:(_date,n)=>n===-1?'2026-09-27':'2026-09-23',V:'Fluxo Diário',FLOWPRESET:'',render:()=>{},
  mergeFlows:(parts)=>({parts:parts.map(x=>x.data.flow.kind)}),
  directRpc:async(_name,args)=>{const kind=args.p_to==='2026-09-27'?'history':'future';calls.push(kind);attempts[kind]=(attempts[kind]||0)+1;maxActive=Math.max(maxActive,++active);
   await new Promise(resolve=>setTimeout(resolve,1));active--;
   const status=failures[kind]?.[attempts[kind]-1];return status?{error:{status,message:'Controlled failure'}}:{data:{flow:{kind}}};}
 };
 vm.createContext(scope);vm.runInContext(source.slice(start,end)+';this.run=performFlowRange',scope);
 await scope.run('2026-09-23','2026-12-31');return{calls,state,maxActive,result:scope.FLOWQ,loading:scope.FLOWLOADING};
}
(async()=>{
 let r=await scenario({history:[500]});assert.deepEqual(r.calls,['history','future','history']);assert.equal(r.maxActive,1);assert.equal(r.result.parts.length,2);assert.equal(r.state.flowWarning,'');assert.equal(r.loading,false);
 r=await scenario({history:[500,500]});assert.deepEqual(r.calls,['history','future','history']);assert.equal(r.result.parts.length,1);assert.match(r.state.flowWarning,/parte do período/);assert.equal(r.loading,false);
 r=await scenario({history:[401]});assert.deepEqual(r.calls,['history','future']);assert.equal(r.result.parts.length,1);
 r=await scenario({history:[503,503],future:[503,503]});assert.equal(r.calls.length,4);assert.match(r.result.error,/Não foi possível/);assert.equal(r.loading,false);
 console.log(JSON.stringify({pass:true,sequential_reads:true,transient_recovery:true,retry_bounded:true,authorization_not_retried:true,partial_failure_visible:true}));
})().catch(error=>{console.error(error);process.exit(1)});
