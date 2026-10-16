-- Validate both the live state and the entire durable metadata independently of the event marker.
IF v_receipt IS NULL OR v_link IS NULL OR v_decision IS NULL THEN RAISE EXCEPTION 'partial state has no exact receipt'; END IF;
v_stamp:=(v_link->>'confirmed_at')::timestamptz;
IF v_link IS DISTINCT FROM jsonb_build_object('id',(v_link->>'id')::bigint,
 'user_id',c->>'owner_id','target_event_id',c->>'target_id','candidate_source_table','lts_open_finance_staging',
 'candidate_source_ref',c->>'source_id','candidate_event_date',c->>'posted_date','candidate_amount',(c->>'amount')::numeric,
 'note',c->>'note','confirmed_at',to_jsonb(v_stamp))
 OR v_stamp IS NULL OR (v_link->>'id')::bigint<=0
THEN RAISE EXCEPTION 'link postimage mismatch'; END IF;
IF v_decision IS DISTINCT FROM jsonb_build_object('user_id',c->>'owner_id','source_table','lts_open_finance_staging',
 'source_ref',c->>'source_id','category_label',c->>'category','property_code',c->>'property_code',
 'beneficiary',NULL,'decision_basis',c->>'decision_basis','decided_at',to_jsonb(v_stamp))
THEN RAISE EXCEPTION 'classification postimage mismatch'; END IF;
v_marker:=jsonb_build_object(
 'operation_id',c->>'operation_id','user_message_id',c->>'user_message_id',
 'source_table','lts_open_finance_staging','source_ref',c->>'source_id','source_owner',c->>'owner_id',
 'source_lease',c->'source_lease','original_event',c->'original_event','original_event_md5',c->>'original_event_md5',
 'original_amount',(c->>'amount')::numeric,'original_date',c->>'forecast_date',
 'posted_amount',(c->>'amount')::numeric,'posted_date',c->>'posted_date','amount_difference',0,
 'date_difference_days',(c->>'posted_date')::date-(c->>'forecast_date')::date,
 'residual_created',false,'official_provider_link',false,'applied_at',to_jsonb(v_stamp),
 'link_snapshot',v_link,'decision_snapshot',v_decision,'learning',c->'learning');
v_expected:=c->'original_event'||jsonb_build_object('is_suppressed',true,'suppression_reason',c->>'reason',
 'metadata',(c#>'{original_event,metadata}')||jsonb_build_object(c->>'marker',v_marker));
IF v_event IS DISTINCT FROM v_expected THEN RAISE EXCEPTION 'event postimage mismatch or later edit'; END IF;
v_meta:=jsonb_build_object('operation_id',c->>'operation_id','contract',c-ARRAY['ready','gates','rollback'],
 'original_event',c->'original_event','original_event_md5',c->>'original_event_md5',
 'before_decision',NULL,'before_link',NULL,'after_event',v_event,'after_link',v_link,'after_decision',v_decision,
 'event_after_md5',md5(v_event::text),'link_after_md5',md5(v_link::text),'decision_after_md5',md5(v_decision::text),
 'source_row_md5_at_apply',c#>>'{source_lease,row_md5}','learning',c->'learning',
 'applied_at',to_jsonb(v_stamp),'epoch_before',v_receipt#>'{meta,epoch_before}',
 'epoch_after',(v_receipt#>>'{meta,epoch_before}')::bigint+(c->>'expected_epoch_delta')::bigint);
IF v_receipt->'meta' IS DISTINCT FROM v_meta
 OR v_receipt->>'user_id' IS DISTINCT FROM c->>'owner_id'
 OR v_receipt->>'action' IS DISTINCT FROM c->>'audit_action'
 OR v_receipt->'email' IS DISTINCT FROM 'null'::jsonb
 OR v_receipt->'created_at' IS DISTINCT FROM to_jsonb(v_stamp)
 OR (v_receipt->>'id')::bigint<=0
 OR v_receipt#>'{meta,epoch_before}' IS NULL
THEN RAISE EXCEPTION 'durable receipt mismatch'; END IF;
