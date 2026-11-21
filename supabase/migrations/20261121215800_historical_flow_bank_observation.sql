-- Read the dated bank observation only when an owner opens the historical balance detail.
CREATE FUNCTION public.lts_browser_flow_bank_observation_v495(p_date date,p_bank text)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO '' SET timezone TO 'America/Sao_Paulo' SET statement_timeout TO '4s'
AS $body$
DECLARE
  owner_id uuid := public.lts_browser_assert_user_v1();
  bank_code text := CASE p_bank WHEN 'Itaú' THEN '341' WHEN 'Bradesco' THEN '237' WHEN 'C6' THEN '336' END;
  result jsonb;
BEGIN
  IF bank_code IS NULL OR p_date IS NULL OR p_date >= current_date THEN
    RAISE EXCEPTION 'Invalid historical bank or date' USING ERRCODE='22023';
  END IF;
  WITH observations AS (
    SELECT o.provider_record_id AS account_ref, (o.normalized_payload->>'as_of')::timestamptz AS stamp,
           (o.normalized_payload->>'amount')::numeric AS amount,
           CASE WHEN jsonb_typeof(o.raw_payload#>'{bankData,automaticallyInvestedBalance}')='number'
             THEN (o.raw_payload#>>'{bankData,automaticallyInvestedBalance}')::numeric END AS automatic_balance
    FROM public.lts_open_finance_observation o
    JOIN public.lts_open_finance_connection cn ON cn.id=o.connection_id AND cn.user_id=o.user_id
    WHERE o.user_id=owner_id AND cn.institution_code=bank_code AND o.resource_type='balance'
      AND o.normalized_payload->>'account_type'='CHECKING_ACCOUNT'
      AND o.raw_payload->>'currencyCode'='BRL' AND o.normalized_payload->>'amount' IS NOT NULL
      AND o.observed_at >= p_date::timestamptz
      AND (o.normalized_payload->>'as_of')::timestamptz >= p_date::timestamptz
      AND (o.normalized_payload->>'as_of')::timestamptz < (p_date+1)::timestamptz
  ), dated AS (
    SELECT *,max(stamp) OVER () AS latest FROM observations
  )
  SELECT jsonb_build_object('date',p_date,'bank',p_bank,'source_at',max(stamp),'balance',min(amount),
         'automatically_invested',CASE WHEN count(automatic_balance)=count(*) AND min(automatic_balance)=max(automatic_balance)
           THEN min(automatic_balance) END)
  INTO result FROM dated
  WHERE stamp=latest
  HAVING (SELECT count(DISTINCT account_ref) FROM observations)=1 AND min(amount)=max(amount);
  RETURN result;
END
$body$;
REVOKE ALL ON FUNCTION public.lts_browser_flow_bank_observation_v495(date,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.lts_browser_flow_bank_observation_v495(date,text) TO authenticated;
