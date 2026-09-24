const {test}=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm');
const source=fs.readFileSync('lts-v183-card-payment-status.js','utf8');
function fn(name){const start=source.indexOf('function '+name+'('),end=source.indexOf('\n  }',start)+4;return vm.runInNewContext('('+source.slice(start,end)+')')}
const row={id:'fixture',card_name:'C6 fixture',due_date:'2030-01-02',documented_amount:100};
const detail={matched:true,due_date:row.due_date,invoice_total:100,payment_documented:false,cash_effect_date:row.due_date};
test('invoice arithmetic does not imply settlement',()=>{
 const result=fn('classify')(row,{...detail,cash_reconciled:true,detail_complete:true});
 assert.equal(result.label,'Pagamento não comprovado');assert.equal(result.documented,false);
});
test('only explicit true documentary payment is accepted',()=>{
 const classify=fn('classify');assert.equal(classify(row,{...detail,payment_documented:true}).label,'Pagamento documentado');
 for(const payment_documented of [false,'true','false',null,undefined])assert.equal(classify(row,{...detail,payment_documented}).documented,false);
});
test('different registered cash date is disclosed, never silently applied',()=>{
 const result=fn('classify')(row,{...detail,cash_effect_date:'2030-01-04'});
 assert.equal(result.dateDifference,true);assert.match(result.note,/04\/01\/2030/);assert.equal(row.due_date,'2030-01-02');
});
test('ambiguous, mismatched and absent totals remain unverified',()=>{
 for(const change of [{matched:false},{due_date:'2030-02-02'},{invoice_total:101},{invoice_total:null},{invoice_total:'bad'}])
  assert.equal(fn('classify')(row,{...detail,...change}).label,'Pagamento não conferido');
});
test('unknown bank is not guessed from a generic Visa name',()=>{
 const bank=fn('bank');assert.equal(bank('Visa'),null);assert.equal(bank('C6 Carbon'),'C6');
 assert.equal(bank('Visa Aeternum'),'Bradesco');assert.equal(bank('Visa Infinite Prime'),'Bradesco');assert.equal(bank('Personnalite Black Pontos'),'Itaú');
});
test('isolated reader is read-only, session-cleared and stale-request guarded',()=>{
 assert.doesNotThrow(()=>new Function(source));
 assert.match(source,/if\(epoch!==state\.epoch\)return/);
 assert.match(source,/SIGNED_OUT.*clear/);
 assert.match(source,/CARD_PERIOD\?\.key===period/);
 assert.doesNotMatch(source,/rpc\(['"]lts_browser_(save|create|apply|register|mutate)/);
 assert.doesNotMatch(fs.readFileSync('index.html','utf8'),/lts-v183-card-payment-status/);
});
