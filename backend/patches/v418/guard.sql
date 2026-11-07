DO $guard$
BEGIN
 IF md5(pg_get_functiondef(to_regprocedure('lts_projection_private_v412.build(uuid,date)'))) IS DISTINCT FROM '5c647f086535c1a4592498629cdf03ed' THEN
  RAISE EXCEPTION 'Unexpected predecessor for build; review before installation';
 END IF;
 IF md5(pg_get_functiondef(to_regprocedure('lts_projection_private_v412.read_policy()'))) IS DISTINCT FROM '97a244d57dad0c0a12364c56fc93e2df' THEN
  RAISE EXCEPTION 'Unexpected predecessor for read_policy; review before installation';
 END IF;
 IF md5(pg_get_functiondef(to_regprocedure('lts_product_refresh_private_v415.run_claimed()'))) IS DISTINCT FROM '5ff1e2d31abb88bbc4972e4ade795c95' THEN
  RAISE EXCEPTION 'Unexpected predecessor for run_claimed; review before installation';
 END IF;
END $guard$;
