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
	 StudentKey int IDENTITY NOT NULL
	,StudentID int NOT NULL
	,StudentFirstName nvarchar(100) NOT NULL
	,StudentLastName nvarchar(100) NOT NULL
	,StudentEmail nvarchar(100) NOT NULL
	,StartDate datetime NOT NULL
	,EndDate datetime
	,IsCurrent char(1) NOT NULL DEFAULT('Y')
	CONSTRAINT PK_DimStudents PRIMARY KEY(StudentKey)
	)
GO

/****** [dbo].[DimClasses] ******/
CREATE TABLE DWStudentEnrollments.dbo.DimClasses(
	 ClassKey int IDENTITY NOT NULL
	,ClassID int NOT NULL
	,ClassName nvarchar(100) NOT NULL
	,ClassDepartmentID int NOT NULL
	,ClassDepartmentName nvarchar(100) NOT NULL
	,ClassStartDate datetime NOT NULL
	,ClassEndDate datetime 
	,ClassPriceCurrent decimal(18,2) NOT NULL
	,ClassEnrollmentMax int NOT NULL
	,ClassroomID int NOT NULL
	,ClassroomName nvarchar(100) NOT NULL
	,ClassroomSizeMax int NOT NULL
	,StartDate datetime NOT NULL
	,EndDate datetime
	,IsCurrent char(1) NOT NULL DEFAULT('Y')
	CONSTRAINT PK_DimClasses PRIMARY KEY(ClassKey)
	)
GO

/****** [dbo].[DimDates] ******/
CREATE TABLE DWStudentEnrollments.dbo.DimDates (
	 [DateKey] int NOT NULL 
	,[Date] date NOT NULL
	,[DateName] nVarchar(100)
	,[DateDayKey] int NOT NULL
	,[DateDayName] nVarchar(50) NOT NULL
	,[DateMonthKey] int NOT NULL
	,[DateMonthName] nVarchar(50) NOT NULL
	,[DateQuarterKey] int NOT NULL
	,[DateQuarterName] nVarchar(50) NOT NULL
	,[DateQuarter] nVarchar(50) NOT NULL
	,[DateYearMonthKey] int NOT NULL
	,[DateYearMonthName] nVarchar(50) NOT NULL
	,[DateYearKey] int NOT NULL
	,[DateYearName] nVarchar(50) NOT NULL
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

--********************************************************************--
-- Review the results of this script
--********************************************************************--
Go
Select 'Database Created'
Select Name, xType, crDate from SysObjects 
Where xType in ('u', 'PK', 'F')
Order By xType Desc, Name


