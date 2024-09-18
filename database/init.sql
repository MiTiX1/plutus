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