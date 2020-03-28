--*************************** Instructors Version ******************************--
-- Title:   DWStudentEnrollments ETL Views for DocumentDB Model
-- Author: Jimmy Nguyen
-- Desc: This file creates [DWStudentEnrollments] ETL Views for DocumentDB Model. 
-- Change Log: When,Who,What
-- 2020-03-26,JimmyN,Created File
-- 2020-03-04,JimmyN, Modified ETL code
--**************************************************************************--
USE DWStudentEnrollments;
Go

Select 
 (dc.ClassEnrollmentMax) AS MaxCourseEnrollment
,[Diff From Max] = (dc.ClassEnrollmentMax - Count(fe.Studentkey) Over(Partition By fe.ClassKey))
From FactEnrollments as fe Join DimClasses as dc
  On fe.ClassKey = dc.ClassKey
Where fe.ClassKey = 1
Go

Create or Alter Function dbo.fKPIMaxLessCurrentEnrollments(@ClassKey int)
Returns int
AS
Begin
  Return(
   Select Distinct [Number of Students] = Case
   When (dc.ClassEnrollmentMax * .75) < (dc.ClassEnrollmentMax - Count(fe.Studentkey) Over(Partition By fe.ClassKey))
    Then 1
   When (dc.ClassEnrollmentMax * .5) < (dc.ClassEnrollmentMax - Count(fe.Studentkey) Over(Partition By fe.ClassKey))
    Then 0
   When (dc.ClassEnrollmentMax * .25) < (dc.ClassEnrollmentMax - Count(fe.Studentkey) Over(Partition By fe.ClassKey))
    Then -1
  End
  From FactEnrollments as fe Join DimClasses as dc
    On fe.ClassKey = dc.ClassKey
  Where fe.ClassKey = @ClassKey
  )
End;
Go

Select dbo.fKPIMaxLessCurrentEnrollments(1);
Select dbo.fKPIMaxLessCurrentEnrollments(2);
Go

Create or Alter View vETLDocumentDB
AS
  Select 
   [EnrollmentID] = EnrollmentID 
	,[FullDateTime] = Cast(FullDateTime as Date)
	,[Date] = Replace([DateName], ',' , ' ') -- Don't forget the comma issue!
	,[Month] = [MonthName]
	,[Quarter] = QuarterName
	,[Year] = YearName
	,[ClassID] = ClassID
  ,[Course] = ClassName
  ,[DepartmentID] = ClassDepartmentID
  ,[Department]= ClassDepartmentName
  ,[ClassStartDate] = ClassStartDate
  ,[ClassEndDate] = ClassEndDate
  ,[CurrentCoursePrice] = ClassPriceCurrent -- Changed Column Name
  ,[ClassEnrollmentMax] = ClassEnrollmentMax
  ,[ClassroomID] = ClassroomID
  ,[Classroom] = ClassroomName
  ,[MaxClassroomSize] = ClassroomSizeMax
  ,[StudentID] = StudentID
  ,[StudentFullName] = StudentFullName
  ,[StudentEmail] = StudentEmail
  ,[EnrollmentsPerCourse] = Count(fe.Studentkey) Over(Partition By fe.ClassKey)
  ,[CourseEnrollmentLevelKPI] = dbo.fKPIMaxLessCurrentEnrollments(fe.ClassKey)
  ,[ActualEnrollmentPrice] = fe.ActualEnrollmentPrice
  From FactEnrollments as fe
  Join DimDates as dd
    On fe.EnrollmentDateKey = dd.DateKey
  Join DimClasses as dc
    On fe.ClassKey = dc.ClassKey
  Join DimStudents as ds
    On fe.StudentKey = ds.StudentKey;
Go
-- Check the view: Select * From vDocumentDBETLFactEnrollments
Select * From vETLDocumentDB; -- To CSV
--Select * From vDocumentDBETL For JSON Path; -- Can be used, BUT will make a single document instead of many!