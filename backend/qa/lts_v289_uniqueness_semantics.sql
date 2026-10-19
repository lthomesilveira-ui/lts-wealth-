WITH base(id,source_table,source_ref,competence_month,expected) AS(VALUES
(1,'a','u',date '2020-01-01',true),(2,'a','dup',date '2020-01-01',false),(3,'a','dup',date '2020-01-01',false),
(4,'b','u',date '2020-01-01',true),(5,'a','u',date '2020-02-01',true),(6,null,'u',date '2020-01-01',false),
(7,'a',null,date '2020-01-01',false),(8,'a','u',null,false),(9,null,null,null,false),(10,'a','',date '2020-01-01',true),
(11,'','u',date '2020-01-01',true),(12,'a','triple',date '2020-01-01',false),(13,'a','triple',date '2020-01-01',false),
(14,'a','triple',date '2020-01-01',false),(15,'a','u',date '2019-01-01',true),(16,'A','u',date '2020-01-01',true),
(17,'a','U',date '2020-01-01',true),(18,'a',' spaced ',date '2020-01-01',true),(19,'a','spaced',date '2020-01-01',true),
(20,'a','dup',date '2020-02-01',true),(21,'a','dup',null,false)
), unique_keys AS MATERIALIZED(
 SELECT source_table,source_ref,competence_month FROM base GROUP BY 1,2,3 HAVING count(*)=1
), checked AS(
 SELECT b.id,b.expected,
 (SELECT count(*) FROM base x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month)=1 original,
 EXISTS(SELECT 1 FROM unique_keys x WHERE x.source_table=b.source_table AND x.source_ref=b.source_ref AND x.competence_month=b.competence_month) candidate FROM base b
)
SELECT jsonb_build_object('cases',count(*),'passed',bool_and(original=candidate AND candidate=expected),'failed',count(*)FILTER(WHERE original IS DISTINCT FROM candidate OR candidate IS DISTINCT FROM expected)) receipt FROM checked;
