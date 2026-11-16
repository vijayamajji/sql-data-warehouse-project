/*
===============================================================================
Stored Procedure: Load Silver Layer (Bronze -> Silver)
===============================================================================
Script Purpose:
    This stored procedure performs the ETL (Extract, Transform, Load) process to
    populate the 'silver' schema tables from the 'bronze' schema.
    Actions Performed:
        - Truncates Silver tables.
        - Inserts transformed and cleansed data from Bronze into Silver tables.

Usage : EXEC Silver.load_silver;
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver AS
BEGIN
    DECLARE @start_time DATETIME , @end_time DATETIME, @batch_start_time DATETIME, @batch_end_time DATETIME;
    BEGIN TRY -- Error Handling
		SET @batch_start_time= GETDATE();
		PRINT '==========================================';
		PRINT 'Loading Silver Layer';
		PRINT '==========================================';
        
        
		PRINT '------------------------------------------';
		PRINT 'Loading CRM tables';
		PRINT '------------------------------------------';

        /*=============================================
        Insert into silver.crm_cust_info
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        Truncate table silver.crm_cust_info;	
        PRINT '>> Inserting Data Into: silver.crm_cust_info';
        Insert into silver.crm_cust_info (
        cst_id,
        cst_key,
        cst_firstname,
        cst_lastname,
        cst_marital_status,
        cst_gndr,
        cst_create_date
        )
        Select 
               cst_id
              ,cst_key
              ,TRIM(cst_firstname) As cst_firstname
              ,TRIM(cst_lastname) As cst_lastname
              ,CASE WHEN UPPER(TRIM(cst_marital_status))='S' Then 'Single'
                     WHEN UPPER(TRIM(cst_marital_status))='M' Then 'Married' 
                     ELSE 'n/a'
                     END cst_marital_status
              ,CASE WHEN UPPER(TRIM(cst_gndr))='F' Then 'Female'
                     WHEN UPPER(TRIM(cst_gndr))='M' Then 'Male' 
                     ELSE 'n/a'
                     END cst_gndr
              ,cst_create_date
        from (
        select *,
        ROW_NUMBER() over (partition by cst_id order by cst_create_date desc) as flag_last
        from bronze.crm_cust_info
        where cst_id is not null
        ) t where flag_last=1;

        -- Do the quality check of silver tables post insertion
        SET @end_time=GETDATE();
		PRINT '>> Load Duration:' + CAST( Datediff(second, @start_time, @end_time) As NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
        /*=============================================
        Insert into silver.crm_cust_info
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        Truncate table silver.crm_prd_info;	
        PRINT '>> Inserting Data Into: silver.crm_prd_info';
        INSERT INTO silver.crm_prd_info ( 
        prd_id,
        cat_id,
        prd_key,
        prd_nm,
        prd_cost,
        prd_line,
        prd_start_dt,
        prd_end_dt)

        SELECT
        prd_id, 
        REPLACE(SUBSTRING(prd_key,1,5),'-','_') As cat_id,
        SUBSTRING(prd_key,7,LEN(prd_key)) As prd_key,
        prd_nm,
        ISNULL(prd_cost,0) AS prd_cost,
        CASE UPPER(TRIM(prd_line))
        WHEN 'M' THEN 'Mountain'
        WHEN 'R' THEN 'Road'
        WHEN 'S' THEN 'Other Sales'
        WHEN 'T' THEN 'Touring'
        ELSE 'n/a' END AS prd_line,
        CAST(prd_start_dt AS DATE) AS prd_start_dt,
        DATEADD(DAY,-1,LEAD(prd_start_dt) over (partition by prd_key order by prd_start_dt)) as prd_end_dt             
        FROM bronze.crm_prd_info ;
        SET @end_time=GETDATE();
		PRINT '>> Load Duration:' + CAST( Datediff(second, @start_time, @end_time) As NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
        /*=============================================
        Insert into silver.crm_sales_details
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        Truncate table silver.crm_sales_details;	
        PRINT '>> Inserting Data Into: silver.crm_sales_details';
        INSERT INTO silver.crm_sales_details
        (
        sls_ord_num,	
        sls_prd_key,	
        sls_cust_id,	
        sls_order_dt,	
        sls_ship_dt,	
        sls_due_dt,	
        sls_sales,	
        sls_quantity,	
        sls_price	
        )
        select 
        sls_ord_num,
        sls_prd_key,
        sls_cust_id,
        CASE WHEN sls_order_dt=0 or LEN(sls_order_dt)!=8 THEN NULL
        ELSE CAST(CAST(sls_order_dt AS VARCHAR) AS DATE) 
        END AS sls_order_dt,

        CASE WHEN sls_ship_dt=0 or LEN(sls_ship_dt)!=8 THEN NULL
        ELSE CAST(CAST(sls_ship_dt AS VARCHAR) AS DATE) 
        END AS sls_ship_dt,

        CASE WHEN sls_due_dt=0 or LEN(sls_due_dt)!=8 THEN NULL
        ELSE CAST(CAST(sls_due_dt AS VARCHAR) AS DATE) 
        END AS sls_due_dt,

        CASE WHEN sls_sales IS NULL OR sls_sales<=0 OR sls_sales!= sls_quantity* ABS(sls_price)
             THEN sls_quantity * ABS(sls_price)
             ELSE sls_sales
             END AS sls_sales,

        sls_quantity,

        CASE WHEN sls_price IS NULL OR sls_price<=0 
        THEN sls_sales/ NULLIF(sls_quantity,0)
        ELSE sls_price
        END AS sls_price
        from bronze.crm_sales_details;
        SET @end_time=GETDATE();
		PRINT '>> Load Duration:' + CAST( Datediff(second, @start_time, @end_time) As NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
        
		PRINT '------------------------------------------';
		PRINT 'Loading ERP tables';
		PRINT '------------------------------------------';

        /*=============================================
        Insert into silver.erp_cust_az12
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        Truncate table silver.erp_cust_az12;	
        PRINT '>> Inserting Data Into: silver.erp_cust_az12';
        INSERT INTO silver.erp_cust_az12(
        cid,
        bdate,
        gen 
        )

        SELECT 
        CASE WHEN cid like 'NAS%' THEN SUBSTRING(cid,4,LEN(cid))  -- Remove NAS prefix
             ELSE cid END cid,

        CASE WHEN bdate> GETDATE() THEN NULL  
        ELSE bdate END bdate,

        CASE WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'FEMALE'
             WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'MALE'
             ELSE 'n/a'
             END gen  -- Normalize genDer values and handle unknown cases
        FROM bronze.erp_cust_az12;
        SET @end_time=GETDATE();
		PRINT '>> Load Duration:' + CAST( Datediff(second, @start_time, @end_time) As NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
		
        /*=============================================
        Insert into silver.erp_loc_a101
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        Truncate table silver.erp_loc_a101;	
        PRINT '>> Inserting Data Into: silver.erp_loc_a101';
        INSERT INTO silver.erp_loc_a101
        (
        cid,
        cntry
        )
        SELECT 
        REPLACE(cid,'-','') AS cid,
        CASE WHEN TRIM(cntry)='DE' THEN 'GERMANY'
             WHEN TRIM(cntry) IN ('US', 'USA') THEN 'United States'
             WHEN TRIM(cntry)= '' OR cntry IS NULL THEN 'n/a' 
             ELSE TRIM(cntry)
             END AS cntry -- Normalize and handle missing or blank country codes
        FROM bronze.erp_loc_a101;
        SET @end_time=GETDATE();
		PRINT '>> Load Duration:' + CAST( Datediff(second, @start_time, @end_time) As NVARCHAR) + ' seconds';
		PRINT '>> -------------';
		
        /*=============================================
        Insert into silver.erp_px_cat_g1v2 
        =============================================*/
        SET @start_time=GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        Truncate table silver.erp_px_cat_g1v2;	
        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';
        INSERT INTO silver.erp_px_cat_g1v2
        (
         id,
         cat,
         subcat,
         maintenance
        )
         SELECT 
         id,
         cat,
         subcat,
         maintenance
         FROM bronze.erp_px_cat_g1v2;

         SET @batch_end_time= GETDATE();
         PRINT '==============================================';
		 PRINT 'Loading silver layer is completed';
		 PRINT '    - Total Load Duration: '+ CAST( Datediff(second, @batch_start_time, @batch_end_time) As NVARCHAR) + ' seconds';
		 PRINT '==============================================';

    END TRY
    BEGIN CATCH-- This section gets executed if sbove section fails
		    PRINT '==============================================';
		    PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
		    PRINT 'Error Message' + ERROR_MESSAGE();
		    PRINT 'Error Message' + CAST(ERROR_NUMBER() AS NVARCHAR);
		    PRINT 'Error Message' + CAST(ERROR_STATE() AS NVARCHAR);
		    PRINT '===============================================';
    END CATCH 

END 



EXEC silver.load_silver;
