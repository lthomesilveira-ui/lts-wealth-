'use strict';
// Empty invented month for unrelated full-app layout tests.
// Monetary monthly behavior is tested separately with PostgreSQL output.
function empty(args,asOf){
 const from=args.p_from,to=args.p_to,monthFrom=from.slice(0,7)+'-01',end=new Date(to.slice(0,7)+'-01T12:00:00Z');end.setUTCMonth(end.getUTCMonth()+1);end.setUTCDate(0);
 const metrics=()=>({entries:0,payments:0,result:0,count:0}),months=[],day=new Date(monthFrom+'T12:00:00Z');
 while(day.toISOString().slice(0,7)<=to.slice(0,7)){months.push({month:day.toISOString().slice(0,10),cash:metrics(),competence:0});day.setUTCMonth(day.getUTCMonth()+1);}
 return{version:'month-overview-v393',from,to,as_of:asOf,complete:true,source_complete:true,
  cash:{realized:metrics(),forecast:metrics(),unconfirmed:metrics(),total:metrics(),items:[],excluded:[],undated:[]},
  competence:{from:monthFrom<'2013-10-10'?'2013-10-10':monthFrom,to:end.toISOString().slice(0,10),total:0,received_total:0,projected_total:0,count:0,items:[],basis:'competence_month',payment_proven:false},months};
}
module.exports={empty};
