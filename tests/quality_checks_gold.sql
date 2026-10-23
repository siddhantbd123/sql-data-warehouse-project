/*
===============================================================================
Quality Checks
===============================================================================
Script Purpose:
    This script performs quality checks to validate the integrity, consistency, and accuracy of the Gold Layer. 
    These checks ensure:
    - Uniqueness of surrogate keys in dimension tables.
    - Referential integrity between fact and dimension tables.
    - Validation of relationships in the data model for analytical purposes.

Usage Notes:
    - Investigate and resolve any discrepancies found during the checks.
===============================================================================
*/

-- Tip: Give friendly alias to columns in gold layer as per conventions and also sort/align (order of the columns) columns as desired
-- Using the Data Model and business requirements we decide which tables to join and keep final in gold 
-- Dimension Table: If it has descriptive info, Create a surrogate key for it (You can ORDER BY using any columns as desired)
-- Fact Table: If it has quantitative info, Create a surrogate key (It comes from the surrogate keys of Dimension Tables)

-- Dimension Table Customer Data
-- Check for Duplicates if any after the Join
-- Expectation: No Result
SELECT cst_id, COUNT(*)
FROM (
SELECT 
ci.cst_id, 
ci.cst_key, 
ci.cst_firstname, 
ci.cst_lastname, 
ci.cst_marital_status, 
ci.cst_gndr, 
ci.cst_create_date, 
ca.bdate, 
ca.gen, 
la.cntry
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid 
LEFT JOIN silver.erp_loc_a101 AS la
ON ci.cst_key = la.cid
) AS t
GROUP BY cst_id
HAVING COUNT(*) > 1;

-- Data Integration
-- We had two columns for gender, so let's see the distinct value from both and choose/create only one by combining them
-- Here we have some Male in 1st column but also Female in 2nd column for the same value. In such case ask the team which is the Master Table.
-- Here assuming crm_cust_info is the Master Table, so we'll consider gender column from it and ignore from the erp_cust_az12
SELECT DISTINCT
ci.cst_gndr,
ca.gen,
CASE
	WHEN ci.cst_gndr != 'n/a' THEN ci.cst_gndr				-- crm is the master table for gender info, So if there is no 'n/a' then use crm data, if it is 'n/a' use erp data, if both has 'n/a' then 'n/a' 
    ELSE COALESCE(ca.gen, 'n/a')							-- If there are NULLs in ca_gen, it is because the customers in crm are not present in erp, so just handle the NULLs here
END AS new_gen
FROM silver.crm_cust_info AS ci
LEFT JOIN silver.erp_cust_az12 AS ca
ON ci.cst_key = ca.cid 
LEFT JOIN silver.erp_loc_a101 AS la
ON ci.cst_key = la.cid
ORDER BY 1, 2;

-- Check for standardization in view
SELECT DISTINCT gender
FROM gold.dim_customers;

-- Check for Uniqueness of Customer Key in gold.dim_customers
-- Expectation: No results 
SELECT customer_key, COUNT(*) AS duplicate_count
FROM gold.dim_customers
GROUP BY customer_key
HAVING COUNT(*) > 1;

-- Dimension Table Product Data
-- We took only current record, if the record has end date means it is already done and is in past, if end date is NULL means it has not yet finished so prd_en_dt is NULL
SELECT
pn.prd_id, 
pn.cat_id, 
pn.prd_key, 
pn.prd_nm, 
pn.prd_cost, 
pn.prd_line, 
pn.prd_start_dt 
-- pn.prd_end_dt		-- And since it will always be NULL we don't really need it to be displayed in the result after using WHERE to  filter all historical data
FROM silver.crm_prd_info AS pn
WHERE prd_end_dt IS NULL;

-- Check for Duplicates if any after the Join
-- Expectation: No Result
SELECT prd_id, COUNT(*)
FROM (
SELECT
pn.prd_id, 
pn.cat_id, 
pn.prd_key, 
pn.prd_nm, 
pn.prd_cost, 
pn.prd_line, 
pn.prd_start_dt,
pc.cat,
pc.subcat,
pc.maintenance
FROM silver.crm_prd_info AS pn
LEFT JOIN silver.erp_px_cat_g1v2 AS pc
ON pn.cat_id = pc.id
WHERE prd_end_dt IS NULL) AS t
GROUP BY prd_id
HAVING COUNT(*) > 1;

-- There was no need for any data integration here so just sort the columns as desired and give friendly alias

-- Check for Uniqueness of Product Key in gold.dim_products
-- Expectation: No results 
SELECT product_key, COUNT(*) AS duplicate_count
FROM gold.dim_products
GROUP BY product_key
HAVING COUNT(*) > 1;

-- Use the Dimension Table's Surrogate keys instead of IDs to easily connect Facts with Dimension (Why? So to connect Fact with Dimension)
-- Fact Table Sales
-- Since it is a Fact Table we will need Surrogate key from the Dimension Table, so let's join with them
SELECT
sd.sls_ord_num, 
pr.product_key,
-- sd.sls_prd_key, 								-- Since we got the product key from dimension table, we don't need this one, we choose it since it was mathcing with dimension
cu.customer_key,
-- sd.sls_cust_id, 								-- Since we got the customer key from dimension table, we don't need this one, we choose it since it was mathcing with dimension
sd.sls_order_dt, 
sd.sls_ship_dt, 
sd.sls_due_dt, 
sd.sls_sales, 
sd.sls_quantity, 
sd.sls_price
FROM silver.crm_sales_details AS sd
LEFT JOIN gold.dim_customers AS pr
ON sd.sls_prd_key = pr.product_number			-- Since this is common in both
LEFT JOIN gold.dim_customers AS cu
ON sd.sls_cust_id = cu.customer_id;				-- Since this is common in both

-- There was no need for any data integration here so just sort the columns as desired and give friendly alias

-- Foreign Key Integrity (Dimensions)
-- Check if all dimension table can successfully join to the fact table
-- Expectation: No Result
SELECT *
FROM gold.fact_sales AS f
LEFT JOIN gold.dim_customers AS c
ON f.customer_key = c.customer_key
WHERE c.customer_key IS NULL;
-- LEFT JOIN gold.dim_products AS p
-- ON f.product_key = p.product_key
-- WHERE p.product_key IS NULL;
