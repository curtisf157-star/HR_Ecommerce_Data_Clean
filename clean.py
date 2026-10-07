import duckdb

con = duckdb.connect("clean.duckdb")

# ---------- HR ----------
con.execute("""
CREATE OR REPLACE TABLE hr_raw AS
SELECT * FROM read_csv_auto('hr_attrition_messy.csv', header=True);
""")

con.execute("""
CREATE OR REPLACE TABLE hr_clean AS
SELECT
  Employee_ID,
  Full_Name,
  TRY_CAST(Age AS INTEGER) AS Age,
  CASE
    WHEN LOWER(TRIM(Gender)) IN ('m','male') THEN 'Male'
    WHEN LOWER(TRIM(Gender)) IN ('f','female','fm','fmale') THEN 'Female'
  END AS Gender,
  CASE
    WHEN UPPER(TRIM(Department)) IN ('MARKETING','MKTG')          THEN 'Marketing'
    WHEN UPPER(TRIM(Department)) IN ('IT','I.T')                  THEN 'IT'
    WHEN UPPER(TRIM(Department)) IN ('HR','H.R')                  THEN 'HR'
    WHEN UPPER(TRIM(Department)) IN ('OPERATIONS','OPS')          THEN 'Operations'
    WHEN UPPER(TRIM(Department)) IN ('ENGINEERING','ENGG')        THEN 'Engineering'
    WHEN UPPER(TRIM(Department)) IN ('SALES')                     THEN 'Sales'
    WHEN UPPER(TRIM(Department)) IN ('LEGAL')                     THEN 'Legal'
    WHEN UPPER(TRIM(Department)) IN ('FINANCE')                   THEN 'Finance'
    WHEN TRIM(Department) = '' OR Department IS NULL THEN 'Unknown'
ELSE TRIM(Department)
  END AS Department,
  Job_Title,
  Education,
  COALESCE(
    TRY_STRPTIME(Hire_Date, '%Y-%m-%d'),
    TRY_STRPTIME(Hire_Date, '%d/%m/%Y'),
    TRY_STRPTIME(Hire_Date, '%m/%d/%Y'),
    TRY_STRPTIME(Hire_Date, '%m-%d-%Y'),
    TRY_STRPTIME(Hire_Date, '%d-%m-%Y'),
    TRY_STRPTIME(Hire_Date, '%d %b %Y'),
    TRY_STRPTIME(Hire_Date, '%b %d, %Y')
  )::DATE AS Hire_Date,
  CASE
    WHEN Salary IS NULL OR TRIM(Salary) IN ('','N/A','TBD','Confidential','NULL','na') THEN NULL
    WHEN LOWER(Salary) LIKE '%k' THEN TRY_CAST(REPLACE(REPLACE(LOWER(Salary),'$',''),'k','') AS DOUBLE) * 1000
    ELSE TRY_CAST(REPLACE(REPLACE(Salary,'$',''),',','') AS DOUBLE)
  END AS Salary,
  TRY_CAST(Years_At_Company AS INTEGER) AS Years_At_Company,
  TRY_CAST(Job_Satisfaction AS INTEGER) AS Job_Satisfaction,
  TRY_CAST(Performance_Rating AS INTEGER) AS Performance_Rating,
  TRY_CAST(Monthly_Hours AS INTEGER) AS Monthly_Hours,
  CASE
    WHEN LOWER(TRIM(Attrition)) IN ('yes','y','left') THEN 'Yes'
    WHEN LOWER(TRIM(Attrition)) IN ('no','n','stayed') THEN 'No'
  END AS Attrition,
   CASE
    WHEN UPPER(TRIM(Region)) IN ('NA','N. AMERICA','NORTH AMERICA','N.A.') THEN 'North America'
    WHEN UPPER(TRIM(Region)) IN ('LATAM','LATIN AMERICA')                   THEN 'Latin America'
    WHEN UPPER(TRIM(Region)) IN ('APAC','ASIA PACIFIC')                     THEN 'Asia Pacific'
    WHEN UPPER(TRIM(Region)) IN ('ME','MID EAST','MIDDLE EAST')             THEN 'Middle East'
    WHEN UPPER(TRIM(Region)) IN ('EUR','EUROPE')                            THEN 'Europe'
    WHEN TRIM(Region) = '' OR Region IS NULL                                THEN NULL
    ELSE TRIM(Region)
  END AS Region,
  Payment_Method,
  Phone,
  Email
FROM hr_raw;
""")

# ---------- Ecommerce ----------
con.execute("""
CREATE OR REPLACE TABLE ecommerce_raw AS
SELECT * FROM read_csv_auto('ecommerce_retail_transactions_raw.csv', header=True);
""")

con.execute("""
CREATE OR REPLACE TABLE ecommerce_clean AS
WITH deduped AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date) AS rn
  FROM ecommerce_raw
)
SELECT
  Order_ID,
  Customer_ID,
  COALESCE(
    TRY_STRPTIME(Order_Date, '%Y-%m-%d'),
    TRY_STRPTIME(Order_Date, '%d/%m/%Y'),
    TRY_STRPTIME(Order_Date, '%m/%d/%Y'),
    TRY_STRPTIME(Order_Date, '%m-%d-%Y'),
    TRY_STRPTIME(Order_Date, '%d-%m-%Y'),
    TRY_STRPTIME(Order_Date, '%d %b %Y'),
    TRY_STRPTIME(Order_Date, '%b %d, %Y')
  )::DATE AS Order_Date,
  Product_Category,
  Product_Name,
  CASE WHEN TRY_CAST(Quantity AS INTEGER) > 0 THEN TRY_CAST(Quantity AS INTEGER) END AS Quantity,
  TRY_CAST(Unit_Price_USD AS DOUBLE) AS Unit_Price_USD,
  COALESCE(TRY_CAST(Discount_Percent AS DOUBLE), 0) AS Discount_Percent,
  CASE
    WHEN LOWER(TRIM(Payment_Method)) IN ('net banking','netbanking') THEN 'Net Banking'
    WHEN LOWER(TRIM(Payment_Method)) IN ('cash on delivery','cod') THEN 'Cash on Delivery'
    WHEN LOWER(TRIM(Payment_Method)) IN ('credit card','credit_card') THEN 'Credit Card'
    WHEN LOWER(TRIM(Payment_Method)) IN ('debit card','debit_card') THEN 'Debit Card'
    WHEN LOWER(TRIM(Payment_Method)) IN ('upi','u.p.i') THEN 'UPI'
    WHEN LOWER(TRIM(Payment_Method)) IN ('paypal','pay pal') THEN 'PayPal'
    ELSE TRIM(Payment_Method)
  END AS Payment_Method,
  Shipping_City,
  CASE
    WHEN UPPER(TRIM(Country)) IN ('USA','U.S.A','UNITED STATES','US') THEN 'USA'
    WHEN UPPER(TRIM(Country)) IN ('UK','U.K.','UNITED KINGDOM') THEN 'UK'
    WHEN UPPER(TRIM(Country)) IN ('CANADA','CA') THEN 'Canada'
    WHEN UPPER(TRIM(Country)) IN ('AUSTRALIA','AU') THEN 'Australia'
    WHEN UPPER(TRIM(Country)) IN ('GERMANY','DE') THEN 'Germany'
    WHEN UPPER(TRIM(Country)) IN ('UAE','U.A.E') THEN 'UAE'
    WHEN UPPER(TRIM(Country)) IN ('INDIA','IN') THEN 'India'
    ELSE TRIM(Country)
  END AS Country,
    CASE LOWER(TRIM(Order_Status))
    WHEN 'delivered' THEN 'Delivered'
    WHEN 'shipped'   THEN 'Shipped'
    WHEN 'pending'   THEN 'Pending'
    WHEN 'cancelled' THEN 'Cancelled'
    WHEN 'returned'  THEN 'Returned'
    ELSE TRIM(Order_Status)
  END AS Order_Status,
  TRY_CAST(Customer_Rating AS DOUBLE) AS Customer_Rating
FROM deduped
WHERE rn = 1;
""")

# ---------- Export ----------
con.sql("COPY hr_clean TO 'hr_clean.csv' (HEADER, DELIMITER ',')")
con.sql("COPY ecommerce_clean TO 'ecommerce_clean.csv' (HEADER, DELIMITER ',')")

# ---------- Preview ----------
print("\n--- HR preview ---")
print(con.sql("SELECT * FROM hr_clean LIMIT 5").df())

print("\n--- Ecommerce preview ---")
print(con.sql("SELECT * FROM ecommerce_clean LIMIT 5").df())

print("\nDone. Cleaned files written to hr_clean.csv and ecommerce_clean.csv")
con.close()