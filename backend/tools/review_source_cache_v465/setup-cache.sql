CREATE TABLE lts_product_refresh_private_v415.review_input_epoch_v465(singleton boolean PRIMARY KEY DEFAULT true CHECK(singleton),revision bigint NOT NULL);
INSERT INTO lts_product_refresh_private_v415.review_input_epoch_v465 VALUES(true,0);
CREATE TABLE lts_product_refresh_private_v415.review_input_contract_v465(schema_name text,table_name text,relation_oid oid NOT NULL,shape_hash text NOT NULL,trigger_name text NOT NULL,trigger_hash text NOT NULL,PRIMARY KEY(schema_name,table_name));
CREATE TABLE lts_product_refresh_private_v415.review_input_hash_cache_v465(user_id uuid PRIMARY KEY,source_revision bigint NOT NULL,financial_epoch bigint NOT NULL,as_of date NOT NULL,profile_hash text NOT NULL,hashes jsonb NOT NULL,digest text NOT NULL);
REVOKE ALL ON lts_product_refresh_private_v415.review_input_epoch_v465,lts_product_refresh_private_v415.review_input_contract_v465,lts_product_refresh_private_v415.review_input_hash_cache_v465 FROM PUBLIC,anon,authenticated,service_role;
