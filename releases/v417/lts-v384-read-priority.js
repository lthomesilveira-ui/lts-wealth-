/* Select read order only. Admission, authentication, cache and queries stay with the transport. */
(function(root,factory){
 'use strict';const api=factory();
 if(typeof module==='object'&&module.exports)module.exports=api;
 else root.LTSV384ReadPriority=api;
})(typeof window==='undefined'?globalThis:window,function(){
 'use strict';
 const legacy=name=>/income_review_queue_|card_review_queue_|expense_review_queue_|expense_detail_|expense_composition_|card_detail_/.test(name)?0:/card_cycles_|flow_v/.test(name)?1:/recurring_future_gap_/.test(name)?3:2;
 function forRoute(name,route){
  if(route!=='Dashboard')return legacy(name);
  if(/dashboard_cockpit_/.test(name))return -2;
  if(/card_cycles_|flow_v|monthly_|wealth_detail_|awards_|expenses_/.test(name))return -1;
  if(/income_review_queue_|card_review_queue_|expense_review_queue_/.test(name))return 4;
  return legacy(name);
 }
 return Object.freeze({forRoute});
});
