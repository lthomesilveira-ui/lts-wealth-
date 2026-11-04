CREATE OR REPLACE FUNCTION public.lts_open_finance_enqueue_bank_v1(p_code text, p_action text DEFAULT 'sync'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid; nonce text; jid uuid; req bigint;
begin
 if p_code not in ('341','237','336') or p_action not in ('sync','discover') then raise exception 'INVALID'; end if;
 uid:=public.lts_open_finance_pilot_owner_v1(); nonce:=encode(extensions.gen_random_bytes(32),'hex');
 insert into public.lts_open_finance_job(user_id,action,token_hash,expires_at) values(uid,p_action,encode(extensions.digest(nonce,'sha256'),'hex'),now()+interval '5 minutes') returning id into jid;
 select net.http_post(url:='https://tadhkamnwtsbdozwkyut.supabase.co/functions/v1/lts-open-finance-itau',body:=jsonb_build_object('action',p_action,'institution_code',p_code),headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer internal-job','x-lts-of-job',nonce),timeout_milliseconds:=180000) into req;
 update public.lts_open_finance_job set http_request_id=req where id=jid;
 return jsonb_build_object('job_id',jid,'http_request_id',req,'institution_code',p_code);
end $function$
