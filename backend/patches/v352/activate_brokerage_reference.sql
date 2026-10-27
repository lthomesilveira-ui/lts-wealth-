-- Service-only manifest. This batch inserts one documentary reference.
DO $apply$
DECLARE u uuid:=current_setting('lts.v352_owner')::uuid;m jsonb:=current_setting('lts.v352_manifest')::jsonb;
 before_j jsonb;after_j jsonb;before_snapshots jsonb;after_snapshots jsonb;
BEGIN
 IF u IS NULL OR public.lts_browser_assert_user_v1()IS DISTINCT FROM u OR m->>'institution'<>'Morgan Stanley'OR m->>'source_file'IS NULL
 OR m->>'source_sha256'!~'^[0-9a-f]{64}$'OR jsonb_typeof(m->'position_as_of')IS DISTINCT FROM 'null'
 OR(m->>'received_on')::date>current_date OR m#>>'{metadata,reference_only}'IS DISTINCT FROM 'true'
 OR m#>>'{metadata,position_date_status}'IS DISTINCT FROM 'not_visible'
 OR jsonb_typeof(m#>'{metadata,unavailable_components,regular_rsu_brl}')IS DISTINCT FROM 'null'
 OR jsonb_typeof(m#>'{metadata,unavailable_components,cash_rsu_brl}')IS DISTINCT FROM 'null'
 OR(m->>'total_gross_brl')::numeric IS DISTINCT FROM(m->>'available_total_brl')::numeric+(m->>'unavailable_total_brl')::numeric
 THEN RAISE EXCEPTION 'V352_INVALID_DOCUMENTARY_REFERENCE';END IF;
 IF EXISTS(SELECT 1 FROM public.lts_brokerage_reference_v352 WHERE user_id=u AND institution=m->>'institution'AND source_sha256=m->>'source_sha256')THEN RAISE EXCEPTION 'V352_ALREADY_RECORDED_REVIEW_REQUIRED';END IF;
 before_j:=public.lts_browser_wealth_detail_v242();
 SELECT jsonb_agg(to_jsonb(s)ORDER BY id)INTO before_snapshots FROM public.lts_brokerage_position_snapshots s WHERE user_id=u;
 INSERT INTO public.lts_brokerage_reference_v352(user_id,institution,received_on,position_as_of,total_gross_brl,available_total_brl,unavailable_total_brl,source_file,source_sha256,metadata)
 VALUES(u,m->>'institution',(m->>'received_on')::date,NULL,(m->>'total_gross_brl')::numeric,(m->>'available_total_brl')::numeric,(m->>'unavailable_total_brl')::numeric,m->>'source_file',m->>'source_sha256',m->'metadata');
 after_j:=public.lts_browser_wealth_detail_v242();
 SELECT jsonb_agg(to_jsonb(s)ORDER BY id)INTO after_snapshots FROM public.lts_brokerage_position_snapshots s WHERE user_id=u;
 IF before_snapshots IS DISTINCT FROM after_snapshots
 OR before_j->'morgan_statement'IS DISTINCT FROM after_j->'morgan_statement'
 OR before_j->'current_awards'IS DISTINCT FROM after_j->'current_awards'
 OR before_j->'rsu_summary'IS DISTINCT FROM after_j->'rsu_summary'
 OR before_j#>'{wealth,summary}'IS DISTINCT FROM after_j#>'{wealth,summary}'
 OR before_j->'rsu'IS DISTINCT FROM after_j->'rsu'
 OR(before_j->'current_liquidity'-'computed_at')IS DISTINCT FROM(after_j->'current_liquidity'-'computed_at')
 THEN RAISE EXCEPTION 'V352_EXISTING_VALUATION_OR_CASH_CHANGED';END IF;
 IF after_j#>>'{brokerage_reference,source_sha256}'IS DISTINCT FROM m->>'source_sha256'
 OR after_j#>'{brokerage_reference,position_as_of}'IS DISTINCT FROM 'null'::jsonb
 OR after_j#>>'{brokerage_reference,included_in_current_liquidity}'IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'V352_REFERENCE_READER_MISMATCH';END IF;
 PERFORM set_config('lts.v352_receipt',jsonb_build_object('pass',true,'new_references',1,'dated_positions_unchanged',true,'current_liquidity_unchanged',true,'projection_schedule_unchanged',true,'unknown_position_date_preserved',true,'unavailable_components_not_inferred',true)::text,true);
END $apply$;
