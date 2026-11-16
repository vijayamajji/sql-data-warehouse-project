/*
===============================================================================
DDL Script: Create Gold Views
===============================================================================
Script Purpose:
    This script creates views for the Gold layer in the data warehouse.
    The Gold layer represents the final dimension and fact tables (Star Schema)

    Each view performs transformations and combines data from the Silver layer
    to produce a clean, enriched, and business-ready dataset.

Usage:
    - These views can be queried directly for analytics and reporting.
===============================================================================
*/

-- =============================================================================
-- Create Dimension: gold.dim_customers
-- =============================================================================
CREATE VIEW gold.dim_customers AS 
SELECT 
    ROW_NUMBER() OVER (ORDER BY cst_id) AS customer_key,
	ci.cst_id AS customer_id,	
	ci.cst_key AS customer_number,	
	ci.cst_firstname AS first_name,	
	ci.cst_lastname AS last_name,	
	la.cntry AS country,
	ci.cst_marital_status AS marital_status,
	CASE WHEN ci.cst_gndr !='n/a' THEN ci.cst_gndr
	     ELSE COALESCE(ca.gen,'n/a') 
		 END AS gender,
	ca.bdate AS birthdate,
    ci.cst_create_date AS create_date
from silver.crm_cust_info ci
LEFT JOIN silver.erp_cust_az12 ca
ON ci.cst_key=ca.cid
LEFT JOIN silver.erp_loc_a101 la
ON ci.cst_key=la.cid;

SELECT * from gold.dim_customers;
-- check for duplicate records
-- data integration: we have gender from 2 colomns - use distinct to find combination - need to know master source
-- rename columns to friendly, meaningful names
-- sort the columns into logical groups to improve readability
-- whether it is dimension or fact?
-- find out primary key = surrogate key
  --  we can generate pk : ddl based generation or query based using window function(Row_number)
-- create view for the table

-----------------------
-- dimension_products
-----------------------
CREATE VIEW gold.dim_products AS
SELECT 
	ROW_NUMBER() OVER (ORDER BY pn.prd_start_dt,pn.prd_key) AS product_key,
	pn.prd_id AS product_id,	
	pn.prd_key AS product_number,
	pn.prd_nm AS product_name,	
	pn.cat_id AS category_id,	
	pc.cat AS category,
	pc.subcat AS subcategory,
	pc.maintenance,
	pn.prd_cost AS cost,	
	pn.prd_line AS product_line,	
	pn.prd_start_dt AS start_date
FROM silver.crm_prd_info pn
LEFT JOIN silver.erp_px_cat_g1v2 pc
ON pn.cat_id=pc.ID
WHERE pn.prd_end_dt	IS NULL; -- Filter out all historical data

-- filter for only current data, ignore historical data
-- check for duplicate records
-- data integration: we have gender from 2 colomns - use distinct to find combination - need to know master source
-- rename columns to friendly, meaningful names
-- sort the columns into logical groups to improve readability
-- whether it is dimension or fact?
-- find out primary key = surrogate key
  --  we can generate pk : ddl based generation or query based using window function(Row_number)
-- create view for the table

-- Fact_Sales
CREATE VIEW gold.fact_sales AS
SELECT 
	sls_ord_num AS order_number,	
	pr.product_key,  -- use surrogate key from dimension 
	cu.customer_key, -- use surrogate key from dimension 
	sls_order_dt AS order_date,	
	sls_ship_dt AS shipping_date,	
	sls_due_dt AS due_date,	
	sls_sales AS sales_amount,	
	sls_quantity AS quantity,	
	sls_price AS price	
FROM silver.crm_sales_details sd
LEFT JOIN gold.dim_products pr
ON sd.sls_prd_key = pr.product_number
LEFT JOIN gold.dim_customers cu
ON sd.sls_cust_id= cu.customer_id;

Select * from gold.fact_sales;
-- join two dimensions with existing keys in the fact
   -- * Use the dimensions's surrogate keys instead of IDs to easily connect facts with dimensions
-- adding surrogatekeys from dimension in fact by joining sivler layer fact with gold layer dimensions as we have surrogates key are in gold layer only
-- give friendly names
-- sort the columns - dimension keys + dates + measures
-- check if all dimension tables can successfully join to the fact table

-- Foreign Key integrity (Dimensions)
SELECT * 
FROM gold.fact_sales f
left join gold.dim_customers c
on c.customer_key=f.customer_key
left join gold.dim_products p
on p.product_key=f.product_key
where  p.product_key IS NULL;
