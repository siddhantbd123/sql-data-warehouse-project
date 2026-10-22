/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to populate the Silver Layer tables from the Bronze Layer.

    Actions Performed:
        - Truncates Silver tables before loading.
        - Inserts transformed and cleansed data from Bronze tables.
        - Handles SQL exceptions and displays error details.

Parameters:
    None.
		This stored procedure does not accept any parameters or return any values.

Note:
    This procedure assumes the Silver tables already exist.

Usage Example:
    CALL silver.load_silver();
===============================================================================
*/

DROP PROCEDURE IF EXISTS silver.load_silver;

DELIMITER $$

CREATE PROCEDURE silver.load_silver()
BEGIN

    DECLARE v_batch_start_time DATETIME;
    DECLARE v_batch_end_time DATETIME;
    DECLARE v_error_message TEXT;
    DECLARE v_error_number INT;
    
	DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
		GET DIAGNOSTICS CONDITION 1
			v_error_message = MESSAGE_TEXT,
            v_error_number = MYSQL_ERRNO;
            
		SELECT 'ERROR OCCURED DURING SILVER LOADING' AS status, v_error_message AS error_message, v_error_number AS error_number;
    END;
    
    SET v_batch_start_time = NOW();

	-- 1. Loading silver.crm_cust_info
    TRUNCATE TABLE silver.crm_cust_info;

	-- Insert clean data into silver for crm.cust_info
	INSERT INTO silver.crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
	SELECT 
		cst_id, 
		cst_key, 
		TRIM(cst_firstname) AS cst_firstname, 
		TRIM(cst_lastname) AS cst_lastname, 
			CASE
				WHEN UPPER(TRIM(cst_marital_status)) = 'M' THEN 'Married'
				WHEN UPPER(TRIM(cst_marital_status)) = 'S' THEN 'Single'
				ELSE 'n/a'
			END AS cst_marital_staus, 							-- Normalize marital status values to readable format
			CASE
				WHEN UPPER(TRIM(cst_gndr)) = 'M' THEN 'Male'
				WHEN UPPER(TRIM(cst_gndr)) = 'F' THEN 'Female'
				ELSE 'n/a'
			END AS cst_gndr,									-- Normalize gender values to readable format
		cst_create_date
	FROM (SELECT * , ROW_NUMBER() OVER(PARTITION BY cst_id ORDER BY cst_create_date DESC) AS flag_last
		FROM bronze.crm_cust_info) AS t
	WHERE flag_last = 1 AND cst_id IS NOT NULL;				-- Select the most recent record per customer and non null

	-- 2. Loading silver.crm_prd_info
    TRUNCATE TABLE silver.crm_prd_info;
    
	-- Insert clean data into silver for crm.prd_info
	INSERT INTO silver.crm_prd_info (prd_id, cat_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
	SELECT 
		prd_id, 															
		REPLACE(SUBSTRING(prd_key, 1,5), '-', '_') AS cat_id,				-- Extract category ID			
		SUBSTRING(prd_key, 7, length(prd_key)) AS prd_key, 					-- Extract product key
		prd_nm, 
		IFNULL(prd_cost, 0) AS prd_cost,									-- Product Cost cannot be NULL								
		CASE UPPER(TRIM(prd_line))
			WHEN 'M' THEN 'Mountain'
			WHEN 'R' THEN 'Road'
			WHEN 'S' THEN 'Other Sales'
			WHEN 'T' THEN 'Touring'
			ELSE 'n/a'
		END AS prd_line,													-- Map product line codes to descriptive values
		CAST(prd_start_dt AS DATE) AS prd_start_dt,
		CAST(DATE_SUB(LEAD(prd_start_dt) OVER(PARTITION BY prd_key ORDER BY prd_start_dt), INTERVAL 1 DAY) AS DATE) AS prd_end_dt		-- Calculate end date as one day before the next start date
	FROM bronze.crm_prd_info;

	-- 3. Loading silver.crm_sales_details
    TRUNCATE TABLE silver.crm_sales_details;
    
	-- Insert clean data into silver for sales_details
	INSERT INTO silver.crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
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
		END AS sls_sales, 														-- Recalculate sales if original value is missing or incorrect
		sls_quantity, 
		CASE
			WHEN sls_price IS NULL OR sls_price <= 0 THEN ROUND(sls_sales / NULLIF(sls_quantity, 0), 0)
			ELSE sls_price
		END AS sls_price  														-- Derive price if original value is invalid
	FROM bronze.crm_sales_details;

    -- 4. Loading silver.erp_cust_az12
    TRUNCATE TABLE silver.erp_cust_az12;
    
	-- Insert clean data into silver for cust_az12
	INSERT INTO silver.erp_cust_az12 (cid, bdate, gen)
	SELECT  
	CASE
		WHEN cid LIKE 'NAS%' THEN SUBSTRING(cid, 4, LENGTH(cid))				-- Remove 'NAS' prefix if present				
		ELSE cid																	
	END AS cid,  
	CASE
		WHEN bdate > NOW() THEN NULL
		ELSE bdate
	END as bdate, 
	CASE
		WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'						
		WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
		ELSE 'n/a'
	END AS gen 																	-- Normalize gender values and handle unknown cases
	FROM bronze.erp_cust_az12;

    -- 5. Loading silver.erp_loc_a101
    TRUNCATE TABLE silver.erp_loc_a101;
   
	-- Insert clean data into silver for loc_a101
	INSERT INTO silver.erp_loc_a101 (cid, cntry)
	SELECT 												
	REPLACE(cid, '-', '') AS cid, 												
	CASE 
		WHEN UPPER(TRIM(cntry)) = 'DE' THEN 'Germany'
		WHEN UPPER(TRIM(cntry)) IN ('US', 'USA') THEN 'United States'
		WHEN UPPER(TRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
		ELSE TRIM(cntry)
	END AS cntry  																-- Normalize and Handle missing or blank country codes
	FROM bronze.erp_loc_a101;

    -- 6. Loading silver.erp_px_cat_g1v2
    TRUNCATE TABLE silver.erp_px_cat_g1v2;
    
	-- Insert clean data into silver for px_cat_g1v2
	INSERT INTO silver.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
	SELECT 
	id, 
	cat, 
	subcat, 
	maintenance 
	FROM bronze.erp_px_cat_g1v2;
    
   -- Batch completion
   SET v_batch_end_time = NOW();
   
   SELECT 'Loading Silver Layer Completed' AS status, TIMESTAMPDIFF(SECOND, v_batch_start_time, v_batch_end_time) AS total_load_duration_seconds;
   
END $$

DELIMITER ;

-- Execute the Stored procedure
CALL silver.load_silver();

-- Verify imported data
SELECT *
FROM silver.crm_cust_info;

SELECT *
FROM silver.crm_prd_info;

SELECT *
FROM silver.crm_sales_details;

SELECT *
FROM silver.erp_loc_a101;

SELECT *
FROM silver.erp_cust_az12;

SELECT *
FROM silver.erp_px_cat_g1v2;
