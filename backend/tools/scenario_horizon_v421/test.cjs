'use strict';
const assert=require('node:assert/strict'),api=require('./model.js');let tests=[];
const from='2026-11-07',to=api.horizon(from);
function fixture(end=to){const days=[];for(let d=new Date(from+'T12:00:00Z');d.toISOString().slice(0,10)<=end;d.setUTCDate(d.getUTCDate()+1))days.push({date:d.toISOString().slice(0,10),fix86_columns:{saldo_apos_d0_1:1000,saldo_apos_rsu:2000,saldo_apos_fgts:3000}});return{complete:true,coverage:{from,to:end,complete:true},flow:{current_future:{days}}};}
function check(name,f){f();tests.push(name)}
function set(f,date,key,value){f.flow.current_future.days.find(x=>x.date===date).fix86_columns[key]=value;}
check('five complete future years before policy metadata',()=>assert.equal(to,'2031-12-31'));
check('annual rollover',()=>assert.equal(api.horizon('2027-01-01'),'2032-12-31'));
check('matching longer configuration retained',()=>assert.equal(api.horizon(from,{asOf:from,horizon:'2033-12-31'}),'2033-12-31'));
check('stale metadata cannot shorten current horizon',()=>assert.equal(api.horizon(from,{asOf:'2025-11-07',horizon:'2030-12-31'}),to));
check('late first deficit and worst balance',()=>{const f=fixture();set(f,'2028-02-01','saldo_apos_d0_1',-10);set(f,'2031-06-30','saldo_apos_d0_1',-900);const s=api.scenario(f,'base',from,to);assert(s.complete);assert.equal(s.firstNegative.date,'2028-02-01');assert.equal(s.firstAmount,-10);assert.equal(s.worstDate,'2031-06-30');assert.equal(s.worstAmount,-900);});
for(const [key,col]of Object.entries({base:'saldo_apos_d0_1',vested:'saldo_apos_rsu',fgts:'saldo_apos_fgts'})){
 check(key+' positive minimum',()=>{let f=fixture();set(f,'2031-11-11',col,19);let s=api.scenario(f,key,from,to);assert(s.complete);assert.equal(s.firstNegative,null);assert.equal(s.worstAmount,19);assert.equal(s.worstDate,'2031-11-11')});
 check(key+' zero not negative',()=>{let f=fixture();set(f,'2030-05-01',col,0);let s=api.scenario(f,key,from,to);assert.equal(s.firstNegative,null);assert.equal(s.worstAmount,0)});
 check(key+' unknown not zero',()=>{let f=fixture();set(f,'2028-02-29',col,null);assert.equal(api.scenario(f,key,from,to).complete,false)});
}
check('partial 2027 data cannot certify full horizon',()=>assert.equal(api.scenario(fixture('2027-12-31'),'base',from,to).complete,false));
check('missing date incomplete',()=>{let f=fixture();f.flow.current_future.days.splice(10,1);assert.equal(api.scenario(f,'base',from,to).complete,false)});
check('duplicate date incomplete',()=>{let f=fixture();f.flow.current_future.days.push(f.flow.current_future.days[4]);assert.equal(api.scenario(f,'base',from,to).complete,false)});
check('invalid date incomplete',()=>{let f=fixture();f.flow.current_future.days[5].date='2026-02-30';assert.equal(api.scenario(f,'base',from,to).complete,false)});
check('null entire response incomplete',()=>assert.equal(api.scenario(null,'base',from,to).complete,false));
check('false completeness preserved',()=>{let f=fixture();f.complete=false;assert.equal(api.scenario(f,'base',from,to).complete,false)});
check('numeric strings supported',()=>{let f=fixture();set(f,'2031-01-01','saldo_apos_d0_1','-1.25');assert.equal(api.scenario(f,'base',from,to).worstAmount,-1.25)});
check('boolean not a balance',()=>{let f=fixture();set(f,'2031-01-01','saldo_apos_d0_1',false);assert.equal(api.scenario(f,'base',from,to).complete,false)});
check('equal minima use first date',()=>{let f=fixture();set(f,'2031-01-01','saldo_apos_d0_1',-5);set(f,'2031-02-01','saldo_apos_d0_1',-5);assert.equal(api.scenario(f,'base',from,to).worstDate,'2031-01-01')});
check('source values and ordering unchanged',()=>{let f=fixture();f.flow.current_future.days.reverse();const before=JSON.stringify(f);api.scenario(f,'base',from,to);assert.equal(JSON.stringify(f),before)});
check('all values remain separate between scenarios',()=>{let f=fixture();set(f,'2031-01-01','saldo_apos_fgts',-8);assert.equal(api.scenario(f,'vested',from,to).firstNegative,null);assert.equal(api.scenario(f,'fgts',from,to).firstAmount,-8)});
console.log(JSON.stringify({passed:true,count:tests.length,tests},null,2));
