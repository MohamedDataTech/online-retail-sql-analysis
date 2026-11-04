/*
ONLINE RETAIL SALES ANALYSIS — SQL PORTFOLIO PROJECT
MySQL 8+ | Source: retail_sales | Clean table: retail_sales_clean
This script reconstructs the core queries documented in our project conversation.
Review and execute section-by-section. Check whether tables already exist before CREATE.
*/

-- 1. CLEAN TABLE (exact duplicates removed)
CREATE TABLE IF NOT EXISTS retail_sales_clean AS
SELECT DISTINCT * FROM retail_sales;

-- 2. DATA QUALITY
SELECT COUNT(*) AS raw_rows FROM retail_sales;
SELECT COUNT(*) AS clean_rows FROM retail_sales_clean;

SELECT
  SUM(Description IS NULL) AS missing_description,
  SUM(CustomerID IS NULL) AS missing_customer_id,
  SUM(StockCode IS NULL) AS missing_stockcode,
  SUM(Country IS NULL) AS missing_country
FROM retail_sales_clean;

SELECT COUNT(*) AS negative_quantity_records
FROM retail_sales_clean WHERE Quantity < 0;

SELECT COUNT(*) AS cancelled_records
FROM retail_sales_clean WHERE InvoiceNo LIKE 'C%';

SELECT COUNT(DISTINCT Country) AS total_countries
FROM retail_sales_clean;

-- 3. BUSINESS KPIs
-- Net revenue includes negative quantities/returns
SELECT ROUND(SUM(Quantity * UnitPrice), 2) AS net_revenue
FROM retail_sales_clean;

-- Gross sales: positive quantities and prices, excluding cancelled invoices
SELECT ROUND(SUM(Quantity * UnitPrice), 2) AS gross_sales
FROM retail_sales_clean
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%';

-- Return value as a positive amount
SELECT ROUND(SUM(Quantity * UnitPrice) * -1, 2) AS return_value
FROM retail_sales_clean WHERE Quantity < 0;

SELECT COUNT(DISTINCT CustomerID) AS total_customers
FROM retail_sales_clean WHERE CustomerID IS NOT NULL;

SELECT SUM(Quantity) AS total_quantity_sold
FROM retail_sales_clean WHERE Quantity > 0;

-- 4. COUNTRY REVENUE
SELECT Country, ROUND(SUM(Quantity * UnitPrice), 2) AS total_revenue
FROM retail_sales_clean
GROUP BY Country
ORDER BY total_revenue DESC;

-- 5. TOP PRODUCTS BY REVENUE
SELECT StockCode, Description,
       ROUND(SUM(Quantity * UnitPrice), 2) AS product_revenue
FROM retail_sales_clean
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
GROUP BY StockCode, Description
ORDER BY product_revenue DESC
LIMIT 10;

-- 6. TOP PRODUCTS BY QUANTITY
SELECT StockCode, Description, SUM(Quantity) AS quantity_sold
FROM retail_sales_clean
WHERE Quantity > 0 AND InvoiceNo NOT LIKE 'C%'
GROUP BY StockCode, Description
ORDER BY quantity_sold DESC
LIMIT 10;

-- 7. MONTHLY SALES
SELECT DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
       ROUND(SUM(Quantity * UnitPrice), 2) AS monthly_revenue
FROM retail_sales_clean
WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
ORDER BY sales_month;

-- MONTH-OVER-MONTH GROWTH (LAG)
WITH monthly_sales AS (
  SELECT DATE_FORMAT(InvoiceDate, '%Y-%m') AS sales_month,
         SUM(Quantity * UnitPrice) AS revenue
  FROM retail_sales_clean
  WHERE Quantity > 0 AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  GROUP BY DATE_FORMAT(InvoiceDate, '%Y-%m')
)
SELECT sales_month, ROUND(revenue, 2) AS revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY sales_month))
       / NULLIF(LAG(revenue) OVER (ORDER BY sales_month), 0) * 100, 2)
       AS mom_growth_pct
FROM monthly_sales ORDER BY sales_month;

-- 8. CUSTOMER ORDERS AND SPENDING
SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS total_orders,
       ROUND(SUM(Quantity * UnitPrice), 2) AS customer_spending
FROM retail_sales_clean
WHERE CustomerID IS NOT NULL AND Quantity > 0
  AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
GROUP BY CustomerID
ORDER BY customer_spending DESC;

-- REPEAT CUSTOMER RATE
WITH customer_orders AS (
  SELECT CustomerID, COUNT(DISTINCT InvoiceNo) AS order_count
  FROM retail_sales_clean
  WHERE CustomerID IS NOT NULL AND Quantity > 0
    AND InvoiceNo NOT LIKE 'C%'
  GROUP BY CustomerID
)
SELECT COUNT(*) AS total_customers,
       SUM(order_count > 1) AS repeat_customers,
       ROUND(SUM(order_count > 1) / COUNT(*) * 100, 2) AS repeat_customer_rate_pct
FROM customer_orders;

-- 9. RFM METRICS
WITH customer_rfm AS (
  SELECT CustomerID,
         DATEDIFF((SELECT MAX(InvoiceDate) FROM retail_sales_clean),
                  MAX(InvoiceDate)) AS recency_days,
         COUNT(DISTINCT InvoiceNo) AS frequency,
         ROUND(SUM(Quantity * UnitPrice), 2) AS monetary_value
  FROM retail_sales_clean
  WHERE CustomerID IS NOT NULL AND Quantity > 0
    AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  GROUP BY CustomerID
)
SELECT * FROM customer_rfm
ORDER BY monetary_value DESC LIMIT 20;

-- RFM SCORES (1–5) USING NTILE
WITH customer_rfm AS (
  SELECT CustomerID,
         DATEDIFF((SELECT MAX(InvoiceDate) FROM retail_sales_clean),
                  MAX(InvoiceDate)) AS recency_days,
         COUNT(DISTINCT InvoiceNo) AS frequency,
         SUM(Quantity * UnitPrice) AS monetary_value
  FROM retail_sales_clean
  WHERE CustomerID IS NOT NULL AND Quantity > 0
    AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  GROUP BY CustomerID
),
rfm_scores AS (
  SELECT CustomerID, recency_days, frequency, monetary_value,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS R,
         NTILE(5) OVER (ORDER BY frequency ASC) AS F,
         NTILE(5) OVER (ORDER BY monetary_value ASC) AS M
  FROM customer_rfm
)
SELECT *, CONCAT(R, F, M) AS rfm_score
FROM rfm_scores
ORDER BY monetary_value DESC LIMIT 20;

-- RFM CUSTOMER SEGMENTS AND SEGMENT SUMMARY
WITH customer_rfm AS (
  SELECT CustomerID,
         DATEDIFF((SELECT MAX(InvoiceDate) FROM retail_sales_clean),
                  MAX(InvoiceDate)) AS recency_days,
         COUNT(DISTINCT InvoiceNo) AS frequency,
         SUM(Quantity * UnitPrice) AS monetary_value
  FROM retail_sales_clean
  WHERE CustomerID IS NOT NULL AND Quantity > 0
    AND UnitPrice > 0 AND InvoiceNo NOT LIKE 'C%'
  GROUP BY CustomerID
),
rfm_scores AS (
  SELECT CustomerID, recency_days, frequency, monetary_value,
         NTILE(5) OVER (ORDER BY recency_days DESC) AS R,
         NTILE(5) OVER (ORDER BY frequency ASC) AS F,
         NTILE(5) OVER (ORDER BY monetary_value ASC) AS M
  FROM customer_rfm
),
customer_segments AS (
  SELECT CustomerID, monetary_value,
         CASE
           WHEN R >= 4 AND F >= 4 AND M >= 4 THEN 'Champions'
           WHEN F >= 4 AND M >= 3 THEN 'Loyal Customers'
           WHEN R >= 4 AND F >= 2 THEN 'Potential Loyalists'
           WHEN R <= 2 AND M >= 4 THEN 'At Risk'
           ELSE 'Others'
         END AS customer_segment
  FROM rfm_scores
)
SELECT customer_segment, COUNT(*) AS total_customers,
       ROUND(SUM(monetary_value), 2) AS total_revenue,
       ROUND(AVG(monetary_value), 2) AS avg_customer_spending
FROM customer_segments
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- 10. JOIN ANALYSIS
-- Create customers once (skip if already created):
-- CREATE TABLE customers AS
-- SELECT DISTINCT CustomerID, Country FROM retail_sales_clean
-- WHERE CustomerID IS NOT NULL;

SELECT c.CustomerID, c.Country,
       COUNT(DISTINCT r.InvoiceNo) AS total_orders,
       ROUND(SUM(r.Quantity * r.UnitPrice), 2) AS total_spending
FROM customers c
INNER JOIN retail_sales_clean r ON c.CustomerID = r.CustomerID
WHERE r.Quantity > 0 AND r.UnitPrice > 0 AND r.InvoiceNo NOT LIKE 'C%'
GROUP BY c.CustomerID, c.Country
ORDER BY total_spending DESC LIMIT 20;

/*
PROJECT FINDINGS (based on outputs recorded in our conversation):
- United Kingdom is the leading revenue-generating country.
- November 2011 was the strongest sales month in the dataset.
- Repeat customer rate was approximately 69.97%.
- Loyal Customers contributed the largest segment revenue.
- RFM segment counts under the selected rules:
  Champions 997; Loyal Customers 670; Others 1,917;
  At Risk 198; Potential Loyalists 557.
*/
