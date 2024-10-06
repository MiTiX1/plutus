CREATE SCHEMA app;

CREATE TYPE app.account_type_enum AS ENUM ('savings', 'checking', 'credit');
CREATE TYPE app.account_status_enum AS ENUM ('active', 'closed', 'frozen');
CREATE TYPE app.transaction_type_enum AS ENUM ('transfer', 'deposit', 'withdrawal');
CREATE TYPE app.transaction_status_enum AS ENUM ('pending', 'completed', 'failed');

CREATE TABLE app.banks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    country CHAR(2) NOT NULL CHECK (country ~ '^[A-Z]{2}$'),
    currency CHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'), 
    bic_code VARCHAR(11) NOT NULL CHECK (CHAR_LENGTH(bic_code) = 8 OR CHAR_LENGTH(bic_code) = 11),
    established_date DATE NOT NULL,
    total_assets NUMERIC(18, 2) NOT NULL,
    total_liabilities NUMERIC(18, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE app.users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years'),
    country CHAR(2) NOT NULL CHECK (country ~ '^[A-Z]{2}$'),
    nationality CHAR(2) NOT NULL CHECK (country ~ '^[A-Z]{2}$'),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE app.accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES app.users(id) ON DELETE CASCADE,
    bank_id INTEGER NOT NULL REFERENCES app.banks(id) ON DELETE CASCADE,
    account_type app.account_type_enum NOT NULL,
    currency CHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'), 
    balance NUMERIC(18, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    status app.account_status_enum DEFAULT 'active' NOT NULL,
    deleted_at TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (user_id, bank_id, account_type)
);

CREATE TABLE app.transactions (
    id SERIAL PRIMARY KEY,
    from_account_id INTEGER NOT NULL REFERENCES app.accounts(id) ON DELETE RESTRICT,
    to_account_id INTEGER NOT NULL REFERENCES app.accounts(id) ON DELETE RESTRICT,
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    currency CHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'), 
    transaction_type app.transaction_type_enum NOT NULL,
    status app.transaction_status_enum DEFAULT 'pending' NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_account_id <> to_account_id)
);


CREATE OR REPLACE FUNCTION app.soft_delete_account() 
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE app.accounts
        SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP
        WHERE id = OLD.id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_soft_delete
BEFORE DELETE ON app.accounts
FOR EACH ROW EXECUTE FUNCTION app.soft_delete_account();


CREATE OR REPLACE FUNCTION app.check_account_currency() 
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT currency FROM app.banks WHERE id = NEW.bank_id) != NEW.currency THEN
        RAISE EXCEPTION 'Account currency % does not match bank currency', NEW.currency;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_currency
BEFORE INSERT OR UPDATE ON app.accounts
FOR EACH ROW
EXECUTE FUNCTION app.check_account_currency();


CREATE OR REPLACE FUNCTION app.update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON app.banks
FOR EACH ROW
EXECUTE FUNCTION app.update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON app.users
FOR EACH ROW
EXECUTE FUNCTION app.update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON app.accounts
FOR EACH ROW
EXECUTE FUNCTION app.update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON app.transactions
FOR EACH ROW
EXECUTE FUNCTION app.update_timestamp();


CREATE INDEX idx_accounts_user_id ON app.accounts(user_id);
CREATE INDEX idx_accounts_bank_id ON app.accounts(bank_id);
CREATE INDEX idx_transactions_from_account_id ON app.transactions(from_account_id);
CREATE INDEX idx_transactions_to_account_id ON app.transactions(to_account_id);
CREATE INDEX idx_transactions_from_to_account ON app.transactions(from_account_id, to_account_id);

CREATE FUNCTION app.get_random_user() 
RETURNS INTEGER AS $$
DECLARE
	v_user_id INTEGER;
BEGIN
	SELECT
		id INTO v_user_id
	FROM
		app.users
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION app.get_random_bank() 
RETURNS INTEGER AS $$
DECLARE
	v_bank_id INTEGER;
BEGIN
	SELECT
		id INTO v_bank_id
	FROM
		app.banks
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_bank_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION app.get_random_account() 
RETURNS INTEGER AS $$
DECLARE
	v_account_id INTEGER;
BEGIN
	SELECT
		id INTO v_account_id
	FROM
		app.accounts
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_account_id;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION app.generate_random_bic_code(country VARCHAR(2))
RETURNS VARCHAR(11) AS $$
DECLARE
	v_bic_code VARCHAR(11);
	v_bank VARCHAR(4);
	v_location VARCHAR(2);
	v_branch VARCHAR(3);
BEGIN
	v_bank := chr((65 + floor(random() * 26))::INT) || chr((65 + floor(random() * 26))::INT) || chr((65 + floor(random() * 26))::INT) || chr((65 + floor(random() * 26))::INT);
	v_location := SUBSTRING(MD5(RANDOM()::TEXT), 1, 2);
	v_branch := chr((65 + floor(random() * 26))::INT) || chr((65 + floor(random() * 26))::INT) || chr((65 + floor(random() * 26))::INT);

	v_bic_code := v_bank || v_location || country;

	IF RANDOM() > 0.5 THEN
		v_bic_code := v_bic_code || v_branch;
	END IF;

	RETURN v_bic_code;
END;
$$ LANGUAGE plpgsql;
	

CREATE OR REPLACE PROCEDURE app.generate_random_banks(nb_banks INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_bic_code VARCHAR(11);
    v_name VARCHAR(255);
    v_country CHAR(2);
    v_now TIMESTAMP;
BEGIN
    FOR i IN 1..nb_banks LOOP
        v_now := CURRENT_TIMESTAMP;
        v_name := SUBSTRING(MD5(RANDOM()::TEXT), 1, 15);
        
        SELECT country INTO v_country
        FROM (VALUES 
                ('AT'), ('BE'), ('HR'), ('CY'), ('EE'), ('FI'), 
                ('FR'), ('DE'), ('GR'), ('IE'), ('IT'), ('LV'), 
                ('LT'), ('LU'), ('MT'), ('NL'), ('PT'), ('SK'), 
                ('SI'), ('ES')) AS eurozone_countries(country)
        ORDER BY RANDOM()
        LIMIT 1;
        
        v_bic_code := app.generate_random_bic_code(v_country);

        INSERT INTO app.banks (
            name, 
            country, 
            currency, 
            bic_code, 
            established_date,
            total_assets, 
            total_liabilities, 
            created_at, 
            updated_at
        ) 
        VALUES (
            v_name,
            v_country,
            'EUR',
            v_bic_code,
            CURRENT_DATE - (RANDOM() * INTERVAL '100 years'),
            ROUND(CAST((100000000 + RANDOM() * (1000000000 - 100000000)) AS NUMERIC), 2),
            ROUND(CAST((10000000 + RANDOM() * (1000000000 - 10000000)) AS NUMERIC), 2),
            v_now,
            v_now
        );
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE app.generate_random_users(nb_users INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_first_name VARCHAR(100);
    v_last_name VARCHAR(100);
    v_date_of_birth DATE;
    v_country CHAR(2);
    v_now TIMESTAMP;
BEGIN
    FOR i IN 1..nb_users LOOP
        v_now := CURRENT_TIMESTAMP;
        v_first_name := SUBSTRING(MD5(RANDOM()::TEXT), 1, 15);
        v_last_name := SUBSTRING(MD5(RANDOM()::TEXT), 1, 15);
        v_date_of_birth := CURRENT_DATE - INTERVAL '18 years' 
                           - (FLOOR(RANDOM() * (100 - 18 + 1) * 365))::INT * INTERVAL '1 day';

        SELECT country 
        INTO v_country
        FROM (VALUES 
                ('AT'), ('BE'), ('HR'), ('CY'), ('EE'), ('FI'), 
                ('FR'), ('DE'), ('GR'), ('IE'), ('IT'), ('LV'), 
                ('LT'), ('LU'), ('MT'), ('NL'), ('PT'), ('SK'), 
                ('SI'), ('ES')) AS eurozone_countries(country)
        ORDER BY RANDOM()
        LIMIT 1;

        INSERT INTO app.users (
            first_name, 
            last_name, 
            date_of_birth, 
            country, 
            nationality, 
            created_at, 
            updated_at
        ) VALUES (
            v_first_name, 
            v_last_name, 
            v_date_of_birth, 
            v_country, 
            v_country, 
            v_now, 
            v_now
        );
    END LOOP;
END;
$$;


CREATE OR REPLACE PROCEDURE app.generate_random_accounts(nb_accounts INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_user_id INTEGER;
    v_bank_id INTEGER;
    v_balance NUMERIC(18, 2);
    v_time TIMESTAMP;
BEGIN
    FOR i IN 1..nb_accounts LOOP
        v_balance := ROUND(CAST((100 + (RANDOM() * (1000000 - 100))) AS NUMERIC), 2);
        v_user_id := app.get_random_user();
        v_bank_id := app.get_random_bank();

        SELECT 
        (established_date + (RANDOM() * (EXTRACT(EPOCH FROM NOW() - established_date)) * INTERVAL '1 second')) INTO v_time
        FROM 
            app.banks 
        WHERE 
            id = v_bank_id;

        BEGIN
            INSERT INTO app.accounts (
                user_id, 
                bank_id, 
                account_type, 
                status, 
                currency, 
                balance, 
                created_at, 
                updated_at, 
                deleted_at, 
                is_deleted
            ) VALUES (
                v_user_id, 
                v_bank_id, 
                'checking', 
                'active', 
                'EUR', 
                v_balance, 
                v_time, 
                v_time, 
                NULL, 
                FALSE
            );
        EXCEPTION
            WHEN unique_violation THEN
                RAISE NOTICE 'Duplicate entry found for user_id %, bank_id %;', v_user_id, v_bank_id;
        END;
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE app.update_account_amount(account_id INTEGER, amount NUMERIC(18, 2))
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE 
        app.accounts
    SET 
        balance = balance + amount
    WHERE
        id = account_id;
END;
$$;

CREATE OR REPLACE PROCEDURE app.generate_random_transactions(nb_transactions INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_from_account_id INTEGER;
    v_to_account_id INTEGER;
    v_amount NUMERIC(18, 2);
    v_status app.transaction_status_enum;
    v_timestamp TIMESTAMP;
BEGIN
    FOR i IN 1..nb_transactions LOOP
        v_from_account_id := app.get_random_account();

        SELECT id INTO v_to_account_id 
        FROM app.accounts 
        WHERE id <> v_from_account_id 
        ORDER BY RANDOM() 
        LIMIT 1;

        SELECT ROUND(CAST((1 + (RANDOM() * (balance / 10 - 1))) AS NUMERIC), 2) AS amount INTO v_amount
        FROM app.accounts
        WHERE id = v_from_account_id;

        SELECT created_at + (RANDOM() * (EXTRACT(EPOCH FROM NOW() - created_at)) * INTERVAL '1 second') INTO v_timestamp
        FROM app.accounts 
        WHERE id = v_from_account_id;

        SELECT  status INTO v_status
        FROM ( SELECT unnest(enum_range(NULL::app.transaction_status_enum)) as status ) sub 
        ORDER BY random() 
        LIMIT 1;

        IF v_status = 'completed' THEN
            CALL app.update_account_amount(v_from_account_id, -v_amount);
            CALL app.update_account_amount(v_to_account_id, v_amount);
        ELSIF v_status = 'pending' THEN
            CALL app.update_account_amount(v_from_account_id, -v_amount);
     	END IF;

        INSERT INTO app.transactions (
            from_account_id, 
            to_account_id, 
            amount, 
            currency, 
            transaction_type, 
            status, 
            timestamp, 
            created_at, 
            updated_at
        ) VALUES (
            v_from_account_id, 
            v_to_account_id, 
            v_amount, 
            'EUR', 
            'transfer', 
            v_status, 
            v_timestamp, 
            v_timestamp, 
            v_timestamp
        );
    END LOOP;
END;
$$;

CREATE PUBLICATION pg_bq_sync FOR TABLE app.banks, app.users, app.accounts, app.transactions;
ALTER USER postgres WITH replication;
SELECT PG_CREATE_LOGICAL_REPLICATION_SLOT ('pg_bq_sync', 'pgoutput');

CREATE USER datastream WITH REPLICATION IN ROLE
cloudsqlsuperuser LOGIN PASSWORD 'datastream';

GRANT SELECT ON ALL TABLES IN SCHEMA app TO datastream;
GRANT USAGE ON SCHEMA app TO datastream;
ALTER DEFAULT PRIVILEGES IN SCHEMA app
GRANT SELECT ON TABLES TO datastream;