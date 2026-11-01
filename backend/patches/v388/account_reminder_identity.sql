-- V388: retain the first real delivery and compare actions by route AND deadline.
-- No forecast, amount, financial source, email template, journal or schedule changes.
DO $patch$
DECLARE definition text:=pg_get_functiondef('lts_account_reminder_private_v387.decision(jsonb,jsonb,timestamptz,timestamptz)'::regprocedure);
 marker text:='V388 distinct deadlines and same-day fingerprint';
 anchor text:=$old$ IF p_previous IS NULL OR p_previous->>'status'='clear' THEN reason:='new_account_plan';$old$;
 pair text:=$old$WHERE x->>'kind'=c->>'kind'AND x->>'from_bank'=c->>'from_bank'AND x->>'to_bank'=c->>'to_bank'LIMIT 1;$old$;
BEGIN
 IF position(marker IN definition)>0 THEN RETURN;END IF;
 IF md5(definition)<>'c7d3bff3a26f59f1d85fbc218792752b'
 OR position(anchor IN definition)=0 OR position(pair IN definition)=0
 THEN RAISE EXCEPTION 'Reminder decision changed; review before applying action identity fix';END IF;
 definition:=replace(definition,anchor,$new$ -- V388 distinct deadlines and same-day fingerprint
 IF p_previous IS NOT NULL AND p_last_sent IS NOT NULL
 AND(p_last_sent AT TIME ZONE'America/Sao_Paulo')::date=(p_current->>'as_of')::date
 AND lts_account_reminder_private_v387.fingerprint(p_current)=lts_account_reminder_private_v387.fingerprint(p_previous)
 THEN RETURN jsonb_build_object('send',false,'reason','no_material_change');END IF;
$new$||anchor);
 definition:=replace(definition,pair,$new$WHERE x->>'kind'=c->>'kind'AND x->>'from_bank'=c->>'from_bank'AND x->>'to_bank'=c->>'to_bank'
    AND x->>'execute_by'=c->>'execute_by'LIMIT 1;$new$);
 EXECUTE definition;
END $patch$;
