-- ==========================================
-- INIT SCRIPT: Role & Security Configuration
-- ==========================================

-- 1. Create a dedicated role for ETL ingestion
-- This role will be used later by your Python pipeline to write data into the vault.
-- It has permission to log in, but cannot create other databases or superusers.
CREATE ROLE etl_service_account WITH 
    LOGIN 
    PASSWORD 'etl_pipeline_pass_456'
    NOSUPERUSER 
    INHERIT 
    NOCREATEDB 
    NOCREATEROLE 
    NOREPLICATION;

-- 2. Create a dedicated role for BI and Reporting
-- This role will be used by BI tools (like Power BI) for read-only access.
-- We restrict this heavily to prevent accidental data deletion by analysts.
CREATE ROLE bi_readonly_account WITH 
    LOGIN 
    PASSWORD 'bi_dashboard_pass_789'
    NOSUPERUSER 
    INHERIT 
    NOCREATEDB 
    NOCREATEROLE 
    NOREPLICATION;

-- 3. Grant connection privileges
-- This explicitly allows both new accounts to connect to our specific database.
GRANT CONNECT ON DATABASE fintech_vault TO etl_service_account;
GRANT CONNECT ON DATABASE fintech_vault TO bi_readonly_account;

-- 4. Set default read privileges for the BI account
-- This is a critical automation step: it ensures that anytime the ETL account 
-- creates a new table in the future, the BI account automatically gets SELECT (read) access to it.
ALTER DEFAULT PRIVILEGES IN SCHEMA public 
    GRANT SELECT ON TABLES TO bi_readonly_account;