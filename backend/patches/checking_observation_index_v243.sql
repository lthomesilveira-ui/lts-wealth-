-- Non-economic access-path repair: preserves all observation rows and permissions.
SET LOCAL lock_timeout='3s';
CREATE INDEX IF NOT EXISTS lts_of_checking_balance_owner_connection_v243
ON public.lts_open_finance_observation(user_id,connection_id)
WHERE resource_type='balance' AND normalized_payload->>'account_type'='CHECKING_ACCOUNT';
