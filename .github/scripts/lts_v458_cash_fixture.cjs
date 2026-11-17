'use strict';
const fixture=require('./lts_v379_fixtures.cjs');
module.exports=function cash(now){
 const day=now.slice(0,10),previous=new Date(day+'T12:00:00Z');previous.setUTCDate(previous.getUTCDate()-1);
 const data=structuredClone(fixture.response('lts_browser_cash_today_v242',{}));
 data.as_of=day;data.day.date=day;
 data.bank_positions=[['341','Itaú'],['237','Bradesco'],['336','C6']].map(([code,bank])=>({
  institution_code:code,institution:bank,source_id:'synthetic-position-'+code,
  balance:data.day[bank].balance,as_of:previous.toISOString().slice(0,10)+'T09:00:00Z'}));
 return data;
};
