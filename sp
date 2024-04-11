USE [Hosttempo_AirbnbIntegration]
GO

/****** Object:  StoredProcedure [dbo].[Save_ExternalReservation_Host]    Script Date: 11-04-2024 19:04:09 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
CREATE PROC [dbo].[Save_ExternalReservation_Host]  
(  
  @GuestProfileId INT,  
 @ClientId INT,  
 @AddressTypeId INT,  
 @GuestFirstName NVARCHAR(50),  
 @GuestLastName NVARCHAR(50),  
 @PhoneNumber NVARCHAR(18),  
 @Email   NVARCHAR(100),  
 @Address1  NVARCHAR(50),  
 @Address2  NVARCHAR(50),  
 @Address3  NVARCHAR(50),  
 @CityId   INT,  
 @PostalCode  NVARCHAR(9),  
 @CountryId  INT,  
 @StateId  INT,  
 @UpdatedBy   INT,  
 @StatusId    INT,  
 @PartyAddressId INT,  
 @SourceId  INT,  
 @SubSourceId INT,  
 @CrsId   INT,  
 @ReservationId INT,  
 @Ext_ReservationId VARCHAR(50),  
 --@ClientPrice DECIMAL(19,4),  
 @StayInfoId NVARCHAR(50),  
 @notes1  NVARCHAR(2000) = NULL ,  
 @notes2  NVARCHAR(2000) = NULL ,  
 @notes3  NVARCHAR(2000) = NULL ,  
 @lastModified DATETIME,  
 @creator  NVARCHAR(100) = NULL,  
 @CrsConfirmationNumber NVARCHAR(100) = NULL,  
 @CrsPropertyId NVARCHAR(100) = NULL,  
 @StartDate DATETIME2 =NULL,  
 @EndDate DATETIME2 = NULL,  
 @cityname nvarchar(255) = null,  
 @statename nvarchar(255) = null,  
 @countryName nvarchar(255) = null,  
 @MultiStay BIT = 0 ,
 @IntegrationId   INT = NULL
)  
AS  
BEGIN  
 DECLARE @UTCDate DATETIME ,@PartyTypeId INT, @errormessage NVARCHAR(MAX)  
  ,@cancelNoteId INT ,@CountryId_sys INT --,@CountryName NVARCHAR(100)  
  ,@BookedAccount NVARCHAR(200),@operationtype NVARCHAR(MAX), @UnitName NVARCHAR(200), @EmailDate DATETIME  
   
 SET @UTCDate = GETUTCDATE()  
  
 SELECT @PartyTypeId = PartyTypeId  
 FROM partytype_ref  
 WHERE PartyTypeName = 'Reservation'  
  
 IF @notes1 = '' set @notes1 = null  
 IF @notes2 = '' set @notes2 = null  
 IF @notes3 = '' set @notes3 = null  
  
 IF @CrsId = 2  
  SELECT  @ClientId = pr.ClientId  
   --,@BookedAccount =  cpp.UserName  
  FROM CrsProperty_Property_ref cpp  
  INNER JOIN dbo.property_ref pr  
   ON pr.PropertyId = cpp.PropertyId  
  WHERE CrsPropertyId = @CrsPropertyId 

  ---------------------- deekshitha -------
 IF @IntegrationId IS NOT NULL
  SELECT  @ClientId = pr.ClientId  
   --,@BookedAccount =  cpp.UserName  
  FROM Crs_Unit_xref cpp  
  INNER JOIN dbo.property_ref pr  
   ON pr.PropertyId = cpp.PropertyId  
  WHERE IntegratedunitId = @CrsPropertyId


----------------------------------------


 IF @CountryId = ''  
  SET @CountryId = NULL  
  
 SELECT @CountryId_sys = CountryId  
  ,@CountryName = CrsCountryName  
 FROM crsCountry_Country_xref  
 WHERE CrsCountryId = @CountryId  
  
 IF @CountryId_sys IS NULL  
 BEGIN  
  SELECT @CountryId_sys = StateId  
   ,@CountryName = CrsStateName  
  FROM CrsStates_State_Xref  
  WHERE CrsStateId = @CountryId  
 END  
  
 SELECT @UpdatedBy = (SELECT UserId FROM User_ref where loginid= 'peris' AND ClientId = @ClientId)  
  
 IF @ReservationId = -1  
  SET @ReservationId = NULL  
  
 IF @SubSourceId IN (-1,-99)  
  SET @SubSourceId = NULL  
  
 IF @StayInfoId = 0  
  SET @StayInfoId = NULL  
  
 SELECT @StatusId = reservationStatus  
 FROM crsReservation_reservationStatus_xref  
 WHERE crsStatus = @StatusId  
  
 IF @creator IS NOT NULL  
 BEGIN  
  IF @CrsId = 2  
  BEGIN  
   SELECT @SourceId = sr.sourceID  
   FROM crsagents_source_ref ca  
    INNER JOIN ccCrsSource_source_ref cs  
     ON ca.AgentId = cs.crsSourceID  
    INNER JOIN Source_ref sr  
     ON sr.sourceID = cs.sourceID  
   WHERE ca.UserName = @creator  
  
   IF @SourceId IS NULL SET @SourceId = 2  
  END  
 END  
    
 IF (@SourceId = 5 OR @SourceId = 10) AND @StatusId = 1  
  SET @StatusId = 5  
 ELSE  
  SET @StatusId = @StatusId  
    
  print @SourceId  
  PRINT @SourceId  
  --For HOMEAWAY Reservations   
 IF @SourceId = 7  
  IF @StatusId IN (10,12)  
   SET @StatusId = 10  
   
  
 SELECT @lastModified = CONVERT(datetime2,@lastModified)  
  
   
 DECLARE  @ResDetails AS TABLE  
 (  
  LogId     INT  
  ,ResId     INT  
  ,GuestFirstname   NVARCHAR(100) 
  ,GuestLastName   NVARCHAR(100)  
  ,StatusId    INT  
  ,EmailAddress   NVARCHAR(100)  
  ,PhoneNumber   NVARCHAR(100)  
  ,ExtAmount    MONEY  
  ,Country    INT  
  ,notes1     NVARCHAR(4000)  
  ,notes2     NVARCHAR(4000)  
  ,notes3     NVARCHAR(4000)  
  ,address    NVARCHAR(1000)  
  ,postalcode    NVARCHAR(20)  
 )  
	DECLARE @UnitId INT

	IF @CrsId IS NOT NULL
	BEGIN
		SET @UnitId = (SELECT distinct unitId FROM CrsProperty_Property_ref WHERE CrsPropertyId = @CrsPropertyId AND Status = 1)
	END
	ELSE IF @IntegrationId IS NOT NULL
	BEGIN
		SET @UnitId = (SELECT UnitId FROM Crs_Unit_xref WHERE IntegratedunitId = @CrsPropertyId and integrationId = @integrationId AND StatusId = 1)
	END

 
  
 DECLARE @saveNotes AS TABLE ( Id INT IDENTITY(1,1) ,NoteSubject NVARCHAR(100) ,Notes NVARCHAR(4000))  
  
 IF (SELECT COUNT(ReservationId) FROM Reservation_ref WHERE Ext_ReservationId = @Ext_ReservationId AND lastModifiedDatetime IS NULL) > 1  
 BEGIN  
  SELECT @ReservationId = NULL  
     
  INSERT INTO dbo.Reservation_Dump VALUES (@ReservationId ,@Ext_ReservationId ,@StayInfoId ,@GuestFirstName ,@GuestLastName ,@PhoneNumber  
   ,@Email ,@Address1 ,@Address2 ,@Address3 ,@CityId ,@PostalCode ,@CountryId ,@StateId ,@UpdatedBy  ,@StatusId   ,@PartyAddressId   
   ,@SourceId ,@SubSourceId ,@CrsId ,@notes1 ,@notes2 ,@notes3  ,@lastModified ,@creator ,@CrsConfirmationNumber   ,@CrsPropertyId   
   ,@StartDate ,@EndDate ,@UTCDate)  
 END  
 ELSE  
 BEGIN  
  --check if the reservation already exists  
  IF EXISTS(SELECT 1 FROM Reservation_ref WHERE Ext_ReservationId = @Ext_ReservationId)  
  BEGIN  
   IF @CrsId = 2  
    SELECT DISTINCT @ReservationId = rr.ReservationId  
    FROM reservation_ref rr  
    INNER JOIN unitinventoryexclude_ref uie  
     ON rr.ReservationId = uie.ReservationId  
    INNER JOIN CrsProperty_Property_ref cpp  
     ON cpp.UnitId = uie.UnitId  
     AND cpp.CrsPropertyId = @CrsPropertyId  
     AND CAST(DateEffective AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(DATEADD(DD,-1,@EndDate)AS DATE)  
     AND (uie.StatusId = 1 AND rr.StatusId NOT IN (12,10) OR  
                         rr.StatusId IN ( 12,10))  
    WHERE Ext_ReservationId = @Ext_ReservationId  


	ELSE IF @IntegrationId IS NOT NULL   
    SELECT DISTINCT @ReservationId = rr.ReservationId  
    FROM reservation_ref rr  
    INNER JOIN unitinventoryexclude_ref uie  
     ON rr.ReservationId = uie.ReservationId  
    INNER JOIN Crs_Unit_xref cpp  
     ON cpp.UnitId = uie.UnitId  
     AND cpp.IntegratedunitId = @CrsPropertyId  
     AND CAST(DateEffective AS DATE) BETWEEN CAST(@StartDate AS DATE) AND CAST(DATEADD(DD,-1,@EndDate)AS DATE)  
     AND (uie.StatusId = 1 AND rr.StatusId NOT IN (12,10) OR  
                         rr.StatusId IN ( 12,10))  
    WHERE Ext_ReservationId = @Ext_ReservationId  
   
 
   IF(@ReservationId IS NULL)  
    --get the reservationid  
    SELECT @ReservationId = ReservationId  
    FROM Crs_MultiReservation_ref  
    WHERE SourceConfNumber = @Ext_ReservationId  
    AND StayInfoId = @StayInfoId  
    
   IF @ReservationId IS NULL  
   BEGIN  
    SELECT @ReservationId = ReservationId  
    FROM reservation_ref  
    WHERE Ext_ReservationId = @Ext_ReservationId  
    AND ReservationId not in ( SELECT ReservationId  
    FROM Crs_MultiReservation_ref  
    WHERE SourceConfNumber = @Ext_ReservationId )  
   END  
    
 
	print 'yo'
	print @ReservationId
  

   IF @ReservationId IS NULL  
   BEGIN  
    Print 'Insert'  
    SELECT @operationtype ='Insert'  
    GOTO ResInsert  
   END  
  
   IF EXISTS(SELECT 1 FROM reservation_ref WHERE ReservationId = @ReservationId  
     AND (lastModifiedDatetime != @lastModified OR lastModifiedDatetime IS NULL))  
   BEGIN  
   PRINT  'update'  
   SELECT @operationtype ='Update'  
    GOTO ResUpdate  
   END  
   ELSE IF EXISTS(SELECT 1 FROM reservation_ref WHERE ReservationId = @ReservationId  
     AND lastModifiedDatetime = @lastModified)  
   BEGIN  
    SELECT @ReservationId = NULL  
	  print 'yoy'
  print @ReservationId
   END  
 END  

  ELSE IF EXISTS (SELECT 1 FROM vW_reservation_arrivalAndDepartureDates v  
                  INNER JOIN reservation_ref r  
                 ON v.reservationID = r.ReservationId  
           where arrivalDate = @StartDate and departureDate = @EndDate and UnitId = @UnitId  
           and CONCAT(r.GuestFirstName,' ',r.GuestLastName) Like CONCAT('%', @GuestFirstName,'%') and v.ResStatusId IN (10,12) and Sourceid = @SourceId)  
  BEGIN  
   SELECT @ReservationId = v.reservationID FROM vW_reservation_arrivalAndDepartureDates v  
                  INNER JOIN reservation_ref r  
                 ON v.reservationID = r.ReservationId  
           where arrivalDate = @StartDate and departureDate = @EndDate and UnitId = @UnitId   
           and CONCAT(r.GuestFirstName,' ',r.GuestLastName) Like CONCAT('%', @GuestFirstName,'%') and v.ResStatusId IN (10,12) and Sourceid = @SourceId  
  
     IF @ReservationId IS NULL  
     BEGIN  
      Print 'Insert'  
      SELECT @operationtype ='Insert'  
      GOTO ResInsert  
     END  
  
     IF EXISTS(SELECT 1 FROM reservation_ref WHERE ReservationId = @ReservationId  
       AND (lastModifiedDatetime != @lastModified OR lastModifiedDatetime IS NULL))  
     BEGIN  
     PRINT  'update'  
     SELECT @operationtype ='Update'  
      GOTO ResUpdate  
     END  
  END  
  ELSE  
  BEGIN  
   SELECT @operationtype ='Insert'  
   GOTO ResInsert   
  END  
  
   
 ResInsert:  
 BEGIN  
 IF @operationtype ='Insert'  
 BEGIN  
  SET @errormessage = ''  
 
  IF NOT EXISTS( SELECT 1 FROM dbo.Crs_MultiReservation_ref   
        WHERE SourceConfNumber = @Ext_ReservationId  
        AND (StayInfoId = @StayInfoId OR StayInfoId IS NULL))  
  BEGIN  

 
        --save reservation  
   INSERT INTO dbo.reservation_ref   
   (  
    ClientId,  
    StatusId,  
    GuestFirstName,  
    GuestLastName,  
    NumberOfAdults,  
    NumberOfChildren,  
    SourceId,  
    SubSourceId,  
    DateBooked,  
    --BookedBy,  
    UpdatedBy,  
    DateUpdated,  
    PartyAddressId,  
    GuestProfileId,  
    CrsId,  
    Ext_ReservationId,  
    lastModifiedDatetime,  
    Bookedbyuser  
   )  
   SELECT   
    @ClientId,  
    @StatusId,  
    LTRIM(RTRIM((select [dbo].[fn_titlecase] (@GuestFirstName)))),  
    LTRIM(RTRIM((select [dbo].[fn_titlecase] (@GuestLastName)))),  
    0,  
    0,  
    @SourceId,  
    @SubSourceId,  
    @UTCDate,  
    --@UpdatedBy,  
    @UpdatedBy,  
    @UTCDate,  
    @PartyAddressId,  
    NULL,  
    @CrsId,  
    LTRIM(RTRIM(@Ext_ReservationId)),  
    @lastModified,      
    @creator  
  
   SELECT @ReservationId = SCOPE_IDENTITY()       
  
	


    INSERT INTO dbo.partyaddress_ref   
    (  
     PartyId,    
     PartyTypeId,  
     ClientId,  
     AddressTypeId,  
     ContactName,  
     Address1,  
     Address2,  
     Address3,  
     CityId,  
     PostalCode,  
     countryId,  
     stateId,  
     DateUpdated,  
     UpdatedBy,  
     cityName,  
     stateName,  
     countryName  
    )   
    SELECT @ReservationId,  
     @PartyTypeId,  
     @ClientId,  
     @AddressTypeId,  
     LTRIM(RTRIM((select [dbo].[fn_titlecase] (@GuestFirstName)) + ' ' + (select [dbo].[fn_titlecase] (@GuestLastName)))),  
     LTRIM(RTRIM(@Address1)),  
     LTRIM(RTRIM(@Address2)),  
     LTRIM(RTRIM(@Address3)),  
     CASE   
      WHEN @CityId = ' ' THEN NULL  
      ELSE @CityId  
     END,  
     @PostalCode,  
     @CountryId_sys,  
     CASE   
      WHEN @StateId = ' ' THEN NULL  
      ELSE @StateId  
     END,  
     @UTCDate,  
     @UpdatedBy,  
     LTRIM(RTRIM(@cityName)),  
     LTRIM(RTRIM(@stateName)),  
     LTRIM(RTRIM(@countryName))  
  
    
    SELECT @PartyAddressId = SCOPE_IDENTITY();   
  
    UPDATE reservation_ref  
    SET PartyAddressId = @PartyAddressId  
    WHERE ReservationId = @ReservationId  
  
    INSERT INTO partyAddress_AddMoreEmail_Xref  
    SELECT @PartyAddressId ,LTRIM(RTRIM(@Email))  
  
    INSERT INTO partyAddress_AddMorePhone_Xref  
    SELECT @PartyAddressId ,LTRIM(RTRIM(@PhoneNumber))  
  
  
   IF NOT EXISTS( SELECT 1 FROM dbo.ResConfirmation_Numbers_ref  
        WHERE SourceConfirmationNum = @Ext_ReservationId )  
   BEGIN  
    INSERT INTO dbo.ResConfirmation_Numbers_ref(ReservationId,SourceConfirmationNum , CrsConfirmationNumber)  
     SELECT ReservationId, Ext_ReservationId,@CrsConfirmationNumber   
     FROM reservation_ref   
     WHERE Ext_ReservationId = @Ext_ReservationId          
   END  
  
   UPDATE rr  
   SET ConfirmationNumber = rcn.ConfirmationNumber  
   FROM dbo.reservation_ref rr  
    INNER JOIN ResConfirmation_Numbers_ref rcn  
     ON (rr.ReservationId = rcn.ReservationId  
     OR rr.Ext_ReservationId = rcn.SourceConfirmationNum)  
   WHERE rr.Ext_ReservationId = @Ext_ReservationId     
  
   --save stayinfo details  
   IF NOT EXISTS(SELECT 1 FROM Crs_MultiReservation_ref   
     WHERE SourceConfNumber = @Ext_ReservationId  
     AND StayInfoId = @StayInfoId AND StayInfoId is not null)  
   BEGIN  
    print 'stayy info'  
    INSERT INTO dbo.Crs_MultiReservation_ref  
    (  
     CrsId  
     ,ReservationId  
     ,ConfirmationNumber  
     ,SourceConfNumber  
     ,StayInfoId  
     ,ResStatusId  
     ,CreatedDate    
    )  
    SELECT @CrsId  
     ,rr.ReservationId  
     ,rcn.ConfirmationNumber  
     ,rcn.SourceConfirmationNum  
     ,@StayInfoId  
     ,@StatusId  
     ,@UTCDate  
    FROM reservation_ref rr  
     INNER JOIN ResConfirmation_Numbers_ref rcn  
      ON rr.Ext_ReservationId = rcn.SourceConfirmationNum  
    WHERE rr.ReservationId = @ReservationId  
   END  
    
   --capture notes from External source  
   IF @notes1 IS NOT NULL  
   BEGIN  
    print 'prop notes'  
    INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Property Details Section',@notes1)  
   END  
   IF @notes2 IS NOT NULL  
   BEGIN  
    print 'guest notes'  
    INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Guest Details section',@notes2)  
   END  
   IF @notes3 IS NOT NULL  
   BEGIN  
    print 'price notes'  
    INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Credit Card Section',@notes3)  
   END  
  END  
  END  
 END  

 
 ResUpdate:    
 BEGIN    
 IF @operationtype ='Update'  
 BEGIN  
  DECLARE @getLastModified DATETIME  
  
  SELECT @getLastModified = lastModifiedDatetime  
  FROM reservation_ref WHERE ReservationId = @ReservationId  
  
  --update lastmodified  
  UPDATE reservation_ref  
  SET lastModifiedDatetime = @lastModified     
  WHERE ReservationId = @ReservationId  
  
  IF @CrsConfirmationNumber IS NOT NULL  
  BEGIN  
   UPDATE ResConfirmation_Numbers_ref  
   SET CrsConfirmationNumber = @CrsConfirmationNumber     
   WHERE SourceConfirmationNum = @Ext_ReservationId  
  END  
  
  IF (SELECT SourceConfirmationNum FROM ResConfirmation_Numbers_ref where ReservationId = @ReservationId)!=@Ext_ReservationId  
  BEGIN  
    UPDATE ResConfirmation_Numbers_ref  
    SET CrsConfirmationNumber = @CrsConfirmationNumber ,  
    SourceConfirmationNum = @Ext_ReservationId  
    WHERE ReservationId = @ReservationId  
  END  
  
  SELECT @PartyAddressId = PartyAddressId  
  FROM reservation_ref WHERE ReservationId = @ReservationId  
  
  IF @getLastModified IS NULL  
  BEGIN  
   INSERT INTO @ResDetails(LogId,ResId,GuestFirstname,GuestLastName,StatusId,EmailAddress,PhoneNumber,country,notes1,notes2,notes3 ,address,postalcode)  
    SELECT TOP 1 ReservationLogId,ReservationId ,GuestFirstName,GuestLastName,StatusId,EmailAddress,PhoneNumber,countryid,notes1,notes2,notes3,address,postalcode  
    FROM reservation_log WHERE Ext_ReservationId = @Ext_ReservationId AND ReservationId = @ReservationId ORDER BY  ReservationLogId DESC  
  END  
  ELSE  
  BEGIN    
   INSERT INTO @ResDetails(LogId,ResId,GuestFirstname,GuestLastName,StatusId,EmailAddress,PhoneNumber,country,notes1,notes2,notes3 ,address,postalcode)  
    SELECT TOP 1 ReservationLogId,ReservationId ,GuestFirstName,GuestLastName,StatusId,EmailAddress,PhoneNumber,countryid,notes1,notes2,notes3,address,postalcode  
    FROM reservation_log WHERE Ext_ReservationId = @Ext_ReservationId AND ReservationId = @ReservationId  
    AND  lastModifiedDatetime IS NOT NULL ORDER BY  lastModifiedDatetime DESC  
  END  
  IF NOT EXISTS (SELECT 1 FROm @ResDetails)  
  BEGIN  
   INSERT INTO @ResDetails(LogId,ResId,GuestFirstname,GuestLastName,StatusId,EmailAddress,PhoneNumber,country,notes1,notes2,notes3 ,address,postalcode)  
   SELECT TOP 1 ReservationLogId,ReservationId ,GuestFirstName,GuestLastName,StatusId,EmailAddress,PhoneNumber,countryid,notes1,notes2,notes3,address,postalcode  
    FROM reservation_log WHERE ReservationId = @ReservationId  
    AND  lastModifiedDatetime IS NOT NULL ORDER BY  lastModifiedDatetime DESC  
  END  
        
  --check if guestname is changed  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE GuestFirstName != @GuestFirstName OR GuestFirstName IS NULL)  
  BEGIN  
   print 'guest firstname'  
     
   UPDATE dbo.reservation_ref  
   SET GuestFirstName = (select [dbo].[fn_titlecase] (@GuestFirstName)),  
    UpdatedBy = @UpdatedBy,  
    DateUpdated = @UTCDate  
   WHERE ReservationId = @ReservationId  
  
   UPDATE par  
   SET ContactName = (select [dbo].[fn_titlecase] (@GuestFirstName))  +  '  ' + (select [dbo].[fn_titlecase] (@GuestLastName)),  
    DateUpdated = @UTCDate,  
    UpdatedBy = @UpdatedBy  
   FROM partyaddress_ref par  
    INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
  END  
  --check if guestlastname is changed  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE GuestLastName != @GuestLastName OR GuestLastName IS NULL)  
  BEGIN  
   print 'guest firstname'  
     
   UPDATE dbo.reservation_ref  
   SET GuestLastName = (select [dbo].[fn_titlecase] (@GuestLastName)),  
    UpdatedBy = @UpdatedBy,  
    DateUpdated = @UTCDate  
   WHERE ReservationId = @ReservationId  
  
   UPDATE par  
   SET ContactName = (select [dbo].[fn_titlecase] (@GuestFirstName))  +  '  ' + (select [dbo].[fn_titlecase] (@GuestLastName)),  
    DateUpdated = @UTCDate,  
    UpdatedBy = @UpdatedBy  
   FROM partyaddress_ref par  
    INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
  END  
  --check if email is changed  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE EmailAddress != @Email OR EmailAddress IS NULL)  
  BEGIN     
   print 'email'  
  
   DELETE par FROM partyAddress_AddMoreEmail_Xref par INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
  
   INSERT INTO partyAddress_AddMoreEmail_Xref  
   SELECT @PartyAddressId ,@Email              
  END  
  --check if phone number is changed      
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE PhoneNumber != @PhoneNumber  OR PhoneNumber IS NULL)  
  BEGIN  
   DELETE par FROM partyAddress_AddMorePhone_Xref par INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
  
   INSERT INTO partyAddress_AddMorePhone_Xref  
    SELECT @PartyAddressId ,@PhoneNumber   
  END  
  
  --check if status is changed      
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE StatusId <> @StatusId AND @StatusId IN (4,5,1) and  statusId  not in (6,7,4))  
  BEGIN  
   UPDATE dbo.reservation_ref  
   SET StatusId = @StatusId,  
    UpdatedBy = @UpdatedBy,  
    DateUpdated = @UTCDate  
   WHERE ReservationId = @ReservationId  
  
   UPDATE Crs_MultiReservation_ref  
   SET ResStatusId = @StatusId,  
    UpdatedDate = @UTCDate  
   WHERE ReservationId = @ReservationId  
  
   IF (SELECT Ext_ReservationId FROM reservation_ref where ReservationId = @ReservationId)!=@Ext_ReservationId  
   BEGIN  
    UPDATE dbo.reservation_ref  
    SET  Ext_ReservationId = @Ext_ReservationId,  
    UpdatedBy = @UpdatedBy,  
    DateUpdated = @UTCDate  
    WHERE ReservationId = @ReservationId  
  
    UPDATE Crs_MultiReservation_ref  
    SET SourceConfNumber = @Ext_ReservationId,  
     UpdatedDate = @UTCDate  
    WHERE ReservationId = @ReservationId  
  
   END  
  END  
    
  --check if address is changed      
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE country != @CountryId_sys  OR country IS NULL  
    OR @CountryId_sys IS NULL)  
  BEGIN     
   UPDATE par  
   SET CityId = @CityId,      
    CountryId = @CountryId_sys,  
    StateId = @StateId,  
    countryName = @CountryName,  
    stateName = @statename,  
    cityName = @cityname,  
    DateUpdated = @UTCDate,  
    UpdatedBy = @UpdatedBy  
   FROM partyaddress_ref par  
    INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
  END  
  
  --update notes  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE notes1 != @notes1 OR notes1 IS NULL OR @notes1 IS NULL)  
  BEGIN     
   IF @notes1 IS NOT NULL  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Property Details Section' AND noteStatusId not in (2,3) )  
    BEGIN  
     UPDATE notes_ref  
     SET noteDetails = @notes1  
      ,userUpdate = @UpdatedBy  
      ,dateUpdate = @UTCDate  
     WHERE reservationId = @ReservationId  
     AND NoteSubject  = 'RU Comments from Property Details Section'       
    END  
    ELSE  
    BEGIN  
     print 'property note'  
     INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Property Details Section',@notes1)  
    END  
   END  
   ELSE  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Property Details Section' AND noteStatusId not in (2,3))  
    BEGIN  
     SELECT @cancelNoteId = noteId  
     FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Property Details Section'  
     AND noteStatusId = 0  
       
     EXEC update_Notes_status  @cancelNoteId,3,@UpdatedBy  
    END  
   END  
  END  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE notes2 != @notes2 OR notes2 IS NULL OR @notes2 IS NULL )  
  BEGIN  
   IF @notes2 IS NOT NULL  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Guest Details Section' AND noteStatusId not in (2,3))  
    BEGIN  
     UPDATE notes_ref  
     SET noteDetails = @notes2  
      ,userUpdate = @UpdatedBy  
      ,dateUpdate = @UTCDate  
     WHERE reservationId = @ReservationId  
     AND NoteSubject  = 'RU Comments from Guest Details Section'  
    END  
    ELSE  
    BEGIN  
     print 'Guest notes'  
     INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Guest Details Section',@notes2)  
    END  
   END  
   ELSE  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Guest Details Section' AND noteStatusId not in (2,3))  
    BEGIN  
     SELECT @cancelNoteId = noteId  
     FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Guest Details Section'  
     AND noteStatusId = 0  
       
     EXEC update_Notes_status  @cancelNoteId,3,@UpdatedBy  
    END  
   END  
  END  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE notes3 != @notes3 OR notes3 IS NULL OR @notes3 IS NULL)  
  BEGIN  
   IF @notes3 IS NOT NULL  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Credit Card Section' AND noteStatusId not in (2,3))  
    BEGIN  
     UPDATE notes_ref  
     SET noteDetails = @notes3  
      ,userUpdate = @UpdatedBy  
      ,dateUpdate = @UTCDate  
     WHERE reservationId = @ReservationId  
     AND NoteSubject  = 'RU Comments from Credit Card Section'  
    END  
    ELSE  
    BEGIN  
     print 'price notes'  
     INSERT INTO @saveNotes (NoteSubject,Notes) VALUES('RU Comments from Credit Card Section',@notes3)  
    END  
   END    
   ELSE  
   BEGIN  
    IF EXISTS(SELECT 1 FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Credit Card Section' AND noteStatusId not in (2,3))  
    BEGIN  
     SELECT @cancelNoteId = noteId  
     FROM notes_ref WHERE reservationId = @ReservationId AND NoteSubject  = 'RU Comments from Credit Card Section'  
     AND noteStatusId = 0  
       
     EXEC update_Notes_status  @cancelNoteId,3,@UpdatedBy  
    END  
   END    
  END  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE [address] != @Address1 OR [address] IS NULL)  
  BEGIN  
   UPDATE par  
   SET Address1 = @Address1,  
    DateUpdated = @UTCDate,  
    UpdatedBy = @UpdatedBy  
   FROM partyaddress_ref par  
    INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId  
      
  END  
  IF EXISTS(SELECT  1 FROM @ResDetails WHERE postalcode != @PostalCode OR postalcode IS NULL)  
  BEGIN  
   UPDATE par  
   SET PostalCode = @PostalCode,  
    DateUpdated = @UTCDate,  
    UpdatedBy = @UpdatedBy  
   FROM partyaddress_ref par  
    INNER JOIN reservation_ref rr  
     ON rr.PartyAddressId = par.PartyAddressId     
   WHERE rr.ReservationId = @ReservationId       
  END  
   
  IF EXISTS(SELECT 1 FROM Crs_MultiReservation_ref   
    WHERE SourceConfNumber = @Ext_ReservationId  
    AND StayInfoId IS NULL)  
  BEGIN  
   IF @StayInfoId IS NOT NULL  
    UPDATE cmr  
    SET StayInfoId = @StayInfoId  
    FROM Crs_MultiReservation_ref cmr  
    WHERE SourceConfNumber = @Ext_ReservationId  
      
  END  
  ELSE  
  --save stayinfo details  
   IF NOT EXISTS(SELECT 1 FROM Crs_MultiReservation_ref   
     WHERE SourceConfNumber = @Ext_ReservationId  
     AND StayInfoId = @StayInfoId AND StayInfoId is not null)  
   BEGIN  
    print 'stayy info'  
    INSERT INTO dbo.Crs_MultiReservation_ref  
    (  
     CrsId  
     ,ReservationId  
     ,ConfirmationNumber  
     ,SourceConfNumber  
     ,StayInfoId  
     ,ResStatusId  
     ,CreatedDate    
    )  
    SELECT @CrsId  
     ,rr.ReservationId  
     ,rcn.ConfirmationNumber  
     ,rcn.SourceConfirmationNum  
     ,@StayInfoId  
     ,@StatusId  
     ,@UTCDate  
    FROM reservation_ref rr  
     INNER JOIN ResConfirmation_Numbers_ref rcn  
      ON rr.Ext_ReservationId = rcn.SourceConfirmationNum  
    WHERE rr.ReservationId = @ReservationId  
   END  
    
  
 END  
 END  
END   
 SELECT @errormessage AS ErrorMessage  
 SELECT  @ReservationId AS ReservationId  
  
 --save notes for the reservation  
 Declare @iloop int = 0, @jloop int, @notes nvarchar(max),@notesubject nvarchar(100)  
  select @jloop = count(*) from @saveNotes  
   
 while @iloop <= @jloop  
 begin  
  select @notesubject = NoteSubject , @notes = Notes from @saveNotes where Id = @iloop  
     
  IF @notes IS NOT NULL AND @ReservationId IS NOT NULL  
  EXEC [dbo].[SaveNotesDetails]       
    @ReservationId = @ReservationId,  
    @NoteId = null,  
    @NoteTypeId  = 1,  
    @NoteSubject  = @notesubject,  
    @NoteDetails = @notes,  
    @IsActionRequired = 0,  
    @DateOrTimeDue = null,  
    @UserUpdate = @UpdatedBy,  
    @dueTime  = null,  
    @noteStatusId = 0,  
    @taskTypeId = null,  
    @isAutoGenerated = 0  
      
  set @iloop = @iloop + 1  
 end   
 
 --set status to gauranteed  
 --for Airbnb reservations  
 IF @SourceId = 5   
 BEGIN  
  IF EXISTS(SELECT 1 FROM @ResDetails WHERE StatusId != @StatusId AND @StatusId IN (4,1))  
  BEGIN  
   UPDATE reservation_ref  
   SET StatusId = 5  
   WHERE ReservationId = @ReservationId  
  
   EXEC [dbo].[SaveTaxExemptForReservation] @ReservationId,@UpdatedBy,1  
  END  
 END  
 ELSE  
 SET @StatusId = @StatusId  
  
  
	
 --capture the reservation log  
 IF NOT EXISTS(SELECT 1 FROM reservation_log WHERE ReservationId = @ReservationId AND lastModifiedDatetime = @lastModified)  
 BEGIN  
  INSERT INTO reservation_log(ReservationId,   PropertyId,   ClientId,    StatusId,  NumberOfAdults,  
         NumberOfChildren,  GuestFirstName,  GuestLastName,   DoNotMove,  RatePlanId,  
         SourceId,    SubSourceId,  DateBooked,    BookedBy,  UpdatedBy,  
         DateUpdated,   PartyAddressId,  GuestProfileId,   CrsId,   Ext_ReservationId,  
         EmailAddress,  PhoneNumber,   Persons,  ConfirmationNumber,  
         Notes,     reservationMode, lastModifiedDatetime, cityid,   cityname,  
         stateid,    statename,   countryid,    countryname, createdBy,  
         notes1,     notes2,    notes3,     address,  postalcode  
         )  
   SELECT DISTINCT rr.ReservationId,   rr.PropertyId,  rr.ClientId,    @StatusId,  NumberOfAdults,  
     NumberOfChildren,  @GuestFirstName, @GuestLastName,   DoNotMove,  RatePlanId,  
     SourceId,    SubSourceId,  DateBooked,    rr.BookedBy, rr.UpdatedBy,  
     lastModifiedDatetime, rr.PartyAddressId, GuestProfileId,   CrsId,   Ext_ReservationId,  
     @Email,     @PhoneNumber,  Persons,    ConfirmationNumber,  
     Notes,     reservationMode, lastModifiedDatetime, @cityid,   cityname,  
     @stateid,    statename,   @CountryId_sys,    @CountryName, rr.UpdatedBy,  
     @notes1,    @notes2,   @notes3,    @Address1,  @PostalCode     
   FROM reservation_ref rr  
    INNER JOIN partyaddress_ref par  
     ON par.PartyAddressId = rr.PartyAddressId   
    LEFT JOIN partyAddress_AddMoreEmail_Xref pe  
     ON pe.partyAddressId = par.PartyAddressId  
    LEFT JOIN partyAddress_AddMorePhone_Xref pp  
     ON pp.partyAddressId = par.PartyAddressId      
    LEFT JOIN notes_ref nr1  
     ON nr1.reservationId = rr.ReservationId  
     AND nr1.noteStatusId not in (2,3)  
     AND nr1.noteSubject = 'RU Comments from Property Details Section'   
    LEFT JOIN notes_ref nr2  
     ON nr2.reservationId = rr.ReservationId  
     AND nr2.noteStatusId not in (2,3)  
     AND nr2.noteSubject = 'RU Comments from Guest Details Section'  
    LEFT JOIN notes_ref nr3  
     ON nr3.reservationId = rr.ReservationId  
     AND nr3.noteStatusId not in (2,3)  
     AND nr3.noteSubject = 'RU Comments from Credit Card Section'  
   WHERE rr.ReservationId = @ReservationId   
 END  
END  

GO
