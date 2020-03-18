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
--Create or Alter View vTabularDimStudents
--go
--Create or Alter View vTabularDimClasses
--go
--Create or Alter View vTabularDimDates 
--go

-- Fact Table --
--Create or Alter View vTabularFactEnrollments 
--go


Select * from vTabularDimStudents
Select * from vTabularDimClasses
Select * from vTabularDimDates
Select * from vTabularFactEnrollments