--*************************** Instructors Version ******************************--
-- Title: DWStudentEnrollments Tabular Models Views
-- Author: Jimmy Nguyen
-- Desc: This file will create or alter views in the [DWStudentEnrollments] database for its Tabular Models. 
-- Change Log: When,Who,What
-- 2020-03-20,JimmyN,Created File
-- <The Date>,<Your Name Here>, Modified ETL code
--**************************************************************************--
Set NoCount On;
Go
USE DWStudentEnrollments;
Go

-- Dimension Tables --
Create or Alter View vTabularDimStudents
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

Create or Alter View vTabularDimClasses
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

Create or Alter View vTabularDimDates 
AS
SELECT 
	Convert(date, Cast([DateKey] as char(8)), 110)   AS DateKey
	,FullDateTime
	,[Date]
	,[DateName]
	,MonthKey
	,[MonthName]
	,QuarterKey
	,QuarterName
	,YearKey
	,YearName
FROM DWStudentEnrollments.dbo.DimDates
GO

-- Fact Table --
Create or Alter View vTabularFactEnrollments 
AS
SELECT 
	EnrollmentID
	,Convert(date, Cast([EnrollmentDateKey] as char(8)), 110) AS EnrollmentDateKey
	,StudentKey
	,ClassKey
	,ActualEnrollmentPrice
FROM DWStudentEnrollments.dbo.FactEnrollments
GO


Select * from vTabularDimStudents
Select * from vTabularDimClasses
Select * from vTabularDimDates
Select * from vTabularFactEnrollments