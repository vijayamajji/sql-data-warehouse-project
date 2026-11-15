/*==============================
Check qaulity of bronze data
================================
*/
-- =============================================================
-- #Quality Check 01 : Primary key must be unique and not null
--==============================================================

Select
cst_id,
count(*)
from bronze.crm_cust_info
group by cst_id
having count(*)>1 or cst_id is null;

--Fix: Rank the duplicate rows by creation date and get the latest one.
Select * 
from (
select *,
ROW_NUMBER() over (partition by cst_id order by cst_create_date desc) as flag_last
from bronze.crm_cust_info
where cst_id is not null
) t where flag_last=1;

-- ===============================================================
-- #Quality Check 02 : Check for unwanted spaces in string values
--================================================================
select 
cst_firstname
from bronze.crm_cust_info
where cst_firstname!=trim(cst_firstname);

-- Fix: Add trim () for every string value.

Select 
       cst_id
      ,cst_key
      ,trim(cst_firstname) As cst_firstname
      ,trim(cst_lastname) As cst_lastname
      ,cst_marital_status
      ,cst_gndr
      ,cst_create_date

from (
select *,
ROW_NUMBER() over (partition by cst_id order by cst_create_date desc) as flag_last
from bronze.crm_cust_info
where cst_id is not null
) t where flag_last=1;

-- ==============================================================================================
-- #Quality Check 03 : Check the consistency of values in low cardinality columns like Gender etc
--===============================================================================================

-- In dwh, we aim to store clear and meaningful vvalues than abbreviated terms

select 
distinct cst_gndr
from bronze.crm_cust_info;

-- Fix: 
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


