-- ==========================================
-- ANALYTICS SCRIPT: Materialized Views & Window Functions
-- ==========================================

-- ------------------------------------------
-- VIEW 1: Daily Branch Performance Matrix
-- ------------------------------------------
-- Materialized views store the result of the query physically on disk, 
-- making BI dashboard load times lightning fast.
CREATE MATERIALIZED VIEW mvw_daily_branch_activity AS
SELECT 
    d.full_date,
    b.branch_code,
    b.region,
    COUNT(f.transaction_id) AS total_transactions,
    SUM(CASE WHEN f.transaction_type = 'Deposit' THEN f.amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN f.transaction_type IN ('Withdrawal', 'Transfer') THEN f.amount ELSE 0 END) AS total_outflows,
    -- Calculates net daily movement for the branch
    SUM(CASE WHEN f.transaction_type = 'Deposit' THEN f.amount ELSE -f.amount END) AS net_daily_flow
FROM 
    fact_transactions f
JOIN 
    dim_branches b ON f.branch_id = b.branch_id
JOIN 
    dim_date d ON f.date_id = d.date_id
GROUP BY 
    d.full_date, b.branch_code, b.region
WITH DATA;

-- ------------------------------------------
-- VIEW 2: High-Value Anomaly Detection
-- ------------------------------------------
-- Identifies transactions that are more than 3x higher than the account's average transaction size.
CREATE MATERIALIZED VIEW mvw_transaction_anomalies AS
WITH AccountAverages AS (
    -- Common Table Expression (CTE) to calculate the historical average per account
    SELECT 
        account_id,
        AVG(amount) as avg_transaction_size
    FROM 
        fact_transactions
    GROUP BY 
        account_id
)
SELECT 
    f.transaction_id,
    c.full_name,
    a.account_type,
    f.transaction_type,
    f.amount,
    avg.avg_transaction_size,
    f.execution_timestamp
FROM 
    fact_transactions f
JOIN 
    dim_accounts a ON f.account_id = a.account_id
JOIN 
    dim_customers c ON a.customer_id = c.customer_id
JOIN 
    AccountAverages avg ON f.account_id = avg.account_id
WHERE 
    -- The anomaly trigger logic: Flag if the amount is 300% greater than their normal activity
    f.amount > (avg.avg_transaction_size * 3)
WITH DATA;

-- ------------------------------------------
-- VIEW 3: Account Rolling Balances (Window Function)
-- ------------------------------------------
CREATE MATERIALIZED VIEW mvw_rolling_balances AS
SELECT 
    f.account_id,
    c.full_name,
    f.execution_timestamp,
    f.transaction_type,
    f.amount,
    -- The Window Function: 
    -- PARTITION BY isolates the math to each specific account
    -- ORDER BY ensures the chronological flow of transactions
    -- This calculates the running total step-by-step
    SUM(CASE WHEN f.transaction_type = 'Deposit' THEN f.amount ELSE -f.amount END) 
        OVER (PARTITION BY f.account_id ORDER BY f.execution_timestamp) AS calculated_rolling_balance
FROM 
    fact_transactions f
JOIN 
    dim_accounts a ON f.account_id = a.account_id
JOIN 
    dim_customers c ON a.customer_id = c.customer_id
WITH DATA;


-- ------------------------------------------
-- PERMISSIONS HANDSHAKE
-- ------------------------------------------
-- Our BI Tool needs permission to read these new Materialized Views
GRANT SELECT ON mvw_daily_branch_activity TO bi_readonly_account;
GRANT SELECT ON mvw_transaction_anomalies TO bi_readonly_account;
GRANT SELECT ON mvw_rolling_balances TO bi_readonly_account;