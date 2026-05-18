# Import the psycopg2 library to enable Python to communicate with PostgreSQL
import psycopg2
# Import the execute_values function to allow highly efficient bulk data insertion
from psycopg2.extras import execute_values
# Import the Faker library to generate realistic synthetic names, emails, and locations
from faker import Faker
# Import the random library to make mathematical selections and generate numerical amounts
import random
# Import date and timedelta to handle the calendar math for our time dimension
from datetime import date, timedelta

# Initialize the Faker object to start generating our synthetic data
fake = Faker()

# Reverting to our restricted ETL role and targeting the newly exposed port 5433
conn = psycopg2.connect(dbname="fintech_vault", user="etl_service_account", password="etl_pipeline_pass_456", host="127.0.0.1", port="5433")
# Create a cursor object which acts as our control mechanism to execute SQL commands over the connection
cur = conn.cursor()

# ---------------------------------------------------------
# 1. GENERATE DIMENSION DATA (Branches, Customers, Accounts)
# ---------------------------------------------------------

# Print a status message to the terminal so we know the script is running
print("Generating Branches...")
# Initialize an empty list to hold our branch tuples
branches = []
# Loop exactly 5 times to create 5 distinct branches
for _ in range(5):
    # Append a tuple containing a unique branch code, a random country, and a random city
    branches.append((fake.unique.bothify(text='BR-####'), fake.country(), fake.city()))
# Execute a bulk insert of the branch list into the dim_branches table
execute_values(cur, "INSERT INTO dim_branches (branch_code, region, city) VALUES %s", branches)

# Query the database to retrieve the auto-generated branch_ids so we can use them later for transactions
cur.execute("SELECT branch_id FROM dim_branches;")
# Extract the first item from every row returned and save it to a flat Python list
branch_ids = [row[0] for row in cur.fetchall()]

# Print a status message for the next dimension
print("Generating Customers & Accounts...")
# Initialize an empty list to hold our customer tuples
customers = []
# Loop exactly 50 times to create 50 distinct customers
for _ in range(50):
    # Append a tuple containing a fake name, a unique fake email, and a random risk tier
    customers.append((fake.name(), fake.unique.email(), random.choice(['Low', 'Medium', 'High'])))
# Execute a bulk insert of the customer list into the dim_customers table
execute_values(cur, "INSERT INTO dim_customers (full_name, email, risk_tier) VALUES %s", customers)

# Query the database to retrieve the auto-generated customer_ids
cur.execute("SELECT customer_id FROM dim_customers;")
# Extract the customer IDs into a flat list
customer_ids = [row[0] for row in cur.fetchall()]

# Initialize an empty list to hold our account tuples
accounts = []
# Loop through every single customer_id we just created
for c_id in customer_ids:
    # Assign a random account type to this specific customer
    acct_type = random.choice(['Checking', 'Savings', 'Credit'])
    # Generate a random past date for when the account was opened
    opened_date = fake.date_between(start_date='-3y', end_date='today')
    # Append a tuple mapping the customer ID to their new account details (setting active status to True)
    accounts.append((c_id, acct_type, True, opened_date))
# Execute a bulk insert of the account list into the dim_accounts table
execute_values(cur, "INSERT INTO dim_accounts (customer_id, account_type, is_active, opened_date) VALUES %s", accounts)

# Query the database to retrieve the auto-generated account_ids
cur.execute("SELECT account_id FROM dim_accounts;")
# Extract the account IDs into a flat list
account_ids = [row[0] for row in cur.fetchall()]

# ---> THREAT HUNT INJECTION: CREATE GHOST ACCOUNT <---
print("Injecting Ghost Account for Salami Attack...")
cur.execute("INSERT INTO dim_customers (full_name, email, risk_tier) VALUES ('System Daemon', 'daemon@internal.net', 'Low') RETURNING customer_id;")
ghost_customer_id = cur.fetchone()[0]
cur.execute("INSERT INTO dim_accounts (customer_id, account_type, is_active, opened_date) VALUES (%s, 'Checking', True, %s) RETURNING account_id;", (ghost_customer_id, date.today()))
ghost_account_id = cur.fetchone()[0]

# ---------------------------------------------------------
# 2. GENERATE DATE DIMENSION (Time Intelligence Calendar)
# ---------------------------------------------------------

# Print a status message for the calendar generation
print("Generating Time Dimension...")
# Define the absolute start date for our calendar (January 1st, 2024)
start_date = date(2024, 1, 1)
# Define the absolute end date for our calendar (December 31st, 2026)
end_date = date(2026, 12, 31)
# Calculate the total number of days between the start and end dates
delta = end_date - start_date
# Initialize an empty list to hold the daily calendar rows
date_rows = []

# Loop through every single day in the calculated range
for i in range(delta.days + 1):
    # Calculate the exact specific date for this current loop iteration
    current_date = start_date + timedelta(days=i)
    # Generate an integer ID format (YYYYMMDD) for highly efficient database indexing
    date_id = int(current_date.strftime('%Y%m%d'))
    # Extract the numerical year
    year = current_date.year
    # Calculate the financial quarter using integer division math
    quarter = (current_date.month - 1) // 3 + 1
    # Extract the numerical month
    month = current_date.month
    # Extract the full string name of the month
    month_name = current_date.strftime('%B')
    # Extract the full string name of the day of the week
    day_of_week = current_date.strftime('%A')
    # Determine if the day is a weekend by checking if the weekday index is 5 (Saturday) or 6 (Sunday)
    is_weekend = current_date.weekday() >= 5
    # Append the fully parsed date tuple to our list
    date_rows.append((date_id, current_date, year, quarter, month, month_name, day_of_week, is_weekend))

# Execute a bulk insert of the calendar list into the dim_date table
execute_values(cur, "INSERT INTO dim_date (date_id, full_date, year, quarter, month, month_name, day_of_week, is_weekend) VALUES %s", date_rows)

# Query the database to retrieve all the generated date_ids
cur.execute("SELECT date_id FROM dim_date;")
# Extract the date IDs into a flat list
date_ids = [row[0] for row in cur.fetchall()]

# ---------------------------------------------------------
# 3. GENERATE FACT DATA (Financial Transactions)
# ---------------------------------------------------------

# Print a status message for the final transaction generation
print("Generating 10,000 Financial Transactions with Hidden Anomaly...")
# Initialize an empty list to hold the massive transaction dataset
transactions = []
# Create an empty dictionary to keep a running track of the current balance for each account ID
running_balances = {}

# Loop 10,000 times, using 'i' to track the exact iteration number (starting at 1)
for i in range(1, 10001):
    
    # ---> THREAT HUNT INJECTION: SALAMI SLICING TRIGGER <---
    if i % 500 == 0:
        acct_id = ghost_account_id
        t_type = 'Withdrawal'
        amount = 0.02
    else:
        acct_id = random.choice(account_ids)
        t_type = random.choice(['Deposit', 'Withdrawal', 'Transfer'])
        amount = round(random.uniform(10.0, 5000.0), 2)
        
    # Randomly select one valid branch ID from our generated list
    b_id = random.choice(branch_ids)
    # Randomly select one valid date ID from our generated calendar list
    d_id = random.choice(date_ids)
    
    # Retrieve the current balance for this specific account, defaulting to 0.0 if it has no history yet
    current_balance = running_balances.get(acct_id, 0.0)
    
    # Check if the transaction type adds money to the account
    if t_type == 'Deposit':
        # Add the amount to the current balance
        new_balance = current_balance + amount
    # If it is not a deposit, it is a deduction
    else:
        # Subtract the amount from the current balance
        new_balance = current_balance - amount
        
    # Update the tracking dictionary with the newly calculated balance for this account
    running_balances[acct_id] = new_balance
    # Append the final transaction tuple, including the precise post-transaction balance
    transactions.append((acct_id, b_id, d_id, t_type, amount, new_balance))

# Execute a bulk insert of the 10,000 transactions into the fact_transactions table
execute_values(cur, "INSERT INTO fact_transactions (account_id, branch_id, date_id, transaction_type, amount, post_transaction_balance) VALUES %s", transactions)

# ---------------------------------------------------------
# 4. COMMIT & CLOSE
# ---------------------------------------------------------

# Hard commit all the inserted data to the PostgreSQL database, locking in the changes permanently
conn.commit()
# Close the cursor control object
cur.close()
# Close the active database connection
conn.close()

# Print a final success message indicating the ETL run is complete
print("Data Seeding Complete! The Vault is full, and the trap is set.")