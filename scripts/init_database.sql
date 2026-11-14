use master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DataWarehouse')
BEGIN
    ALTER DATABASE DataWarehouse SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DataWarehouse;
END;
GO

create database DataWarehouse;

Use DataWarehouse;
Go

-- Create Medallion Architecture Schemas
Create schema bronze;
Go
Create schema silver;
Go
Create schema gold;
Go
