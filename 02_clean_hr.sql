-- 02_clean_hr.sql
-- Mirrors clean.py (HR block). Run from project root.

CREATE OR REPLACE TABLE hr_raw AS
SELECT * FROM read_csv_auto('hr_attrition_messy.csv', header = true);

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