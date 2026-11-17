TRUNCATE fixture_expenses,lts_v229_read_cache;
INSERT INTO fixture_expenses(user_id,row_key,event_date,competence_month,amount,category,description,account_source,source_table,source_ref,coverage_mode,identity_status,management_group) VALUES
('00000000-0000-4000-8000-000000000001','card-health','2020-01-10','2020-01-01',100,'Saúde','Clínica A','Cartão A','lts_open_finance_staging','card-health','card_posted','identified','Saúde'),
('00000000-0000-4000-8000-000000000001','bank-health','2020-01-11','2020-01-01',20,'Saúde','Clínica B','Conta A','financial_events','bank-health','direct_cash','identified','Saúde'),
('00000000-0000-4000-8000-000000000001','card-food','2020-01-12','2020-01-01',50,'Restaurantes','Restaurante A','Cartão B','card_purchases','card-food','card_posted','identified','Restaurantes'),
('00000000-0000-4000-8000-000000000001','bank-food','2020-01-13','2020-01-01',25,'iFood','Refeição A','Conta B','financial_events','bank-food','direct_cash','identified','iFood'),
('00000000-0000-4000-8000-000000000001','card-refund','2020-01-14','2020-01-01',-10,'Saúde','Estorno','Cartão A','card_purchases','card-refund','card_posted','identified','Saúde'),
('00000000-0000-4000-8000-000000000001','gift','2020-01-15','2020-01-01',15,'Presentes','Presente A','Conta A','financial_events','gift','direct_cash','identified','Presentes'),
('00000000-0000-4000-8000-000000000001','original-person-category','2020-01-16','2020-01-01',20,'Benjamin','Categoria original sem finalidade inferida','Conta A','financial_events','original-person-category','direct_cash','identified','Benjamin'),
('00000000-0000-4000-8000-000000000001','historical-card','2020-01-17','2020-01-01',200,'Cartão — detalhe histórico não recuperado','Fatura histórica','Cartão C','card_history','historical-card','card_invoice_aggregate_fallback','identified','Cartões históricos'),
('00000000-0000-4000-8000-000000000099','other-owner','2020-01-10','2020-01-01',999,'Saúde','Outra pessoa','Outra conta','financial_events','other-owner','direct_cash','identified','Saúde');
