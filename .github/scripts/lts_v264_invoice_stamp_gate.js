'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const root='releases/'+(process.env.LTS_RELEASE||'v264')+'/';
const code=fs.readFileSync(root+'lts-v226-card-composition.js','utf8');
const a=code.indexOf('    function sourceStamp('),b=code.indexOf('    function upcomingPanel(',a);
const ctx={esc:String,date:x=>x.split('-').reverse().join('/'),receivedFormatter:new Intl.DateTimeFormat('pt-BR',{timeZone:'America/Sao_Paulo',day:'2-digit',month:'2-digit',year:'numeric',hour:'2-digit',minute:'2-digit'})};
vm.createContext(ctx);vm.runInContext(code.slice(a,b),ctx);
// A document's civil date must not turn into the preceding Brazilian day.
let text=ctx.sourceStamp({document_source_as_of:'2026-10-02'},{basis:'bank_document_composition'});
assert.match(text,/Fatura parcial complementar: 02\/10\/2026/);
assert.doesNotMatch(text,/01\/10\/2026|21:00/);
// Current invoice timestamps are authoritative for that invoice; account
// metadata and ingestion timestamps cannot replace the provider update.
text=ctx.sourceStamp({source_updated_at:'2026-10-01T10:00:00Z',received_at:'2026-10-12T23:15:00Z'},{basis:'open_finance_invoice_v263',invoice_source_updated_at:'2026-10-12T18:03:33Z',invoice_received_at:'2026-10-12T23:15:00Z'});
assert.match(text,/Fatura atualizada no banco: 12\/10\/2026, 15:03/);
assert.match(text,/Recebida pelo LTS: 12\/10\/2026, 20:15/);
assert.doesNotMatch(text,/01\/10\/2026|Dados do cartão/);
assert.equal((text.match(/<small/g)||[]).length,2);
assert.equal(ctx.sourceStamp({},{}),'');
assert.equal(ctx.sourceStamp({received_at:'invalid'},{}),'');
console.log('PASS V264: civil document dates, actual invoice updates, separate receipt time and unchanged compact stamp count');
