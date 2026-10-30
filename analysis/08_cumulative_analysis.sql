/*
===============================================================================
Cumulative Analysis
===============================================================================
Purpose:
    - To calculate running totals or moving averages for key metrics.
    - To track performance over time cumulatively.
    - Useful for growth analysis or identifying long-term trends.

SQL Functions Used:
    - Window Functions: SUM() OVER(), AVG() OVER()
===============================================================================
*/

-- Calculate the total sales per month 
-- and the running total of sales over time 
SELECT
order_date,
total_sales,
SUM(total_sales) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) AS running_total_sales,
AVG(avg_price) OVER(PARTITION BY YEAR(order_date) ORDER BY order_date) AS moving_average_price
FROM (SELECT 
		DATE_FORMAT(order_date, '%Y-%m-01') AS order_date,
		SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
		FROM gold.t_fact_sales
		WHERE order_date IS NOT NULL
		GROUP BY DATE_FORMAT(order_date, '%Y-%m-01')) AS t;
