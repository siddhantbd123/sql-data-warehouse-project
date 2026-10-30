/*
===============================================================================
Date Range Exploration 
===============================================================================
Purpose:
    - To determine the temporal boundaries of key data points.
    - To understand the range of historical data.

SQL Functions Used:
    - MIN(), MAX(), DATEDIFF()
===============================================================================
*/

-- Determine the first and last order date and the total duration in months
SELECT 
MIN(order_date) AS first_order_date, 
MAX(order_date) AS last_order_date,
TIMESTAMPDIFF(YEAR, MIN(order_date), MAX(order_date)) AS order_range_years
FROM gold.t_fact_sales;

-- Find the youngest and oldest customer based on birthdate
SELECT 
MIN(birthdate) AS oldest_customer,
TIMESTAMPDIFF(YEAR, MIN(birthdate), NOW()) AS oldest_age, 
MAX(birthdate) AS youngest_customer, 
TIMESTAMPDIFF(YEAR, MAX(birthdate), NOW()) AS youngest_age
FROM gold.t_dim_customers;
