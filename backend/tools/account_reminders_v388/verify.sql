\set ON_ERROR_STOP on
SET TIME ZONE 'America/Sao_Paulo';
CREATE TABLE public.fixture_policy_cases_v388(label text PRIMARY KEY);
DO $test$
DECLARE current_report jsonb:=jsonb_build_object('version',387,'as_of',current_date,'recipient','owner@example.invalid','complete',true,'days',30,'accounts','[]'::jsonb,'scheduled_transfers','[]'::jsonb,'unfunded','[]'::jsonb,'cofrinho',jsonb_build_object('planning_budget_brl','500'),
 'actions',jsonb_build_array(jsonb_build_object('kind','suggested_redemption','from_bank','Cofrinho Itaú','to_bank','Itaú','execute_by',current_date+3,'amount_brl','50'),
 jsonb_build_object('kind','suggested_redemption','from_bank','Cofrinho Itaú','to_bank','Itaú','execute_by',current_date+19,'amount_brl','175')));
 previous jsonb;distant jsonb;changed jsonb;r jsonb;before_hash text:=(SELECT md5(jsonb_agg(to_jsonb(d)ORDER BY token)::text)FROM lts_account_reminder_private_v387.delivery d);
BEGIN
 r:=lts_account_reminder_private_v387.decision(current_report,current_report,now(),now());
 IF r->>'send'<>'false'THEN RAISE EXCEPTION 'Two unchanged redemptions to same bank repeated';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('same route different dates same day suppressed');
 previous:=jsonb_set(current_report,'{as_of}',to_jsonb((current_date-1)::text));
 r:=lts_account_reminder_private_v387.decision(current_report,previous,now()-interval'1 day',now());
 IF r->>'reason'<>'daily_action_reminder'THEN RAISE EXCEPTION 'Later amount compared to earlier action: %',r;END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('new day uses due reminder not false amount increase');
 distant:=jsonb_set(current_report,'{actions,0,execute_by}',to_jsonb((current_date+15)::text));previous:=jsonb_set(distant,'{as_of}',to_jsonb((current_date-1)::text));
 r:=lts_account_reminder_private_v387.decision(distant,previous,now()-interval'1 day',now());
 IF r->>'send'<>'false'THEN RAISE EXCEPTION 'Distant unchanged repeated: %',r;END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('distant unchanged two redemptions do not repeat daily');
 r:=lts_account_reminder_private_v387.decision(distant,previous,now()-interval'7 days',now());
 IF r->>'reason'<>'weekly_plan_review'THEN RAISE EXCEPTION 'Weekly reminder suppressed';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('weekly review retained');
 changed:=jsonb_set(current_report,'{actions,1,amount_brl}','"275"');r:=lts_account_reminder_private_v387.decision(changed,current_report,now(),now());
 IF r->>'reason'<>'action_increased_at_least_100'THEN RAISE EXCEPTION 'Actual later increase suppressed';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('later deadline actual increase retained');
 changed:=jsonb_set(current_report,'{actions,1,execute_by}',to_jsonb((current_date+18)::text));r:=lts_account_reminder_private_v387.decision(changed,current_report,now(),now());
 IF r->>'send'<>'true'THEN RAISE EXCEPTION 'Moved deadline suppressed';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('deadline change remains eligible');
 r:=lts_account_reminder_private_v387.decision(current_report,current_report,((current_date::timestamp AT TIME ZONE'America/Sao_Paulo')+interval'1 minute'),((current_date::timestamp AT TIME ZONE'America/Sao_Paulo')+interval'23 hours'));
 IF r->>'send'<>'false'THEN RAISE EXCEPTION 'UTC date boundary repeated local day';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('same São Paulo day across UTC midnight suppressed');
 IF before_hash IS DISTINCT FROM(SELECT md5(jsonb_agg(to_jsonb(d)ORDER BY token)::text)FROM lts_account_reminder_private_v387.delivery d)THEN RAISE EXCEPTION 'Delivery journal modified';END IF;INSERT INTO public.fixture_policy_cases_v388 VALUES('original delivery journal unchanged');
END $test$;
SELECT jsonb_build_object('version',388,'pass',true,'additional_policy_cases',(SELECT count(*)FROM public.fixture_policy_cases_v388),'existing_cases',(SELECT count(*)FROM public.fixture_assertions_v387),'journal_unchanged',true,'financial_sources_changed',false);
