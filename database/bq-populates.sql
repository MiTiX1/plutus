INSERT INTO datawarehouse.dim_time (id, date, year, quarter, month, week, day_of_month, day_of_year, day_name, is_weekend)
SELECT
    ROW_NUMBER() OVER () AS id,
    date,
    EXTRACT(YEAR FROM date) AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    EXTRACT(MONTH FROM date) AS month,
    EXTRACT(WEEK FROM date) AS week, 
    EXTRACT(DAY FROM date) AS day_of_month,
    EXTRACT(DAYOFYEAR FROM date) AS day_of_year, 
    FORMAT_DATE('%A', date) AS day_name, 
    CASE 
        WHEN FORMAT_DATE('%A', date) IN ('Saturday', 'Sunday') THEN TRUE
        ELSE FALSE
    END AS is_weekend
FROM UNNEST(GENERATE_DATE_ARRAY('1900-01-01', '2030-01-01', INTERVAL 1 DAY)) AS date;

INSERT INTO datawarehouse.dim_banks (id, name, country, currency, bic_code, established_date, total_assets, total_liabilities)
SELECT
    id,
    name,
    country,
    currency,
    bic_code,
    established_date,
    total_assets,
    total_liabilities
FROM staging.banks
WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);

INSERT INTO datawarehouse.dim_users (id, date_of_birth, age, age_group, country, nationality, created_at)
SELECT
    id,
    date_of_birth,
    DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) AS age,
    CASE
        WHEN DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) BETWEEN 18 AND 25 THEN '18-25'
        WHEN DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) BETWEEN 26 AND 35 THEN '26-35'
        WHEN DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) BETWEEN 36 AND 45 THEN '36-45'
        WHEN DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) BETWEEN 46 AND 55 THEN '46-55'
        WHEN DATE_DIFF(CURRENT_DATE, date_of_birth, YEAR) BETWEEN 56 AND 65 THEN '56-65'
        ELSE '65+'
    END AS age_group,
    country, 
    nationality, 
    created_at
FROM staging.users
WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);

INSERT INTO datawarehouse.dim_accounts (id, bank_id, user_id, account_type, status, currency, balance, created_at)
SELECT
    id,
    bank_id,
    user_id,
    account_type,
    status,
    currency,
    balance,
    created_at
FROM staging.accounts
WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);

INSERT INTO datawarehouse.fact_transactions (id, from_account_id, to_account_id, from_user_id, to_user_id, from_bank_id, to_bank_id, time_id, amount, currency, transaction_type, status, timestamp)
SELECT
    t.id as id,
    from_account_id,
    to_account_id,
    a1.user_id AS from_user_id,
    a2.user_id AS to_user_id,
    a1.bank_id AS from_bank_id,
    a2.bank_id AS to_bank_id,
    (
        SELECT
            id
        FROM 
            datawarehouse.dim_time
        WHERE 
            EXTRACT(DATE FROM t.timestamp) = date
    ) AS time_id,
    amount,
    t.currency,
    transaction_type,
    t.status,
    timestamp
FROM staging.transactions t
JOIN staging.accounts a1 ON t.from_account_id = a1.id
JOIN staging.accounts a2 ON t.to_account_id = a2.id
WHERE created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY);