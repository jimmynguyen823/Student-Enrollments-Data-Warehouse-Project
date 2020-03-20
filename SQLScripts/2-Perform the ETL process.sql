--*************************************************************************--
-- Title: Perform the DWStudentEnrollments ETL process
-- Author: Jimmy Nguyen
-- Desc: This file will flush and fill the [DWStudentEnrollments] database tables. 
-- Change Log: When,Who,What
-- 2020-03-17,JimmyN,Created File
-- <The Date>,<Your Name Here>, Modified ETL code
--**************************************************************************--

--********************************************************************--
USE DWStudentEnrollments
GO

--********************************************************************--
-- Drop Foreign Keys Constraints
--********************************************************************--
Create or Alter Procedure dbo.pETLDropFKs
As
 Begin
	Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimStudents
	Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimClasses
	Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimDates
END
GO

--********************************************************************--
-- Clear all tables and reset their Identity Auto Number 
--********************************************************************--
Create or Alter Procedure dbo.pETLTruncateTables
As
 Begin
	TRUNCATE TABLE DWStudentEnrollments.dbo.DimClasses
	TRUNCATE TABLE DWStudentEnrollments.dbo.DimDates
	TRUNCATE TABLE DWStudentEnrollments.dbo.DimStudents
	TRUNCATE TABLE DWStudentEnrollments.dbo.FactEnrollments
 END
GO

--********************************************************************--
-- Fill Dimension Tables
--********************************************************************--

/****** [dbo].[DimDates] ******/
Create or Alter Procedure pETLFillDimDates
As
 Begin
-- Create variables to hold the start and end date
DECLARE @StartDate datetime = '01/01/2020';
DECLARE @EndDate datetime = '12/31/2029';

 --Test Expressions: 
 --Select Convert(nVarchar(50),@StartDate , 112)
 --Select Right('0' + Cast(Month(@StartDate) as nVarchar(3)), 2)
 --Select Cast(Year( @StartDate ) as nvarchar(4)) + Right('0' + Cast(Month( @StartDate ) as nVarchar(3)), 2) -- [MonthKey]    
 --Select Cast(Year( @StartDate ) as nvarchar(4)) + Right('0' + (DateName( quarter, @StartDate )), 2)

-- Use a while loop to add dates to the table
DECLARE @DateInProcess datetime;
SET @DateInProcess = @StartDate;

WHILE @DateInProcess <= @EndDate
 BEGIN
	 -- Add a row into the date dimension table for this date
	 INSERT INTO dbo.DimDates ( 
	   DateKey
	 , FullDateTime
	 , [Date]
	 , [DateName]
	 , MonthKey
	 , [MonthName]
	 , QuarterKey
	 , [QuarterName]
	 , YearKey
	 , [YearName]
	 )
	 Values ( 
		Convert(nVarchar(50), @DateInProcess, 112) -- [DateKey]
	  , Convert(nVarchar(50), @DateInProcess, 112) -- [FullDateTime]
	  , Convert(nVarchar(50), @DateInProcess, 112) -- [Date]
	  , DateName(weekday, @DateInProcess ) + ', ' +   Convert(nVarchar(50), @DateInProcess, 110) -- [DateName]  

	  , Cast(Year( @DateInProcess ) as nvarchar(4)) + Right('0' + Cast(Month( @DateInProcess ) as nVarchar(3)), 2) -- [MonthKey]    
	  , DateName( month, @DateInProcess ) + ' - ' + Cast( Year(@DateInProcess) as nVarchar(50) )-- [MonthName]

	  , Cast(Year( @DateInProcess ) as nvarchar(4)) + Right('0' + (DateName( quarter, @DateInProcess )), 2) -- [QuarterKey]
	  , 'Qtr' + DateName( quarter, @DateInProcess ) + ' - ' + Cast( Year(@DateInProcess) as nVarchar(50) ) -- [QuarterName] 

	  , Year( @DateInProcess ) -- [YearKey]
	  , Cast( Year(@DateInProcess ) as nVarchar(50) ) -- [Year] 
	  );
	 -- Add a day and loop again
	 Set @DateInProcess = DateAdd(d, 1, @DateInProcess);
	 End
END
GO

/****** [dbo].[DimStudents] ******/

Create or Alter Procedure dbo.pETLFillDimStudents
AS
 BEGIN
-- Implements Slowly Changing Dimension Type 1 
MERGE INTO DWStudentEnrollments.dbo.DimStudents AS t -- t is for target table
USING
(
SELECT 
		 CAST(StudentID AS int) AS StudentID
		,CAST((StudentFirstName + ' ' + StudentLastName) AS NVARCHAR(400)) AS StudentFullName
		,CAST(StudentFirstName AS NVARCHAR(200)) AS StudentFirstName
		,CAST(StudentLastName AS NVARCHAR(200)) AS StudentLastName
		,CAST(StudentEmail AS NVARCHAR(200)) AS StudentEmail
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT * From dbo.Students'
) AS s1
	) AS s-- s is for source table
	ON t.StudentID = s.StudentID  

WHEN NOT MATCHED THEN -- The StudentID in the source table is not found in the target table; Add new row
			INSERT (StudentId, StudentFullName, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent)
			VALUES(s.StudentId, s.StudentFullName, s.StudentFirstName, s.StudentLastName, s.StudentEmail, GETDATE(), null, 'Y')
  
WHEN MATCHED -- The StudentID matches between source and target table; SCD 1 - update the values below if the fields below don't match 
	AND (s.StudentEmail <> t.StudentEmail)
THEN 
	UPDATE
	SET t.StudentEmail = s.StudentEmail;

-- Implements Slowly Changing Dimension Type 2
INSERT INTO DWStudentEnrollments.dbo.DimStudents (StudentId, StudentFullName, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent)
SELECT StudentID, StudentFullName, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent
FROM
(MERGE INTO DWStudentEnrollments.dbo.DimStudents AS t -- t is for target table
USING
(
SELECT 
		CAST(StudentID AS int) AS StudentID
		,CAST((StudentFirstName + ' ' + StudentLastName) AS NVARCHAR(400)) AS StudentFullName
		,CAST(StudentFirstName AS NVARCHAR(200)) AS StudentFirstName
		,CAST(StudentLastName AS NVARCHAR(200)) AS StudentLastName
		,CAST(StudentEmail AS NVARCHAR(200)) AS StudentEmail
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT * From dbo.Students'
) AS s1
	) AS s-- s is for source table
	ON t.StudentID = s.StudentID 
	
WHEN NOT MATCHED BY SOURCE -- The StudentID in the Target table is not in the Source table then delete the row
	THEN 
		DELETE

WHEN MATCHED AND t.IsCurrent = 'Y' -- If the current row IsCurrent value is 'Y' and the fields below do not match between the source and target table then end date the row and change the IsCurrent value to 'N'
	AND (ISNULL(t.StudentFullName, '') != ISNULL(s.StudentFullName, '') 
	OR ISNULL(t.StudentFirstName, '') != ISNULL(s.StudentFirstName, '') 
	OR ISNULL(t.StudentLastName, '') != ISNULL(s.StudentLastName, ''))
THEN
	UPDATE 
	SET t.IsCurrent= 'N', t.EndDate = GETDATE()
	OUTPUT $Action Action_Taken, s.StudentID, s.StudentFullName, s.StudentFirstName, s.StudentLastName, s.StudentEmail, GETDATE() AS StartDate, NULL as EndDate, 'Y' as IsCurrent
) AS MERGE_OUT
WHERE MERGE_OUT.Action_Taken = 'UPDATE';
END
GO
		

/****** [dbo].[DimClasses] ******/
Create or Alter Procedure dbo.pETLFillDimClasses
As
 Begin
-- Implements Slowly Changing Dimension Type 1 
MERGE INTO DWStudentEnrollments.dbo.DimClasses AS t -- t is for target table
USING
(
SELECT 
	 CAST(ClassID AS int) AS ClassID
	,CAST(ClassName AS nvarchar(200)) AS ClassName
	,CAST(ClassStartDate AS date) AS ClassStartDate
	,CAST(ClassEndDate AS date) AS ClassEndDate
	,CAST(ClassPriceCurrent AS decimal(18,2)) AS ClassPriceCurrent
	,CAST(classenrollmentmax as int) AS ClassEnrollmentMax
	,CAST(classroomid AS int) AS ClassroomID
	,CAST(classroomname AS nvarchar(200)) AS ClassroomName
	,CAST(classroomsizemax AS int) AS ClassroomSizeMax
	,CAST(ClassDepartmentID AS int) AS ClassDepartmentID
	,CAST(ClassDepartmentName AS nvarchar(200)) AS ClassDepartmentName
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT  
		c.classid
		,c.classname
		,d.departmentid AS classdepartmentid
		,d.departmentname AS classdepartmentname
		,c.classstartdate
		,c.classenddate
		,c.currentclassprice AS classpricecurrent
		,c.maxclassenrollment AS classenrollmentmax
		,cl.classroomid
		,cl.classroomname
		,cl.maxclasssize AS classroomsizemax
	From dbo.Classes c
	INNER JOIN dbo.Departments d
		ON d.departmentid = c.departmentid
	INNER JOIN dbo.ClassRooms cl
		ON cl.classroomid = c.classroomid'
) AS s1
	) AS s-- s is for source table
	ON t.ClassID = s.ClassID

WHEN NOT MATCHED THEN -- The ClassID in the source table is not found in the target table; Add new row
			INSERT (ClassID, ClassName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, ClassDepartmentID, ClassDepartmentName, StartDate, EndDate, IsCurrent)
			VALUES(s.ClassID, s.ClassName, s.ClassStartDate, s.ClassEndDate, s.ClassPriceCurrent, s.ClassEnrollmentMax, s.ClassroomID, s.ClassroomName, s.ClassroomSizeMax,  s.ClassDepartmentID, s.ClassDepartmentName, GETDATE(), null, 'Y')
  
WHEN MATCHED -- The ClassID matches between source and target table; SCD 1 - update the values below if the fields below don't match 
	AND (s.ClassStartDate <> t.ClassStartDate
	OR s.ClassEndDate <> t.ClassEndDate
	OR s.ClassPriceCurrent <> t.ClassPriceCurrent
	OR s.ClassEnrollmentMax <> t.ClassEnrollmentMax
	OR s.ClassroomSizeMax <> t.ClassroomSizeMax)
THEN 
	UPDATE
	SET t.ClassStartDate = s.ClassStartDate
	,t.ClassEndDate = s.ClassEndDate
	,t.ClassPriceCurrent = s.ClassPriceCurrent
	,t.ClassEnrollmentMax = s.ClassEnrollmentMax
	,t.ClassroomSizeMax = s.ClassroomSizeMax;

-- Implements Slowly Changing Dimension Type 2
INSERT INTO DWStudentEnrollments.dbo.DimClasses (ClassID, ClassName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, ClassDepartmentID, ClassDepartmentName, StartDate, EndDate, IsCurrent)
SELECT ClassID, ClassName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, ClassDepartmentID, ClassDepartmentName, StartDate, EndDate, IsCurrent
FROM
(MERGE INTO DWStudentEnrollments.dbo.DimClasses AS t -- t is for target table
USING
(
SELECT 
	 CAST(ClassID AS int) AS ClassID
	,CAST(ClassName AS nvarchar(200)) AS ClassName
	,CAST(ClassStartDate AS date) AS ClassStartDate
	,CAST(ClassEndDate AS date) AS ClassEndDate
	,CAST(ClassPriceCurrent AS decimal(18,2)) AS ClassPriceCurrent
	,CAST(classenrollmentmax as int) AS ClassEnrollmentMax
	,CAST(classroomid AS int) AS ClassroomID
	,CAST(classroomname AS nvarchar(200)) AS ClassroomName
	,CAST(classroomsizemax AS int) AS ClassroomSizeMax
	,CAST(ClassDepartmentID AS int) AS ClassDepartmentID
	,CAST(ClassDepartmentName AS nvarchar(200)) AS ClassDepartmentName
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT  
		c.classid
		,c.classname
		,d.departmentid AS classdepartmentid
		,d.departmentname AS classdepartmentname
		,c.classstartdate
		,c.classenddate
		,c.currentclassprice AS classpricecurrent
		,c.maxclassenrollment AS classenrollmentmax
		,cl.classroomid
		,cl.classroomname
		,cl.maxclasssize AS classroomsizemax
	From dbo.Classes c
	INNER JOIN dbo.Departments d
		ON d.departmentid = c.departmentid
	INNER JOIN dbo.ClassRooms cl
		ON cl.classroomid = c.classroomid'
) AS s1
	) AS s -- s is for source table
	ON t.ClassID = s.ClassID
	
WHEN NOT MATCHED BY SOURCE -- The ClassID in the Target table is not in the Source table then delete the row
	THEN 
		DELETE

WHEN MATCHED AND t.IsCurrent = 'Y' -- If the current row value is 'Y' and the fields below do not match between the source and target table then end date the row and change the IsCurrent value to 'N'
	AND (ISNULL(t.ClassName, '') != ISNULL(s.ClassName, '') 
	OR ISNULL(t.ClassDepartmentName, '') != ISNULL(s.ClassDepartmentName, '')
	OR ISNULL(t.ClassroomName, '') != ISNULL(s.ClassroomName, ''))
THEN
	UPDATE 
	SET t.IsCurrent= 'N', t.EndDate = GETDATE()
	OUTPUT $Action Action_Taken, s.ClassID, s.ClassName, s.ClassStartDate, s.ClassEndDate, s.ClassPriceCurrent, s.ClassEnrollmentMax, s.ClassroomID, s.ClassroomName, s.ClassroomSizeMax, s.ClassDepartmentID, s.ClassDepartmentName, GETDATE() AS StartDate, NULL as EndDate, 'Y' as IsCurrent
) AS MERGE_OUT
WHERE MERGE_OUT.Action_Taken = 'UPDATE';
END
GO

--********************************************************************--
-- Fill Fact Tables 
--********************************************************************--

/****** [dbo].[FactEnrollments] ******/

--- Insert only new records into fact table
--- Fact table Grain: Enrollments by day, student, and class
Create or Alter Procedure dbo.pETLFillFactEnrollments
As
 Begin
MERGE INTO DWStudentEnrollments.dbo.FactEnrollments AS t -- t is for target table
USING
(
SELECT 
	 CAST(s1.enrollmentid AS int) AS EnrollmentID
	,d.DateKey AS EnrollmentDateKey
	,st.StudentKey
	,c.ClassKey
	,CAST(s1.actualenrollmentprice AS decimal(18,2)) AS ActualEnrollmentPrice
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT  
		enrollmentid
		,CAST(enrollmentdate AS date) AS enrollmentdate
		,studentid
		,classid
		,actualenrollmentprice
	From dbo.enrollments'
) AS s1
INNER JOIN DWStudentEnrollments.dbo.DimDates d
	ON d.[datekey] = isNull(Convert(nvarchar(50), s1.enrollmentdate, 112), '-1')
INNER JOIN DWStudentEnrollments.dbo.DimStudents st
	ON st.studentid = s1.studentid
	AND st.IsCurrent = 'Y'
INNER JOIN DWStudentEnrollments.dbo.DimClasses c
	ON c.classid = s1.classid
	AND c.IsCurrent = 'Y'
) AS s -- s is for source table
	ON t.EnrollmentID = s.EnrollmentID

WHEN NOT MATCHED THEN -- The EnrollmentID in the source table is not found in the target table; Add new row
		INSERT (EnrollmentID, EnrollmentDateKey, StudentKey, ClassKey, ActualEnrollmentPrice)
		VALUES(s.EnrollmentID, s.EnrollmentDateKey, s.StudentKey, s.ClassKey, s.ActualEnrollmentPrice)
;
END
GO

/*
INSERT INTO DWStudentEnrollments.dbo.FactEnrollments (EnrollmentID, EnrollmentDateKey, StudentKey, ClassKey, ActualEnrollmentPrice)
SELECT 
	 CAST(s.enrollmentid AS int) AS EnrollmentID
	,d.DateKey AS EnrollmentDateKey
	,st.StudentKey
	,c.ClassKey
	,CAST(s.actualenrollmentprice AS decimal(18,2)) AS ActualEnrollmentPrice
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT  
		enrollmentid
		,CAST(enrollmentdate AS date) AS enrollmentdate
		,studentid
		,classid
		,actualenrollmentprice
	From dbo.enrollments'
) AS s
INNER JOIN DWStudentEnrollments.dbo.DimDates d
	ON d.[date] = s.enrollmentdate
INNER JOIN DWStudentEnrollments.dbo.DimStudents st
	ON st.studentid = s.studentid
	AND st.IsCurrent = 'Y'
INNER JOIN DWStudentEnrollments.dbo.DimClasses c
	ON c.classid = s.classid
	AND c.IsCurrent = 'Y'
GO
*/
--********************************************************************--
-- Replace Foreign Keys Constraints
--********************************************************************--
CREATE OR ALTER PROCEDURE dbo.pETLReplaceFKs
AS
	BEGIN
		ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimStudents
		FOREIGN KEY  (StudentKey) REFERENCES dbo.DimStudents (StudentKey)

		ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimClasses
		FOREIGN KEY  (ClassKey) REFERENCES dbo.DimClasses (ClassKey)

		ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimDates
		FOREIGN KEY  (EnrollmentDateKey) REFERENCES dbo.DimDates (DateKey)
	END
GO

--********************************************************************--
-- Review the results of this script
--********************************************************************--
Go
Select 'Database Created'
Select Name, xType, crDate from SysObjects 
Where xType in ('u', 'PK', 'F')
Order By xType Desc, Name

Exec pETLDropFKs;
Exec pETLTruncateTables;
Exec pETLFillDimClasses;
Exec pETLFillDimDates;
Exec pETLFillDimStudents;
Exec pETLFillFactEnrollments;
Exec pETLReplaceFKs;
Select * From DimDates;
Select * From DimClasses;
Select * From DimStudents
Select * From FactEnrollments;








