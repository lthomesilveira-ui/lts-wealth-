/* A classification reader may lose admission when the banking snapshot changes. */
(function (root) {
  'use strict';
  const queues = new Set([
    'lts_browser_income_review_queue_v296',
    'lts_browser_expense_review_queue_v229',
    'lts_browser_card_review_queue_v312'
  ]);
  function transient(issue) {
    if (!issue) return false;
    if ([401, 403].includes(issue.status)) return false;
    if ([408, 429, 502, 503, 504].includes(issue.status)) return true;
    if (['40001', '55000', '57014'].includes(issue.code)) return true;
    return /^(?:aborted|aborterror(?::.*)?|the operation was aborted\.?|signal is aborted without reason|failed to fetch|load failed|networkerror when attempting to fetch resource\.?|canceling statement due to statement timeout|expense review is waiting for the existing product refresh)$/i.test(issue.message || '');
  }
  async function read(rpc, name, args, applicable) {
    if (!queues.has(name)) throw Error('Unknown classification queue');
    let result;
    try {
      result = await rpc(name, args);
    } catch (error) {
      if (!transient(error)) throw error;
      result = {data: null, error};
    }
    if (!transient(result?.error) || !applicable()) return result;
    await new Promise(resolve => setTimeout(resolve, 750));
    if (!applicable()) return result;
    return rpc(name, args);
  }
  const api = {read};
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.LTSReviewRead = api;
})(typeof window === 'undefined' ? null : window);
