CREATE TABLE staging.banks AS
SELECT id, name, country, currency, bic_code, established_date, total_assets, total_liabilities, created_at, updated_at FROM app.banks; 

CREATE TABLE staging.users AS
SELECT id, first_name, last_name, date_of_birth, country, nationality, created_at, updated_at FROM app.users;

CREATE TABLE staging.accounts AS
SELECT id, user_id, bank_id, account_type, currency, balance, created_at, updated_at, status, deleted_at, is_deleted FROM app.accounts;

CREATE TABLE staging.transactions AS
SELECT id, from_account_id, to_account_id, amount, currency, transaction_type, status, timestamp, created_at, updated_at FROM app.transactions;
