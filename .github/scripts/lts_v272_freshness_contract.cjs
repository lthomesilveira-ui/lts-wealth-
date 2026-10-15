const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),path=require('node:path');
const src=fs.readFileSync('releases/v272/lts-v225-open-finance.js','utf8');
const original=fs.readFileSync('releases/v271/lts-v225-open-finance.js','utf8');
const clock=Date.parse('2026-10-15T04:00:00Z');class FixedDate extends Date{static now(){return clock}}
const ctx=vm.createContext({Intl,Date:FixedDate,state:{status:{connections:[]}},window:{}});
vm.runInContext(src.slice(src.indexOf('    const v233Formatters'),src.indexOf('    if (window.__LTS_V225'))+src.slice(src.indexOf('    const names'),src.indexOf('    function paint()'))+'\nthis.format=stamp;this.rows=bankRows;',ctx);
let cases=0;function test(name,fn){fn();cases++;console.log('PASS '+name)}
test('BRT regardless of device timezone',()=>assert.match(ctx.format('2026-10-15T01:30:00Z'),/14\/10\/2026,? 22:30 BRT/));
test('BRT midnight boundary',()=>{assert.match(ctx.format('2026-10-15T02:59:59Z'),/14\/10\/2026/);assert.match(ctx.format('2026-10-15T03:00:00Z'),/15\/10\/2026/)});
test('missing and invalid safe',()=>{for(const x of [null,undefined,'','x','2026-99-99T00:00:00Z','2026-02-30T00:00:00Z',0])assert.equal(ctx.format(x),'indisponível')});
test('date only and offsetless are not timestamps',()=>{for(const x of ['2026-10-15','2026-10-15T01:30:00'])assert.equal(ctx.format(x),'indisponível')});
test('future source not certified',()=>assert.equal(ctx.format('2026-10-16T01:30:00Z'),'indisponível'));
test('explicit offset accepted',()=>assert.match(ctx.format('2026-10-14T22:30:00-03:00'),/14\/10\/2026,? 22:30 BRT/));
function bank(extra={}){return {institution_code:'341',status:'connected',last_success_at:'2026-10-15T03:15:00Z',...extra}}
test('existing RPC has honest missing source',()=>{ctx.state.status.connections=[bank()];const s=ctx.rows();assert.match(s,/Dados recebidos pelo Wealth em/);assert.match(s,/Atualização da conexão na origem: <time>indisponível/);assert.doesNotMatch(s,/Bancos atualizados/)});
test('old source is preserved after fresh collection',()=>{ctx.state.status.connections=[bank({provider_item_updated_at:'2026-10-13T18:00:00Z'})];const s=ctx.rows();assert.match(s,/13\/10\/2026,? 15:00 BRT/);assert.match(s,/15\/10\/2026,? 00:15 BRT/)});
test('later failure keeps last receipt visible',()=>{ctx.state.status.connections=[bank({last_error_code:'synthetic',last_attempt_at:'2026-10-15T03:30:00Z'})];assert.match(ctx.rows(),/Falha na última coleta/);assert.match(ctx.rows(),/15\/10\/2026,? 00:15 BRT/)});
test('three banks rendered without global certification',()=>{const s=ctx.rows();assert.equal((s.match(/class="v225-bank"/g)||[]).length,3);assert.doesNotMatch(s,/Bancos atualizados/)});
test('success and timeout attribute only collection',()=>{assert.match(src,/state.message='Coleta concluída'/);assert.match(src,/a coleta ainda não foi confirmada/);assert.doesNotMatch(src,/os bancos ainda estão processando|Atualizando bancos|Bancos atualizados/)});
test('financial cash criteria untouched',()=>{const old=fs.readFileSync('releases/v271/lts-v179-cash-recovery.js','utf8'),next=fs.readFileSync('releases/v272/lts-v179-cash-recovery.js','utf8');assert.equal(next,old.replace("complete?dateLabel(c.as_of):'Indisponível'","complete?'Calculado para '+dateLabel(c.as_of):'Indisponível'"));});
test('RPC names and call count unchanged',()=>assert.deepEqual(src.match(/rpc\('[^']+'/g),original.match(/rpc\('[^']+'/g)));
test('timestamp source never falls back to calculation or collector',()=>assert.match(src,/stamp\(bank\?\.provider_item_updated_at\)/));
console.log(JSON.stringify({passed:cases,timezone:process.env.TZ||'default',scope:'synthetic unit and static contracts; not browser QA'}));
