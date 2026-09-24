const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-v168-feedback-safe.js','utf8');
const begin=source.indexOf('    function transferProposal(x){'),end=source.indexOf('    function reviewTransferProposal',begin);
const transfer=vm.runInNewContext('('+source.slice(begin,end).trim()+')');
test('bank-to-bank receipt suggestions cannot become new income',()=>{
 for(const description of ['Recebimento Itaú para Bradesco','Recebimento de c6 para Bradesco','Transferência entre contas','Transferir Bradesco para Itaú'])assert.equal(transfer({description}),true);
 for(const value of [{internal_transfer:true},{is_internal_transfer:true},{direction:'transfer'}])assert.equal(transfer(value),true);
});
test('ordinary salary, insurance and family income retain the existing review',()=>{
 for(const description of ['Salário','Seguro cartão Itaú','Netflix','Benjamin - Saúde','Recebimento de familiar'])assert.equal(transfer({description}),false);
});
test('detected transfer returns before constructing the single-entry writer',()=>{
 assert.match(source,/function openProposal\(x\)\{if\(transferProposal\(x\)\)return reviewTransferProposal\(x\);const bg=/);
 const start=source.indexOf('    function reviewTransferProposal'),stop=source.indexOf('    function openProposal',start),review=source.slice(start,stop);
 assert.match(review,/runSearch\(query\)/);assert.match(review,/Conferir lançamentos existentes/);
 assert.doesNotMatch(review,/\brpc\(|Adicionar ao Fluxo|create_future_event/);
});
