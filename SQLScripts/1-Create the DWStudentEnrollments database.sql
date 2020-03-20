--*************************************************************************--
-- Title: Create the DWStudentEnrollments database
-- Author: Jimmy Nguyen
-- Desc: This file will drop and create the [DWStudentEnrollments] database, with all its objects. 
-- Change Log: When,Who,What
-- 2020-13-03,Jimmy Nguyen, Created File
--**************************************************************************--

USE [master]
If Exists (Select Name from SysDatabases Where Name = 'DWStudentEnrollments')
  Begin
   ALTER DATABASE DWStudentEnrollments SET SINGLE_USER WITH ROLLBACK IMMEDIATE
   DROP DATABASE DWStudentEnrollments
  End
GO
Create Database DWStudentEnrollments;
GO
USE DWStudentEnrollments;
GO

--********************************************************************--
-- Create the Dimension Tables
--********************************************************************--

/****** [dbo].[DimStudents] ******/
CREATE TABLE DWStudentEnrollments.dbo.DimStudents (
	 StudentKey int IDENTITY NOT NULL --Identity Constraint pkDimStudents Primary Key
	,StudentID int NOT NULL
	,StudentFullName nvarchar(400) NOT NULL
	,StudentFirstName nvarchar(200) NOT NULL
	,StudentLastName nvarchar(200) NOT NULL
	,StudentEmail nvarchar(200) NOT NULL
	,StartDate datetime NOT NULL
	,EndDate datetime
	,IsCurrent char(1) NOT NULL DEFAULT('Y')
	CONSTRAINT PK_DimStudents PRIMARY KEY(StudentKey)
	)
GO

/****** [dbo].[DimClasses] ******/
CREATE TABLE DWStudentEnrollments.dbo.DimClasses(
	 ClassKey int IDENTITY NOT NULL --Identity Constraint pkDimClasses Primary Key
	,ClassID int NOT NULL
	,ClassName nvarchar(200) NOT NULL
	,ClassStartDate date NOT NULL
	,ClassEndDate date NOT NULL
	,ClassPriceCurrent decimal(18,2) NOT NULL
	,ClassEnrollmentMax int NOT NULL
	,ClassroomID int NOT NULL
	,ClassroomName nvarchar(200) NOT NULL
	,ClassroomSizeMax int NOT NULL
	,ClassDepartmentID int NOT NULL
	,ClassDepartmentName nvarchar(200) NOT NULL
	,StartDate datetime NOT NULL
	,EndDate datetime
	,IsCurrent char(1) NOT NULL DEFAULT('Y')
	CONSTRAINT PK_DimClasses PRIMARY KEY(ClassKey)
	)
GO

/****** [dbo].[DimDates] ******/
CREATE TABLE DWStudentEnrollments.dbo.DimDates (
	 [DateKey] int NOT NULL --Constraint pkDimDates PRIMARY KEY 
	,[Datetime] datetime NOT NULL
	,[Date] date NOT NULL
	,[DateName] nVarchar(100) NOT NULL
	,[DateDayKey] int NOT NULL
	,[DateDayName] nVarchar(100) NOT NULL
	,[DateMonthKey] int NOT NULL
	,[DateMonthName] nVarchar(100) NOT NULL
	,[DateQuarterKey] int NOT NULL
	,[DateQuarterName] nVarchar(100) NOT NULL
	,[DateQuarter] nVarchar(100) NOT NULL
	,[DateYearMonthKey] int NOT NULL
	,[DateYearMonthName] nVarchar(100) NOT NULL
	,[DateYearKey] int NOT NULL
	,[DateYearName] nVarchar(100) NOT NULL
	,[InsertDate] [datetime] NOT NULL DEFAULT GETDATE()
	CONSTRAINT PK_DimDates PRIMARY KEY(DateKey)
)
GO


--********************************************************************--
-- Create the Fact Tables
--********************************************************************--

/****** [dbo].[FactEnrollments] ******/
CREATE TABLE DWStudentEnrollments.dbo.FactEnrollments (
	 EnrollmentID int NOT NULL
	,EnrollmentDateKey int NOT NULL
	,StudentKey int NOT NULL
	,ClassKey int NOT NULL
	,ActualEnrollmentPrice decimal(18,2) NOT NULL
	,InsertDate [datetime] NOT NULL DEFAULT GETDATE()
 CONSTRAINT [PK_FactEnrollments] PRIMARY KEY CLUSTERED 
	( [EnrollmentID] ASC,[EnrollmentDateKey] ASC, [StudentKey] ASC, [ClassKey] ASC )
	-- Constraint pkFactEnrollments Primary Key(EnrollmentID, EnrollmentDateKey, StudentKey, ClassKey )
)
GO

--********************************************************************--
-- Add the Foreign Key Constraints
--********************************************************************--

ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimStudents
FOREIGN KEY  (StudentKey) REFERENCES dbo.DimStudents (StudentKey)

ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimClasses
FOREIGN KEY  (ClassKey) REFERENCES dbo.DimClasses (ClassKey)

ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimDates
FOREIGN KEY  (EnrollmentDateKey) REFERENCES dbo.DimDates (DateKey)

GO

--********************************************************************--
-- Create a Reporting View of all tables
--********************************************************************--
CREATE VIEW dbo.vStudentEnrollmentByClassDay
AS 
SELECT 
	 f.EnrollmentID
	,d.[date] AS EnrollmentDate
	,SUM(f.actualenrollmentprice) AS TotalEnrollmentPrice
	,s.StudentFullName
	,s.StudentFirstName
	,s.StudentLastName
	,s.StudentEmail
	,c.ClassName
	,c.ClassStartDate
	,c.ClassEndDate
	,c.ClassPriceCurrent
	,c.ClassEnrollmentMax
	,c.ClassroomName
	,c.ClassroomSizeMax
	,c.ClassDepartmentName
FROM dbo.factenrollments f
INNER JOIN dbo.dimdates d
	ON f.EnrollmentDateKey = d.DateKey
INNER JOIN dbo.dimstudents s
	ON s.studentkey = f.StudentKey
	AND s.iscurrent = 'Y'
INNER JOIN dbo.dimclasses c
	ON c.classkey = f.ClassKey
	AND s.iscurrent = 'Y'
GROUP BY 
	f.EnrollmentID
	,d.[date]
	,s.StudentFullName
	,s.StudentFirstName
	,s.StudentLastName
	,s.StudentEmail
	,c.ClassName
	,c.ClassDepartmentName
	,c.ClassStartDate
	,c.ClassEndDate
	,c.ClassPriceCurrent
	,c.ClassEnrollmentMax
	,c.ClassroomName
	,c.ClassroomSizeMax
GO

-- Base Views
CREATE OR ALTER VIEW vDimStudents
AS
SELECT 
	 StudentKey
	,StudentID
	,StudentFullName
	,StudentFirstName
	,StudentLastName
	,StudentEmail
FROM DWStudentEnrollments.dbo.DimStudents
WHERE IsCurrent = 'Y'
GO

CREATE OR ALTER VIEW vDimClasses
AS
SELECT 
	ClassKey
	,ClassID
	,ClassName
	,ClassStartDate
	,ClassEndDate
	,ClassPriceCurrent
	,ClassEnrollmentMax
	,ClassroomID
	,ClassroomName
	,ClassroomSizeMax
	,ClassDepartmentID
	,ClassDepartmentName
FROM DWStudentEnrollments.dbo.DimClasses
WHERE IsCurrent = 'Y'
GO

CREATE OR ALTER VIEW vDimDates
AS
SELECT 
	*
FROM DWStudentEnrollments.dbo.DimDates
GO

CREATE OR ALTER VIEW vFactEnrollments
AS
SELECT 
	EnrollmentID
	,EnrollmentDateKey
	,StudentKey
	,ClassKey
	,ActualEnrollmentPrice
FROM DWStudentEnrollments.dbo.FactEnrollments
GO

-- Metadata View
USE DWStudentEnrollments;
Create or Alter View vStudentEnrollmentsMetaData
As
Select Top 100 Percent
 [Source Table] = DB_Name() + '.' + SCHEMA_NAME(tab.[schema_id]) + '.' + object_name(tab.[object_id])
,[Source Column] =  col.[Name]
,[Source Type] = Case 
				When t.[Name] in ('char', 'nchar', 'varchar', 'nvarchar' ) 
				  Then t.[Name] + ' (' +  format(col.max_length, '####') + ')'                
				When t.[Name]  in ('decimal', 'money') 
				  Then t.[Name] + ' (' +  format(col.[precision], '#') + ',' + format(col.scale, '#') + ')'
				 Else t.[Name] 
                End 
,[Source Nullability] = iif(col.is_nullable = 1, 'Null', 'Not Null') 
From Sys.Types as t 
Join Sys.Columns as col 
 On t.system_type_id = col.system_type_id 
Join Sys.Tables tab
  On tab.[object_id] = col.[object_id]
And t.name <> 'sysname'
Order By [Source Table], col.column_id; 
go

Select * From vStudentEnrollmentsMetaData;
GO
SELECT * FROM [dbo].[vDimDates]


--********************************************************************--
-- Review the results of this script
--********************************************************************--
Go
Select 'Database Created'
Select Name, xType, crDate from SysObjects 
Where xType in ('u', 'PK', 'F')
Order By xType Desc, Name
