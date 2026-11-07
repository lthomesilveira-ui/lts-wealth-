CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE OR REPLACE FUNCTION public.lts_v178_norm(v text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$ select pg_catalog.regexp_replace(pg_catalog.lower(pg_catalog.translate(coalesce(v,''),'áàâãäéèêëíìîïóòôõöúùûüçÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ','aaaaaeeeeiiiiooooouuuucAAAAAEEEEIIIIOOOOOUUUUC')),'\\s+',' ','g') $function$;
CREATE OR REPLACE FUNCTION public.lts_bank_merchant_key_v231(p_text text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
 SELECT pg_catalog.regexp_replace(pg_catalog.regexp_replace(pg_catalog.regexp_replace(pg_catalog.regexp_replace(public.lts_v178_norm(p_text),
 '^(pagamento de pix qr code|pix qrs|pix recebido|pix enviado|pagamento de seguro)[[:space:]]+','','i'),
 '[[:space:]]+[0-9]{2}/[0-9]{2}$','','g'),'[[:space:]]+(s[.]?[[:space:]]*a[.]?|ltda[.]?)$','','i'),'[^a-z0-9]','','g')
$function$;
REVOKE ALL ON FUNCTION public.lts_v178_norm(text),public.lts_bank_merchant_key_v231(text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.lts_v178_norm(text),public.lts_bank_merchant_key_v231(text) TO service_role;
CREATE SCHEMA qa;
CREATE TABLE qa.inputs(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,input text);
INSERT INTO qa.inputs(input) SELECT * FROM unnest(ARRAY[
 NULL,'',' ','áàâãäéèêëíìîïóòôõöúùûüç','ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇ',
 E'Uma\tLoja\nFictícia','Loja  Fictícia',E'loja\\s+',
 'PIX ENVIADO COMÉRCIO EXEMPLO LTDA','Pagamento de Pix QR Code Loja Exemplo 01/02',
 'Não é uma identidade financeira real','1234','日本語','🙂',repeat('x',2048)
 ]::text[]);
INSERT INTO qa.inputs(input)
SELECT prefix||'Loja Fictícia '||n::text||suffix
FROM generate_series(1,20)n,
 unnest(ARRAY['','Pix enviado ','PIX RECEBIDO ','Pagamento de Seguro ','PIX QRS '])prefix,
 unnest(ARRAY['',' LTDA',' S.A.',' 12/10'])suffix;
CREATE TABLE qa.before_results AS SELECT id,input,public.lts_v178_norm(input) AS norm,
 public.lts_bank_merchant_key_v231(input) AS merchant FROM qa.inputs;
CREATE TABLE qa.before_attributes AS SELECT oid,to_jsonb(p)-'proconfig' AS attrs
FROM pg_proc p WHERE oid IN('public.lts_v178_norm(text)'::regprocedure,'public.lts_bank_merchant_key_v231(text)'::regprocedure);
