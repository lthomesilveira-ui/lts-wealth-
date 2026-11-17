CREATE SCHEMA lts_fgts_private_v419;
CREATE TABLE public.lts_product_read_cache(user_id uuid PRIMARY KEY,payload jsonb,refreshed_at timestamptz,source text);
CREATE TABLE public.fixture_sources(user_id uuid PRIMARY KEY,source_key text);
INSERT INTO fixture_sources VALUES('00000000-0000-4000-8000-000000000001','source-one');
CREATE TABLE fixture_calls(n integer);
INSERT INTO fixture_calls VALUES(0);
CREATE FUNCTION public.lts_dashboard_source_key_v240(uuid) RETURNS text LANGUAGE sql SET search_path='' AS $$SELECT source_key FROM public.fixture_sources WHERE user_id=$1$$;
CREATE FUNCTION public.lts_dashboard_payload_key_v240(jsonb) RETURNS text LANGUAGE sql SET search_path='' AS $$SELECT md5(($1-'canonical_summary')::text)$$;
CREATE FUNCTION public.lts_flow_cache_core_v240(uuid,date,date) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$
 SELECT jsonb_build_object('flow',jsonb_build_object('current_future',jsonb_build_object('days',
 jsonb_build_array(jsonb_build_object('date',$2,'fix86_columns',jsonb_build_object('fgts',0,'saldo_final',123.456789))),
 'events',jsonb_build_array(jsonb_build_object('signed_amount',-98.765432,'description','synthetic-only'))),
 'fgts_position',jsonb_build_object('amount',0)))$$;
CREATE FUNCTION lts_fgts_private_v419.align_flow(uuid,jsonb,date) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT $2$$;
CREATE FUNCTION lts_fgts_private_v419.wealth(jsonb,jsonb,numeric) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT $1||jsonb_build_object('fgts',$2)$$;
CREATE FUNCTION public.lts_planning_executive_from_flow_v1(uuid,date,date,jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT jsonb_build_object('period',jsonb_build_object('from',$2,'to',$3),'layers',jsonb_build_array(1,NULL,3),'summary',jsonb_build_object('first_real_gap_date',NULL,'first_negative_even_with_fgts',NULL),'fgts_access','restricted')$$;
CREATE FUNCTION public.lts_dashboard_executive_from_flow_v1(uuid,date,jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT jsonb_build_object('today',$2,'cash',123.456789)$$;
CREATE FUNCTION public.lts_wealth_executive_report_v5(uuid) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT '{"wealth":"fixture","unknown":null,"exact":1.234567}'::jsonb$$;
CREATE FUNCTION public.lts_updates_current_sources_v240(uuid) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT '{"sources":"synthetic"}'::jsonb$$;
CREATE FUNCTION public.lts_updates_salary_coverage_v243(uuid,jsonb,jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT $2||jsonb_build_object('fixture_flow',$3)$$;
CREATE FUNCTION public.lts_v229_review_rows(uuid,date,date) RETURNS TABLE(event_date date,source_ref text,identity_status text,amount numeric) LANGUAGE sql SET search_path='' AS $$VALUES($3,'one','pending',123.456789),($3,'two','pending',-8.765432),($3,'known','identified',700)$$;
CREATE FUNCTION public.lts_card_operating_view_v2(uuid,date) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT '{"known_invoice":42.123456}'::jsonb$$;
CREATE FUNCTION public.lts_cashflow_scenarios_from_flow_v1(uuid,date,date,jsonb) RETURNS jsonb LANGUAGE sql SET search_path='' AS $$SELECT jsonb_build_object('end',$3,'flow',$4)$$;
CREATE FUNCTION public.lts_refresh_dashboard_cockpit_v2(uuid) RETURNS jsonb LANGUAGE plpgsql SET search_path='' AS $$BEGIN UPDATE public.fixture_calls SET n=n+1;RETURN '{"fixture":"cockpit"}'::jsonb;END$$;
