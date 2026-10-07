# Messy Data Cleaning Portfolio

A hands-on data cleaning project demonstrating **SQL (DuckDB)** and **Python** on two intentionally messy real-world datasets.

The goal: take raw, dirty CSVs and transform them into clean, analysis-ready tables — using **two independent pipelines** (Python and SQL), then prove they agree.

---

## Datasets

### 1. HR Attrition (Messy)
- **File:** `hr_attrition_messy.csv`
- **Rows:** ~13,000
- **Domain:** Human Resources
- **Description:** Employee records with inconsistent formatting, mixed date styles, corrupted categorical values, and unparseable salary strings.

### 2. Ecommerce Retail Transactions (Raw)
- **File:** `ecommerce_retail_transactions_raw.csv`
- **Rows:** ~12,000
- **Domain:** Retail / Ecommerce
- **Description:** Order-level transaction data from multiple countries, with duplicated order IDs, invalid quantities, inconsistent country and payment-method spellings, and mixed date formats.

---

## Tools Used

| Tool | Purpose |
|---|---|
| **DuckDB** | SQL engine — runs embedded, reads CSVs directly, no server needed |
| **Python 3** | Orchestrates the SQL files, exports results, runs parity checks |
| **VS Code** | Development environment |
| **Git / GitHub** | Version control and portfolio hosting |

---

## Data Quality Issues Found

### HR Attrition

| Issue | Examples | Rows Affected |
|---|---|---|
| Mixed gender values | `M`, `Male`, `MALE`, `F`, `Female`, `fm`, `fmale` | Many |
| Mixed department labels | `Mktg`, `Marketing`, `I.T`, `IT`, `Engg`, `Engineering`, `HR`, `H.R`, `sales`, `SALES` | Many |
| Mixed region labels | `NA`, `N. America`, `North America`, `LATAM`, `APAC`, `ME`, `EUR` | Many |
| Mixed date formats | `2021/01/11`, `2022-06-17`, `07/07/2023`, `17-Oct-2013`, `Jun 17, 2015` | Many |
| Salary as text | `"25,000"`, `$25000`, `57.0k`, `TBD`, `Confidential`, `N/A` | Many |
| Attrition variants | `Yes`, `Y`, `Left`, `No`, `N`, `Stayed` | Many |
| Missing values | Empty ages, salaries, emails, regions | Several |
| Invalid ages | `NULL`, `N/A`, `na`, `--`, `unknown` | Several |

### Ecommerce Retail Transactions

| Issue | Examples | Rows Affected |
|---|---|---|
| Mixed date formats | `2026-04-03`, `10-15-2024`, `17 Jun 2024`, `16/10/2025` | Many |
| Duplicate Order_IDs | Same order appears twice | Several |
| Invalid quantities | `-1`, `0` | 186 |
| Mixed country spellings | `USA`, `U.S.A`, `United States`, `US`, `UK`, `U.K.`, `Australia`, `AU` | Many |
| Mixed payment methods | `Net Banking`, `NetBanking`, `COD`, `Cash on Delivery`, `Credit Card`, `Credit_Card` | Many |
| Mixed order statuses | `DELIVERED`, `delivered`, `Shipped`, `shipped` | Many |
| Missing ratings | Blank `Customer_Rating` | 6,056 |

---

## Cleaning Logic

Both pipelines (`clean.py` and the two `.sql` files) implement **identical rules**. This is deliberate — it lets you verify the two produce the same output.

### HR (`clean.py` + `02_clean_hr.sql`)

- **Gender** → `Male` / `Female` via CASE.
- **Department** → alias mapping (`Mktg` → `Marketing`, `I.T` → `IT`, `Engg` → `Engineering`, `sales`/`SALES` → `Sales`, etc.). Blank → `NULL`.
- **Region** → alias mapping (`NA`, `N. America`, `North America` → `North America`; `LATAM`/`Latin America` → `Latin America`; etc.). Blank → `NULL`.
- **Hire_Date** → parsed across 7 date patterns with `COALESCE(TRY_STRPTIME(...))`, cast to `DATE`.
- **Salary** → strips `$` and `,`, expands `k` suffix (`57.0k` → `57000`), rejects junk (`TBD`, `Confidential`, `N/A`) as `NULL`.
- **Attrition** → `Y`/`Yes`/`Left` → `Yes`; `N`/`No`/`Stayed` → `No`.
- **All numeric columns** → `TRY_CAST` so bad values become `NULL` instead of erroring.

### Ecommerce (`clean.py` + `03_clean_ecommerce.sql`)

- **Deduplication** → `ROW_NUMBER() OVER (PARTITION BY Order_ID ORDER BY Order_Date)` keeps one row per order. ⚠️ See caveat below.
- **Order_Date** → parsed across 7 date patterns, cast to `DATE`.
- **Quantity** → negative or zero → `NULL`.
- **Discount_Percent** → nulls → `0`.
- **Payment_Method** → alias mapping (`COD` → `Cash on Delivery`, `U.P.I` → `UPI`, `Credit_Card` → `Credit Card`, etc.).
- **Country** → alias mapping (`U.S.A`, `United States`, `US` → `USA`; `AU` → `Australia`; `DE` → `Germany`; etc.).
- **Order_Status** → explicit CASE (replaces `INITCAP`, which DuckDB dropped).
- **Customer_Rating** → cast to `DOUBLE`; blanks preserved as `NULL`.

#### Caveat on deduplication

The dedupe orders by `Order_Date` **as a raw string**, not as a parsed date. That means "first record" is the alphabetically-first string, not the chronologically-earliest date. This mirrors the original Python implementation exactly, so the two pipelines agree — but it's not what "earliest order" intuitively means. Fixing it would require parsing the date inside the dedupe CTE. Left as-is to keep the parity story honest, and flagged here so reviewers know it was a conscious choice.

---

## Project Structure
---
## Author

**Curtis Ferdinand**
- GitHub: [@curtisf157-star](https://github.com/curtisf157-star)
- LinkedIn: [curtis-ferdinand](https://www.linkedin.com/in/curtis-ferdinand-a56232113)
