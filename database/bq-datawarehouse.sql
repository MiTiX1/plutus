CREATE TABLE datawarehouse.dim_banks (
    id INT64 PRIMARY KEY NOT ENFORCED,
    name STRING,
    country STRING,
    currency STRING,
    bic_code STRING,
    established_date DATE,
    total_assets NUMERIC(18, 2),
    total_liabilities NUMERIC(18, 2),
    created_at TIMESTAMP
);

CREATE TABLE datawarehouse.dim_users (
    id INT64 PRIMARY KEY NOT ENFORCED,
    date_of_birth DATE,
    age INT64,
    age_group STRING,
    country STRING,
    nationality STRING,
    created_at TIMESTAMP
);

CREATE TABLE datawarehouse.dim_accounts (
    id INT64 PRIMARY KEY NOT ENFORCED,
    bank_id INT64 REFERENCES datawarehouse.dim_banks(id) NOT ENFORCED,
    user_id INT64 REFERENCES datawarehouse.dim_users(id) NOT ENFORCED,
    account_type STRING,
    status STRING,
    currency STRING,
    balance NUMERIC(18, 2),
    created_at TIMESTAMP
);

CREATE TABLE datawarehouse.dim_time (
    id INT64 PRIMARY KEY NOT ENFORCED,
    date DATE,
    year INT64,
    quarter INT64,
    month INT64,
    week INT64,
    day_of_month INT64,    
    day_of_year INT64,
    day_name STRING,
    is_weekend BOOLEAN
);

CREATE TABLE datawarehouse.fact_transactions (
    id INT64 PRIMARY KEY NOT ENFORCED,
    from_account_id INT64 REFERENCES datawarehouse.dim_accounts(id) NOT ENFORCED,
    to_account_id INT64 REFERENCES datawarehouse.dim_accounts(id) NOT ENFORCED,
    from_user_id INT64 REFERENCES datawarehouse.dim_users(id) NOT ENFORCED,
    to_user_id INT64 REFERENCES datawarehouse.dim_users(id) NOT ENFORCED,
    from_bank_id INT64 REFERENCES datawarehouse.dim_banks(id) NOT ENFORCED,
    to_bank_id INT64 REFERENCES datawarehouse.dim_banks(id) NOT ENFORCED,
    time_id INT64 REFERENCES datawarehouse.dim_time(id) NOT ENFORCED,
    amount NUMERIC(18, 2),
    currency STRING,
    transaction_type STRING,
    status STRING,
    timestamp TIMESTAMP
);

