-- ==========================================
-- DDL SCRIPT: Star Schema Physical Deployment
-- ==========================================

-- We start by dropping tables if they exist to ensure a clean slate if we ever need to rerun this script.
-- CASCADE ensures that if we drop a dimension, it also removes the connected fact table constraints.
DROP TABLE IF EXISTS fact_transactions CASCADE;
DROP TABLE IF EXISTS dim_accounts CASCADE;
DROP TABLE IF EXISTS dim_customers CASCADE;
DROP TABLE IF EXISTS dim_branches CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- ------------------------------------------
-- 1. DIMENSION TABLES 
-- ------------------------------------------

-- Create the Customers dimension to track the people making transactions
CREATE TABLE dim_customers (
    -- SERIAL creates an auto-incrementing integer to act as our Primary Key (surrogate key)
    customer_id SERIAL PRIMARY KEY,
    -- VARCHAR(100) stores the customer's full name, up to 100 characters
    full_name VARCHAR(100) NOT NULL,
    -- UNIQUE constraint ensures no two customers share the same email address
    email VARCHAR(150) UNIQUE NOT NULL,
    -- Categorizes the customer's risk profile (e.g., 'Low', 'Medium', 'High')
    risk_tier VARCHAR(20) DEFAULT 'Low',
    -- Records the exact timestamp when this customer record was inserted into our vault
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create the Branches dimension to track where transactions physically or digitally originate
CREATE TABLE dim_branches (
    -- Auto-incrementing primary key for the branch
    branch_id SERIAL PRIMARY KEY,
    -- A unique identifier assigned by the business to this specific branch
    branch_code VARCHAR(20) UNIQUE NOT NULL,
    -- The geographic region (e.g., 'North America', 'Southeast Asia')
    region VARCHAR(50) NOT NULL,
    -- The specific city where the branch is located
    city VARCHAR(50) NOT NULL
);

-- Create the Accounts dimension to track the specific financial vehicles being used
CREATE TABLE dim_accounts (
    -- Auto-incrementing primary key for the account
    account_id SERIAL PRIMARY KEY,
    -- Creates a relationship linking this account back to a specific customer in dim_customers
    customer_id INT REFERENCES dim_customers(customer_id),
    -- The type of account (e.g., 'Checking', 'Savings', 'Credit')
    account_type VARCHAR(30) NOT NULL,
    -- A boolean flag (True/False) to quickly filter out closed accounts in our BI tool
    is_active BOOLEAN DEFAULT TRUE,
    -- The exact timestamp the account was opened
    opened_date DATE NOT NULL
);

-- Create a robust Date dimension for advanced time-intelligence BI reporting
CREATE TABLE dim_date (
    -- An integer representation of the date (e.g., 20260508) used as a highly efficient primary key
    date_id INT PRIMARY KEY,
    -- The actual standard date format
    full_date DATE NOT NULL,
    -- Extracts just the year (e.g., 2026) for quick year-over-year grouping
    year INT NOT NULL,
    -- Extracts the quarter (1 through 4)
    quarter INT NOT NULL,
    -- Extracts the month number (1 through 12)
    month INT NOT NULL,
    -- Extracts the string name of the month (e.g., 'May')
    month_name VARCHAR(20) NOT NULL,
    -- Extracts the day of the week (e.g., 'Monday')
    day_of_week VARCHAR(20) NOT NULL,
    -- A boolean flag indicating if this date falls on a weekend, crucial for financial volume analysis
    is_weekend BOOLEAN NOT NULL
);

-- ------------------------------------------
-- 2. FACT TABLE (The "Action")
-- ------------------------------------------

-- Create the central Fact table to log every single financial movement
CREATE TABLE fact_transactions (
    -- A unique identifier for the specific transaction event (often called a degenerate dimension)
    transaction_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- Foreign key linking to the specific account involved
    account_id INT REFERENCES dim_accounts(account_id),
    -- Foreign key linking to the branch where it occurred
    branch_id INT REFERENCES dim_branches(branch_id),
    -- Foreign key linking to our time-intelligence calendar
    date_id INT REFERENCES dim_date(date_id),
    -- Categorizes the movement (e.g., 'Deposit', 'Withdrawal', 'Transfer')
    transaction_type VARCHAR(30) NOT NULL,
    -- DECIMAL(15,2) stores the monetary value precisely up to 15 digits, with 2 decimal places for cents
    amount DECIMAL(15, 2) NOT NULL,
    -- Tracks the account's total balance immediately following this transaction
    post_transaction_balance DECIMAL(15, 2) NOT NULL,
    -- The exact microsecond the transaction was executed
    execution_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------
-- 3. PERMISSIONS HANDSHAKE
-- ------------------------------------------

-- Explicitly grant the ETL account full permission to insert, update, and delete records in these new tables
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO etl_service_account;

-- Explicitly grant the BI account read-only access to these new tables for dashboarding
GRANT SELECT ON ALL TABLES IN SCHEMA public TO bi_readonly_account;

-- Grant usage on sequence generators so the ETL account can trigger the auto-incrementing SERIAL primary keys
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO etl_service_account;