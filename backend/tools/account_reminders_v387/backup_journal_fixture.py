"""Build isolated notification fixtures from the actual migrations, never private records."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
print("SET TIME ZONE 'America/Sao_Paulo';\nCREATE TABLE public.fixture_archived_backup_hash AS SELECT user_id,snapshot_date,payload_sha256 FROM public.lts_backup_supplement_v380;\nCREATE SCHEMA auth;CREATE TABLE auth.users(id uuid PRIMARY KEY,email text);\nINSERT INTO auth.users SELECT id,email FROM public.usuario;\nINSERT INTO public.usuario(id,email)VALUES('00000000-0000-4000-8000-000000000003','owner-three@example.invalid');\nINSERT INTO auth.users SELECT id,email FROM public.usuario WHERE id='00000000-0000-4000-8000-000000000003';\n")
print((ROOT/'backend/patches/v377/cash_alerts.sql').read_text().split('-- The service role')[0])
print((ROOT/'backend/patches/v387/account_reminder_plan.sql').read_text())
print((ROOT/'backend/patches/v387/account_reminder_delivery.sql').read_text())
print("\nINSERT INTO lts_cash_alert_private_v377.delivery(token,user_id,message_id,report)VALUES(md5('cash-three'),'00000000-0000-4000-8000-000000000003','cash-three','{}'),(md5('cash-two'),'00000000-0000-4000-8000-000000000002','cash-two','{}');\nINSERT INTO lts_account_reminder_private_v387.delivery(token,user_id,message_id,report)VALUES(md5('accounts-three'),'00000000-0000-4000-8000-000000000003','accounts-three','{}'),(md5('accounts-two'),'00000000-0000-4000-8000-000000000002','accounts-two','{}');\n")
