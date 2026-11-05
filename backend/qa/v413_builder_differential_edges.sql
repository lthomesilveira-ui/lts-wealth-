-- Synthetic values only. Run in the disposable fixture database.
SELECT qa_v412.reset();
SELECT qa_v412.set_policy(qa_v412.policy('fixed','{"amount_brl":100}'));
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2021-02-01','Itaú','synthetic',-10,'document',NULL,NULL),
 ('2021-02-02','Itaú','synthetic',-20,'legacy_fix86','duplicate',NULL),
 ('2021-02-03','Itaú','synthetic',0,'document','zero','confirmed'),
 ('2021-02-04','Itaú','synthetic',15,'document','opposite-sign','confirmed'),
 ('2021-02-05','Itaú','synthetic',NULL,'document','null-amount','confirmed'),
 ('2021-02-06','Itaú',NULL,-100,'document','null-description','confirmed'),
 ('2021-02-07','Itaú','synthetic',-100,NULL,'null-source','confirmed'),
 ('2021-02-08','Itaú','synthetic',-5,'document','duplicate','confirmed');
SELECT qa_v413.check_case('fixed null refs confidence source and signed zero','2020-11-04');
SELECT qa_v413.check_case('owner without policy preserves disabled result','2020-11-04',qa_v412.owner(2));

SELECT qa_v412.reset();
SELECT qa_v412.set_policy(qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020,"template_year":2020}'));
INSERT INTO qa_v412.calendar(series_key,template_year,event_month,event_day,amount_brl,source_ref) VALUES
 ('synthetic',2020,2,18,100,'tax-a'),('synthetic',2020,3,15,100,'tax-b'),('synthetic',2020,5,28,20,'license');
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2021-01-01','Itaú','synthetic',-100,'legacy_fix86','duplicate','legacy_projection_adjusted'),
 ('2021-03-01','Itaú','synthetic',-150,'legacy_fix86','duplicate','legacy_projection_adjusted'),
 ('2022-01-01','Itaú','synthetic',-400,'legacy_fix86','duplicate','legacy_projection_adjusted'),
 ('2021-02-05','Itaú','synthetic',-40,'document','protected-month','confirmed'),
 ('2021-03-05','Itaú','synthetic',0,'legacy_fix86','zero','legacy_projection_adjusted'),
 ('2021-04-05','Itaú','synthetic',-30,'legacy_fix86','unknown-confidence',NULL);
SELECT qa_v413.check_case('legacy duplicate refs cross year and protected documentary month','2020-11-04');
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence)
 VALUES('2021-03-02','Itaú','synthetic',0,'legacy_fix86',NULL,'legacy_projection_adjusted');
SELECT qa_v413.check_case('legacy null reference preserves replacement_seen three-valued logic','2020-11-04');

SELECT qa_v412.reset();
SELECT qa_v412.set_policy(jsonb_set(
 qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020,"template_year":2020}'),
 '{rules}',
 jsonb_build_array(
  qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020,"template_year":2020}')#>'{rules,0}',
  (qa_v412.policy('inflated_calendar','{"annual_rate":0.05,"base_year":2020,"template_year":2020}')#>'{rules,0}')||'{"series_key":"second","description":"second"}'::jsonb
 )));
INSERT INTO qa_v412.calendar(series_key,template_year,event_month,event_day,amount_brl,source_ref) VALUES
 ('synthetic',2020,2,18,100,'template-a'),('second',2020,2,18,200,'template-b');
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2021-01-01','Itaú','synthetic',-100,'legacy_fix86','global-ref','legacy_projection_adjusted'),
 ('2021-01-01','Itaú','second',-200,'legacy_fix86','global-ref','legacy_projection_adjusted'),
 ('2022-01-01','Itaú','second',-300,'legacy_fix86','global-ref','legacy_projection_adjusted');
SELECT qa_v413.check_case('replacement identity shared across series and years','2020-11-04');

SELECT qa_v412.reset();
SELECT qa_v412.set_policy(qa_v412.policy('history_total_budget','{"card_family":"synthetic_shift","due_day":31}'));
INSERT INTO qa_v412.history(series_key,month,amount_brl,coverage)
 SELECT 'synthetic',m::date,1000,'complete' FROM generate_series(date '2019-11-01',date '2020-10-01',interval '1 month')m;
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2021-02-20','Itaú','synthetic',-100,'card_invoice','invoice-a','confirmed'),
 ('2021-02-21','Itaú','synthetic',-100,'card_invoice','invoice-b','confirmed');
INSERT INTO qa_v412.cycles(series_key,reference_month,due_date,amount_brl,closed,paid,complete) VALUES
 ('synthetic','2021-01-01','2021-02-20',100,false,false,true),
 ('synthetic','2021-02-01','2021-02-21',100,NULL,NULL,true),
 ('synthetic','2021-03-01','2021-03-20',NULL,false,false,NULL),
 (NULL,'2021-02-01','2021-02-20',999,true,true,true),
 ('synthetic','2021-04-01',NULL,999,true,true,true);
SELECT qa_v413.check_case('canonical minimum due duplicate cycles null amount flags and shifted cash date','2020-11-04');
UPDATE qa_v412.cycles SET paid=true WHERE due_date='2021-02-21';
SELECT qa_v413.check_case('one paid cycle protects whole canonical period','2020-11-04');
UPDATE qa_v412.cycles SET paid=false,complete=false WHERE due_date='2021-02-21';
SELECT qa_v413.check_case('one incomplete cycle retains unresolved period','2020-11-04');

SELECT qa_v412.reset();
SELECT qa_v412.set_policy(qa_v412.policy('salary_net','{"series_key":"salary","description":"Salário líquido","direction":"income","amount_brl":1000,"due_day":28,"withholding_commitment":"synthetic-loan","withholding_ends_on":"2022-12-31","withholding_end_source_ref":"synthetic-contract-end"}'));
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2020-11-28','Itau','Salário',1000,'financial_events','gross-known','confirmed'),
 ('2020-12-28','Itaú','Salário líquido',100,'financial_events','partial-net','confirmed');
INSERT INTO qa_v412.withholding VALUES(qa_v412.owner(),'gross-known',-250);
INSERT INTO public.lts_commitment_documentary_schedule VALUES
 (qa_v412.owner(),'synthetic-loan','2020-11-25',250),
 (qa_v412.owner(),'synthetic-loan','2020-12-20',-100),
 (qa_v412.owner(),'synthetic-loan','2020-12-25',150),
 (qa_v412.owner(2),'synthetic-loan','2020-12-25',999),
 (qa_v412.owner(),'other-loan','2020-12-25',999);
SELECT qa_v413.check_case('salary documentary sums missing months owner scope and evidenced end','2020-11-04');
SELECT qa_v413.check_case('salary post contract end','2023-01-01');

SELECT qa_v412.reset();
SELECT qa_v412.set_policy(jsonb_set(jsonb_set(
 qa_v412.policy('fixed','{"amount_brl":100,"due_day":31,"amount_changes":[{"effective_on":"2027-02-01","amount_brl":120,"source_ref":"synthetic-price"}]}'),
 '{approved_on}','"2026-11-04"'),'{rules,0,starts_on}','"2026-11-06"'));
INSERT INTO qa_v412.raw_flow(event_date,account,description,signed_amount,source,source_ref,confidence) VALUES
 ('2026-11-04','Itaú','synthetic',-100,'document','past','confirmed'),
 ('2026-11-05','Itaú','synthetic',-100,'document','as-of','confirmed'),
 ('2026-11-06','Itaú','synthetic',-20,'document','future','confirmed'),
 ('2027-01-01','Itaú','synthetic',-40,'document','new-year','confirmed'),
 ('2028-02-29','Itaú','synthetic',-50,'document','leap-day','confirmed');
SELECT qa_v413.check_case('exact 2026 as_of cutoff','2026-11-05');
SELECT qa_v413.check_case('December 31 horizon','2026-12-31');
SELECT qa_v413.check_case('January 1 rolling horizon','2027-01-01');
SELECT qa_v413.check_case('leap year due-day clamping','2027-12-31');
SELECT qa_v413.check_case('future as_of past all known rows','2031-12-31');
