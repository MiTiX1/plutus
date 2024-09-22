\connect plutus;

CREATE DOMAIN bic_code_type AS VARCHAR(11)
    CHECK (CHAR_LENGTH(VALUE) = 8 OR CHAR_LENGTH(VALUE) = 11);

CREATE DOMAIN currency_type AS CHAR(3)
    CHECK (VALUE ~ '^[A-Z]{3}$');

CREATE DOMAIN country_type AS CHAR(2)
    CHECK (VALUE ~ '^[A-Z]{2}$');

CREATE TYPE account_type_enum AS ENUM ('savings', 'checking', 'credit');
CREATE TYPE account_status_enum AS ENUM ('active', 'closed', 'frozen');
CREATE TYPE transaction_type_enum AS ENUM ('transfer', 'deposit', 'withdrawal');
CREATE TYPE transaction_status_enum AS ENUM ('pending', 'completed', 'failed');
CREATE TYPE action_enum AS ENUM ('transfer', 'withdrawal', 'deposit');

CREATE TABLE banks (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    country country_type NOT NULL,
    currency currency_type NOT NULL, 
    bic_code bic_code_type NOT NULL,
    established_date DATE NOT NULL,
    total_assets NUMERIC(18, 2) NOT NULL,
    total_liabilities NUMERIC(18, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATE NOT NULL CHECK (date_of_birth <= CURRENT_DATE - INTERVAL '18 years'),
    country country_type NOT NULL,
    nationality country_type NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
);

CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    bank_id INTEGER NOT NULL REFERENCES banks(id) ON DELETE CASCADE,
    account_type account_type_enum NOT NULL,
    currency currency_type NOT NULL,
    balance NUMERIC(18, 2) DEFAULT 0.00 NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ,
    status account_status_enum DEFAULT 'active' NOT NULL,
    deleted_at TIMESTAMP,
    is_deleted BOOLEAN DEFAULT FALSE,
    UNIQUE (user_id, bank_id, account_type)
);

CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    from_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    to_account_id INTEGER NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    currency currency_type NOT NULL,
    transaction_type transaction_type_enum NOT NULL,
    status transaction_status_enum DEFAULT 'pending' NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (from_account_id <> to_account_id)
);

CREATE TABLE fees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    amount NUMERIC(18, 2) NOT NULL CHECK (amount > 0),
    currency currency_type NOT NULL,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    account_id INTEGER REFERENCES accounts(id),
    transaction_id INTEGER REFERENCES transactions(id),
    CHECK (account_id IS NOT NULL OR transaction_id IS NOT NULL)
);

CREATE TABLE audit_logs (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    action action_enum NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    details JSONB
);

CREATE TABLE account_history (
    id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(id),
    balance NUMERIC(18, 2),
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    change_reason VARCHAR(255)
);

CREATE OR REPLACE FUNCTION soft_delete_account() 
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        UPDATE accounts
        SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP
        WHERE id = OLD.id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_soft_delete
BEFORE DELETE ON accounts
FOR EACH ROW EXECUTE FUNCTION soft_delete_account();


CREATE OR REPLACE FUNCTION check_account_currency() 
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT currency FROM banks WHERE id = NEW.bank_id) != NEW.currency THEN
        RAISE EXCEPTION 'Account currency % does not match bank currency', NEW.currency;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_currency
BEFORE INSERT OR UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION check_account_currency();

CREATE OR REPLACE FUNCTION check_fee_currency()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.transaction_id IS NOT NULL THEN
        IF (SELECT currency FROM transactions WHERE id = NEW.transaction_id) != NEW.currency THEN
            RAISE EXCEPTION 'Fee currency % does not match transaction currency', NEW.currency;
        END IF;
    END IF;

    IF NEW.account_id IS NOT NULL THEN
        IF (SELECT currency FROM accounts WHERE id = NEW.account_id) != NEW.currency THEN
            RAISE EXCEPTION 'Fee currency % does not match account currency', NEW.currency;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_check_fee_currency
BEFORE INSERT OR UPDATE ON fees
FOR EACH ROW
EXECUTE FUNCTION check_fee_currency();


CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON banks
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON users
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON accounts
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER set_timestamp
BEFORE UPDATE ON transactions
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();


CREATE INDEX idx_accounts_user_id ON accounts (user_id);
CREATE INDEX idx_accounts_bank_id ON accounts (bank_id);
CREATE INDEX idx_transactions_from_account_id ON transactions (from_account_id);
CREATE INDEX idx_transactions_to_account_id ON transactions (to_account_id);
CREATE INDEX idx_transactions_from_to_account ON transactions (from_account_id, to_account_id);
CREATE INDEX idx_audit_logs_user_id ON audit_logs (user_id);

CREATE FUNCTION get_random_user() 
RETURNS INTEGER AS $$
DECLARE
	v_user_id INTEGER;
BEGIN
	SELECT
		id INTO v_user_id
	FROM
		users
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_user_id;
END;
$$ LANGUAGE plpgsql;


CREATE FUNCTION get_random_bank() 
RETURNS INTEGER AS $$
DECLARE
	v_bank_id INTEGER;
BEGIN
	SELECT
		id INTO v_bank_id
	FROM
		banks
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_bank_id;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_random_account() 
RETURNS INTEGER AS $$
DECLARE
	v_account_id INTEGER;
BEGIN
	SELECT
		id INTO v_account_id
	FROM
		accounts
	ORDER BY
		RANDOM()
	LIMIT 1;

	RETURN v_account_id;
END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION generate_random_bic_code(country VARCHAR(2))
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
	

CREATE OR REPLACE PROCEDURE generate_random_banks(nb_banks INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_bic_code VARCHAR(11);
    v_name VARCHAR(255);
    v_country country_type;
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
        
        v_bic_code := generate_random_bic_code(v_country);

        INSERT INTO banks (
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

CREATE OR REPLACE PROCEDURE generate_random_users(nb_users INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_first_name VARCHAR(100);
    v_last_name VARCHAR(100);
    v_date_of_birth DATE;
    v_country country_type;
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

        INSERT INTO users (
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


CREATE OR REPLACE PROCEDURE generate_random_accounts(nb_accounts INTEGER)
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
        v_user_id := get_random_user();
        v_bank_id := get_random_bank();

        SELECT 
        (established_date + (RANDOM() * (EXTRACT(EPOCH FROM NOW() - established_date)) * INTERVAL '1 second')) INTO v_time
        FROM 
            banks 
        WHERE 
            id = v_bank_id;

        BEGIN
            INSERT INTO accounts (
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

CREATE OR REPLACE PROCEDURE update_account_amount(account_id INTEGER, amount NUMERIC(18, 2))
LANGUAGE plpgsql
AS $$
BEGIN
    UPDATE 
        accounts
    SET 
        balance = balance + amount
    WHERE
        id = account_id;
END;
$$;

CREATE OR REPLACE PROCEDURE generate_random_transactions(nb_transactions INTEGER)
LANGUAGE plpgsql
AS $$
DECLARE 
    v_from_account_id INTEGER;
    v_to_account_id INTEGER;
    v_amount NUMERIC(18, 2);
    v_status transaction_status_enum;
    v_timestamp TIMESTAMP;
BEGIN
    FOR i IN 1..nb_transactions LOOP
        v_from_account_id := get_random_account();

        SELECT id INTO v_to_account_id 
        FROM accounts 
        WHERE id <> v_from_account_id 
        ORDER BY RANDOM() 
        LIMIT 1;

        SELECT ROUND(CAST((1 + (RANDOM() * (balance / 10 - 1))) AS NUMERIC), 2) AS amount INTO v_amount
        FROM accounts
        WHERE id = v_from_account_id;

        SELECT created_at + (RANDOM() * (EXTRACT(EPOCH FROM NOW() - created_at)) * INTERVAL '1 second') INTO v_timestamp
        FROM accounts 
        WHERE id = v_from_account_id;

        SELECT  status INTO v_status
        FROM ( SELECT unnest(enum_range(NULL::transaction_status_enum)) as status ) sub 
        ORDER BY random() 
        LIMIT 1;

        IF v_status = 'completed' THEN
            CALL update_account_amount(v_from_account_id, -v_amount);
            CALL update_account_amount(v_to_account_id, v_amount);
        ELSIF v_status = 'pending' THEN
            CALL update_account_amount(v_from_account_id, -v_amount);
     	END IF;

        INSERT INTO transactions (
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


CALL generate_random_banks(1000);
CALL generate_random_users(10000);
CALL generate_random_accounts(20000);
CALL generate_random_transactions(10000);