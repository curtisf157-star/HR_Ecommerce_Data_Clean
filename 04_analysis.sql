-- ============================================================
-- 04_analysis.sql
-- Purpose : Sample analysis queries on the cleaned tables.
-- Depends : hr_clean, ecommerce_clean  (built by 02 + 03)
-- Engine  : DuckDB
-- Run     : from the project root
-- ============================================================


-- ============================================================
-- HR ATTRITION
-- ============================================================

-- Q1. Attrition rate by department
--     Raw HR has 'Mktg'/'Marketing', 'I.T'/'IT', 'Engg'/'Engineering' etc.
--     Against raw data this would split one department into multiple rows.
SELECT
  Department,
  COUNT(*)                                                   AS total_employees,
  SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)         AS attrition_count,
  ROUND(
    100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),
    2
  )                                                          AS attrition_rate_pct
FROM hr_clean
GROUP BY Department
ORDER BY attrition_rate_pct DESC;


-- Q2. Average salary by department (only rows with a valid parsed salary)
--     Raw Salary contains '$25000', '"25,000"', '57.0k', 'TBD', 'Confidential'.
--     Against raw data AVG() would either error or ignore most rows.
SELECT
  Department,
  COUNT(*)                              AS employees_with_salary,
  ROUND(AVG(Salary), 2)                 AS avg_salary,
  ROUND(MEDIAN(Salary), 2)              AS median_salary,
  MIN(Salary)                           AS min_salary,
  MAX(Salary)                           AS max_salary
FROM hr_clean
WHERE Salary IS NOT NULL
GROUP BY Department
ORDER BY avg_salary DESC;


-- Q3. Attrition rate by tenure band
--     Shows whether newer or longer-tenured employees leave more.
SELECT
  CASE
    WHEN Years_At_Company IS NULL         THEN 'Unknown'
    WHEN Years_At_Company <  2            THEN '0-1 yrs'
    WHEN Years_At_Company <  5            THEN '2-4 yrs'
    WHEN Years_At_Company < 10            THEN '5-9 yrs'
    WHEN Years_At_Company < 20            THEN '10-19 yrs'
    ELSE '20+ yrs'
  END                                                              AS tenure_band,
  COUNT(*)                                                         AS total_employees,
  SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)               AS leavers,
  ROUND(
    100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),
    2
  )                                                                AS attrition_rate_pct
FROM hr_clean
GROUP BY tenure_band
ORDER BY
  CASE tenure_band
    WHEN '0-1 yrs'  THEN 1
    WHEN '2-4 yrs'  THEN 2
    WHEN '5-9 yrs'  THEN 3
    WHEN '10-19 yrs' THEN 4
    WHEN '20+ yrs'  THEN 5
    ELSE 6
  END;


-- Q4. Attrition rate by gender
SELECT
  Gender,
  COUNT(*)                                                   AS total_employees,
  SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END)         AS leavers,
  ROUND(
    100.0 * SUM(CASE WHEN Attrition = 'Yes' THEN 1 ELSE 0 END) / COUNT(*),
    2
  )                                                          AS attrition_rate_pct
FROM hr_clean
WHERE Gender IS NOT NULL
GROUP BY Gender
ORDER BY attrition_rate_pct DESC;


-- Q5. Top 10 job titles by headcount
--     Trims the long tail so you can see what the org actually does.
SELECT
  Job_Title,
  COUNT(*) AS headcount
FROM hr_clean
WHERE Job_Title IS NOT NULL
GROUP BY Job_Title
ORDER BY headcount DESC
LIMIT 10;


-- ============================================================
-- ECOMMERCE
-- ============================================================

-- Q6. Revenue by product category (delivered orders only)
--     Raw Quantity contains -1 and 0 rows, and Discount_Percent is sometimes NULL.
--     Against raw data this would understate or miscount revenue.
SELECT
  Product_Category,
  COUNT(*)                                                                    AS orders,
  ROUND(SUM(Quantity * Unit_Price_USD * (1 - Discount_Percent / 100.0)), 2)   AS revenue,
  ROUND(AVG(Customer_Rating), 2)                                              AS avg_rating
FROM ecommerce_clean
WHERE Order_Status = 'Delivered'
GROUP BY Product_Category
ORDER BY revenue DESC;


-- Q7. Top countries by order count
--     Raw Country has 'USA' / 'U.S.A' / 'United States', 'UK' / 'U.K.', 'AU' / 'Australia'.
--     Against raw data the US would appear as 3+ separate rows.
SELECT
  Country,
  COUNT(*)          AS orders,
  ROUND(
    SUM(Quantity * Unit_Price_USD * (1 - Discount_Percent / 100.0)),
    2
  )                 AS revenue
FROM ecommerce_clean
GROUP BY Country
ORDER BY orders DESC;


-- Q8. Order status breakdown
--     Raw Order_Status has mixed casing: 'DELIVERED', 'delivered', 'Shipped', 'shipped'.
SELECT
  Order_Status,
  COUNT(*)          AS orders,
  ROUND(
    100.0 * COUNT(*) / (SELECT COUNT(*) FROM ecommerce_clean),
    2
  )                 AS pct_of_orders
FROM ecommerce_clean
GROUP BY Order_Status
ORDER BY orders DESC;


-- Q9. Payment method share
--     Raw Payment_Method has 'NetBanking'/'Net Banking', 'COD'/'Cash on Delivery',
--     'Credit Card'/'Credit_Card', etc.
SELECT
  Payment_Method,
  COUNT(*) AS orders
FROM ecommerce_clean
GROUP BY Payment_Method
ORDER BY orders DESC;


-- Q10. Monthly order trend (delivered orders only)
--      Raw Order_Date is a mix of at least 7 formats.
--      Against raw data this GROUP BY would produce ~1200 distinct 'months'.
SELECT
  DATE_TRUNC('month', Order_Date) AS month,
  COUNT(*)                        AS delivered_orders,
  ROUND(
    SUM(Quantity * Unit_Price_USD * (1 - Discount_Percent / 100.0)),
    2
  )                               AS revenue
FROM ecommerce_clean
WHERE Order_Status = 'Delivered'
  AND Order_Date IS NOT NULL
GROUP BY month
ORDER BY month;


-- Q11. Top 10 products by delivered revenue
SELECT
  Product_Name,
  COUNT(*)                                                                    AS orders,
  ROUND(SUM(Quantity * Unit_Price_USD * (1 - Discount_Percent / 100.0)), 2)   AS revenue
FROM ecommerce_clean
WHERE Order_Status = 'Delivered'
GROUP BY Product_Name
ORDER BY revenue DESC
LIMIT 10;


-- Q12. Data quality recap
--      How many rows were affected by each cleaning rule.
SELECT
  'rows loaded'                 AS metric, COUNT(*) AS value FROM ecommerce_clean
UNION ALL
SELECT 'invalid quantity (-1/0)',          COUNT(*) FROM ecommerce_clean WHERE Quantity IS NULL
UNION ALL
SELECT 'missing rating',                   COUNT(*) FROM ecommerce_clean WHERE Customer_Rating IS NULL
UNION ALL
SELECT 'unknown country',                  COUNT(*) FROM ecommerce_clean WHERE Country IS NULL OR Country = ''
UNION ALL
SELECT 'unknown payment method',           COUNT(*) FROM ecommerce_clean WHERE Payment_Method IS NULL OR Payment_Method = ''
UNION ALL
SELECT 'unknown order status',             COUNT(*) FROM ecommerce_clean WHERE Order_Status IS NULL OR Order_Status = '';

-- Q13. Region distribution (after alias normalization)
--      Before the Region fix, 'NA' / 'N. America' / 'North America' all appeared separately.
--      After: exactly 5 clean regions + a NULL bucket for blank rows.
SELECT
  COALESCE(Region, 'Unknown') AS Region,
  COUNT(*)                    AS employees
FROM hr_clean
GROUP BY Region
ORDER BY employees DESC;