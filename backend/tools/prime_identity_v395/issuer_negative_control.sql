DO $negative$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM public.lts_card_projection_rows_v290(qa.owner(1)) WHERE card_name ILIKE '%PRIME%');
 RAISE NOTICE 'Actual family helper reproduces missing institution in received identity fallback';
END $negative$;
