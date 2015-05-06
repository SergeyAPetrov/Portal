USE [Portal]
GO
/****** Object:  User [ASPNET]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [ASPNET] WITH DEFAULT_SCHEMA=[ASPNET]
GO
/****** Object:  User [dbot]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [dbot] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [FIRM\$AlexanderK]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [FIRM\$AlexanderK] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [FIRM\vadims]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [FIRM\vadims] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [LeonidS]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [LeonidS] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [ULTERSYSYAR\SDC$]    Script Date: 21.04.2015 15:24:03 ******/
CREATE USER [ULTERSYSYAR\SDC$] WITH DEFAULT_SCHEMA=[ULTERSYSYAR\SDC$]
GO
ALTER ROLE [db_owner] ADD MEMBER [dbot]
GO
ALTER ROLE [db_owner] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_accessadmin] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_securityadmin] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_ddladmin] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_backupoperator] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_datareader] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_denydatareader] ADD MEMBER [LeonidS]
GO
ALTER ROLE [db_denydatawriter] ADD MEMBER [LeonidS]
GO
/****** Object:  Schema [ASPNET]    Script Date: 21.04.2015 15:24:03 ******/
CREATE SCHEMA [ASPNET]
GO
/****** Object:  Schema [ULTERSYSYAR\SDC$]    Script Date: 21.04.2015 15:24:03 ******/
CREATE SCHEMA [ULTERSYSYAR\SDC$]
GO
/****** Object:  StoredProcedure [dbo].[AuthenticateUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Ivan Yakimov
-- Create date: 15.08.2007
-- Description:	Процедура аутентификации Internet-пользователя.
-- =============================================
CREATE PROCEDURE [dbo].[AuthenticateUser]
	-- Add the parameters for the stored procedure here
	@UserName nvarchar(50),
	@Password nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT COUNT(*) 
	FROM
		Users usr,
		InternetUsers iusr
	WHERE
		(usr.ID = iusr.UserID) AND
		(Lower(usr.DomainName) = Lower(@UserName)) AND 
		(iusr.Password = @Password)
END

GO
/****** Object:  StoredProcedure [dbo].[CleanAttachments]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[CleanAttachments] 
AS
BEGIN
DELETE
	FROM NewsAttachments WHERE NewsID = 0
END

GO
/****** Object:  StoredProcedure [dbo].[CloseEventRows]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CloseEventRows] 
(
@BeginTime datetime,
@EndTime datetime
)
AS
UPDATE UptimeEvents 
SET 
EndTime=@EndTime,
Duration=Datediff(second,BeginTime, @EndTime)
WHERE (FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, @BeginTime))) and Duration=0  and UptimeEventTypeID=10

GO
/****** Object:  StoredProcedure [dbo].[CreateRequest]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		VadimS
-- Description:	Create request for object.
-- =============================================
CREATE PROCEDURE [dbo].[CreateRequest]
	@UserID INT,
	@ObjectID INT,
	@IsTaken BIT,
	@Date DATETIME
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @OwnerID INT, @HolderID INT;
	DECLARE @LastOperation table(ID int NOT NULL,
								UserID int,
								ObjectID int NOT NULL,
								Date datetime not null,
								IsTaken bit not null);

	INSERT INTO @LastOperation
		SELECT * FROM Requests
		WHERE ObjectID = @ObjectID 
				AND Date = (SELECT MAX(DATE) FROM Requests WHERE ObjectID = @ObjectID)

	IF (@UserID IS NULL)
		SET @UserID = 0

	SET @HolderID = [dbo].GetRequestObjectHolderID(@ObjectID)

	SET @OwnerID = (SELECT OwnerID FROM RequestObject WHERE ID = @ObjectID)
	IF (@OwnerID IS NULL)
		SET @OwnerID = 0

	IF (@OwnerID = @UserID)
	BEGIN	
		SET @UserID = @HolderID
		SET @IsTaken = 0
	END

	-- Request Table does'n contain taken operation.
	IF ((SELECT Date FROM @LastOperation) is null AND @IsTaken = 0)
	BEGIN
		PRINT '-- NO OPERATIONS'
		RETURN
	END

	-- ALREADY RETURNED
	IF ((SELECT IsTaken FROM @LastOperation) = 0 AND @IsTaken = 0)
	BEGIN
		PRINT '-- ALREADY RETURNED'
		RETURN
	END

	-- ALREADY TAKEN
	IF ((SELECT IsTaken FROM @LastOperation) = 1 AND @IsTaken = 1
		AND @UserID = @HolderID)
	BEGIN
		PRINT '-- ALREADY TAKEN'
		RETURN
	END

	-- CANT RETURN cause holder another person
	IF ((SELECT IsTaken FROM @LastOperation) = 1 
		AND @IsTaken = 0 AND @HolderID <> @UserID)
	BEGIN
		PRINT '-- CANT RETURN'
		RETURN
	END

	IF (@UserID = 0)
		SET @UserID = NULL

	INSERT INTO Requests (UserID, ObjectID, Date, IsTaken) 
				VALUES (@UserID, @ObjectID, @Date, @IsTaken)
END
GO
/****** Object:  StoredProcedure [dbo].[CreateUptimeEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Процедура добавления нового события
CREATE PROCEDURE [dbo].[CreateUptimeEvent] 
(
@Name nvarchar(50),
@BeginTime datetime,
@EndTime datetime,
@Duration int,
@UserID int,
@ProjectID int,
@WorkCategoryID int,
@UptimeEventTypeID int
)
AS

Select ID From UptimeEvents Where UserID=@UserID AND FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, @BeginTime)) And UptimeEventTypeID=10
IF(@@rowcount=0 or @UptimeEventTypeID <> 10)
 INSERT INTO UptimeEvents([Name],BeginTime,EndTime,Duration,UserID,ProjectID,WorkCategoryID,UptimeEventTypeID)
 VALUES (@Name,@BeginTime,@EndTime,@Duration,@UserID,@ProjectID,@WorkCategoryID,@UptimeEventTypeID)
ELSE
 RETURN
GO
/****** Object:  StoredProcedure [dbo].[CreateUptimeEventTest]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateUptimeEventTest]
--Процедура добавления нового события
(
@Name nvarchar(50),
@BeginTime datetime,
@EndTime datetime,
@Duration int,
@UserID int,
@ProjectID int,
@WorkCategoryID int,
@UptimeEventTypeID int
)
AS
Select ID From UptimeEvents Where UserID=@UserID AND FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, @BeginTime)) And UptimeEventTypeID=10
IF(@@rowcount=0)
 INSERT INTO UptimeEvents([Name],BeginTime,EndTime,Duration,UserID,ProjectID,WorkCategoryID,UptimeEventTypeID)
 VALUES (@Name,@BeginTime,@EndTime,@Duration,@UserID,@ProjectID,@WorkCategoryID,@UptimeEventTypeID)
  ELSE
 RETURN
	
GO
/****** Object:  StoredProcedure [dbo].[CreateUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Author:		Ivan Yakimov
-- Create date: 08.08.2007
-- Description:	Процедура создания пользователя.
-- =============================================
CREATE PROCEDURE [dbo].[CreateUser]
	-- Add the parameters for the stored procedure here
	@FirstNameRus nvarchar(50),
	@MiddleNameRus nvarchar(50),
	@LastNameRus nvarchar(100),
	@FirstNameEng nvarchar(50),
	@InitialEng nvarchar(1),
	@LastNameEng nvarchar(100),
	@Sex smallint,
	@Birthday datetime,
	@DomainName nvarchar(50),
	@PrimaryEMail nvarchar(50),
	@Project nvarchar(50),
	@Room nvarchar(5),
	@PrimaryIP nvarchar(23),
	@LongServiceEmployees bit,
	@PersonnelReserve bit,
	@EmployeesUlterSYSMoscow bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	INSERT INTO Users
	(
		FName, 
		IName, 
		LName, 
		nlFName,
		Initial,
		nlLName,
		Sex,
		Birthday,
		DomainName,
		PrimaryEMail,
		Project,
		Room,
		PrimaryIP,
		LongServiceEmployees,
		PersonnelReserve,
		EmployeesUlterSYSMoscow
	)
	VALUES
	(
		@FirstNameRus,
		@MiddleNameRus,
		@LastNameRus,
		@FirstNameEng,
		@InitialEng,
		@LastNameEng,
		@Sex,
		@Birthday,
		@DomainName,
		@PrimaryEMail,
		@Project,
		@Room,
		@PrimaryIP,
		@LongServiceEmployees,
		@PersonnelReserve,
		@EmployeesUlterSYSMoscow
	)
END

GO
/****** Object:  StoredProcedure [dbo].[DeleteUptimeEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DeleteUptimeEvent] 
(@ID int)
AS

DELETE
FROM UptimeEvents
WHERE ID=@ID
GO
/****** Object:  StoredProcedure [dbo].[DeleteUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Sheydakov Vadim
-- Create date: 26.12.2008
-- Description:	Отписка юзера от события.
-- =============================================
CREATE PROCEDURE [dbo].[DeleteUser]
	-- Add the parameters for the stored procedure here
	@UserID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	-- Удалить все события пользователя
	DELETE FROM UptimeEvents
	WHERE UserID = @UserID

    -- Insert statements for procedure here
	DELETE FROM Users
	WHERE ID = @UserID
END

GO
/****** Object:  StoredProcedure [dbo].[GetAdminList]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetAdminList]
	
AS
	SELECT Id FROM PortalAdmins
	RETURN


GO
/****** Object:  StoredProcedure [dbo].[GetCalendarDate]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ivan Yakimov
-- Create date: 2007.08.06
-- Description:	Returns record about calendar date.
-- =============================================
CREATE PROCEDURE [dbo].[GetCalendarDate] 
	@Date datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT * FROM Calendar WHERE FLOOR(CONVERT( float, Date)) = FLOOR(CONVERT( float, @Date))
END

GO
/****** Object:  StoredProcedure [dbo].[GetCountUserNow]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetCountUserNow] 
	
AS
	SET NOCOUNT ON
	SELECT     COUNT(*) AS count_users
	FROM         UptimeEvents
	WHERE     (FLOOR(CONVERT(float, BeginTime)) = FLOOR(CONVERT(float, GETDATE()))) AND (UptimeEventTypeID = 10) AND (Duration = 0)

	RETURN

GO
/****** Object:  StoredProcedure [dbo].[GetEventBeginWorkToday]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetEventBeginWorkToday]

	(
		@UserID integer
		--@parameter2 datatype OUTPUT
	)

AS
	SET NOCOUNT ON
    SELECT * FROM UptimeEvents WHERE UserID = @UserID AND  FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, GETDATE())) AND UptimeEventTypeId=10
	RETURN 

GO
/****** Object:  StoredProcedure [dbo].[GetEventTimeOff]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetEventTimeOff]

	(
		@UserID integer
		--@parameter2 datatype OUTPUT
	)

AS
	SET NOCOUNT ON
    SELECT * FROM UptimeEvents WHERE UserID = @UserID AND  FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, GETDATE())) AND BeginTime=EndTime AND UptimeEventTypeId=9
	RETURN 

GO
/****** Object:  StoredProcedure [dbo].[GetHoliday]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Ivan Yakimov
-- Create date: 2007.08.06
-- Description:	Returns record about calendar date.
-- =============================================
CREATE PROCEDURE [dbo].[GetHoliday]
	@HolidayDate datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT ID FROM Calendar WHERE ID=-1
END


GO
/****** Object:  StoredProcedure [dbo].[GetInternetUserID]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ivan Yakimov
-- Create date: 16.08.2007
-- Description:	Возвращает ID Интернет-пользователя по его имени.
-- =============================================
CREATE PROCEDURE [dbo].[GetInternetUserID] 
	-- Add the parameters for the stored procedure here
	@UserName nvarchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT TOP (1) ID
	FROM Users
	WHERE Lower(DomainName) = Lower(@UserName)
END

GO
/****** Object:  StoredProcedure [dbo].[GetListUsersForm1]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE   PROCEDURE [dbo].[GetListUsersForm1] AS

SELECT     FName, LName, DomainName, PrimaryEMail, Project, Room, PrimaryIP
FROM         Users
WHERE     (LongServiceEmployees = 1)
ORDER BY Project


GO
/****** Object:  StoredProcedure [dbo].[GetNewsAttachments]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
ALTER TABLE [dbo].[NewsAttachments]  WITH CHECK ADD  CONSTRAINT [FK_NewsAttachments_News] FOREIGN KEY([NewsID])
REFERENCES [dbo].[News] ([ID])
ON DELETE CASCADE
GO

ALTER TABLE [dbo].[NewsAttachments] CHECK CONSTRAINT [FK_NewsAttachments_News]
*/

CREATE PROCEDURE [dbo].[GetNewsAttachments]
                   @NewsID int
AS
BEGIN
    SELECT * 
    FROM NewsAttachments
    WHERE NewsID = @NewsID
END


GO
/****** Object:  StoredProcedure [dbo].[GetNotificationList]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[GetNotificationList] 
	@Type int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	SELECT EMail FROM NotificationLists WHERE [Type] = @Type
END

GO
/****** Object:  StoredProcedure [dbo].[GetObjectsOnHand]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-------------------------------------------------------------------------------------
CREATE procedure [dbo].[GetObjectsOnHand](@UserID int) as
BEGIN
	IF (@UserID = 0)
		SET @UserID = NULL	
	
	SELECT Title, 
		FirstName as OwnerFirstName, 
		CASE WHEN LastName is null
		THEN '<MLText><Text lang="en">Office</Text><Text lang="ru">Офис</Text></MLText>'
		ELSE LastName 
		END as OwnerLastName,
		dbo.GetRequestObjectType(RequestObject.ID) as ObjType
	FROM RequestObject
	LEFT JOIN Users ON Users.ID = OwnerID
	WHERE 
		(@UserID IS NULL AND [dbo].GetRequestObjectHolderID(RequestObject.ID) IS NULL)
		OR
		(@UserID IS NOT NULL AND [dbo].GetRequestObjectHolderID(RequestObject.ID) = @UserID)
END

GO
/****** Object:  StoredProcedure [dbo].[GetSumUptimeOrder]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [dbo].[GetSumUptimeOrder]
(
@UserID int,
@BeginDate datetime,
@EndDate datetime
)
AS
	SET NOCOUNT ON;
SELECT (CAST(SUM(CASE UptimeEventTypeId WHEN 3 THEN 0 WHEN 1 THEN 0 ELSE DATEDIFF(s,BeginTime,EndTime) END)/3600 AS VARCHAR(3))+':'+
RIGHT('00'+CAST(SUM(CASE UptimeEventTypeId WHEN 3 THEN 0 WHEN 1 THEN 0 ELSE DATEDIFF(s,BeginTime,EndTime) END)%3600/60 AS VARCHAR(2)),2))AS Uptime,
(CAST(SUM(CASE UptimeEventTypeId WHEN 0 THEN DATEDIFF(s,BeginTime,EndTime) WHEN 3 THEN DATEDIFF(s,BeginTime,EndTime) ELSE 0 END)/3600 AS VARCHAR(3))+':'+
RIGHT('00'+CAST(SUM(CASE UptimeEventTypeId WHEN 0 THEN DATEDIFF(s,BeginTime,EndTime) WHEN 3 THEN DATEDIFF(s,BeginTime,EndTime) ELSE 0 END)%3600/60 AS VARCHAR(2)),2))AS Rest
FROM UptimeEvents 
WHERE UserID=@UserID 
  AND BeginTime>=@BeginDate
  AND BeginTime<=@EndDate
GO
/****** Object:  StoredProcedure [dbo].[GetSumWorkTimeThisWeek]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetSumWorkTimeThisWeek]

	(
		@UserID int
	)

AS
	SET NOCOUNT ON

DECLARE @first_day_week datetime 
SET @first_day_week = cast( (7*( FLOOR(cast(GETDATE() - 1 as int) / 7) ) ) as datetime )

    SELECT SUM(Duration) FROM dbo.UptimeEvents 
	WHERE UserID = @UserID
		AND UptimeEventTypeID = 10
		AND BeginTime >= @first_day_week
		AND EndTime < DATEADD( hh, 24, @first_day_week + 7) -- Last moment week

	
	/*RETURN */

GO
/****** Object:  StoredProcedure [dbo].[GetUnnecessaryAttachments]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetUnnecessaryAttachments] 
AS
BEGIN
	select * from NewsAttachments where NewsID = 0
END

GO
/****** Object:  StoredProcedure [dbo].[GetUptimeOrder]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetUptimeOrder]
(
@UserID int,
@BeginDate datetime,
@EndDate datetime
)
AS
	SET NOCOUNT ON;
SELECT CONVERT (CHAR(10), BeginTime, 103) AS Date, 
CONVERT (CHAR(5), CONVERT (DATETIME, (SUM(CASE UptimeEventTypeId WHEN 3 THEN 0 WHEN 1 THEN 0 ELSE DATEDIFF(s,BeginTime,EndTime) END) + 1) / 24.0 / 60 / 60), 108) AS Uptime,
CONVERT (CHAR(5), CONVERT (DATETIME, (SUM(CASE UptimeEventTypeId WHEN 0 THEN DATEDIFF(s,BeginTime,EndTime) WHEN 3 THEN DATEDIFF(s,BeginTime,EndTime) ELSE 0 END) + 1) / 24.0 / 60 / 60), 108) AS Rest, 
CONVERT (CHAR(5), MIN(BeginTime), 108) AS DayBegin, 
CONVERT (CHAR(5), MAX(EndTime), 108) AS DayEnd 
FROM UptimeEvents 
WHERE UserID=@UserID 
  AND BeginTime>=@BeginDate
  AND BeginTime<=@EndDate
GROUP BY CONVERT (CHAR(10), BeginTime, 103), CONVERT (CHAR(10), BeginTime, 102) 
ORDER BY CONVERT (CHAR(10), BeginTime, 102)
GO
/****** Object:  StoredProcedure [dbo].[GetUserByDomainName]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetUserByDomainName]
(
@DomainName nvarchar(50)
)
AS
SELECT 
	ID, 
	ISNULL(FName,'') AS FName, 
	ISNULL(IName,'') AS IName, 
	ISNULL(LName,'') AS LName,
	ISNULL(nlFName, '') AS nlFName,
	ISNULL(Initial, '') AS Initial,
	ISNULL(nlLName, '') AS nlLName,
	Sex,
	Birthday,
	ISNULL(DomainName, '') AS DomainName,
	ISNULL(PrimaryEMail, '') AS PrimaryEMail,
	ISNULL(Project, '') AS Project,
	ISNULL(Room, '') AS Room,
	ISNULL(PrimaryIP, '') AS PrimaryIP,
	LongServiceEmployees,
	PersonnelReserve,
	EmployeesUlterSYSMoscow
FROM Users 
WHERE UPPER(DomainName)=UPPER(@DomainName)
RETURN @@ROWCOUNT

GO
/****** Object:  StoredProcedure [dbo].[GetUserByID]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[GetUserByID]
(
@ID int
)
AS
SELECT 
	ISNULL(FName,'') AS FName, 
	ISNULL(IName,'') AS IName, 
	ISNULL(LName,'') AS LName, 
	ISNULL(nlFName, '') AS nlFName,
	ISNULL(Initial, '') AS Initial,
	ISNULL(nlLName, '') AS nlLName,
	Sex,
	Birthday,
	ISNULL(DomainName,'') AS DomainName,
	ISNULL(PrimaryEMail, '') AS PrimaryEMail,
	ISNULL(Project, '') AS Project,
	ISNULL(Room, '') AS Room,
	ISNULL(PrimaryIP, '') AS PrimaryIP,
	LongServiceEmployees,
	PersonnelReserve,
	EmployeesUlterSYSMoscow
FROM Users 
WHERE ID=@ID
RETURN @@ROWCOUNT

GO
/****** Object:  StoredProcedure [dbo].[GetUserEvents]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO
CREATE PROCEDURE [dbo].[GetUserEvents]
(
@UserID int,
@IntervalBegin datetime,
@IntervalEnd datetime
)
AS

SELECT ID, ISNULL(Name,'') AS Name, BeginTime, EndTime, ISNULL(Duration,0) AS Duration, ISNULL(ProjectID,1) AS ProjectID, ISNULL(WorkCategoryID,1) AS WorkCategoryID, ISNULL(UptimeEventTypeID,1) AS UptimeEventTypeID 
FROM UptimeEvents 
WHERE UserID=@UserID 
AND BeginTime<=@IntervalEnd 
AND EndTime>=@IntervalBegin 
ORDER BY BeginTime

RETURN @@ROWCOUNT
GO
/****** Object:  StoredProcedure [dbo].[GetUserList]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetUserList]
AS
SELECT ID, LName+' '+Fname AS Name
FROM Users 
WHERE LongServiceEmployees=1
RETURN @@ROWCOUNT
GO
/****** Object:  StoredProcedure [dbo].[GetUserWithOpenWorkPeriod]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetUserWithOpenWorkPeriod]
(
	@CurrentDate DateTime
)
	
AS
	
 SELECT ue.UserID as ID, us.FName + ' ' + us.LName as Name, us.PrimaryEMail as Mail 
 
 FROM UptimeEvents ue
 INNER JOIN Users us ON ue.UserID=us.ID

 WHERE FLOOR(CONVERT(float,BeginTime)) = FLOOR(CONVERT(float, @CurrentDate)) AND BeginTime = EndTime AND UptimeEventTypeID = 10 

GO
/****** Object:  StoredProcedure [dbo].[GetWorkEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Ivan Yakimov
-- Create date: 14.08.2007
-- Description:	Возвращает рабочее событие за указанную дату.
-- =============================================
CREATE PROCEDURE [dbo].[GetWorkEvent]
	@UserID int,
	@Date datetime
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
    SELECT * FROM UptimeEvents WHERE UserID = @UserID AND  FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, @Date)) AND UptimeEventTypeId=10
END

GO
/****** Object:  StoredProcedure [dbo].[SetEventEndWorkToday]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SetEventEndWorkToday]

	(
		@UserID int,
		@EndTime datetime
		
		--@parameter2 datatype OUTPUT
	)

AS
	SET NOCOUNT ON
	DECLARE @IDEvent int,
	        @BeginTime DateTime
	
	SELECT @IDEvent = ID, @BeginTime = BeginTime FROM UptimeEvents WHERE UserID = @UserID AND  FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, GETDATE())) AND UptimeEventTypeId=10
	
	DECLARE @Duration int
	SELECT @Duration =  DATEDIFF( second, @BeginTime, @EndTime )
	
	UPDATE UptimeEvents SET UserID = @UserID, EndTime = @EndTime, Duration = @Duration WHERE ID = @IDEvent 
	
	RETURN 

GO
/****** Object:  StoredProcedure [dbo].[SetEventTimeOn]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[SetEventTimeOn]

	(
		@UserID int,
		@EndTime datetime
		
		--@parameter2 datatype OUTPUT
	)

AS
	SET NOCOUNT ON
	DECLARE @IDEvent int,
	        @BeginTime DateTime
	
	SELECT @IDEvent = ID, @BeginTime = BeginTime FROM UptimeEvents WHERE UserID = @UserID AND  FLOOR(CONVERT( float, BeginTime)) = FLOOR(CONVERT( float, GETDATE())) AND BeginTime=EndTime And UptimeEventTypeId=9
	
	DECLARE @Duration int
	SELECT @Duration =  DATEDIFF( second, @BeginTime, @EndTime )
	
	UPDATE UptimeEvents SET UserID = @UserID, EndTime = @EndTime, Duration = @Duration WHERE ID = @IDEvent 
	
	RETURN 

GO
/****** Object:  StoredProcedure [dbo].[sp_alterdiagram]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_alterdiagram]
	(
		@diagramname 	sysname,
		@owner_id	int	= null,
		@version 	int,
		@definition 	varbinary(max)
	)
	WITH EXECUTE AS 'dbo'
	AS
	BEGIN
		set nocount on
	
		declare @theId 			int
		declare @retval 		int
		declare @IsDbo 			int
		
		declare @UIDFound 		int
		declare @DiagId			int
		declare @ShouldChangeUID	int
	
		if(@diagramname is null)
		begin
			RAISERROR ('Invalid ARG', 16, 1)
			return -1
		end
	
		execute as caller
		select @theId = DATABASE_PRINCIPAL_ID()	 
		select @IsDbo = IS_MEMBER(N'db_owner') 
		if(@owner_id is null)
			select @owner_id = @theId
		revert
	
		select @ShouldChangeUID = 0
		select @DiagId = diagram_id, @UIDFound = principal_id from dbo.sysdiagrams where principal_id = @owner_id and name = @diagramname 
		
		if(@DiagId IS NULL or (@IsDbo = 0 and @theId <> @UIDFound))
		begin
			RAISERROR ('Diagram does not exist or you do not have permission.', 16, 1);
			return -3
		end
	
		if(@IsDbo <> 0)
		begin
			if(@UIDFound is null or USER_NAME(@UIDFound) is null) -- invalid principal_id
			begin
				select @ShouldChangeUID = 1 ;
			end
		end

		-- update dds data			
		update dbo.sysdiagrams set definition = @definition where diagram_id = @DiagId ;

		-- change owner
		if(@ShouldChangeUID = 1)
			update dbo.sysdiagrams set principal_id = @theId where diagram_id = @DiagId ;

		-- update dds version
		if(@version is not null)
			update dbo.sysdiagrams set version = @version where diagram_id = @DiagId ;

		return 0
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_creatediagram]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_creatediagram]
	(
		@diagramname 	sysname,
		@owner_id		int	= null, 	
		@version 		int,
		@definition 	varbinary(max)
	)
	WITH EXECUTE AS 'dbo'
	AS
	BEGIN
		set nocount on
	
		declare @theId int
		declare @retval int
		declare @IsDbo	int
		declare @userName sysname
		if(@version is null or @diagramname is null)
		begin
			RAISERROR (N'E_INVALIDARG', 16, 1);
			return -1
		end
	
		execute as caller
		select @theId = DATABASE_PRINCIPAL_ID() 
		select @IsDbo = IS_MEMBER(N'db_owner')
		revert 
		
		if @owner_id is null
		begin
			select @owner_id = @theId;
		end
		else
		begin
			if @theId <> @owner_id
			begin
				if @IsDbo = 0
				begin
					RAISERROR (N'E_INVALIDARG', 16, 1);
					return -1
				end
				select @theId = @owner_id
			end
		end
		-- next 2 line only for test, will be removed after define name unique
		if EXISTS(select diagram_id from dbo.sysdiagrams where principal_id = @theId and name = @diagramname)
		begin
			RAISERROR ('The name is already used.', 16, 1);
			return -2
		end
	
		insert into dbo.sysdiagrams(name, principal_id , version, definition)
				VALUES(@diagramname, @theId, @version, @definition) ;
		
		select @retval = @@IDENTITY 
		return @retval
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_dropdiagram]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_dropdiagram]
	(
		@diagramname 	sysname,
		@owner_id	int	= null
	)
	WITH EXECUTE AS 'dbo'
	AS
	BEGIN
		set nocount on
		declare @theId 			int
		declare @IsDbo 			int
		
		declare @UIDFound 		int
		declare @DiagId			int
	
		if(@diagramname is null)
		begin
			RAISERROR ('Invalid value', 16, 1);
			return -1
		end
	
		EXECUTE AS CALLER
		select @theId = DATABASE_PRINCIPAL_ID()	-- UNDONE: more work 
		select @IsDbo = IS_MEMBER(N'db_owner') 
		if(@owner_id is null)
			select @owner_id = @theId
		REVERT 
		
		select @DiagId = diagram_id, @UIDFound = principal_id from dbo.sysdiagrams where principal_id = @owner_id and name = @diagramname 
		if(@DiagId IS NULL or (@IsDbo = 0 and @UIDFound <> @theId))
		begin
			RAISERROR ('Diagram does not exist or you do not have permission.', 16, 1)
			return -3
		end
	
		delete from dbo.sysdiagrams where diagram_id = @DiagId;
	
		return 0;
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_helpdiagramdefinition]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_helpdiagramdefinition]
	(
		@diagramname 	sysname,
		@owner_id	int	= null 		
	)
	WITH EXECUTE AS N'dbo'
	AS
	BEGIN
		set nocount on

		declare @theId 		int
		declare @IsDbo 		int
		declare @DiagId		int
		declare @UIDFound	int
	
		if(@diagramname is null)
		begin
			RAISERROR (N'E_INVALIDARG', 16, 1);
			return -1
		end
	
		execute as caller
		select @theId = DATABASE_PRINCIPAL_ID()
		select @IsDbo = IS_MEMBER(N'db_owner')
		if(@owner_id is null)
			select @owner_id = @theId
		revert 
	
		select @DiagId = diagram_id, @UIDFound = principal_id from dbo.sysdiagrams where principal_id = @owner_id and name = @diagramname;
		if(@DiagId IS NULL or (@IsDbo = 0 and @UIDFound <> @theId ))
		begin
			RAISERROR ('Diagram does not exist or you do not have permission.', 16, 1);
			return -3
		end

		select version, definition FROM dbo.sysdiagrams where diagram_id = @DiagId ; 
		return 0
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_helpdiagrams]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_helpdiagrams]
	(
		@diagramname sysname = NULL,
		@owner_id int = NULL
	)
	WITH EXECUTE AS N'dbo'
	AS
	BEGIN
		DECLARE @user sysname
		DECLARE @dboLogin bit
		EXECUTE AS CALLER
			SET @user = USER_NAME()
			SET @dboLogin = CONVERT(bit,IS_MEMBER('db_owner'))
		REVERT
		SELECT
			[Database] = DB_NAME(),
			[Name] = name,
			[ID] = diagram_id,
			[Owner] = USER_NAME(principal_id),
			[OwnerID] = principal_id
		FROM
			sysdiagrams
		WHERE
			(@dboLogin = 1 OR USER_NAME(principal_id) = @user) AND
			(@diagramname IS NULL OR name = @diagramname) AND
			(@owner_id IS NULL OR principal_id = @owner_id)
		ORDER BY
			4, 5, 1
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_renamediagram]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_renamediagram]
	(
		@diagramname 		sysname,
		@owner_id		int	= null,
		@new_diagramname	sysname
	
	)
	WITH EXECUTE AS 'dbo'
	AS
	BEGIN
		set nocount on
		declare @theId 			int
		declare @IsDbo 			int
		
		declare @UIDFound 		int
		declare @DiagId			int
		declare @DiagIdTarg		int
		declare @u_name			sysname
		if((@diagramname is null) or (@new_diagramname is null))
		begin
			RAISERROR ('Invalid value', 16, 1);
			return -1
		end
	
		EXECUTE AS CALLER
		select @theId = DATABASE_PRINCIPAL_ID()
		select @IsDbo = IS_MEMBER(N'db_owner') 
		if(@owner_id is null)
			select @owner_id = @theId
		REVERT
	
		select @u_name = USER_NAME(@owner_id)
	
		select @DiagId = diagram_id, @UIDFound = principal_id from dbo.sysdiagrams where principal_id = @owner_id and name = @diagramname 
		if(@DiagId IS NULL or (@IsDbo = 0 and @UIDFound <> @theId))
		begin
			RAISERROR ('Diagram does not exist or you do not have permission.', 16, 1)
			return -3
		end
	
		-- if((@u_name is not null) and (@new_diagramname = @diagramname))	-- nothing will change
		--	return 0;
	
		if(@u_name is null)
			select @DiagIdTarg = diagram_id from dbo.sysdiagrams where principal_id = @theId and name = @new_diagramname
		else
			select @DiagIdTarg = diagram_id from dbo.sysdiagrams where principal_id = @owner_id and name = @new_diagramname
	
		if((@DiagIdTarg is not null) and  @DiagId <> @DiagIdTarg)
		begin
			RAISERROR ('The name is already used.', 16, 1);
			return -2
		end		
	
		if(@u_name is null)
			update dbo.sysdiagrams set [name] = @new_diagramname, principal_id = @theId where diagram_id = @DiagId
		else
			update dbo.sysdiagrams set [name] = @new_diagramname where diagram_id = @DiagId
		return 0
	END
	
GO
/****** Object:  StoredProcedure [dbo].[sp_upgraddiagrams]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE PROCEDURE [dbo].[sp_upgraddiagrams]
	AS
	BEGIN
		IF OBJECT_ID(N'dbo.sysdiagrams') IS NOT NULL
			return 0;
	
		CREATE TABLE dbo.sysdiagrams
		(
			name sysname NOT NULL,
			principal_id int NOT NULL,	-- we may change it to varbinary(85)
			diagram_id int PRIMARY KEY IDENTITY,
			version int,
	
			definition varbinary(max)
			CONSTRAINT UK_principal_name UNIQUE
			(
				principal_id,
				name
			)
		);


		/* Add this if we need to have some form of extended properties for diagrams */
		/*
		IF OBJECT_ID(N'dbo.sysdiagram_properties') IS NULL
		BEGIN
			CREATE TABLE dbo.sysdiagram_properties
			(
				diagram_id int,
				name sysname,
				value varbinary(max) NOT NULL
			)
		END
		*/

		IF OBJECT_ID(N'dbo.dtproperties') IS NOT NULL
		begin
			insert into dbo.sysdiagrams
			(
				[name],
				[principal_id],
				[version],
				[definition]
			)
			select	 
				convert(sysname, dgnm.[uvalue]),
				DATABASE_PRINCIPAL_ID(N'dbo'),			-- will change to the sid of sa
				0,							-- zero for old format, dgdef.[version],
				dgdef.[lvalue]
			from dbo.[dtproperties] dgnm
				inner join dbo.[dtproperties] dggd on dggd.[property] = 'DtgSchemaGUID' and dggd.[objectid] = dgnm.[objectid]	
				inner join dbo.[dtproperties] dgdef on dgdef.[property] = 'DtgSchemaDATA' and dgdef.[objectid] = dgnm.[objectid]
				
			where dgnm.[property] = 'DtgSchemaNAME' and dggd.[uvalue] like N'_EA3E6268-D998-11CE-9454-00AA00A3F36E_' 
			return 2;
		end
		return 1;
	END
	
GO
/****** Object:  StoredProcedure [dbo].[SubscribeUserOnEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Sheydakov Vadim
-- Create date: 26.12.2008
-- Description:	Подписка пользователя на событие.
-- =============================================

CREATE PROCEDURE [dbo].[SubscribeUserOnEvent]
	@UserID int,
	@EventID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @UserGroupID INT,
			@IsGroupEvent BIT

	SET @IsGroupEvent = 'False'

	DECLARE UserGroupIDs_Cursor CURSOR FOR 
		SELECT DISTINCT P2G.GroupID
		FROM Person2Group P2G
		WHERE P2G.PersonID = @UserID

    OPEN UserGroupIDs_Cursor
    FETCH NEXT FROM UserGroupIDs_Cursor INTO @UserGroupID

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF (EXISTS ( SELECT * FROM GroupEvents GE WHERE GE.EventID = @EventID AND GE.GroupID = @UserGroupID))
		BEGIN
			SET @IsGroupEvent = 'True'
			BREAK
		END

		FETCH NEXT FROM UserGroupIDs_Cursor INTO @UserGroupID
	END

    CLOSE UserGroupIDs_Cursor
    DEALLOCATE UserGroupIDs_Cursor
	
	-- Subscribe
	IF (@IsGroupEvent = 'True')
		DELETE FROM UserEvents 
			WHERE UserEvents.UserID = @UserID 
				AND UserEvents.EventID = @EventID 
				AND UserEvents.IsIgnore = 'True'
	ELSE
		IF (NOT EXISTS ( SELECT * FROM UserEvents UE WHERE UE.UserID = @UserID AND UE.EventID = @EventID))
			INSERT INTO UserEvents (UserID, EventID) VALUES (@UserID, @EventID)
		ELSE
			UPDATE UserEvents SET UserEvents.IsIgnore = 'False'
				WHERE UserEvents.UserID = @UserID AND UserEvents.EventID = @EventID

END






GO
/****** Object:  StoredProcedure [dbo].[TestStoredProcedure]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[TestStoredProcedure]
	(
	@UserId int,
	@beginDate datetime,
	@endDate datetime
	)
AS

SELECT BeginTime, EndTime, Duration, UptimeEventTypeID FROM UptimeEvents WHERE (UserID=@UserID AND BeginTime >=Convert(datetime,@beginDate))

RETURN

GO
/****** Object:  StoredProcedure [dbo].[uiGetListPage]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


create  PROCEDURE [dbo].[uiGetListPage]
   @PageIndex 	INT,	
   @PageSize 	INT,
   @OrderField 	NVARCHAR(64),
   @IsOrderASC 	BIT,
   @TotalCount  INT,
   @Query 	NVARCHAR(4000)
AS
/*
	Возвращает результат запроса с учетом пейджинга
*/
SET XACT_ABORT ON

DECLARE @Order1 AS NVARCHAR(6)
DECLARE @Order2 AS NVARCHAR(6)

IF (@IsOrderASC = 1)
BEGIN
   SET @Order1 = ' ASC '
   SET @Order2 = ' DESC '
END
ELSE
BEGIN
   SET @Order1 = ' DESC '
   SET @Order2 = ' ASC '
END

DECLARE @Count INT
SET @Count = @TotalCount - @PageIndex * @PageSize

IF @Count < 0 SET @Count = 0

DECLARE @SQL AS NVARCHAR(4000)
SET @SQL = 
    'SELECT TOP ' + CAST(@PageSize AS NVARCHAR(16)) + ' * FROM
            (SELECT TOP ' + CAST(@Count AS NVARCHAR(16)) + ' * FROM (' + @Query + ') SO0 ORDER BY ' + @OrderField + @Order2 + ') SO1 ' +
    ' ORDER BY ' + @OrderField + @Order1

print @SQL 

EXEC (@SQL)


GO
/****** Object:  StoredProcedure [dbo].[uiGetObjectsPage]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE procedure [dbo].[uiGetObjectsPage]
	@PageIndex int,
	@PageSize int,
	@OrderField nvarchar(64),
	@IsOrderASC bit,
	@Query nvarchar(4000)
as
begin
	if @OrderField = ''
		set @OrderField = 'ID'
	
	-- Вычислить общее количество записей
	declare @countQuery nvarchar(4000)
	declare @totalCount int
	set @countQuery = N'with T as (' + @Query + ') select @TotalCountOut = count(1) from T'
	exec sp_executesql @countQuery, N'@TotalCountOut int output', @TotalCountOut = @totalCount output

	exec uiGetListPage @PageIndex, @PageSize, @OrderField, @IsOrderASC, @TotalCount, @Query
	return @TotalCount
end




GO
/****** Object:  StoredProcedure [dbo].[UnSubscribeUserEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Sheydakov Vadim
-- Create date: 26.12.2008
-- Description:	Отписка юзера от события.
-- =============================================

CREATE PROCEDURE [dbo].[UnSubscribeUserEvent]
	@UserID int,
	@EventID int
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	DECLARE @UserGroupID INT,
			@IsGroupEvent BIT

	SET @IsGroupEvent = 'False'

	DECLARE UserGroupIDs_Cursor CURSOR FOR 
		SELECT DISTINCT P2G.GroupID
		FROM Person2Group P2G
		WHERE P2G.PersonID = @UserID

    OPEN UserGroupIDs_Cursor
    FETCH NEXT FROM UserGroupIDs_Cursor INTO @UserGroupID

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF (EXISTS ( SELECT * FROM GroupEvents GE WHERE GE.EventID = @EventID AND GE.GroupID = @UserGroupID))
		BEGIN
			SET @IsGroupEvent = 'True'
			BREAK
		END

		FETCH NEXT FROM UserGroupIDs_Cursor INTO @UserGroupID
	END

    CLOSE UserGroupIDs_Cursor
    DEALLOCATE UserGroupIDs_Cursor

	-- UnSubscribe
	IF (@IsGroupEvent = 'True')
		BEGIN
			IF (NOT EXISTS ( SELECT * FROM UserEvents UE WHERE UE.UserID = @UserID AND UE.EventID = @EventID AND UE.IsIgnore = 'True'))
				INSERT INTO UserEvents (UserID, EventID, IsIgnore) VALUES (@UserID, @EventID, 'True')
		END
	ELSE
		DELETE FROM UserEvents 
			WHERE UserEvents.UserID = @UserID 
				AND UserEvents.EventID = @EventID 
				AND UserEvents.IsIgnore = 'False'

END











GO
/****** Object:  StoredProcedure [dbo].[UpdateUptimeEvent]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[UpdateUptimeEvent] 
(
@ID int,
@Name nvarchar(50),
@BeginTime datetime,
@EndTime datetime,
@Duration int,
@ProjectID int,
@WorkCategoryID int,
@UptimeEventTypeID int
)
AS
UPDATE UptimeEvents 
SET 
[Name]=@Name,
BeginTime=@BeginTime,
EndTime=@EndTime,
Duration=@Duration,
ProjectID=@ProjectID,
WorkCategoryID=@WorkCategoryID,
UptimeEventTypeID=@UptimeEventTypeID
WHERE ID=@ID
GO
/****** Object:  StoredProcedure [dbo].[UpdateUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- Author:		Ivan Yakimov
-- Create date: 08.08.2007
-- Description:	Процедура изменения данных пользователя.
-- =============================================
CREATE PROCEDURE [dbo].[UpdateUser]
	-- Add the parameters for the stored procedure here
	@UserID int,
	@FirstNameRus nvarchar(50),
	@MiddleNameRus nvarchar(50),
	@LastNameRus nvarchar(100),
	@FirstNameEng nvarchar(50),
	@InitialEng nvarchar(1),
	@LastNameEng nvarchar(100),
	@Sex smallint,
	@Birthday datetime,
	@DomainName nvarchar(50),
	@PrimaryEMail nvarchar(50),
	@Project nvarchar(50),
	@Room nvarchar(5),
	@PrimaryIP nvarchar(23),
	@LongServiceEmployees bit,
	@PersonnelReserve bit,
	@EmployeesUlterSYSMoscow bit
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	UPDATE Users
	SET
		FName = @FirstNameRus, 
		IName = @MiddleNameRus, 
		LName = @LastNameRus, 
		nlFName = @FirstNameEng,
		Initial = @InitialEng,
		nlLName = @LastNameEng,
		Sex = @Sex,
		Birthday = @Birthday,
		DomainName = @DomainName,
		PrimaryEMail = @PrimaryEMail,
		Project = @Project,
		Room = @Room,
		PrimaryIP = @PrimaryIP,
		LongServiceEmployees = @LongServiceEmployees,
		PersonnelReserve = @PersonnelReserve,
		EmployeesUlterSYSMoscow = @EmployeesUlterSYSMoscow
	WHERE ID = @UserID
END

GO
/****** Object:  UserDefinedFunction [dbo].[fn_diagramobjects]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	CREATE FUNCTION [dbo].[fn_diagramobjects]() 
	RETURNS int
	WITH EXECUTE AS N'dbo'
	AS
	BEGIN
		declare @id_upgraddiagrams		int
		declare @id_sysdiagrams			int
		declare @id_helpdiagrams		int
		declare @id_helpdiagramdefinition	int
		declare @id_creatediagram	int
		declare @id_renamediagram	int
		declare @id_alterdiagram 	int 
		declare @id_dropdiagram		int
		declare @InstalledObjects	int

		select @InstalledObjects = 0

		select 	@id_upgraddiagrams = object_id(N'dbo.sp_upgraddiagrams'),
			@id_sysdiagrams = object_id(N'dbo.sysdiagrams'),
			@id_helpdiagrams = object_id(N'dbo.sp_helpdiagrams'),
			@id_helpdiagramdefinition = object_id(N'dbo.sp_helpdiagramdefinition'),
			@id_creatediagram = object_id(N'dbo.sp_creatediagram'),
			@id_renamediagram = object_id(N'dbo.sp_renamediagram'),
			@id_alterdiagram = object_id(N'dbo.sp_alterdiagram'), 
			@id_dropdiagram = object_id(N'dbo.sp_dropdiagram')

		if @id_upgraddiagrams is not null
			select @InstalledObjects = @InstalledObjects + 1
		if @id_sysdiagrams is not null
			select @InstalledObjects = @InstalledObjects + 2
		if @id_helpdiagrams is not null
			select @InstalledObjects = @InstalledObjects + 4
		if @id_helpdiagramdefinition is not null
			select @InstalledObjects = @InstalledObjects + 8
		if @id_creatediagram is not null
			select @InstalledObjects = @InstalledObjects + 16
		if @id_renamediagram is not null
			select @InstalledObjects = @InstalledObjects + 32
		if @id_alterdiagram  is not null
			select @InstalledObjects = @InstalledObjects + 64
		if @id_dropdiagram is not null
			select @InstalledObjects = @InstalledObjects + 128
		
		return @InstalledObjects 
	END
	
GO
/****** Object:  UserDefinedFunction [dbo].[GetRequestObjectHolderID]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		VadimS
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[GetRequestObjectHolderID]
(
	-- Add the parameters for the function here
	@ObjectID INT
)
RETURNS INT
AS
BEGIN
	DECLARE @OwnerID INT, @LastOperationDate DATETIME

	SET @OwnerID = (SELECT OwnerID FROM [RequestObject] WHERE ID = @ObjectID) 
	SET @LastOperationDate = (SELECT MAX(DATE) FROM [Requests] WHERE ObjectID = @ObjectID) 

	IF (@LastOperationDate is null) 
	BEGIN
		 RETURN @OwnerID
	END 

	RETURN (SELECT 
		CASE WHEN IsTaken = 0 
		THEN @OwnerID 
		ELSE UserID 
		END as holderID 
	FROM [Requests] 
	WHERE Date = @LastOperationDate AND ObjectID = @ObjectID )
END

GO
/****** Object:  UserDefinedFunction [dbo].[GetRequestObjectType]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  UserDefinedFunction [dbo].[GetRequestObjectType]    Script Date: 04/15/2010 15:57:08 ******/
-- =============================================
-- Author:		VadimS
-- Description:	GetRequestObjectType
-- =============================================
CREATE FUNCTION [dbo].[GetRequestObjectType]
(
	@ObjectID INT
)
RETURNS NVARCHAR(50)
AS
BEGIN
	IF (EXISTS (SELECT ID FROM Disks WHERE ID = @ObjectID))
		RETURN 'Disk'

	IF (EXISTS (SELECT ID FROM DiscountCard WHERE ID = @ObjectID))
		RETURN 'Card'

	IF (EXISTS (SELECT ID FROM Books_Books WHERE ID = @ObjectID))
		RETURN 'Book'
	
	RETURN 'UNKNOWN'
END

GO
/****** Object:  Table [dbo].[Ability]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Ability](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_Ability] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AbilityUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AbilityUser](
	[PersonID] [int] NOT NULL,
	[AbilityID] [int] NOT NULL,
 CONSTRAINT [PK_AbilityUser] PRIMARY KEY CLUSTERED 
(
	[PersonID] ASC,
	[AbilityID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[AllowTags]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AllowTags](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[tagName] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_AllowTags] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Arrangement]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Arrangement](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[ConferenceHallID] [int] NOT NULL,
	[TimeBegin] [datetime] NOT NULL,
	[TimeEnd] [datetime] NOT NULL,
	[ListOfGuests] [nvarchar](max) NULL,
	[Equipment] [nvarchar](max) NULL,
 CONSTRAINT [PK_Arrangement] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ArrangementDate]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ArrangementDate](
	[ArrangementID] [int] NOT NULL,
	[Date] [datetime] NOT NULL,
 CONSTRAINT [PK_ArrangementDate] PRIMARY KEY CLUSTERED 
(
	[ArrangementID] ASC,
	[Date] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Books]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Books](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Title] [nvarchar](255) NOT NULL,
	[Autors] [nvarchar](255) NULL,
	[ISBNrus] [nvarchar](25) NULL,
	[ISBNeng] [nvarchar](25) NULL,
	[PublishingHouse] [nvarchar](50) NULL,
	[Notes] [ntext] NULL,
	[Bought] [bit] NULL,
	[Price] [money] NULL,
	[BuyPlace] [nvarchar](100) NULL,
	[BuyDate] [datetime] NULL,
	[Prim] [text] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Books_Books]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Books_Books](
	[ID] [int] NOT NULL,
	[Authors] [nvarchar](max) NOT NULL,
	[PublishingYear] [int] NOT NULL,
	[Annotation] [nvarchar](max) NOT NULL,
	[Language] [nvarchar](100) NOT NULL,
	[DownloadLink] [nvarchar](max) NULL,
	[IsElectronic] [bit] NOT NULL,
 CONSTRAINT [PK_Books_Books] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Books_BookThemes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Books_BookThemes](
	[BookID] [int] NOT NULL,
	[ThemeID] [int] NOT NULL,
 CONSTRAINT [PK_Books_BookThemes] PRIMARY KEY CLUSTERED 
(
	[BookID] ASC,
	[ThemeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Books_Themes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Books_Themes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Books_Themes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Calendar]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Calendar](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NOT NULL,
	[WorkTime] [datetime] NOT NULL,
	[Comment] [nvarchar](max) NULL,
 CONSTRAINT [PK_Calendar] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ConferenceHall]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ConferenceHall](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[OfficeID] [int] NOT NULL,
 CONSTRAINT [PK_ConferenceHall] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[DiscountCard]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[DiscountCard](
	[ID] [int] NOT NULL,
	[ValuePercent] [tinyint] NOT NULL,
	[ShopName] [nvarchar](255) NULL,
	[ShopSite] [nvarchar](255) NULL,
 CONSTRAINT [PK_DiscountCard] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Disks]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Disks](
	[ID] [int] NOT NULL,
	[Manufacturers] [nvarchar](max) NOT NULL,
	[PublishingYear] [int] NOT NULL,
	[Annotation] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_1_Disks] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Events]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Events](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NOT NULL,
	[Title] [nvarchar](50) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[DateFormat] [nvarchar](50) NULL,
	[OwnerID] [int] NOT NULL,
	[IsPublic] [bit] NOT NULL,
 CONSTRAINT [PK_Event] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[EventTypes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[EventTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[TypeID] [nvarchar](100) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[ForeColor] [char](6) NULL,
	[BackColor] [char](6) NULL,
 CONSTRAINT [PK_EmployeeEventTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Games]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Games](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
	[MaximumPlayers] [int] NOT NULL,
 CONSTRAINT [PK_Games] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[GroupEvents]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[GroupEvents](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[GroupID] [int] NOT NULL,
	[EventID] [int] NOT NULL,
 CONSTRAINT [PK_GroupEvents] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Groups]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Groups](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[GroupID] [nvarchar](100) NOT NULL,
	[Name] [nvarchar](max) NOT NULL,
	[Description] [nvarchar](max) NULL,
 CONSTRAINT [PK_Groups] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[InternetUsers]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[InternetUsers](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[Password] [nvarchar](50) NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[MailsStorage]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MailsStorage](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NOT NULL,
	[IsSend] [bit] NOT NULL,
	[FromAddress] [nvarchar](255) NOT NULL,
	[ToAddress] [nvarchar](500) NOT NULL,
	[Subject] [nvarchar](500) NOT NULL,
	[Body] [nvarchar](max) NOT NULL,
	[IsHTML] [bit] NOT NULL,
	[MessageType] [int] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Matches]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Matches](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[GameID] [int] NOT NULL,
	[Date] [datetime] NOT NULL,
	[State] [int] NOT NULL,
 CONSTRAINT [PK_Matches] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[News]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[News](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Caption] [nvarchar](max) NOT NULL,
	[Text] [nvarchar](max) NOT NULL,
	[AuthorID] [int] NOT NULL,
	[CreateTime] [datetime] NOT NULL,
	[ExpireTime] [datetime] NOT NULL,
	[OfficeID] [int] NOT NULL,
	[PostID] [int] NULL,
 CONSTRAINT [PK_News] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NewsAttachments]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NewsAttachments](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[NewsID] [int] NOT NULL,
	[FileName] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Attachments] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NotificationLists]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[NotificationLists](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[EMail] [nvarchar](100) NOT NULL,
	[Type] [int] NOT NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Offices]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Offices](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[OfficeName] [nvarchar](255) NOT NULL,
	[StatusesServiceURL] [nvarchar](1000) NULL,
	[StatusesServiceUserName] [nvarchar](50) NULL,
	[StatusesServicePassword] [nvarchar](50) NULL,
	[MeteoInformer] [nvarchar](255) NULL,
	[ClockInformer] [nvarchar](1024) NULL,
	[DigitalClockInformer] [nvarchar](1024) NULL,
 CONSTRAINT [PK_Offices] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Person2Group]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Person2Group](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PersonID] [int] NOT NULL,
	[GroupID] [int] NOT NULL,
 CONSTRAINT [PK_Person2Group] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PersonAttributes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PersonAttributes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PersonID] [int] NOT NULL,
	[InsertionDate] [datetime] NOT NULL,
	[AttributeID] [int] NOT NULL,
	[ValueType] [nvarchar](500) NOT NULL,
	[StringField] [nvarchar](max) NULL,
	[IntegerField] [int] NULL,
	[DoubleField] [float] NULL,
	[BooleanField] [bit] NULL,
	[DateTimeField] [datetime] NULL,
	[BinaryField] [varbinary](max) NULL,
 CONSTRAINT [PK_PersonAttributes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[PersonAttributeTypes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PersonAttributeTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[AttributeName] [nvarchar](50) NOT NULL,
	[IsShownToUsers] [bit] NOT NULL,
 CONSTRAINT [PK_PersonAttributeTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UK_PersonAttributeTypes] UNIQUE NONCLUSTERED 
(
	[AttributeName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PlayerEarnedPoints]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PlayerEarnedPoints](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[MatchID] [int] NOT NULL,
	[UserID] [int] NOT NULL,
	[Points] [int] NULL,
 CONSTRAINT [PK_EarnedPoints] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PortalAdmins]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[PortalAdmins](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
 CONSTRAINT [PK_PortalAdmins] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Projects]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Projects](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Description] [text] NULL,
 CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[ProjectUser]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProjectUser](
	[UserID] [int] NOT NULL,
	[ProjectID] [int] NOT NULL,
	[UserInProject] [int] NOT NULL,
 CONSTRAINT [PK_ProjectUser] PRIMARY KEY CLUSTERED 
(
	[UserID] ASC,
	[ProjectID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Request]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Request](
	[ID] [int] NOT NULL,
	[ObjectID] [int] NOT NULL,
 CONSTRAINT [PK_Request] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RequestObject]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[RequestObject](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Title] [nvarchar](max) NOT NULL,
	[OwnerID] [int] NULL,
	[OfficeID] [int] NOT NULL,
 CONSTRAINT [PK_1_RequsetObject] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Requests]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Requests](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NULL,
	[ObjectID] [int] NOT NULL,
	[Date] [datetime] NOT NULL,
	[IsTaken] [bit] NOT NULL,
 CONSTRAINT [PK_Requests] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Settings]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Settings](
	[ID] [int] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Value] [nvarchar](max) NULL,
 CONSTRAINT [PK_Settings] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[sysdiagrams]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[sysdiagrams](
	[name] [sysname] NOT NULL,
	[principal_id] [int] NOT NULL,
	[diagram_id] [int] IDENTITY(1,1) NOT NULL,
	[version] [int] NULL,
	[definition] [varbinary](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[diagram_id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY],
 CONSTRAINT [UK_principal_name] UNIQUE NONCLUSTERED 
(
	[principal_id] ASC,
	[name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UptimeEvents]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UptimeEvents](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[BeginTime] [datetime] NOT NULL,
	[EndTime] [datetime] NOT NULL,
	[Duration] [int] NULL,
	[UserID] [int] NOT NULL,
	[ProjectID] [int] NULL,
	[WorkCategoryID] [int] NULL,
	[UptimeEventTypeID] [int] NOT NULL,
 CONSTRAINT [PK_Events] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UptimeEventTypes]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UptimeEventTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](1000) NOT NULL,
	[Description] [nvarchar](max) NULL,
	[Color] [char](6) NULL,
 CONSTRAINT [PK_Event_types] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserEvents]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserEvents](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[EventID] [int] NOT NULL,
	[IsIgnore] [bit] NOT NULL,
 CONSTRAINT [PK_UserEvents] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UserGameRatings]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UserGameRatings](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[GameID] [int] NOT NULL,
	[RatingType] [int] NOT NULL,
	[Rating] [int] NOT NULL,
 CONSTRAINT [PK_UserRatings] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Users]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Users](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Sex] [smallint] NOT NULL,
	[Birthday] [datetime] NULL,
	[DomainName] [nvarchar](50) NULL,
	[PrimaryEMail] [nvarchar](50) NULL,
	[Project] [nvarchar](50) NULL,
	[Room] [nvarchar](5) NULL,
	[PrimaryIP] [nvarchar](23) NULL,
	[LongServiceEmployees] [bit] NOT NULL,
	[PersonnelReserve] [bit] NOT NULL,
	[EmployeesUlterSYSMoscow] [bit] NOT NULL,
	[FirstName] [varchar](255) NULL,
	[MiddleName] [varchar](255) NULL,
	[LastName] [varchar](255) NULL,
 CONSTRAINT [PK_p_User] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UsersDeliveries]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UsersDeliveries](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserID] [int] NOT NULL,
	[DeliveryID] [int] NOT NULL,
	[DeliveryPresentation] [int] NOT NULL,
	[StatisticsUserID] [int] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[VersionInfo]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[VersionInfo](
	[Version] [bigint] NOT NULL,
	[AppliedOn] [datetime] NULL,
	[Description] [nvarchar](1024) NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[WorkCategories]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[WorkCategories](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[Description] [text] NULL,
 CONSTRAINT [PK_Work_categories] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  View [dbo].[AllInOffice]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[AllInOffice]
AS
SELECT     TOP (100) PERCENT dbo.Users.FName, dbo.Users.LName, dbo.Users.PrimaryEMail, MAX(dbo.UptimeEvents.BeginTime) AS BeginTime
FROM         dbo.UptimeEvents INNER JOIN
                      dbo.Users ON dbo.UptimeEvents.UserID = dbo.Users.ID
WHERE     (dbo.Users.LongServiceEmployees = 1)
GROUP BY dbo.Users.FName, dbo.Users.LName, dbo.Users.PrimaryEMail
ORDER BY BeginTime

GO
/****** Object:  View [dbo].[UsersOfYaroslavl]    Script Date: 21.04.2015 15:24:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[UsersOfYaroslavl]
AS
SELECT     ID, FName, IName, LName, PrimaryEMail, Birthday, Room, Project
FROM         dbo.Users
WHERE     (LongServiceEmployees = 1)

GO
ALTER TABLE [dbo].[Books_Books] ADD  CONSTRAINT [DF_Books_Books_IsElectronic]  DEFAULT ((1)) FOR [IsElectronic]
GO
ALTER TABLE [dbo].[Events] ADD  CONSTRAINT [DF_Events_IsPublic]  DEFAULT ((1)) FOR [IsPublic]
GO
ALTER TABLE [dbo].[PersonAttributeTypes] ADD  CONSTRAINT [DF_PersonAttributeTypes_IsShownToUsers]  DEFAULT ((1)) FOR [IsShownToUsers]
GO
ALTER TABLE [dbo].[UptimeEvents] ADD  CONSTRAINT [DF_Events_Begin_time]  DEFAULT (getdate()) FOR [BeginTime]
GO
ALTER TABLE [dbo].[UptimeEvents] ADD  CONSTRAINT [DF_Events_End_time]  DEFAULT (getdate()) FOR [EndTime]
GO
ALTER TABLE [dbo].[UptimeEvents] ADD  CONSTRAINT [DF_UptimeEvents_ProjectID]  DEFAULT (1) FOR [ProjectID]
GO
ALTER TABLE [dbo].[UptimeEvents] ADD  CONSTRAINT [DF_UptimeEvents_WorkCategoryID]  DEFAULT (1) FOR [WorkCategoryID]
GO
ALTER TABLE [dbo].[UptimeEvents] ADD  CONSTRAINT [DF_UptimeEvents_UptimeEventTypeID]  DEFAULT (1) FOR [UptimeEventTypeID]
GO
ALTER TABLE [dbo].[UserEvents] ADD  CONSTRAINT [DF_UserEvents_IsIgnore]  DEFAULT ((0)) FOR [IsIgnore]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_Sex]  DEFAULT ((0)) FOR [Sex]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_LongServiceEmployees]  DEFAULT ((0)) FOR [LongServiceEmployees]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_PersonnelReserve]  DEFAULT ((0)) FOR [PersonnelReserve]
GO
ALTER TABLE [dbo].[Users] ADD  CONSTRAINT [DF_Users_EmployeesUlterSYSMoscow]  DEFAULT ((0)) FOR [EmployeesUlterSYSMoscow]
GO
ALTER TABLE [dbo].[AbilityUser]  WITH CHECK ADD  CONSTRAINT [FK_AbilityUser_Ability] FOREIGN KEY([AbilityID])
REFERENCES [dbo].[Ability] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AbilityUser] CHECK CONSTRAINT [FK_AbilityUser_Ability]
GO
ALTER TABLE [dbo].[AbilityUser]  WITH CHECK ADD  CONSTRAINT [FK_AbilityUser_Users] FOREIGN KEY([PersonID])
REFERENCES [dbo].[Users] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[AbilityUser] CHECK CONSTRAINT [FK_AbilityUser_Users]
GO
ALTER TABLE [dbo].[Arrangement]  WITH CHECK ADD  CONSTRAINT [FK_Arrangement_ConferenceHall] FOREIGN KEY([ConferenceHallID])
REFERENCES [dbo].[ConferenceHall] ([ID])
GO
ALTER TABLE [dbo].[Arrangement] CHECK CONSTRAINT [FK_Arrangement_ConferenceHall]
GO
ALTER TABLE [dbo].[ArrangementDate]  WITH CHECK ADD  CONSTRAINT [FK_ArrangementDate_Arrangement] FOREIGN KEY([ArrangementID])
REFERENCES [dbo].[Arrangement] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ArrangementDate] CHECK CONSTRAINT [FK_ArrangementDate_Arrangement]
GO
ALTER TABLE [dbo].[Books_Books]  WITH CHECK ADD  CONSTRAINT [FK_Books_Books_RequestObject] FOREIGN KEY([ID])
REFERENCES [dbo].[RequestObject] ([ID])
GO
ALTER TABLE [dbo].[Books_Books] CHECK CONSTRAINT [FK_Books_Books_RequestObject]
GO
ALTER TABLE [dbo].[Books_BookThemes]  WITH CHECK ADD  CONSTRAINT [FK_Books_BookThemes_Books_Books] FOREIGN KEY([BookID])
REFERENCES [dbo].[Books_Books] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Books_BookThemes] CHECK CONSTRAINT [FK_Books_BookThemes_Books_Books]
GO
ALTER TABLE [dbo].[Books_BookThemes]  WITH CHECK ADD  CONSTRAINT [FK_Books_BookThemes_Books_BookThemes] FOREIGN KEY([BookID], [ThemeID])
REFERENCES [dbo].[Books_BookThemes] ([BookID], [ThemeID])
GO
ALTER TABLE [dbo].[Books_BookThemes] CHECK CONSTRAINT [FK_Books_BookThemes_Books_BookThemes]
GO
ALTER TABLE [dbo].[Books_BookThemes]  WITH CHECK ADD  CONSTRAINT [FK_Books_BookThemes_Books_Themes] FOREIGN KEY([ThemeID])
REFERENCES [dbo].[Books_Themes] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Books_BookThemes] CHECK CONSTRAINT [FK_Books_BookThemes_Books_Themes]
GO
ALTER TABLE [dbo].[ConferenceHall]  WITH CHECK ADD  CONSTRAINT [FK_ConferenceHall_Offices] FOREIGN KEY([OfficeID])
REFERENCES [dbo].[Offices] ([ID])
GO
ALTER TABLE [dbo].[ConferenceHall] CHECK CONSTRAINT [FK_ConferenceHall_Offices]
GO
ALTER TABLE [dbo].[DiscountCard]  WITH CHECK ADD  CONSTRAINT [FK_DiscountCard_RequestObject] FOREIGN KEY([ID])
REFERENCES [dbo].[RequestObject] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[DiscountCard] CHECK CONSTRAINT [FK_DiscountCard_RequestObject]
GO
ALTER TABLE [dbo].[Disks]  WITH CHECK ADD  CONSTRAINT [FK_1_Disks_1_RequsetObject] FOREIGN KEY([ID])
REFERENCES [dbo].[RequestObject] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Disks] CHECK CONSTRAINT [FK_1_Disks_1_RequsetObject]
GO
ALTER TABLE [dbo].[GroupEvents]  WITH CHECK ADD  CONSTRAINT [FK_GroupEvents_Events] FOREIGN KEY([EventID])
REFERENCES [dbo].[Events] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[GroupEvents] CHECK CONSTRAINT [FK_GroupEvents_Events]
GO
ALTER TABLE [dbo].[GroupEvents]  WITH CHECK ADD  CONSTRAINT [FK_GroupEvents_Groups] FOREIGN KEY([GroupID])
REFERENCES [dbo].[Groups] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[GroupEvents] CHECK CONSTRAINT [FK_GroupEvents_Groups]
GO
ALTER TABLE [dbo].[News]  WITH CHECK ADD  CONSTRAINT [FK_News_Users] FOREIGN KEY([AuthorID])
REFERENCES [dbo].[Users] ([ID])
GO
ALTER TABLE [dbo].[News] CHECK CONSTRAINT [FK_News_Users]
GO
ALTER TABLE [dbo].[PersonAttributes]  WITH CHECK ADD  CONSTRAINT [FK_PersonAttributes_PersonAttributes] FOREIGN KEY([AttributeID])
REFERENCES [dbo].[PersonAttributeTypes] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[PersonAttributes] CHECK CONSTRAINT [FK_PersonAttributes_PersonAttributes]
GO
ALTER TABLE [dbo].[ProjectUser]  WITH CHECK ADD  CONSTRAINT [FK_ProjectUser_Projects] FOREIGN KEY([ProjectID])
REFERENCES [dbo].[Projects] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ProjectUser] CHECK CONSTRAINT [FK_ProjectUser_Projects]
GO
ALTER TABLE [dbo].[ProjectUser]  WITH CHECK ADD  CONSTRAINT [FK_ProjectUser_Users] FOREIGN KEY([UserID])
REFERENCES [dbo].[Users] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[ProjectUser] CHECK CONSTRAINT [FK_ProjectUser_Users]
GO
ALTER TABLE [dbo].[RequestObject]  WITH CHECK ADD  CONSTRAINT [FK_1_RequsetObject_Offices] FOREIGN KEY([OfficeID])
REFERENCES [dbo].[Offices] ([ID])
GO
ALTER TABLE [dbo].[RequestObject] CHECK CONSTRAINT [FK_1_RequsetObject_Offices]
GO
ALTER TABLE [dbo].[RequestObject]  WITH CHECK ADD  CONSTRAINT [FK_1_RequsetObject_Users] FOREIGN KEY([OwnerID])
REFERENCES [dbo].[Users] ([ID])
GO
ALTER TABLE [dbo].[RequestObject] CHECK CONSTRAINT [FK_1_RequsetObject_Users]
GO
ALTER TABLE [dbo].[Requests]  WITH CHECK ADD  CONSTRAINT [FK_Requests_RequestObject] FOREIGN KEY([ObjectID])
REFERENCES [dbo].[RequestObject] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[Requests] CHECK CONSTRAINT [FK_Requests_RequestObject]
GO
ALTER TABLE [dbo].[Requests]  WITH CHECK ADD  CONSTRAINT [FK_Requests_Users] FOREIGN KEY([UserID])
REFERENCES [dbo].[Users] ([ID])
GO
ALTER TABLE [dbo].[Requests] CHECK CONSTRAINT [FK_Requests_Users]
GO
ALTER TABLE [dbo].[UptimeEvents]  WITH NOCHECK ADD  CONSTRAINT [FK_Events_Event_types] FOREIGN KEY([UptimeEventTypeID])
REFERENCES [dbo].[UptimeEventTypes] ([ID])
GO
ALTER TABLE [dbo].[UptimeEvents] CHECK CONSTRAINT [FK_Events_Event_types]
GO
ALTER TABLE [dbo].[UptimeEvents]  WITH NOCHECK ADD  CONSTRAINT [FK_Events_Projects] FOREIGN KEY([ProjectID])
REFERENCES [dbo].[Projects] ([ID])
GO
ALTER TABLE [dbo].[UptimeEvents] CHECK CONSTRAINT [FK_Events_Projects]
GO
ALTER TABLE [dbo].[UptimeEvents]  WITH NOCHECK ADD  CONSTRAINT [FK_Events_Users] FOREIGN KEY([UserID])
REFERENCES [dbo].[Users] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UptimeEvents] CHECK CONSTRAINT [FK_Events_Users]
GO
ALTER TABLE [dbo].[UptimeEvents]  WITH NOCHECK ADD  CONSTRAINT [FK_Events_Work_categories] FOREIGN KEY([WorkCategoryID])
REFERENCES [dbo].[WorkCategories] ([ID])
GO
ALTER TABLE [dbo].[UptimeEvents] CHECK CONSTRAINT [FK_Events_Work_categories]
GO
ALTER TABLE [dbo].[UserEvents]  WITH CHECK ADD  CONSTRAINT [FK_UserEvents_Events] FOREIGN KEY([EventID])
REFERENCES [dbo].[Events] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UserEvents] CHECK CONSTRAINT [FK_UserEvents_Events]
GO
ALTER TABLE [dbo].[UserEvents]  WITH CHECK ADD  CONSTRAINT [FK_UserEvents_Users] FOREIGN KEY([UserID])
REFERENCES [dbo].[Users] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [dbo].[UserEvents] CHECK CONSTRAINT [FK_UserEvents_Users]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Идентификатор' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Название' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'Title'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Авторы' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'Autors'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ISBN российский' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'ISBNrus'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ISBN страны издателя' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'ISBNeng'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Издательство' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'PublishingHouse'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Описание и содержание' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'Notes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Цена' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'Price'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Место покупки' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'BuyPlace'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Дата покупки' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'BuyDate'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Примечаниия' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books', @level2type=N'COLUMN',@level2name=N'Prim'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Идентификатор книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Books', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Авторы книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Books', @level2type=N'COLUMN',@level2name=N'Authors'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Аннотация к книге.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Books', @level2type=N'COLUMN',@level2name=N'Annotation'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Ссылка для скачивания (только для электронных книг).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Books', @level2type=N'COLUMN',@level2name=N'DownloadLink'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Является ли книга электронной (компьютерный вариант).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Books', @level2type=N'COLUMN',@level2name=N'IsElectronic'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Идентификатор книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_BookThemes', @level2type=N'COLUMN',@level2name=N'BookID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Идентификатор темы книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_BookThemes', @level2type=N'COLUMN',@level2name=N'ThemeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Связь с таблицей книг.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_BookThemes', @level2type=N'CONSTRAINT',@level2name=N'FK_Books_BookThemes_Books_Books'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Связь с таблицей тем книг.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_BookThemes', @level2type=N'CONSTRAINT',@level2name=N'FK_Books_BookThemes_Books_Themes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Идентификатор темы книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Themes', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Тема книги.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Books_Themes', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Уникальный идентификатор.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Дата постановки в таблицу.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'Date'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Отослано ли письмо' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'IsSend'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Адрес отправителя' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'FromAddress'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Одреса получателей, разделенные запятой.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'ToAddress'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Тема письма.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'Subject'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Текст письма.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'Body'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Имеет ли письмо формат HTML.' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'IsHTML'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Тип письма (рассылки).' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'MailsStorage', @level2type=N'COLUMN',@level2name=N'MessageType'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=1965 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Наименование проекта' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Пояснение' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Projects'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=4965 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Описание события' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'BeginTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'BeginTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=1950 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'BeginTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Время начала' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'BeginTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'EndTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'EndTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=1950 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'EndTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Время окончания' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'EndTime'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Duration'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Duration'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Duration'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Продолжительность' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'Duration'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UserID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UserID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UserID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Работник' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UserID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ProjectID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ProjectID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ProjectID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Проект' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'ProjectID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'WorkCategoryID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'WorkCategoryID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'WorkCategoryID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Категория работ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'WorkCategoryID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UptimeEventTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UptimeEventTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UptimeEventTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Тип события' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents', @level2type=N'COLUMN',@level2name=N'UptimeEventTypeID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEvents'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=360 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=3330 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Наименование типа события' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=3435 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Пояснение' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Цвет в формате HHHHHH где H - шестнадцатеричный символ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes', @level2type=N'COLUMN',@level2name=N'Color'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'UptimeEventTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'ID' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Sex'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Sex'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Sex'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Sex'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Sex'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Birthday'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Birthday'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Birthday'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Birthday'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Birthday'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Доменное имя' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'DomainName'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryEMail'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryEMail'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryEMail'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryEMail'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryEMail'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Project'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Project'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Project'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Project'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Project'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Room'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Room'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Room'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Room'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'Room'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryIP'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryIP'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryIP'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryIP'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PrimaryIP'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Постоянные сотрудники' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'LongServiceEmployees'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Кадровый резерв' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'PersonnelReserve'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_AggregateType', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Сотрудники Московского офиса' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TextAlign', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users', @level2type=N'COLUMN',@level2name=N'EmployeesUlterSYSMoscow'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=N'([Users].[LastName] ALike "%<MLText><Text lang=""ru"">Мельников</Text></MLText>%")' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_FilterOnLoad', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_HideNewField', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOnLoad', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TotalsRow', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'Users'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'ID'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=3750 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Наименование категории работ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Name'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnHidden', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnOrder', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_ColumnWidth', @value=-1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Пояснение' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories', @level2type=N'COLUMN',@level2name=N'Description'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DefaultView', @value=0x02 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Filter', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderBy', @value=NULL , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_OrderByOn', @value=0 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Orientation', @value=0x00 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_TableMaxRecords', @value=10000 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'TABLE',@level1name=N'WorkCategories'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[31] 4[16] 2[10] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "UptimeEvents"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 241
               Right = 214
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "Users"
            Begin Extent = 
               Top = 6
               Left = 252
               Bottom = 250
               Right = 507
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1875
         Width = 1905
         Width = 1920
         Width = 1875
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 12
         Column = 2310
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'AllInOffice'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'AllInOffice'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[41] 4[20] 2[6] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4[30] 2[40] 3) )"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2[66] 3) )"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3) )"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 7
   End
   Begin DiagramPane = 
      PaneHidden = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
         Begin Table = "Users"
            Begin Extent = 
               Top = 6
               Left = 38
               Bottom = 264
               Right = 248
            End
            DisplayFlags = 280
            TopColumn = 12
         End
      End
   End
   Begin SQLPane = 
      PaneHidden = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 9
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 2760
      End
   End
   Begin CriteriaPane = 
      PaneHidden = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'UsersOfYaroslavl'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'UsersOfYaroslavl'
GO
