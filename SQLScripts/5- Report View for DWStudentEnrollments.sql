--*************************** Instructors Version ******************************--
-- Title:   DWStudentEnrollments ETL Views for DocumentDB
-- Author: Jimmy Nguyen
-- Desc: This file creates [DWStudentEnrollments] Reporting Functions and Views for DWStudentEnrollment. 
-- Change Log: When,Who,What
-- 2020-03-26,JimmyN,Created File

--**************************************************************************--

USE DWStudentEnrollments;
Go --NOTE: We don't really need this because we created it in the A4 file.
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

Create or Alter View vRptStudentEnrollments
AS
  Select 
     [EnrollmentID] = EnrollmentID 
	,[FullDateTime] = Cast(FullDateTime as Date)
	,[Date] = [DateName]
	,[Month] = [MonthName]
	,[Quarter] = QuarterName
	,[Year] = YearName
	,[ClassID] = ClassID
	,[Course] = ClassName
	,[DepartmentID] = ClassDepartmentID
	,[Department]= ClassDepartmentName
	,[ClassStartDate] = ClassStartDate
	,[ClassEndDate] = ClassEndDate
	,[CurrentCoursePrice] = ClassPriceCurrent  -- Changed Column Name
	,[MaxCourseEnrollment] = ClassEnrollmentMax
	,[ClassroomID] = ClassroomID
	,[Classroom] = ClassroomName
	,[MaxClassroomSize] = ClassroomSizeMax
	,[StudentID] = StudentID
	,[StudentFullName] = StudentFullName
	,[StudentEmail] = StudentEmail
	,[CourseEnrollmentLevelKPI] = dbo.fKPIMaxLessCurrentEnrollments(fe.ClassKey)
  From FactEnrollments as fe
  Join DimDates as dd
    On fe.EnrollmentDateKey = dd.DateKey
  Join DimClasses as dc
    On fe.ClassKey = dc.ClassKey
  Join DimStudents as ds
    On fe.StudentKey = ds.StudentKey;
Go
Select * From vRptStudentEnrollments;
