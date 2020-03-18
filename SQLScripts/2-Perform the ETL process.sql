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
Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimStudents
Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimClasses
Alter Table DWStudentEnrollments.dbo.FactEnrollments Drop Constraint IF EXISTS FK_FactEnrollments_DimDates
GO

--********************************************************************--
-- Clear all tables and reset their Identity Auto Number 
--********************************************************************--
TRUNCATE TABLE DWStudentEnrollments.dbo.DimClasses
TRUNCATE TABLE DWStudentEnrollments.dbo.DimDates
TRUNCATE TABLE DWStudentEnrollments.dbo.DimStudents
TRUNCATE TABLE DWStudentEnrollments.dbo.FactEnrollments
GO

--********************************************************************--
-- Fill Dimension Tables
--********************************************************************--

/****** [dbo].[DimStudents] ******/

-- Implements Slowly Changing Dimension Type 1 
MERGE INTO DWStudentEnrollments.dbo.DimStudents AS t -- t is for target table
USING
(
SELECT 
		 CAST(StudentID AS int) AS StudentID
		,CAST(StudentFirstName AS NVARCHAR(100)) AS StudentFirstName
		,CAST(StudentLastName AS NVARCHAR(100)) AS StudentLastName
		,CAST(StudentEmail AS NVARCHAR(100)) AS StudentEmail
FROM OPENROWSET('SQLNCLI11'
,'Server=continuumsql.westus2.cloudapp.azure.com;uid=BICert;pwd=BICert;database=StudentEnrollments;' 
, 'SELECT * From dbo.Students'
) AS s1
	) AS s-- s is for source table
	ON t.StudentID = s.StudentID  

WHEN NOT MATCHED THEN -- The StudentID in the source table is not found in the target table; Add new row
			INSERT (StudentId, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent)
			VALUES(s.StudentId, s.StudentFirstName, s.StudentLastName, s.StudentEmail, GETDATE(), null, 'Y')
  
WHEN MATCHED -- The StudentID matches between source and target table; SCD 1 - update the values below if the fields below don't match 
	AND (s.StudentEmail <> t.StudentEmail)
THEN 
	UPDATE
	SET t.StudentEmail = s.StudentEmail;
GO

-- Implements Slowly Changing Dimension Type 2
INSERT INTO DWStudentEnrollments.dbo.DimStudents (StudentId, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent)
SELECT StudentId, StudentFirstName, StudentLastName, StudentEmail, StartDate, EndDate, IsCurrent
FROM
(MERGE INTO DWStudentEnrollments.dbo.DimStudents AS t -- t is for target table
USING
(
SELECT 
		 CAST(StudentID AS int) AS StudentID
		,CAST(StudentFirstName AS NVARCHAR(100)) AS StudentFirstName
		,CAST(StudentLastName AS NVARCHAR(100)) AS StudentLastName
		,CAST(StudentEmail AS NVARCHAR(100)) AS StudentEmail
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
	AND (ISNULL(t.StudentFirstName, '') != ISNULL(s.StudentFirstName, '') 
	OR ISNULL(t.StudentLastName, '') != ISNULL(s.StudentLastName, ''))
THEN
	UPDATE 
	SET t.IsCurrent= 'N', t.EndDate = GETDATE()
	OUTPUT $Action Action_Taken, s.StudentID, s.StudentFirstName, s.StudentLastName, s.StudentEmail, GETDATE() AS StartDate, NULL as EndDate, 'Y' as IsCurrent
) AS MERGE_OUT
WHERE MERGE_OUT.Action_Taken = 'UPDATE';
GO
		


/****** [dbo].[DimClasses] ******/

-- Implements Slowly Changing Dimension Type 1 
MERGE INTO DWStudentEnrollments.dbo.DimClasses AS t -- t is for target table
USING
(
SELECT 
	 CAST(ClassID AS int) AS ClassID
	,CAST(ClassName AS nvarchar(100)) AS ClassName
	,CAST(ClassDepartmentID AS int) AS ClassDepartmentID
	,CAST(ClassDepartmentName AS nvarchar(100)) AS ClassDepartmentName
	,CAST(ClassStartDate AS datetime) AS ClassStartDate
	,CAST(ClassEndDate AS datetime) AS ClassEndDate
	,CAST(ClassPriceCurrent AS decimal(18,2)) AS ClassPriceCurrent
	,CAST(classenrollmentmax as nvarchar(100)) AS ClassEnrollmentMax
	,CAST(classroomid AS int) AS ClassRoomID
	,CAST(classroomname AS nvarchar(100)) AS ClassroomName
	,CAST(classroomsizemax AS int) AS ClassroomSizeMax
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
			INSERT (ClassID, ClassName, ClassDepartmentID, ClassDepartmentName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, StartDate, EndDate, IsCurrent)
			VALUES(s.ClassID, s.ClassName, s.ClassDepartmentID, s.ClassDepartmentName, s.ClassStartDate, s.ClassEndDate, s.ClassPriceCurrent, s.ClassEnrollmentMax, s.ClassroomID, s.ClassroomName, s.ClassroomSizeMax, GETDATE(), null, 'Y')
  
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
GO

-- Implements Slowly Changing Dimension Type 2
INSERT INTO DWStudentEnrollments.dbo.DimClasses (ClassID, ClassName, ClassDepartmentID, ClassDepartmentName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, StartDate, EndDate, IsCurrent)
SELECT ClassID, ClassName, ClassDepartmentID, ClassDepartmentName, ClassStartDate, ClassEndDate, ClassPriceCurrent, ClassEnrollmentMax, ClassroomID, ClassroomName, ClassroomSizeMax, StartDate, EndDate, IsCurrent
FROM
(MERGE INTO DWStudentEnrollments.dbo.DimClasses AS t -- t is for target table
USING
(
SELECT 
	 CAST(ClassID AS int) AS ClassID
	,CAST(ClassName AS nvarchar(100)) AS ClassName
	,CAST(ClassDepartmentID AS int) AS ClassDepartmentID
	,CAST(ClassDepartmentName AS nvarchar(100)) AS ClassDepartmentName
	,CAST(ClassStartDate AS datetime) AS ClassStartDate
	,CAST(ClassEndDate AS datetime) AS ClassEndDate
	,CAST(ClassPriceCurrent AS decimal(18,2)) AS ClassPriceCurrent
	,CAST(classenrollmentmax as nvarchar(100)) AS ClassEnrollmentMax
	,CAST(classroomid AS int) AS ClassRoomID
	,CAST(classroomname AS nvarchar(100)) AS ClassroomName
	,CAST(classroomsizemax AS int) AS ClassroomSizeMax
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
	OUTPUT $Action Action_Taken, s.ClassID, s.ClassName, s.ClassDepartmentID, s.ClassDepartmentName, s.ClassStartDate, s.ClassEndDate, s.ClassPriceCurrent, s.ClassEnrollmentMax, s.ClassroomID, s.ClassroomName, s.ClassroomSizeMax, GETDATE() AS StartDate, NULL as EndDate, 'Y' as IsCurrent
) AS MERGE_OUT
WHERE MERGE_OUT.Action_Taken = 'UPDATE';
GO


/****** [dbo].[DimDates] ******/

-- Create variables to hold the start and end date
DECLARE @StartDate date = '01/01/2020'
DECLARE @EndDate date = '01/01/2050' 

-- Use a while loop to add dates to the table
DECLARE @DateInProcess date
SET @DateInProcess = @StartDate

WHILE @DateInProcess <= @EndDate
 BEGIN
 -- Add a row into the date dimension table for this date
 INSERT INTO DWStudentEnrollments.dbo.DimDates
 ( [DateKey], [Date], [DateName], [DateDayKey], [DateDayName], [DateMonthKey], [DateMonthName], [DateQuarterKey], [DateQuarterName], [DateQuarter], [DateYearMonthKey], [DateYearMonthName], [DateYearKey], [DateYearName] )
 VALUES (
    Cast(Convert(nvarchar(50), @DateInProcess , 112) as int) -- [DateKey]
  , @DateInProcess --[Date]
  , CAST(DateName( month, @DateInProcess ) AS NVARCHAR(50)) + ' ' + CAST(DAY( @DateInProcess) AS NVARCHAR(50)) +', ' + Cast(Year(@DateInProcess) as nVarchar(50)) -- datename
  , DAY( @DateInProcess) --DATE_DAY_KEY
  , DateName(weekday, @DateInProcess ) -- [DateDayNumber) 
  , Month( @DateInProcess ) -- [Month]   
  , DateName( month, @DateInProcess ) -- [MonthName]
  , DateName( quarter, @DateInProcess ) -- DATE_QUARTER_KEY
  , 'Q' + DateName( quarter, @DateInProcess ) + ' - ' + Cast( Year(@DateInProcess) as nVarchar(50) )  -- DATE_QUARTER_NAME
  , 'Q' + DateName( quarter, @DateInProcess ) -- DATE_QUARTER
  , CASE 
		WHEN LEN(MONTH(@DateInProcess )) = 1 THEN CONCAT(Year(@DateInProcess), CONCAT('0', MONTH(@DateInProcess)))
		WHEN LEN(MONTH(@DateInProcess )) = 2 THEN CONCAT(Year(@DateInProcess), Month(@DateInProcess))
	end -- DATE_YEAR_MONTH_KEY
  , DateName( month, @DateInProcess ) + ' ' + Cast(Year(@DateInProcess ) as nVarchar(50)) -- DATE_YEAR_MONTH_NAME
  , Year( @DateInProcess) -- DATE_YEAR_KEY
  , Cast(Year(@DateInProcess) as nVarchar(50)) -- YEAR
  )  
 -- Add a day and loop again
 SET @DateInProcess = DateAdd(d, 1, @DateInProcess)
 END

 
-- 2e) Add additional lookup values to DimDates
INSERT INTO DWStudentEnrollments.dbo.DimDates
  ([DateKey],
   [Date], 
   [DateName], 
   [DateDayKey], 
   [DateDayName], 
   [DateMonthKey], 
   [DateMonthName], 
   [DateQuarterKey], 
   [DateQuarterName], 
   [DateQuarter], 
   [DateYearMonthKey], 
   [DateYearMonthName], 
   [DateYearKey], 
   [DateYearName] )
SELECT
    [DateKey] = -1
  , [Date] = '1/1/1900'
  , [DateName] = Cast('Unknown Date' as nVarchar(100) )
  , [DateDayKey] = -1
  , [DateDayName] = Cast('Unknown Day' as nVarchar(50) )
  , [DateMonthKey] = -1
  , [DateMonthName] = Cast('Unknown Month' as nVarchar(50) )
  , [DateQuarterKey] =  -1
  , [DateQuarterName] = Cast('Unknown Quarter' as nVarchar(50) )
  , [DateQuarter] = Cast('Unknown Quarter' as nVarchar(50) )
  , [DateYearMonthKey] = -1
  , [DateYearMonthName] = Cast('Unknown Year Month' as nVarchar(50) )
  , [DateYearKey] = -1
  , [DateYearName] = Cast('Unknown Year' as nVarchar(50) )
  UNION
SELECT
    [DateKey] = -2
  , [Date] = '1/1/1900'
  , [DateName] = Cast('Corrupt Date' as nVarchar(50) )
  , [DateDayKey] = -2
  , [DateDayName] = Cast('Corrupt Day' as nVarchar(50) )
  , [DateMonthKey] = -2
  , [DateMonthName] = Cast('Corrupt Month' as nVarchar(50) )
  , [DateQuarterKey] =  -2
  , [DateQuarterName] = Cast('Corrupt Quarter' as nVarchar(50) )
  , [DateQuarter] = Cast('Corrupt Quarter' as nVarchar(50) )
  , [DateYearMonthKey] = -2
  , [DateYearMonthName] = Cast('Unknown Year Month' as nVarchar(50) )
  , [DateYearKey] = -2
  , [DateYearName] = Cast('Corrupt Year' as nVarchar(50) )

GO

--********************************************************************--
-- Fill Fact Tables 
--********************************************************************--

/****** [dbo].[FactEnrollments] ******/

--- Insert only new records into fact table
--- Fact table Grain: Enrollments by day, student, and class
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
ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimStudents
FOREIGN KEY  (StudentKey) REFERENCES dbo.DimStudents (StudentKey)

ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimClasses
FOREIGN KEY  (ClassKey) REFERENCES dbo.DimClasses (ClassKey)

ALTER TABLE DWStudentEnrollments.dbo.FactEnrollments WITH CHECK ADD CONSTRAINT FK_FactEnrollments_DimDates
FOREIGN KEY  (EnrollmentDateKey) REFERENCES dbo.DimDates (DateKey)
GO

--********************************************************************--
-- Review the results of this script
--********************************************************************--
Go
Select 'Database Created'
Select Name, xType, crDate from SysObjects 
Where xType in ('u', 'PK', 'F')
Order By xType Desc, Name









