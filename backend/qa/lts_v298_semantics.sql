-- Synthetic algebra checks: no credentials, bank records or project identities.
BEGIN;
DO $cases$ DECLARE failed integer; tested integer; BEGIN
 WITH native_ids(id) AS(VALUES('12345678-aaaa-bbbb-cccc-123456789abc'::uuid),('00000000-0000-0000-0000-000000000000'::uuid)),
 probes(value) AS(VALUES(NULL::text),(''),('garbage'),('12345678-aaaa-bbbb-cccc-123456789abc'),
 ('12345678-AAAA-BBBB-CCCC-123456789ABC'),(' 12345678-aaaa-bbbb-cccc-123456789abc'),
 ('12345678aaaabbbbcccc123456789abc'),('12345678-aaaa-bbbb-cccc-123456789abg'),
 ('00000000-0000-0000-0000-000000000000'),('{12345678-aaaa-bbbb-cccc-123456789abc}')),
 checked AS(SELECT id,value,id::text=value original,(id::text=value AND id=CASE WHEN value ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN value::uuid END) candidate FROM native_ids CROSS JOIN probes)
 SELECT count(*),count(*) FILTER(WHERE (original IS TRUE) IS DISTINCT FROM (candidate IS TRUE)) INTO tested,failed FROM checked;
 IF failed<>0 THEN RAISE EXCEPTION 'V298 strict identity mismatch: %',failed; END IF;
 RAISE NOTICE 'PASS: % strict native/text identity cases',tested;
END $cases$;
DO $pairs$ DECLARE failed integer; BEGIN
 WITH expenses(scenario,source_ref,competence_month,amount,source_table) AS(VALUES
 (1,'rep',date '2026-10-01',10::numeric,'provider'),(1,'old',date '2026-10-01',10,'provider'),
 (1,'unrelated',date '2026-10-01',10,'provider'),
 (2,'rep',date '2026-10-01',10,'provider'),(2,'old',date '2026-10-01',10,'provider'),(2,'old',date '2026-10-01',99,'other_source'),
 (3,'rep',date '2026-10-01',10,'provider'),(3,'old',date '2026-10-01',99,'provider'),
 (4,'rep',date '2026-10-01',10,'provider'),(4,'old',date '2026-11-01',10,'provider'),
 (5,'rep',date '2026-10-01',10,'provider'),(5,'old',NULL,10,'provider'),
 (6,'rep',date '2026-10-01',10,'provider'),(6,'old',date '2026-10-01',10,'provider'),(6,'old',date '2026-10-01',10,'provider'),
 (7,NULL,date '2026-10-01',10,'provider'),(7,'old',date '2026-10-01',10,'provider'),
 (8,'rep',date '2026-10-01',10,'provider'),(8,'old',date '2026-10-01',10,'provider'),(8,'old',date '2026-09-01',99,'provider')),
 pairs AS(SELECT n scenario,jsonb_build_object('representative_id','rep','prior_id','old','competence_month','2026-10-01',
 'representative_expense_identity',jsonb_build_object('amount',10,'source_table','provider'),
 'prior_expense_identity',jsonb_build_object('amount',10,'source_table','provider')) c,n IN(1,8) expected FROM generate_series(1,8)n),
 relevant AS MATERIALIZED(SELECT x.* FROM expenses x WHERE EXISTS(SELECT 1 FROM pairs p WHERE p.scenario=x.scenario
 AND (x.source_ref=p.c->>'representative_id' OR x.source_ref=p.c->>'prior_id') AND to_jsonb(x.competence_month)=p.c->'competence_month')),
 checked AS(SELECT p.scenario,p.expected,
 ((SELECT count(*) FROM expenses x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND (SELECT count(*) FROM expenses x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND EXISTS(SELECT 1 FROM expenses x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'representative_expense_identity'))
 AND EXISTS(SELECT 1 FROM expenses x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'prior_expense_identity'))) original,
 ((SELECT count(*) FROM relevant x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND (SELECT count(*) FROM relevant x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month')=1
 AND EXISTS(SELECT 1 FROM relevant x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'representative_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'representative_expense_identity'))
 AND EXISTS(SELECT 1 FROM relevant x WHERE x.scenario=p.scenario AND x.source_ref=p.c->>'prior_id' AND to_jsonb(x.competence_month)=p.c->'competence_month' AND to_jsonb(x) @> (p.c->'prior_expense_identity'))) candidate FROM pairs p)
 SELECT count(*) FILTER(WHERE original IS DISTINCT FROM candidate OR candidate IS DISTINCT FROM expected) INTO failed FROM checked;
 IF failed<>0 THEN RAISE EXCEPTION 'V298 multiplicity/mask mismatch: %',failed; END IF;
 RAISE NOTICE 'PASS: 8 pair cases including conflicting duplicate, identical duplicate, other source, changed amount, month and NULL';
END $pairs$;
CREATE TEMP TABLE workbook_fixture(id integer,evidence jsonb,amount numeric,description text,observed_date date) ON COMMIT DROP;
INSERT INTO workbook_fixture SELECT n,evidence,12.34,'unchanged row',date '2026-10-01' FROM(VALUES
 (1,'{}'::jsonb),(2,'{"source":"synthetic"}'::jsonb),(3,'{"bank_precedence_applied":true}'::jsonb),
 (4,'{"bank_precedence_applied":false}'::jsonb),(5,'{"bank_precedence_applied":null}'::jsonb),
 (6,NULL::jsonb),(7,'["bank_precedence_applied"]'::jsonb),(8,'[]'::jsonb))q(n,evidence);
DO $workbook$ DECLARE failed integer; BEGIN
 WITH variants AS(SELECT w.*,v.valid FROM workbook_fixture w CROSS JOIN(VALUES(false),(true))v(valid)),
 checked AS(SELECT w.id,w.valid,
 jsonb_populate_record(NULL::pg_temp.workbook_fixture,(to_jsonb(w)-'valid')||CASE WHEN valid THEN jsonb_build_object('amount',99.99,'evidence',w.evidence||jsonb_build_object('bank_precedence_applied',true)) ELSE jsonb_build_object('evidence',w.evidence-'bank_precedence_applied') END) original,
 CASE WHEN NOT valid AND jsonb_typeof(w.evidence)='object' AND NOT(w.evidence?'bank_precedence_applied') THEN jsonb_populate_record(NULL::pg_temp.workbook_fixture,to_jsonb(w)-'valid')
 ELSE jsonb_populate_record(NULL::pg_temp.workbook_fixture,(to_jsonb(w)-'valid')||CASE WHEN valid THEN jsonb_build_object('amount',99.99,'evidence',w.evidence||jsonb_build_object('bank_precedence_applied',true)) ELSE jsonb_build_object('evidence',w.evidence-'bank_precedence_applied') END) END candidate FROM variants w)
 SELECT count(*) FILTER(WHERE to_jsonb(original) IS DISTINCT FROM to_jsonb(candidate)) INTO failed FROM checked;
 IF failed<>0 THEN RAISE EXCEPTION 'V298 unchanged record shortcut mismatch: %',failed; END IF;
 RAISE NOTICE 'PASS: 16 whole-row workbook override/no-op cases';
END $workbook$;
SELECT 'PASS: 44 synthetic identity, multiplicity and whole-row preservation cases' result;
ROLLBACK;
