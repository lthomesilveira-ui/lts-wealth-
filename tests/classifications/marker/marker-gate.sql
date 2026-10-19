-- Synthetic PostgreSQL 17 gate template. Render with marker_runner.build_marker_sql().
-- Never execute against an application database. Every fixture is invented.
-- Tokens supply byte-exact SELECT projections from sanitized public source fragments;
-- no private source file is read by the public runner.
BEGIN;
SET LOCAL search_path = pg_catalog, pg_temp;
SET LOCAL statement_timeout = '120s';
SET LOCAL lock_timeout = '5s';
SET LOCAL TimeZone = 'America/Sao_Paulo';
DO $guard$
BEGIN
  IF current_setting('server_version_num')::integer NOT BETWEEN 170000 AND 179999 THEN
    RAISE EXCEPTION 'marker gate requires PostgreSQL 17';
  END IF;
  IF current_database() <> 'wealth_synthetic_classifications' THEN
    RAISE EXCEPTION 'marker gate requires the disposable wealth_synthetic_classifications database';
  END IF;
  IF to_regprocedure('public.lts_expense_management_subgroup_v2(text,text,text,text,text)') IS NOT NULL THEN
    RAISE EXCEPTION 'marker gate refuses to replace an existing dependency';
  END IF;
END $guard$;

-- A predictable stand-in for the only external call in the exact final projection.
-- Its implementation is not part of this marker regression claim.
CREATE FUNCTION public.lts_expense_management_subgroup_v2(text,text,text,text,text)
RETURNS text LANGUAGE sql IMMUTABLE
SET search_path TO ''
AS $stub$ SELECT 'synthetic-subgroup'::text $stub$;

CREATE TEMP TABLE marker_input (
  source_ref text PRIMARY KEY,
  fixture_group text NOT NULL,
  source_table text NOT NULL DEFAULT 'synthetic_source',
  event_date date DEFAULT DATE '2040-02-12',
  transaction_date date DEFAULT DATE '2040-02-11',
  competence_month date DEFAULT DATE '2040-02-01',
  amount numeric DEFAULT 12.34,
  category text DEFAULT 'Synthetic category',
  category_decision text,
  person_final text,
  descr text DEFAULT 'Synthetic description',
  origin_name text DEFAULT 'Synthetic account',
  coverage_mode text DEFAULT 'synthetic_coverage',
  original_category text DEFAULT 'Synthetic raw category',
  center_cost text DEFAULT 'Synthetic center',
  counterparty text DEFAULT 'Synthetic counterparty',
  purchased date DEFAULT DATE '2040-02-10',
  kind text DEFAULT 'Synthetic kind',
  group_without_property text DEFAULT 'Synthetic group',
  prop_component text,
  prop text,
  old_group text DEFAULT 'Synthetic old group',
  expect_category_reason boolean DEFAULT false,
  expect_group_reason boolean DEFAULT false,
  expect_component_reason boolean DEFAULT NULL,
  expect_property_reason boolean DEFAULT false,
  expect_description_reason boolean DEFAULT false,
  expect_person_original boolean DEFAULT false,
  expect_person_candidate boolean DEFAULT false
);

-- Factorial matrix. Nullable reason flags are hand-specified fixture expectations,
-- independently of the extracted production expression; PostgreSQL evaluates all ORs.
INSERT INTO marker_input (
  source_ref,fixture_group,kind,person_final,category,category_decision,
  group_without_property,prop_component,prop,old_group,descr,
  expect_category_reason,expect_group_reason,expect_component_reason,
  expect_property_reason,expect_description_reason,expect_person_original,expect_person_candidate)
SELECT 'matrix_'||row_number() OVER (), 'matrix',k.kind,p.person,c.category,c.decision,
  g.label,pc.component,pr.prop,pr.old_group,d.descr,
  c.reason,g.reason,pc.reason,pr.reason,d.reason,
  k.old_person AND p.is_null,k.new_person AND p.is_null
FROM (VALUES
  ('Saúde'::text,true,false),('Vestuário',true,false),('Educação',true,true),
  ('Presentes',false,false),('Moradia',false,false),('Synthetic kind',false,false),
  ('',false,false),(NULL,NULL,NULL)
) k(kind,old_person,new_person)
CROSS JOIN (VALUES (NULL::text,true),('synthetic-person',false),('',false)) p(person,is_null)
CROSS JOIN (VALUES
  ('Synthetic category'::text,NULL::text,false),('A classificar',NULL,true),
  (NULL,NULL,false),('A classificar','Synthetic override',false),
  ('Synthetic category','Sem categoria',true)
) c(category,decision,reason)
CROSS JOIN (VALUES ('Synthetic group'::text,false),('Synthetic a revisar',true),(NULL,NULL)) g(label,reason)
CROSS JOIN (VALUES ('Synthetic component'::text,false),('A revisar',true),(NULL,NULL)) pc(component,reason)
CROSS JOIN (VALUES
  (NULL::text,'Moradia'::text,true),(NULL,'Condomínio',true),
  (NULL,'Energia',true),(NULL,'Impostos do imóvel',true),
  (NULL,'Investimento no imóvel — aquisição e histórico',true),(NULL,'Seguro Residencial',true),
  (NULL,'Synthetic old group',false),(NULL,NULL,NULL),
  ('synthetic-property','Moradia',false),('synthetic-property',NULL,false),
  ('synthetic-property-matched','Synthetic old group',false),
  (NULL,'Empréstimos',false)
) pr(prop,old_group,reason)
CROSS JOIN (VALUES ('Synthetic description'::text,false),('Descrição pendente',true),(NULL,NULL)) d(descr,reason);

-- Named boundary cases supplement the matrix: normalization, exact comparisons,
-- SQL NULL, assigned empty person, nullable financial fields and all source columns.
INSERT INTO marker_input (source_ref,fixture_group,kind,category,category_decision,
  person_final,group_without_property,prop_component,prop,old_group,descr,
  expect_category_reason,expect_group_reason,expect_component_reason,
  expect_property_reason,expect_description_reason,expect_person_original,expect_person_candidate)
VALUES
 ('health_generic','named','Saúde','Saúde',NULL,NULL,'Saúde',NULL,NULL,'Saúde','Synthetic description',false,false,NULL,false,false,true,false),
 ('clothing_generic','named','Vestuário','Vestuário',NULL,NULL,'Vestuário',NULL,NULL,'Vestuário','Synthetic description',false,false,NULL,false,false,true,false),
 ('education_kept','named','Educação','Educação',NULL,NULL,'Educação',NULL,NULL,'Educação','Synthetic description',false,false,NULL,false,false,true,true),
 ('education_person_assigned','named','Educação','Educação',NULL,'synthetic-person','Educação',NULL,NULL,'Educação','Synthetic description',false,false,NULL,false,false,false,false),
 ('education_empty_person','named','Educação','Educação',NULL,'','Educação',NULL,NULL,'Educação','Synthetic description',false,false,NULL,false,false,false,false),
 ('normalized_category','named','Saúde','NÃO  IDENTIFICADO',NULL,NULL,'Saúde',NULL,NULL,'Saúde','Synthetic description',true,false,NULL,false,false,true,false),
 ('normalized_decision','named','Saúde','Synthetic category','SEM CATEGORIA',NULL,'Saúde',NULL,NULL,'Saúde','Synthetic description',true,false,NULL,false,false,true,false),
 ('description_unknown','named','Saúde','Saúde',NULL,NULL,'Saúde',NULL,NULL,'Saúde','Não identificado',false,false,NULL,false,true,true,false),
 ('description_case_exact','named','Saúde','Saúde',NULL,NULL,'Saúde',NULL,NULL,'Saúde','não identificado',false,false,NULL,false,false,true,false),
 ('group_suffix_exact','named','Saúde','Saúde',NULL,NULL,'Synthetic a revisar extra',NULL,NULL,'Saúde','Synthetic description',false,false,NULL,false,false,true,false),
 ('group_case_exact','named','Saúde','Saúde',NULL,NULL,'Synthetic A revisar',NULL,NULL,'Saúde','Synthetic description',false,false,NULL,false,false,true,false),
 ('null_financial_fields','named','Saúde',NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,false,NULL,NULL,NULL,NULL,true,false),
 ('loan_subgroup_stub','named','Saúde','Saúde',NULL,NULL,'Empréstimos',NULL,NULL,'Empréstimos','Synthetic description',false,false,NULL,false,false,true,false);

UPDATE marker_input SET event_date=NULL,transaction_date=NULL,competence_month=NULL,
 amount=NULL,origin_name=NULL,coverage_mode=NULL,original_category=NULL,
 center_cost=NULL,counterparty=NULL,purchased=NULL WHERE source_ref='null_financial_fields';

CREATE FUNCTION pg_temp.marker_projection_original()
RETURNS TABLE(__RETURN_COLUMNS__)
LANGUAGE sql STABLE SET search_path TO ''
AS $original$
WITH labeled AS (SELECT * FROM pg_temp.marker_input)
__ORIGINAL_FINAL_PROJECTION__
$original$;
CREATE FUNCTION pg_temp.marker_projection_candidate()
RETURNS TABLE(__RETURN_COLUMNS__)
LANGUAGE sql STABLE SET search_path TO ''
AS $candidate$
WITH labeled AS (SELECT * FROM pg_temp.marker_input)
__CANDIDATE_FINAL_PROJECTION__
$candidate$;

CREATE TEMP TABLE marker_original AS SELECT * FROM pg_temp.marker_projection_original();
CREATE TEMP TABLE marker_candidate AS SELECT * FROM pg_temp.marker_projection_candidate();
CREATE TEMP TABLE marker_expectations AS
SELECT source_ref,
  (expect_category_reason OR expect_group_reason OR expect_component_reason OR
   expect_person_original OR expect_property_reason OR expect_description_reason) old_raw,
  (expect_category_reason OR expect_group_reason OR expect_component_reason OR
   expect_person_candidate OR expect_property_reason OR expect_description_reason) new_raw
FROM marker_input;

-- Independently execute the actual raw predicate so NULL is distinguished from false;
-- CASE alone maps both to identified and would miss this three-valued-logic regression.
CREATE TEMP TABLE marker_predicates AS
SELECT source_ref,(__ORIGINAL_RAW_PREDICATE__) old_raw,
                  (__CANDIDATE_RAW_PREDICATE__) new_raw
FROM marker_input;
CREATE TEMP TABLE marker_checks (test text PRIMARY KEY, passed boolean NOT NULL, checked_rows bigint NOT NULL);
INSERT INTO marker_checks
SELECT 'original_matches_oracle',count(*) FILTER (WHERE o.identity_status IS DISTINCT FROM
  CASE WHEN e.old_raw THEN 'pending' ELSE 'identified' END)=0,count(*)
FROM marker_original o JOIN marker_expectations e USING(source_ref)
UNION ALL
SELECT 'candidate_matches_oracle',count(*) FILTER (WHERE n.identity_status IS DISTINCT FROM
  CASE WHEN e.new_raw THEN 'pending' ELSE 'identified' END)=0,count(*)
FROM marker_candidate n JOIN marker_expectations e USING(source_ref)
UNION ALL
SELECT 'sql_null_raw_predicates',count(*) FILTER (WHERE
 p.old_raw IS DISTINCT FROM e.old_raw OR p.new_raw IS DISTINCT FROM e.new_raw)=0,count(*)
FROM marker_predicates p JOIN marker_expectations e USING(source_ref)
UNION ALL
SELECT 'nineteen_other_columns_invariant',count(*) FILTER (WHERE
 (to_jsonb(o)-'identity_status') IS DISTINCT FROM (to_jsonb(n)-'identity_status'))=0,count(*)
FROM marker_original o JOIN marker_candidate n USING(source_ref)
UNION ALL
SELECT 'only_allowed_transitions',count(*) FILTER (WHERE
 o.identity_status IS DISTINCT FROM n.identity_status AND NOT
 (o.identity_status='pending' AND n.identity_status='identified' AND
  i.kind IN ('Saúde','Vestuário') AND i.person_final IS NULL))=0,count(*)
FROM marker_original o JOIN marker_candidate n USING(source_ref) JOIN marker_input i USING(source_ref)
UNION ALL
SELECT 'never_creates_pending',count(*) FILTER (WHERE o.identity_status='identified' AND n.identity_status='pending')=0,count(*)
FROM marker_original o JOIN marker_candidate n USING(source_ref)
UNION ALL
SELECT 'education_is_invariant',count(*) FILTER (WHERE o.identity_status IS DISTINCT FROM n.identity_status)=0,count(*)
FROM marker_original o JOIN marker_candidate n USING(source_ref) JOIN marker_input i USING(source_ref) WHERE i.kind='Educação'
UNION ALL
SELECT 'all_unrelated_reasons_preserved',count(*) FILTER (WHERE n.identity_status<>'pending')=0,count(*)
FROM marker_candidate n JOIN marker_input i USING(source_ref)
WHERE expect_category_reason OR expect_group_reason OR expect_component_reason OR expect_property_reason OR expect_description_reason
UNION ALL
SELECT 'nullable_raw_coverage',count(*) FILTER (WHERE old_raw IS NULL)>0 AND
 count(*) FILTER (WHERE new_raw IS NULL)>0 AND count(*) FILTER (WHERE old_raw IS TRUE)>0 AND
 count(*) FILTER (WHERE new_raw IS FALSE)>0,count(*) FROM marker_predicates
UNION ALL
SELECT 'named_generic_transitions',count(*) FILTER (WHERE o.identity_status='pending' AND n.identity_status='identified')=2,count(*)
FROM marker_original o JOIN marker_candidate n USING(source_ref) WHERE source_ref IN ('health_generic','clothing_generic')
UNION ALL
SELECT 'loan_subgroup_uses_declared_stub',bool_and(management_subgroup='synthetic-subgroup'),count(*)
FROM marker_candidate n JOIN marker_input i USING(source_ref) WHERE i.old_group='Empréstimos' AND i.prop IS NULL;

INSERT INTO marker_checks
SELECT 'matched_property_projection_branch',
 bool_and(n.management_group='Synthetic property display' AND n.management_subgroup IS NOT DISTINCT FROM i.prop_component),count(*)
FROM marker_candidate n JOIN marker_input i USING(source_ref) WHERE i.prop='synthetic-property-matched';

INSERT INTO marker_checks
SELECT 'row_cardinality_and_key_set',
 (SELECT count(*) FROM marker_original)=(SELECT count(*) FROM marker_input) AND
 (SELECT count(*) FROM marker_candidate)=(SELECT count(*) FROM marker_input) AND
 NOT EXISTS ((SELECT source_ref FROM marker_input EXCEPT SELECT source_ref FROM marker_original)
  UNION ALL (SELECT source_ref FROM marker_input EXCEPT SELECT source_ref FROM marker_candidate)) AND
 (SELECT count(DISTINCT source_ref) FROM marker_candidate)=(SELECT count(*) FROM marker_input),
 (SELECT count(*) FROM marker_input);

-- Counts and sanitized fixture keys only. No projected source fields or SQL bodies are emitted.
SELECT jsonb_build_object(
 'suite','generic_identity_marker',
 'server_version_num',current_setting('server_version_num')::integer,
 'synthetic_rows',(SELECT count(*) FROM marker_input),
 'matrix_rows',(SELECT count(*) FROM marker_input WHERE fixture_group='matrix'),
 'named_rows',(SELECT count(*) FROM marker_input WHERE fixture_group='named'),
 'status_changes',(SELECT count(*) FROM marker_original o JOIN marker_candidate n USING(source_ref)
   WHERE o.identity_status IS DISTINCT FROM n.identity_status),
 'null_original_predicates',(SELECT count(*) FROM marker_predicates WHERE old_raw IS NULL),
 'null_candidate_predicates',(SELECT count(*) FROM marker_predicates WHERE new_raw IS NULL),
 'checks',(SELECT jsonb_agg(jsonb_build_object('test',test,'passed',passed,'checked_rows',checked_rows) ORDER BY test) FROM marker_checks),
 'passed',(SELECT bool_and(passed) FROM marker_checks),
 'failures',(SELECT coalesce(jsonb_agg(test ORDER BY test),'[]'::jsonb) FROM marker_checks WHERE NOT passed)
);
DO $assert$
BEGIN
 IF EXISTS (SELECT 1 FROM marker_checks WHERE NOT passed) THEN
   RAISE EXCEPTION 'generic marker regression failed; see sanitized assertion report';
 END IF;
END $assert$;
ROLLBACK;
