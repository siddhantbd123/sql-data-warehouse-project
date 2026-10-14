/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure prepares the Bronze Layer tables for a fresh data load. It performs the following actions:
		- Truncates all six Bronze tables before loading new data.
		- Uses an EXIT HANDLER to catch SQL exceptions.
		- Retrieves and displays the error message if an exception occurs.
 
 Parameters:
    None. 
	  This stored procedure does not accept any parameters or return any values.

Note: This stored procedure does not import CSV files. CSV data is loaded separately using the LOAD DATA LOCAL INFILE statement in MySQL Workbench.        
===============================================================================
Script: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
	This script loads data from local CSV files into the Bronze Layer tables in the 'bronze' database. It performs the following actions:
        - Loads data from local CSV files using LOAD DATA LOCAL INFILE.
        - Calculates the total data loading duration.

Note:
	Execute CALL bronze.load_bronze() before running the CSV import script.
===============================================================================
*/

DROP PROCEDURE IF EXISTS bronze.load_bronze;

DELIMITER $$

CREATE PROCEDURE bronze.load_bronze()
BEGIN
	DECLARE v_error_message TEXT;
    
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
	BEGIN
		GET DIAGNOSTICS CONDITION 1
			v_error_message = MESSAGE_TEXT;
            
		SELECT 'ERROR OCCURED DURING BRONZE PREPARTION' AS status, v_error_message AS error_message;
    END;
	
    SELECT 'Preparaing Bronze Layer' AS status;
    
    TRUNCATE TABLE bronze.crm_cust_info;
    TRUNCATE TABLE bronze.crm_prd_info;
    TRUNCATE TABLE bronze.crm_sales_details;

    TRUNCATE TABLE bronze.erp_loc_a101;
    TRUNCATE TABLE bronze.erp_cust_az12;
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    
    SELECT 'Bronze table truncated successfully' AS status;
END $$

DELIMITER ;

CALL bronze.load_bronze();

SET @batch_start = NOW();

-- CRM: Customer information
SELECT 'Bronze tables truncated successfully' AS status;
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_crm/cust_info.csv'
-- LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/cust_info.csv'			-- If you don't want to use Local then paste the file in this path and use
INTO TABLE bronze.crm_cust_info
FIELDS TERMINATED BY ','																	-- Since they are separated by ','
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;																				-- Since 1st line is a header(column name) it tells SQL to ignore the 1st line and start from 2nd line

-- CRM: Product information
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_crm/prd_info.csv'
INTO TABLE bronze.crm_prd_info
FIELDS TERMINATED BY ','					
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;	

-- CRM: Sales details
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_crm/sales_details.csv'
INTO TABLE bronze.crm_sales_details
FIELDS TERMINATED BY ','					
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;	

-- ERP: Customer information
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_erp/cust_az12.csv'
INTO TABLE bronze.erp_cust_az12
FIELDS TERMINATED BY ','					
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;	

-- ERP: Location information
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_erp/loc_a101.csv'
INTO TABLE bronze.erp_loc_a101
FIELDS TERMINATED BY ','					
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;	

-- ERP: Product category information
LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-warehouse-project-main/datasets/source_erp/px_cat_g1v2.csv'
INTO TABLE bronze.erp_px_cat_g1v2
FIELDS TERMINATED BY ','					
LINES TERMINATED BY '\r\n'					
IGNORE 1 LINES;	

SET @batch_end = NOW();

SELECT 'Bronze Layer Loading Completed' AS status, TIMESTAMPDIFF(SECOND, @batch_end, @batch_start) AS total_load_duration_seconds;

-- If MySQL rejects LOCAL INFILE
-- SHOW GLOBAL VARIABLES LIKE 'local_infile';		-- First check whether local loading is enabled
-- SET GLOBAL local_infile = 1;						-- If it is OFF, and you don't have sufficient privileges, enable it

-- Verify imported data
SELECT COUNT(*) AS total_rows
FROM bronze.crm_cust_info;

SELECT COUNT(*) AS total_rows
FROM bronze.crm_prd_info;

SELECT COUNT(*) AS total_rows
FROM bronze.crm_sales_details;

SELECT COUNT(*) AS total_rows
FROM bronze.erp_loc_a101;

SELECT COUNT(*) AS total_rows
FROM bronze.erp_cust_az12;

SELECT COUNT(*) AS total_rows
FROM bronze.erp_px_cat_g1v2;
