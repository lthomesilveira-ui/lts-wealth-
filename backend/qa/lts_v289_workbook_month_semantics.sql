WITH scoped(scenario,competence_month,coverage_mode) AS(VALUES
(1,date '2020-01-01','card_category_allocated_workbook_v176'),(1,date '2020-01-01','card_category_allocated_workbook_v176'),
(1,date '2020-02-01','card_bank_closed_complete'),(1,date '2020-03-01',null),
(1,null,'card_category_allocated_workbook_v176'),(1,date '2020-04-01','CARD_CATEGORY_ALLOCATED_WORKBOOK_V176')
), probes(id,scenario,reference_month,expected)AS(VALUES
(1,1,date '2020-01-01',false),(2,1,date '2020-02-01',true),(3,1,date '2020-03-01',true),
(4,1,date '2020-04-01',true),(5,1,date '2020-05-01',true),(6,1,null,true),
(7,1,date '2019-12-01',true),(8,1,date '2021-01-01',true),(9,2,date '2020-01-01',true),(10,2,null,true)
), workbook_months AS MATERIALIZED(
 SELECT DISTINCT scenario,competence_month FROM scoped WHERE coverage_mode='card_category_allocated_workbook_v176'
), checked AS(
 SELECT p.id,p.expected,
 NOT EXISTS(SELECT 1 FROM scoped w WHERE w.scenario=p.scenario AND w.competence_month=p.reference_month AND w.coverage_mode='card_category_allocated_workbook_v176') original,
 NOT EXISTS(SELECT 1 FROM workbook_months w WHERE w.scenario=p.scenario AND w.competence_month=p.reference_month) candidate FROM probes p
)
SELECT jsonb_build_object('cases',count(*),'passed',bool_and(original=candidate AND candidate=expected),'failed',count(*)FILTER(WHERE original IS DISTINCT FROM candidate OR candidate IS DISTINCT FROM expected)) receipt FROM checked;
