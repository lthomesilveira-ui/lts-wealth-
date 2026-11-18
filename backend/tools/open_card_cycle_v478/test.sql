\set ON_ERROR_STOP on
BEGIN;
CREATE SCHEMA lts_recurring_private_v469;
\ir functions.sql
DO $test$
DECLARE
  cards jsonb := '{"cards":[{"family":"aeternum","cycles":[{"month":"2028-04-01","due_date":"2028-05-04"}]}]}';
  month1 text := '2028-05-03'; month2 text := '2028-06-03';
  a jsonb := jsonb_build_object('account','Bradesco','source','planning_projection_v412','event_date',month1,'source_ref','projection:v469:owner_food:'||month1,'signed_amount',-6.65);
  b jsonb := a || jsonb_build_object('source_ref','projection:v469:sub_example:'||month1,'signed_amount',-3.35);
  later jsonb := a || jsonb_build_object('event_date',month2,'source_ref','projection:v469:owner_food:'||month2);
  real_charge jsonb := a || '{"source":"received","signed_amount":-109.50}'::jsonb;
  bank jsonb := a || '{"account":"Itaú"}'::jsonb;
  school jsonb := a || jsonb_build_object('source_ref','projection:v469:school_food:'||month1);
  refund jsonb := a || '{"signed_amount":10}'::jsonb;
  other_day jsonb := a || '{"event_date":"2028-05-05"}'::jsonb;
  series jsonb; original jsonb; result jsonb; shift jsonb;
BEGIN
  series := jsonb_build_array(
    jsonb_build_object('series_key','owner_food','coverage',jsonb_build_array(
      jsonb_build_object('event_date',month1,'additional_brl',6.65,'known_brl',3.35,'budget_total_brl',10),
      jsonb_build_object('event_date',month2,'additional_brl',6.65,'known_brl',3.35,'budget_total_brl',10)),
      'annual_totals','[{"year":2028,"known_brl":6.70,"additional_brl":13.30,"budget_total_brl":20}]'::jsonb),
    jsonb_build_object('series_key','subscription_example','coverage',jsonb_build_array(
      jsonb_build_object('event_date',month1,'additional_brl',3.35,'amount_brl',3.35)),
      'annual_totals','[{"year":2028,"additional_brl":3.35,"budget_total_brl":3.35}]'::jsonb));
  original := jsonb_build_object('events',jsonb_build_array(a,real_charge,b,school,later,bank,refund,other_day),'series',series,'unrelated',true);
  result := lts_recurring_private_v469.open_card_cycle_v478(original,cards,'2028-04-11');
  ASSERT result->'events'=jsonb_build_array(real_charge,school,later,bank,refund,other_day);
  ASSERT (result#>>'{series,0,coverage,0,additional_brl}')::numeric=0;
  ASSERT (result#>>'{series,0,coverage,0,budget_total_brl}')::numeric=3.35;
  ASSERT result#>'{series,0,coverage,1}'=original#>'{series,0,coverage,1}';
  ASSERT (result#>>'{series,0,annual_totals,0,additional_brl}')::numeric=6.65;
  ASSERT (result#>>'{series,0,annual_totals,0,budget_total_brl}')::numeric=13.35;
  ASSERT (result#>>'{series,1,coverage,0,amount_brl}')::numeric=0;
  ASSERT result->'unrelated'='true'::jsonb;
  ASSERT lts_recurring_private_v469.open_card_cycle_v478(result,cards,'2028-04-11')=result;
  ASSERT lts_recurring_private_v469.open_card_cycle_v478(original,'{}','2028-04-11')=result;
  ASSERT lts_recurring_private_v469.open_card_cycle_v478(NULL,cards,'2028-04-11') IS NULL;
  shift:=lts_recurring_private_v469.open_card_cycle_v478(original,'{"cards":[{"family":"aeternum","cycles":[{"month":"2028-04-01","due_date":"2028-06-01"}]}]}','2028-04-11');
  ASSERT NOT (shift->'events' @> jsonb_build_array(later));
  ASSERT lts_recurring_private_v469.open_card_cycle_v478(original,cards,'2028-05-20')->'events'=jsonb_build_array(a,real_charge,b,school,bank,refund,other_day);
  BEGIN
    PERFORM lts_recurring_private_v469.open_card_cycle_v478(jsonb_set(original,'{series,0,coverage,0,additional_brl}','9'),cards,'2028-04-11');
    RAISE EXCEPTION USING ERRCODE='XX000',MESSAGE='Inconsistent coverage accepted';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
END;
$test$;
ROLLBACK;
