-- You can just replace the tables in the checks to verify clean data for different tables

-- Table crm_cust_info
-- 1. Check for NULL or Duplicates in Primary Key
-- Expectation: No result
SELECT cst_id, COUNT(*) 
FROM bronze.crm_cust_info
GROUP BY cst_id
HAVING COUNT(*) > 1 OR cst_id IS NULL;

-- Check for number of duplicates, then rank them based on when they were created and will take only the latest one as per creation date
SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info
WHERE cst_id = 29466;

-- Check how many duplicates are there
SELECT * 
FROM (SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info) AS t
WHERE flag_last != 1;

-- Check if unique are selected and only the lastest one
SELECT * 
FROM (SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info) AS t
WHERE flag_last = 1;

-- 2. Check for unwanted spaces in the string values
-- Expectation: No result
-- Just Trim those columns with spaces
SELECT TRIM(cst_firstname) AS cst_firstname, TRIM(cst_lastname) AS cst_lastname
FROM (SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info) AS t
WHERE flag_last = 1 AND cst_id IS NOT NULL;

-- 3. Data Standardization and Consistency
-- Expectation: M Male, F Female, NULL n/a or M Married, S Single, NULL n/a
SELECT DISTINCT cst_marital_status 
FROM bronze.crm_cust_info;

SELECT DISTINCT gen 
FROM bronze.crm_cust_info;

-- Cleaned
SELECT 
cst_id, 
cst_key, 
TRIM(cst_firstname) AS cst_firstname, 
TRIM(cst_lastname) AS cst_lastname, 
CASE
		WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
        WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
        ELSE 'n/a'
END AS cst_marital_staus, 
CASE
		WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
        WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
        ELSE 'n/a'
END AS cst_gndr, 
cst_create_date
FROM (SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
FROM bronze.crm_cust_info) AS t
WHERE flag_last = 1 AND cst_id IS NOT NULL;

-- Now let's verify that the inserted data into silver is clean by running the checks again but using silver as table
-- Repeat the code for the checks and see

-- Table crm_prd_info
-- 1. Check for NULL or Duplicates in Primary Key
-- Expectation: No result
SELECT prd_id, COUNT(*) 
FROM bronze.crm_prd_info
GROUP BY prd_id
HAVING COUNT(*) > 1 OR prd_id IS NULL;

-- 2. Check for unwanted spaces in the string values
-- Expectation: No result
SELECT prd_nm
FROM bronze.crm_prd_info
WHERE prd_nm != TRIM(prd_nm);

-- 3. Data Standardization and Consistency
-- Expectation: M Mountain, R Road, S Other Sales, T Touring, n/a
SELECT DISTINCT prd_line 
FROM bronze.crm_prd_info;

-- 4. Check for NULLs and Negative Numbers
-- Expectation: No Result
SELECT prd_cost
FROM bronze.crm_prd_info 
WHERE prd_cost < 0 OR prd_cost IS NULL;

-- 5. Check for Invalid Date Orders
-- Expectation: No Result
SELECT * 
FROM bronze.crm_prd_info
WHERE prd_end_dt < prd_start_dt;				-- End date must not be earlier than start date

/*
Rules:
1. We can Switch the Start and End Date but if the price varies, i.e. if the price of product old date is 1 and for same product it is 2 within same time interval then don't use it.
2. The Start date cannot be NULL, while it is fine if End Date is NULL in that case we can rebuild the End Date. 
	We can do: End Date = (Start Date of next record - 1) so it is smaller then the next Start Date, So if it came for last record we keep it NULL since there won't be any info after that.
*/

-- So here we used LEAD to take the next date of prd_start_dt and DATE_SUB to get the (date - 1 day)
SELECT prd_id, prd_key, prd_nm, prd_start_dt, prd_end_dt, 
DATE_SUB(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY) AS prd_end_dt_test		
FROM bronze.crm_prd_info
WHERE prd_key IN ('AC-HE-HL-U509-R', 'AC-HE-HL-U509');			-- we took these two values from the result for testing

-- Cleaned
SELECT 
prd_id, 															-- the first five letters in prd_key is the id in erp_px_cat_g1v2 so we can join with it, after them from 7th letter is the sls_prd_key in crm_sales_details 
REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id, 				-- So using substring to get the first five letters, also id has '_' rather than '-' so replacing the '-' with '_'
SUBSTRING(prd_key, 7, length(prd_key)) AS prd_key,					-- This is the sls_prd_key in crm_sales_details
prd_nm, 
IFNULL(prd_cost, 0) AS prd_cost,									-- Cost cannot be NULL
CASE UPPER(TRIM(prd_line))											-- Shortcut only if you have mapping values and not for complex conditions, so we don't have to use UPPER(TRIM(prd_line)) each time for M, R, S, T. The Function UPPER(TRIM(prd_line)) is applied each time after that
	WHEN 'M' THEN 'Mountain'
    WHEN 'R' THEN 'Road'
    WHEN 'S' THEN 'Other Sales'
    WHEN 'T' THEN 'Touring'
    ELSE 'n/a'
END AS prd_line,
CAST(prd_start_dt AS DATE) AS prd_start_dt, 						-- Since Timestamp were all 00:00:00 so we do not need them so we cast it from DATETIME to only DATE 
CAST(DATE_SUB(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY) AS DATE) AS prd_end_dt			-- End Date can be NULL but not the Start Date
FROM bronze.crm_prd_info;
-- WHERE REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') NOT IN 
-- (SELECT DISTINCT id FROM bronze.erp_px_cat_g1v2);					-- to check if we got all categories matching from crm_prd in the erp_px_cat table, if blank then we have them all and if any category shows then we need that in erp_px_cat table
-- WHERE SUBSTRING(prd_key, 7, length(prd_key)) NOT IN
-- (SELECT DISTINCT sls_prd_key FROM bronze.crm_sales_details);			-- here we got result with a few products which don't have any orders, but it's fine since we have many other mathcing prd_key so we can join the table

-- Now let's verify that the inserted data into silver is clean by running the checks again
-- Repeat the code for the checks and see

-- Table crm_sales_details
-- 1. Check for Invalid Date Orders
-- Expectation: No Result
-- Here we were getting values as 0, which is bad so get them to NULL using NULLIF, also a date is of length 8 i.e. YYYYMMDD so check if it exceeds or less for bad data, don't want the date high than 2050 or less than 1990 
SELECT NULLIF(sls_order_dt, 0) 
FROM bronze.crm_sales_details
WHERE sls_order_dt <= 0 OR length(sls_order_dt) != 8 OR sls_order_dt > 20500101 OR sls_order_dt < 19900101;		-- you can check each condition one at a time instead of OR's

-- You can convert INT to DATE if it is a date literal i.e. 20261018 YYYYMMDD, If it isn't date literal i.e. 18102026 DDMMYYYY then convert it to string then to date using STR_TO_DATE(18102026, '%d%m%Y')
SELECT CAST(sls_order_dt AS DATE), 
	STR_TO_DATE(CAST(sls_order_dt AS CHAR), '%Y%m%d')
FROM bronze.crm_sales_details;

-- Order Date should never be more than ship or due date
SELECT * 
FROM bronze.crm_sales_details
WHERE sls_order_dt > sls_ship_dt OR sls_order_dt > sls_due_dt;

-- 2. Check for NULLs and Negative Numbers
-- Expectation: No Result
/* Business Rule for Sales, sales = quantity * price. Negative, NULLs, Zeroes not allowed
If Sales is negative, zero or NULL then derive it from Quantity and price, 
If Price is zero or NULL then calculate it using Sales and Quantity, If Price is Negative then convert it to positive */
SELECT DISTINCT sls_sales, sls_quantity, sls_price  
FROM bronze.crm_sales_details
WHERE sls_sales != sls_quantity * sls_price OR 
sls_sales IS NULL OR sls_quantity IS NULL OR sls_price IS NULL OR 
sls_sales <= 0 OR sls_quantity <= 0 OR sls_price <= 0
ORDER BY sls_sales, sls_quantity, sls_price;

-- Cleaned
SELECT 
sls_ord_num, 
sls_prd_key, 
sls_cust_id,
CASE
	WHEN sls_order_dt = 0 OR length(sls_order_dt) != 8 THEN NULL		-- If date is 0 or length is less then 8 then make it NULL, else convert it from INT to DATE
    ELSE CAST(sls_order_dt AS DATE)
END AS sls_order_dt, 
CASE
	WHEN sls_ship_dt = 0 OR length(sls_ship_dt) != 8 THEN NULL
    ELSE CAST(sls_ship_dt AS DATE)
END AS sls_ship_dt, 
CASE
	WHEN sls_due_dt = 0 OR length(sls_due_dt) != 8 THEN NULL
    ELSE CAST(sls_due_dt AS DATE)
END AS sls_due_dt, 
CASE
	WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != sls_quantity * ABS(sls_price) THEN sls_quantity * ABS(sls_price)
    ELSE sls_sales
END AS sls_sales, 
sls_quantity, 
CASE
	WHEN sls_price IS NULL OR sls_price <= 0 THEN ROUND(sls_sales / NULLIF(sls_quantity, 0), 0)				-- cannot divide by 0 so if you get any then make it NULL
    ELSE sls_price
END AS sls_price  
FROM bronze.crm_sales_details;
-- WHERE sls_prd_key NOT IN (SELECT prd_key FROM silver.crm_prd_info)			-- To check if the prd_key is in the silver layer table where we cleaned it
-- WHERE sls_cust_id NOT IN (SELECT cst_id FROM silver.crm_cust_info)			-- To check if the cust_id is in the silver layer table where we cleaned it

-- Now let's verify that the inserted data into silver is clean by running the checks again
-- Repeat the code for the checks and see

-- Table erp_cust_az12
-- 1. Check for out-of range dates for table erp_cust_az12
-- Expectation: No Result
SELECT bdate 
FROM silver.erp_cust_az12 
WHERE bdate < '1924-01-01' OR bdate > NOW();				-- birthdate less than 1924 means customer might be approx more than 100 years old (depends if you wanna remove or not), OR birthdate is in future i.e. great than today's date

-- 2. Data Standardization and Consistency
-- Expectation: M Male, F Female, NULL n/a
SELECT DISTINCT gen 
FROM silver.erp_cust_az12;

-- Cleaned
SELECT  
CASE
	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))					-- We can connect cid with cst_key, but cst_key starts without the three charachtes 'NAS' found in cid so let's transform it by taking only the rest of characters after 'NAS'
    ELSE cid																	-- If there is no 'NAS' then keep it as it is
END AS cid,  
CASE
	WHEN bdate > NOW() THEN NULL
    ELSE bdate
END as bdate, 
CASE
	WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'						-- If there is F or FEMALE then make it Female, Why FEMALE because we took UPPER
    WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
    ELSE 'n/a'
END AS gen 
FROM bronze.erp_cust_az12;
-- WHERE CASE																		-- To check if cid is matching with cst_key in the silver layer table where we cleaned it
-- 	WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))
--     ELSE cid																	
-- END NOT IN (SELECT cst_key FROM silver.crm_cust_info);

-- Now let's verify that the inserted data into silver is clean by running the checks again
-- Repeat the code for the checks and see

-- Table erp_loc_a101
-- 1. Data Standardization and Consistency
-- Expectation: DE Germany, US/USA United States, '' n/a
SELECT DISTINCT cntry 
FROM silver.erp_loc_a101
ORDER BY cntry;

-- Cleaned
SELECT 												
REPLACE(cid, '-', '') AS cid, 														-- We can connect cid with cst_key, but cst_key don't have any '-' in it so let's replace '-' with ''
CASE 
    WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
    WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
    WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
    ELSE TRIM(cntry)
END AS cntry  
FROM bronze.erp_loc_a101;
-- WHERE REPLACE(cid, '-', '') NOT IN (SELECT cst_key FROM silver.crm_cust_info);		-- To check if any replaced value is not inside cst_key

-- Now let's verify that the inserted data into silver is clean by running the checks again
-- Repeat the code for the checks and see

-- Table erp_px_cat_g1v2
-- 1. Check for unwanted spaces in the string values
-- Expectation: No result
SELECT * 
FROM bronze.erp_px_cat_g1v2 
WHERE cat != TRIM(cat) OR subcat != TRIM(subcat) OR maintenance != TRIM(maintenance);

-- 2. Data Standardization and Consistency
SELECT DISTINCT cat 
-- subcat, 
-- maintenance 
FROM bronze.erp_px_cat_g1v2;

-- Cleaned
SELECT 
id, 																			-- We can connect id with cat_id which we created new in the silver to match this id column
cat, 
subcat, 
maintenance 
FROM bronze.erp_px_cat_g1v2;													-- Data was clean after doing all checks so load as it is

-- Now let's verify that the inserted data into silver is clean by running the checks again
-- Repeat the code for the checks and see
