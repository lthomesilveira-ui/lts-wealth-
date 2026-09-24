const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-v168-feedback-safe.js','utf8');
const start=source.indexOf('    async function uploadStatement(bg){'),end=source.indexOf('\n    function nextSuggestion',start);
const upload=source.slice(start,end).trim();
function fixture(options={}){
 const calls=[],messages=[],button={dataset:{},disabled:false,remove(){this.removed=true}};
 const file={name:'fixture.pdf',type:'application/pdf',size:100,...options.file};
 const fields={'#v168UpSend':button,'#v168UpFile':{files:options.noFile?[]:[file]},'#v168UpBank':{value:options.bank??'Itaú'},'#v168UpDate':{value:options.date??'2030-01-02'}};
 const bg={querySelector:s=>fields[s]},scope={
  S:{auth:{getUser:async()=>{calls.push('auth');if(options.authWait)await options.authWait;return {data:{user:{id:'fixture-user'}}}}},
   storage:{from:()=>({upload:async(...args)=>{calls.push(['upload',...args]);return options.uploadError?{error:{message:'fixture failure'}}:{}},remove:async()=>{calls.push('REMOVE')}})},
   rpc:async(name,args)=>{calls.push([name,args]);if(options.registerThrow)throw Error('timeout');return options.registerError?{error:{message:'timeout'}}:{data:options.malformed?{}:{ok:true,inbox_id:'fixture-inbox'}}}},
  today:()=> '2030-01-03',crypto:{randomUUID:()=> 'fixture-random'},st:{updates:{recurring:{}}},
  modalMsg:(bg,text,ok)=>messages.push({text,ok}),ensureUpdates:async()=>{calls.push('refresh');if(options.refreshError)throw Error('fixture refresh failure')}
 };
 const run=vm.runInNewContext('('+upload+')',scope);
 return {run:()=>run(bg),fields,button,calls,messages};
}
test('success registers exactly once, keeps the source and creates no financial entry',async()=>{
 const f=fixture();await f.run();await f.run();
 assert.equal(f.calls.filter(x=>Array.isArray(x)&&x[0]==='lts_browser_register_document_v2').length,1);
 assert.equal(f.calls.includes('REMOVE'),false);assert.equal(f.button.dataset.uploadState,'registered');assert.equal(f.button.removed,true);
 assert.match(f.messages.at(-1).text,/Nenhum lançamento financeiro/);
});
test('validation is complete before authentication or upload',async()=>{
 for(const options of [{noFile:true},{file:{size:0}},{file:{size:52428801}},{bank:'Unknown'},{date:''},{date:'2030-02-31'}]){
  const f=fixture(options);await f.run();assert.equal(f.calls.length,0);assert.equal(f.messages.at(-1).ok,false);
 }
});
test('registration timeout never deletes the uploaded document or retries automatically',async()=>{
 for(const options of [{registerError:true},{registerThrow:true},{malformed:true}]){
  const f=fixture(options);await f.run();await f.run();
  assert.equal(f.calls.includes('REMOVE'),false);assert.equal(f.button.dataset.uploadState,'uncertain');assert.equal(f.button.disabled,true);
  assert.equal(f.calls.filter(x=>Array.isArray(x)&&x[0]==='upload').length,1);
  assert.match(f.messages.at(-1).text,/preservado/);
 }
});
test('refresh failure after registration preserves success and the private file',async()=>{
 const f=fixture({refreshError:true});await f.run();
 assert.equal(f.button.dataset.uploadState,'registered');assert.equal(f.messages.at(-1).ok,true);assert.equal(f.calls.includes('REMOVE'),false);
});
test('simultaneous clicks cannot upload or register twice',async()=>{
 let release;const authWait=new Promise(r=>release=r),f=fixture({authWait});
 const first=f.run(),second=f.run();release();await Promise.all([first,second]);
 assert.equal(f.calls.filter(x=>Array.isArray(x)&&x[0]==='upload').length,1);
});
test('association is captured before async work and input controls are locked',async()=>{
 let release;const authWait=new Promise(r=>release=r),f=fixture({authWait});const pending=f.run();
 assert.equal(f.fields['#v168UpBank'].disabled,true);f.fields['#v168UpBank'].value='C6';release();await pending;
 const registration=f.calls.find(x=>Array.isArray(x)&&x[0]==='lts_browser_register_document_v2')[1];
 assert.equal(registration.p_task_context.institution,'Itaú');assert.equal(registration.p_task_context.reference_date,'2030-01-02');
});
test('failed storage request re-enables input without a registration',async()=>{
 const f=fixture({uploadError:true});await f.run();assert.equal(f.button.disabled,false);
 assert.equal(f.calls.some(x=>Array.isArray(x)&&x[0]==='lts_browser_register_document_v2'),false);
});
test('only uploadStatement and transfer-proposal guard differ from the protected shared source',()=>{
 const original=fs.readFileSync('lts-v168-feedback-package.js','utf8');
 const normalize=text=>text.replace(/    async function uploadStatement\(bg\)\{[\s\S]*?(?=\n    function nextSuggestion)/,'UPLOAD\n').replace(/    function transferProposal\(x\)\{[\s\S]*?(?=    function openProposal)/,'').replace('if(transferProposal(x))return reviewTransferProposal(x);','');
 assert.equal(normalize(source),normalize(original));assert.doesNotThrow(()=>new Function(source));
 assert.match(fs.readFileSync('wip35-v183-candidate.html','utf8'),/lts-v183-v168-feedback-safe\.js/);
 assert.doesNotMatch(fs.readFileSync('wip35-v181-candidate.html','utf8'),/lts-v183-v168-feedback-safe/);
});
