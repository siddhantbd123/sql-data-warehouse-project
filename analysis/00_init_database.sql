/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouseAnalytics' after checking if it already exists. 
    If the database exists, it is dropped and recreated. Additionally, this script creates a schema called gold
	
WARNING:
    Running this script will drop the entire 'DataWarehouseAnalytics' database if it exists. 
    All data in the database will be permanently deleted. Proceed with caution 
    and ensure you have proper backups before running this script.
*/

USE mysql;

-- Drop the 'DataWarehouseAnalytics' database
DROP DATABASE IF EXISTS DataWarehouseAnalytics;

-- Create the 'DataWarehouseAnalytics' database

CREATE DATABASE DataWarehouseAnalytics;

USE DataWarehouseAnalytics;

-- Create Schemas, if it doesn't exist

-- CREATE SCHEMA gold;

USE gold;

CREATE TABLE gold.t_dim_customers (
    customer_key INT,
    customer_id INT,
    customer_number VARCHAR(50),
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    country VARCHAR(50),
    marital_status VARCHAR(50),
    gender VARCHAR(50),
    birthdate DATE,
    create_date DATE
);

CREATE TABLE gold.t_dim_products (
    product_key INT,
    product_id INT,
    product_number VARCHAR(50),
    product_name VARCHAR(50),
    category_id VARCHAR(50),
    category VARCHAR(50),
    subcategory VARCHAR(50),
    maintenance VARCHAR(50),
    cost INT,
    product_line VARCHAR(50),
    start_date DATE
);

CREATE TABLE gold.t_fact_sales (
    order_number VARCHAR(50),
    product_key INT,
    customer_key INT,
    order_date DATE,
    shipping_date DATE,
    due_date DATE,
    sales_amount INT,
    quantity INT,
    price INT
);

TRUNCATE TABLE gold.t_dim_customers;

LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-analytics-project-main/datasets/gold.dim_customers.csv'
INTO TABLE gold.t_dim_customers
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(customer_key, customer_id, customer_number, first_name, last_name, country, marital_status, gender, @birthdate, create_date)
SET birthdate = NULLIF(@birthdate, '');


TRUNCATE TABLE gold.t_dim_products;

LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-analytics-project-main/datasets/gold.dim_products.csv'
INTO TABLE gold.t_dim_products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(product_key, product_id, product_number, product_name, category_id, @category, @subcategory, maintenance, cost, product_line, start_date)
SET category 	= NULLIF(@category, ''),
	subcategory = NULLIF(@subcategory, '');

TRUNCATE TABLE gold.t_fact_sales;

LOAD DATA LOCAL INFILE 'C:/Users/Sid/Downloads/sql-ultimate-course-main/sql-data-analytics-project-main/datasets/gold.fact_sales.csv'
INTO TABLE gold.t_fact_sales
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES
(order_number, product_key, customer_key, @order_date, shipping_date, due_date, sales_amount, quantity, price)
SET order_date = NULLIF(@order_date, '');


-- If MySQL rejects LOCAL INFILE
-- SHOW GLOBAL VARIABLES LIKE 'local_infile';		-- First check whether local loading is enabled
-- SET GLOBAL local_infile = 1;						-- If it is OFF, and you don't have sufficient privileges, enable it
