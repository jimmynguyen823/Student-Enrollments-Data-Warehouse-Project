--*************************************************************************--
-- Title: Investigating Data Techniques
-- Author: Jimmy Nguyen
-- Desc: This file shows different ways to investigate data when starting a BI Solution. 
-- Change Log: When,Who,What
-- 2020-01-01,JimmyN,Created File
--**************************************************************************--

-- Getting MetaData --------------------------------------------------------------
Use StudentEnrollments;

-- Two important functions are Object_Name and Object_ID
Select 'Name' = object_name(-105), 'ID' = object_id('SysObjects');
-- Note the aliases
Select 'Object_Name' = Object_Name(-105), 'Object_Id' = object_id('SysObjects');


-- [SysObjects] --
Select * 
From SysObjects Order by crdate desc;

-- Filter out most system objects
Select * 
From SysObjects 
Where xtype in ('u', 'pk', 'f') 
Order By  parent_obj

-- Just the object and Parent objects
Select  Name, [Parent object] = iif(parent_obj = 0, '', Object_Name(parent_obj)) 
From SysObjects 
Where xtype in ('u', 'pk', 'f')
Order By  parent_obj


-- [Sys.Objects] -- Newer
Select * 
From Sys.Objects Order by create_date desc;

-- Filter out most system objects
Select *, 'Parent object' = iif(parent_object_id = 0, '', Object_Name(parent_object_id)) 
From Sys.Objects 
Where type in ('u', 'pk', 'f') 
Order By  parent_object_id

-- Just the object and Parent objects
Select Name, 'Parent object' = iif(parent_object_id = 0, '', Object_Name(parent_object_id)) 
From Sys.Objects 
Where type in ('u', 'pk', 'f') 
Order By  parent_object_id

-- [Sys.Tables] -- 
Select * From Sys.Tables Order By create_date;

Select "Schema" = schema_name([schema_id]), [name] 
From Sys.Tables 

-- [Sys.Columns] -- 
Select * From Sys.Columns; 

Select [Table] = object_name([object_id]), [Name], system_type_id, max_length, [precision], scale, is_nullable 
From Sys.Columns; 

Select [Table] = object_name([object_id]), [Name], system_type_id, max_length, [precision], scale, is_nullable  
From Sys.Columns
Where [object_id] in (Select [object_id] From Sys.Tables); 

-- [Sys.Types] -- 
Select * From Sys.Types;

Select [Table] = object_name([object_id]), c.[Name], t.[Name], c.max_length, t.max_length
From Sys.Types as t 
Join Sys.Columns as c 
 On t.system_type_id = c.system_type_id 
Where [object_id] in (Select [object_id] From Sys.Tables); 

-- Combining the results 
Select 
 [Database] = DB_Name()
,[Schema Name] = SCHEMA_NAME(tab.[schema_id])
,[Table] = object_name(tab.[object_id])
,[Column] =  col.[Name]
,[Type] =  t.[Name] 
,[Nullable] = col.is_nullable
From Sys.Types as t 
Join Sys.Columns as col 
 On t.system_type_id = col.system_type_id 
Join Sys.Tables tab
  On Tab.[object_id] = col.[object_id]
And t.name <> 'sysname'
Order By 1, 2; 

-- Formating for documentation
Select 
 [Source Table] = DB_Name() + '.' + SCHEMA_NAME(tab.[schema_id]) + '.' + object_name(tab.[object_id])
,[Source Column] =  col.[Name]
,[Source Type] = Case 
	      When t.[Name] in ('char', 'nchar', 'varchar', 'nvarchar' ) 
		Then t.[Name] + ' (' +  format(col.max_length, '####') + ')'                
	      When t.[Name]  in ('decimal', 'money') 
		Then t.[Name] + ' (' +  format(col.[precision], '#') + ',' + format(col.scale, '#') + ')'
             Else t.[Name] 
             End 
,[Source Nullability] = iif(col.is_nullable = 0, 'null', 'not null')  
,[Sort] = ROW_NUMBER() Over (Order By tab.[object_id])
From Sys.Types as t 
Join Sys.Columns as col 
 On t.system_type_id = col.system_type_id 
Join Sys.Tables tab
  On Tab.[object_id] = col.[object_id]
And t.name <> 'sysname'
Order By [Sort]; 

-- Getting Sample Data --------------------------------------------------------------

Exec sp_msforeachtable @Command1 = 'sp_help [?]'
Go
--Notice that sp_help is called for each table in the database and that I am using square brackets instead of a double quote. 
--This make this command evaluate as an object and not just a string, which can be important sometimes, though in this case it doesn’t matter.

--We create our own Sproc and pass in the table name as an argument value. 
--This next example uses the TSQL Exec command run a string of text characters as if it were a typed-out SQL statement.
Create or Alter Proc pSelTop2
(@TableName as nVarchar(100))
AS 
Print @TableName
Declare @SQLCode nvarchar(100) = 'Select Top 2 [Table] = Replace(''' +  @TableName +  ''', ''[dbo].'', '''')' + ' , * ' 
                                                  + 'From  ' + @TableName 
Print @SQLCode
Exec(@SQLCode)
Go
--Now I can use Microsoft’s stored procedure to execute my stored procedure like this:
Exec sp_msforeachtable @Command1 = 'exec pSelTop2 "?" '
Go
