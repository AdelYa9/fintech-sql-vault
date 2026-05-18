-- Create a permanent view to act as an automated threat detection trap
CREATE OR REPLACE VIEW vw_salami_slicing_alerts AS
-- Initialize a Common Table Expression (CTE) to calculate behavioral metrics per account
WITH AccountVelocity AS (
    -- Select the account ID to group our metrics by
    SELECT 
        account_id,
        -- Count the total number of transactions per account to establish transaction volume
        COUNT(account_id) AS total_transactions,
        -- Calculate the standard deviation of transaction amounts to measure fluctuation
        STDDEV(amount) AS amount_variance
    -- Specify the fact table containing the seeded financial data
    FROM fact_transactions
    -- Aggregate the count and standard deviation calculations for each unique account
    GROUP BY account_id
)
-- Select all columns from our newly created CTE
SELECT * -- Specify the CTE as the data source for the main query
FROM AccountVelocity
-- Filter for accounts where the transaction amount never changes AND has occurred multiple times
WHERE amount_variance = 0 AND total_transactions > 3
-- Sort the final output so the most active robotic accounts appear at the top
ORDER BY total_transactions DESC;