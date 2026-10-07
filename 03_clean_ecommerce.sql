-- 03_clean_ecommerce.sql
-- Mirrors clean.py (ecommerce block). Run from project root.

CREATE OR REPLACE TABLE ecommerce_raw AS
SELECT * FROM read_csv_auto('ecommerce_retail_transactions_raw.csv', header = true);

CREATE OR REPLACE TABLE ecommerce_clean AS
WITH deduped AS (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date) AS rn
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