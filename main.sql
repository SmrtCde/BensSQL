BEGIN
SET ANSI_NULLS ON
SET NOCOUNT ON
SET QUOTED_IDENTIFIER ON

/*****************************************************************************************************************************
* Description: Calendar Dimension Table Stored Procedure
* Author: Ben Brown
* Date: 03/15/2024
******************************************************************************************************************************
** Change History
******************************************************************************************************************************
**PR    Date            Author          Description
**1     03/15/2024      BLB             Initial code & procedure implemented, tested, and saved
**2		03/19/2024		BLB				Added Fiscal date parts to code
**3		03/22/2024		BLB				Stored Procedure for CORE database configured
**4		07/08/2024		BLB				Added DateNBR column, a numerical representation of the date; '20240101'
**5		07/11/2024		BLB				Added logic for Next and Previous Business Day


******************************************************************************************************************************/
/*###########################################################################################################################*/
/* SET PROCEDURE VARIABLES */
/*###########################################################################################################################*/

DECLARE @Start date
DECLARE @End date
DECLARE @Range int
DECLARE @CreateYN varchar
DECLARE @PrevLoad datetime2
DECLARE @Rows int

SET @Start = '2000-01-01'
SET @End = '2100-12-31'
SET @Range = DATEDIFF(DAY,@Start,@End)
;

/*###########################################################################################################################*/
/* CREATE TABLE OR TRUNCATE EXISTING TABLE */
/*###########################################################################################################################*/

IF OBJECT_ID (N'CORE.Reference.StandardCalendar') IS NOT NULL

  BEGIN

    DROP TABLE CORE.Reference.StandardCalendar

    CREATE TABLE CORE.Reference.StandardCalendar (
      DateKeyID					INT							--Unique identifier, primary key
      ,DateDT						DATE NOT NULL				-- The date addressed in this row.
      ,CurrentDateFLG				BIT							-- Flags date of row if current to the present date
      ,DateDTS					DATETIME NOT NULL			-- The date addressed in this row.
      ,DateNBR					int							-- Numerical reprsentation of a given date
      ,CalendarYearNBR			INT NOT NULL				-- Current year eg: 2017 2025 1984.
      ,CalendarYearNM				VARCHAR(7)					-- Current year with "CY" prefix
      ,CurrentYearFLG				BIT							-- Flags year of row if current to present year
      ,CalendarQuarterNBR			TINYINT NOT NULL			-- 1-4 indicates quarter within the current year.
      ,CalendarMonthNBR			TINYINT NOT NULL			-- Number from 1-12
      ,CalendarWeekNBR			TINYINT NOT NULL			-- Number from 1-52
      ,CalendarDayNBR				TINYINT NOT NULL			-- Number from 1 through 31
      ,CalendarDaySuffixTXT		VARCHAR(4) NOT NULL			-- Number from 1 through 31, combined with 'st', 'nd', 'rd', et
      ,DayOfWeekNBR				TINYINT NOT NULL			-- Number from 1-7 (1 = Sunday)
      ,DayOfWeekNM				VARCHAR(9) NOT NULL			-- Name of the day of the week Sunday...Saturday
      ,DayOfWeekAbbrNM			VARCHAR(3) NOT NULL			-- Abbreviation of the day of the week Sun...Sat
      ,DayOfQuarterNBR			TINYINT NOT NULL			-- Number from 1-92 indicates the day # in the quarter.
      ,DayOfYearNBR				INT NOT NULL				-- Number from 1-366
      ,DayOfWeekInMonthNBR		TINYINT NOT NULL			-- Number from 1-5 indicates for example that it's the Nth saturday of the month.
      ,DayOfWeekInQuarterNBR		TINYINT NOT NULL			-- Number from 1-13 indicates for example that it's the Nth saturday of the quarter.
      ,DayOfWeekInYearNBR			TINYINT NOT NULL			-- Number from 1-53 indicates for example that it's the Nth saturday of the year.
      ,WeekOfMonthNBR				TINYINT NOT NULL			-- Number from 1-6 indicates the number of week within the current month.
      ,WeekOfQuarterNBR			TINYINT NOT NULL			-- Number from 1-14 indicates the number of week within the current quarter.
      ,WeekOfYearNBR				TINYINT NOT NULL			-- Number from 1-53 indicates the number of week within the current year.
      ,FirstDateOfWeekDT			DATE NOT NULL				-- Date of the first day of this week.
      ,LastDateOfWeekDT			DATE NOT NULL				-- Date of the last day of this week.
      ,MonthNM					VARCHAR(9) NOT NULL			-- January-December
      ,MonthAbbrNM				VARCHAR(3) NOT NULL			-- Jan-Dec
      ,DaysInMonthNBR				TINYINT NOT NULL			-- Number of days in the current month.
      ,FirstDateOfMonthDT			DATE NOT NULL				-- Date of the first day of this month.
      ,LastDateOfMonthDT			DATE NOT NULL				-- Date of the last day of this month.
      ,MonthYearTXT				VARCHAR(8) NOT NULL			-- Month and Year concatenated
      ,QuarterNM					VARCHAR(2) NOT NULL			-- Q1-Q4 indicates quarter within the current year.
      ,YearQuarterNM				VARCHAR(8) NOT NULL			-- Year prefixed to the quarter, Q1-Q4
      ,FirstDateOfQuarterDT		DATE NOT NULL				-- Date of the first day of this quarter.
      ,LastDateOfQuarterDT		DATE NOT NULL				-- Date of the last day of this quarter.
      ,IsLeapYearFLG				BIT NOT NULL				-- 1 if current year is a leap year.
      ,FirstDateOfYearDT			DATE NOT NULL				-- Date of the first day of this year.
      ,LastDateOfYearDT			DATE NOT NULL				-- Date of the last day of this year.
      ,IsWeekdayFLG				BIT NULL					-- 1 if Monday-->Friday 0 for Saturday/Sunday
      ,IsBusinessDayFLG			BIT NULL					-- 1 if a workday otherwise 0.
      ,PreviousBusinessDayDT		DATE NULL					-- Previous date that is a work day
      ,NextBusinessDayDT			DATE NULL					-- Next date that is a work day
      ,IsHolidayFLG				BIT NULL					-- 1 if a holiday
      ,IsSSMHolidayFLG			BIT NULL					-- 1 if a SSM holiday
      ,HolidayNM					VARCHAR(50) NULL			-- Name of holiday if Is_Holiday = 1
      ,IsHolidaySeasonFLG			BIT NULL					-- 1 if part of a holiday season
      ,HolidaySeasonNM			VARCHAR(50) NULL			-- Name of holiday season if Is_Holiday_Season = 1
      ,FiscalYearNM				VARCHAR(7) NOT NULL			-- FISCAL year with "FY" prefix
      ,FiscalQuarterNBR			TINYINT						-- FISCAL quarter number 1-4
      ,FiscalMonthNBR				TINYINT						-- FISCAL month number 1-12
      ,FiscalMonthYearTXT			VARCHAR(8)					-- FISCAL Month and Year concatenated
      ,FiscalFirstDayOfMonthDT	date						-- First day of a given FISCAL month
      ,FiscalLastDayOfMonthDT		date						-- Last day of a given FISCAL month
      ,FiscalFirstDayOfQuarterDT	date						-- First day of a given FISCAL quarter
      ,FiscalLastDayOfQuarterDT	date						-- Last day of a given FISCAL quarter
      ,FiscalFirstDayOfYearDT		date						-- First day of a given FISCAL year
      ,FiscalLastDayOfYearDT		date						-- Last day of a given FISCAL year
      ,LastLoadDTS				datetime2					-- DateTime the table was last loaded
      CONSTRAINT PK_ReferenceStandardCalendar PRIMARY KEY (
      DateKeyID ASC
      )
    )

  END

  ELSE BEGIN

    CREATE TABLE CORE.Reference.StandardCalendar (
      DateKeyID					INT							--Unique identifier, primary key
      ,DateDT						DATE NOT NULL				-- The date addressed in this row.
      ,CurrentDateFLG				BIT							-- Flags date of row if current to the present date
      ,DateDTS					DATETIME NOT NULL			-- The date addressed in this row.
      ,DateNBR					int							-- Numerical reprsentation of a given date
      ,CalendarYearNBR			INT NOT NULL				-- Current year eg: 2017 2025 1984.
      ,CalendarYearNM				VARCHAR(7)					-- Current year with "CY" prefix
      ,CurrentYearFLG				BIT							-- Flags year of row if current to present year
      ,CalendarQuarterNBR			TINYINT NOT NULL			-- 1-4 indicates quarter within the current year.
      ,CalendarMonthNBR			TINYINT NOT NULL			-- Number from 1-12
      ,CalendarWeekNBR			TINYINT NOT NULL			-- Number from 1-52
      ,CalendarDayNBR				TINYINT NOT NULL			-- Number from 1 through 31
      ,CalendarDaySuffixTXT		VARCHAR(4) NOT NULL			-- Number from 1 through 31, combined with 'st', 'nd', 'rd', et
      ,DayOfWeekNBR				TINYINT NOT NULL			-- Number from 1-7 (1 = Sunday)
      ,DayOfWeekNM				VARCHAR(9) NOT NULL			-- Name of the day of the week Sunday...Saturday
      ,DayOfWeekAbbrNM			VARCHAR(3) NOT NULL			-- Abbreviation of the day of the week Sun...Sat
      ,DayOfQuarterNBR			TINYINT NOT NULL			-- Number from 1-92 indicates the day # in the quarter.
      ,DayOfYearNBR				INT NOT NULL				-- Number from 1-366
      ,DayOfWeekInMonthNBR		TINYINT NOT NULL			-- Number from 1-5 indicates for example that it's the Nth saturday of the month.
      ,DayOfWeekInQuarterNBR		TINYINT NOT NULL			-- Number from 1-13 indicates for example that it's the Nth saturday of the quarter.
      ,DayOfWeekInYearNBR			TINYINT NOT NULL			-- Number from 1-53 indicates for example that it's the Nth saturday of the year.
      ,WeekOfMonthNBR				TINYINT NOT NULL			-- Number from 1-6 indicates the number of week within the current month.
      ,WeekOfQuarterNBR			TINYINT NOT NULL			-- Number from 1-14 indicates the number of week within the current quarter.
      ,WeekOfYearNBR				TINYINT NOT NULL			-- Number from 1-53 indicates the number of week within the current year.
      ,FirstDateOfWeekDT			DATE NOT NULL				-- Date of the first day of this week.
      ,LastDateOfWeekDT			DATE NOT NULL				-- Date of the last day of this week.
      ,MonthNM					VARCHAR(9) NOT NULL			-- January-December
      ,MonthAbbrNM				VARCHAR(3) NOT NULL			-- Jan-Dec
      ,DaysInMonthNBR				TINYINT NOT NULL			-- Number of days in the current month.
      ,FirstDateOfMonthDT			DATE NOT NULL				-- Date of the first day of this month.
      ,LastDateOfMonthDT			DATE NOT NULL				-- Date of the last day of this month.
      ,MonthYearTXT				VARCHAR(8) NOT NULL			-- Month and Year concatenated
      ,QuarterNM					VARCHAR(2) NOT NULL			-- Q1-Q4 indicates quarter within the current year.
      ,YearQuarterNM				VARCHAR(8) NOT NULL			-- Year prefixed to the quarter, Q1-Q4
      ,FirstDateOfQuarterDT		DATE NOT NULL				-- Date of the first day of this quarter.
      ,LastDateOfQuarterDT		DATE NOT NULL				-- Date of the last day of this quarter.
      ,IsLeapYearFLG				BIT NOT NULL				-- 1 if current year is a leap year.
      ,FirstDateOfYearDT			DATE NOT NULL				-- Date of the first day of this year.
      ,LastDateOfYearDT			DATE NOT NULL				-- Date of the last day of this year.
      ,IsWeekdayFLG				BIT NULL					-- 1 if Monday-->Friday 0 for Saturday/Sunday
      ,IsBusinessDayFLG			BIT NULL					-- 1 if a workday otherwise 0.
      ,PreviousBusinessDayDT		DATE NULL					-- Previous date that is a work day
      ,NextBusinessDayDT			DATE NULL					-- Next date that is a work day
      ,IsHolidayFLG				BIT NULL					-- 1 if a holiday
      ,IsSSMHolidayFLG			BIT NULL					-- 1 if a SSM holiday
      ,HolidayNM					VARCHAR(50) NULL			-- Name of holiday if Is_Holiday = 1
      ,IsHolidaySeasonFLG			BIT NULL					-- 1 if part of a holiday season
      ,HolidaySeasonNM			VARCHAR(50) NULL			-- Name of holiday season if Is_Holiday_Season = 1
      ,FiscalYearNM				VARCHAR(7) NOT NULL			-- FISCAL year with "FY" prefix
      ,FiscalQuarterNBR			TINYINT						-- FISCAL quarter number 1-4
      ,FiscalMonthNBR				TINYINT						-- FISCAL month number 1-12
      ,FiscalMonthYearTXT			VARCHAR(8)					-- FISCAL Month and Year concatenated
      ,FiscalFirstDayOfMonthDT	date						-- First day of a given FISCAL month
      ,FiscalLastDayOfMonthDT		date						-- Last day of a given FISCAL month
      ,FiscalFirstDayOfQuarterDT	date						-- First day of a given FISCAL quarter
      ,FiscalLastDayOfQuarterDT	date						-- Last day of a given FISCAL quarter
      ,FiscalFirstDayOfYearDT		date						-- First day of a given FISCAL year
      ,FiscalLastDayOfYearDT		date						-- Last day of a given FISCAL year
      ,LastLoadDTS				datetime2					-- DateTime the table was last loaded
      CONSTRAINT PK_ReferenceStandardCalendar PRIMARY KEY (
      DateKeyID ASC
      )
    )

  END
  ;
/*###########################################################################################################################*/
/* ASSEMBLE DATA */
/*###########################################################################################################################*/

DROP TABLE IF EXISTS #Base;

/* Creates sequence of numbers based on the number of days between the @Start and @End variables, expressed as @Range */
SELECT
  CAST(DATEADD(DAY,num,@Start) AS date) AS DateDT
INTO #Base
FROM (
  SELECT TOP (@Range+1)(0-1)+ROW_NUMBER() OVER(ORDER BY t1.number) AS num
  FROM master..spt_values t1
  CROSS JOIN master..spt_values t2
) a

SET @Rows = @@ROWCOUNT
;

/* Based on the DateDT column created in #Base, the following SELECT statement will calc the rest of the relevant calendar data */

WITH
BusinessDaysNextPrev AS (
  SELECT
    DateDT
    ,PreviousBusinessDayDT = LAG(DateDT) OVER (PARTITION BY YEAR(DateDT), MONTH(DateDT) ORDER BY DateDT)
    ,NextBusinessDayDT = LEAD(DateDT) OVER (PARTITION BY YEAR(DateDT), MONTH(DateDT) ORDER BY DateDT)
  FROM
    #Base
  WHERE
    DATEPART(WEEKDAY,DateDT) NOT IN (1,7)
)
,

HolidaySeason AS (
  SELECT
    YEAR(b1.DateDT) AS YearNBR
    ,b1.DateDT AS StartDT
    ,DATEADD(YEAR,1,b2.DateDT) AS EndDT
    ,1 AS FLG
  FROM
    #Base AS b1
    LEFT JOIN #Base b2
      ON YEAR(b1.DateDT) = YEAR(b2.DateDT)
      AND MONTH(b1.DateDT) = 11
      AND DATEPART(WEEKDAY,b1.DateDT) = 5
      AND ((DATEPART(DAY,b1.DateDT) + 6) / 7) = 4
      AND	MONTH(b2.DateDT) = 1
      AND DATEPART(DAY,b2.DateDT) = 1
  WHERE
    b2.DateDT IS NOT NULL
)

INSERT INTO CORE.Reference.StandardCalendar
SELECT
  DateKeyID = CAST(CAST(b.DateDT AS datetime)+2 AS float)
  ,b.DateDT
  ,CurrentDateFLG = CAST(IIF(b.DateDT = CAST(CURRENT_TIMESTAMP AS date),1,NULL) AS bit)
  ,DateDTS = CAST(b.DateDT AS datetime)
  ,DateNBR = CAST(CONCAT(
    DATEPART(YEAR,b.DateDT)
    ,SUBSTRING(CAST(b.DateDT AS varchar(10)),6,2)
    ,SUBSTRING(CAST(b.DateDT AS varchar(10)),9,2)
  ) AS int)
  ,CalendarYearNBR = DATEPART(YEAR,b.DateDT)
  ,CalendarYearNM = CONCAT('CY ',DATEPART(YEAR,b.DateDT))
  ,CurrentYearFLG = CAST(IIF(YEAR(b.DateDT) = YEAR(GETDATE()),1,NULL) AS bit)
  ,CalendarQuarterNBR = CAST(DATEPART(QUARTER,b.DateDT) AS tinyint)
  ,CalendarMonthNBR = CAST(DATEPART(MONTH,b.DateDT) AS tinyint)
  ,CalendarWeekNBR = CAST(DATEPART(WEEK,b.DateDT) AS tinyint)
  ,CalendarDayNBR = CAST(DATEPART(DAY,b.DateDT) AS tinyint)
  ,CalendarDaySuffixTXT = CONCAT(DATEPART(DAY,b.DateDT),
              CASE
                WHEN DATEPART(DAY,b.DateDT) IN (11,12,13) THEN 'th'
                WHEN RIGHT(DATEPART(DAY,b.DateDT),1) = 1 THEN 'st'
                WHEN RIGHT(DATEPART(DAY,b.DateDT),1) = 2 THEN 'nd'
                WHEN RIGHT(DATEPART(DAY,b.DateDT),1) = 3 THEN 'rd'
                ELSE 'th'
                END)
  ,DayOfWeekNBR = CAST(DATEPART(WEEKDAY,b.DateDT) AS tinyint)
  ,DayOfWeekNM = CASE DATEPART(WEEKDAY,b.DateDT)
          WHEN 1 THEN 'Sunday'
          WHEN 2 THEN 'Monday'
          WHEN 3 THEN 'Tuesday'
          WHEN 4 THEN 'Wednesday'
          WHEN 5 THEN 'Thursday'
          WHEN 6 THEN 'Friday'
          WHEN 7 THEN 'Saturday'
          END
  ,DayOfWeekAbbrNM = CASE DATEPART(WEEKDAY,b.DateDT)
          WHEN 1 THEN 'Sun'
          WHEN 2 THEN 'Mon'
          WHEN 3 THEN 'Tue'
          WHEN 4 THEN 'Wed'
          WHEN 5 THEN 'Thu'
          WHEN 6 THEN 'Fri'
          WHEN 7 THEN 'Sat'
          END
  ,DayOfQuarterNBR = CAST(DATEDIFF(DAY, DATEADD(QUARTER, DATEDIFF(QUARTER, 0 , b.DateDT), 0), b.DateDT) + 1 AS tinyint)
  ,DayOfYearNBR = CAST(DATEPART(DAYOFYEAR, b.DateDT) AS int)
  ,DayOfWeekInMonthNBR = CAST((DATEPART(DAY,b.DateDT) + 6) / 7 AS tinyint)/* i.e. third Monday of the month */
  ,DayOfWeekInQuarterNBR = CAST(((DATEDIFF(DAY, DATEADD(QUARTER, DATEDIFF(QUARTER, 0 , b.DateDT), 0), b.DateDT) + 1) + 6) / 7 AS tinyint)
  ,DayOfWeekInYearNBR = CAST((DATEPART(DAYOFYEAR, b.DateDT) + 6) / 7 AS tinyint)
  ,WeekOfMonthNBR = CAST(DATEDIFF(WEEK, DATEADD(WEEK, DATEDIFF(WEEK, 0, DATEADD(MONTH, DATEDIFF(MONTH, 0, b.DateDT), 0)), 0), b.DateDT ) + 1 AS tinyint)
  ,WeekOfQuarterNBR = CAST(DATEDIFF(DAY, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, b.DateDT), 0), b.DateDT)/7 + 1 AS tinyint)
  ,WeekOfYearNBR = CAST(DATEPART(WEEK, b.DateDT) AS tinyint)
  ,FirstDateOfWeekDT = DATEADD(DAY,(-1 * DATEPART(WEEKDAY,b.DateDT) + 1), b.DateDT)
  ,LastDateOfWeekDT = DATEADD(DAY, 1 * (7 - DATEPART(WEEKDAY,b.DateDT)), b.DateDT)
  ,MonthNM = CASE DATEPART(MONTH,b.DateDT)
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
        END
  ,MonthAbbrNM = CASE DATEPART(MONTH,b.DateDT)
        WHEN 1 THEN 'Jan'
        WHEN 2 THEN 'Feb'
        WHEN 3 THEN 'Mar'
        WHEN 4 THEN 'Apr'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'Jun'
        WHEN 7 THEN 'Jul'
        WHEN 8 THEN 'Aug'
        WHEN 9 THEN 'Sep'
        WHEN 10 THEN 'Oct'
        WHEN 11 THEN 'Nov'
        WHEN 12 THEN 'Dec'
        END
  ,DaysInMonthNBR = CAST(CASE
            WHEN DATEPART(MONTH,b.DateDT) IN (4, 6, 9, 11) THEN 30
            WHEN DATEPART(MONTH,b.DateDT) IN (1, 3, 5, 7, 8, 10, 12) THEN 31
            WHEN DATEPART(MONTH,b.DateDT) = 2 AND
              CASE
                WHEN DATEPART(YEAR,b.DateDT) % 4 <> 0 THEN 0
                WHEN DATEPART(YEAR,b.DateDT) % 100 <> 0 THEN 1
                WHEN DATEPART(YEAR,b.DateDT) % 400 <> 0 THEN 0
                ELSE 1
                END = 1
            THEN 29
            ELSE 28
            END AS tinyint)
  ,FirstDateOfMonthDT = DATEADD(DAY, -1 * DATEPART(DAY, b.DateDT) + 1, b.DateDT)
  ,LastDateOfMonthDT = EOMONTH(b.DateDT)
  ,MonthYearTXT = CONCAT(
      CASE DATEPART(MONTH,b.DateDT)
        WHEN 1 THEN 'Jan'
        WHEN 2 THEN 'Feb'
        WHEN 3 THEN 'Mar'
        WHEN 4 THEN 'Apr'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'Jun'
        WHEN 7 THEN 'Jul'
        WHEN 8 THEN 'Aug'
        WHEN 9 THEN 'Sep'
        WHEN 10 THEN 'Oct'
        WHEN 11 THEN 'Nov'
        WHEN 12 THEN 'Dec'
        END,'-',DATEPART(YEAR,b.DateDT))
  ,QuarterNM =  CONCAT('Q',DATEPART(QUARTER,b.DateDT))
  ,YearQuarterNM = CONCAT(DATEPART(YEAR,GETDATE()),' Q',DATEPART(QUARTER,GETDATE()))
  ,FirstDateOfQuarterDT = CAST(DATEADD(QUARTER, DATEDIFF(QUARTER, 0, b.DateDT), 0) AS date)
  ,LastDateOfQuarterDT = CAST(DATEADD (DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, b.DateDT) + 1, 0)) AS date)
  ,IsLeapYearFLG = CAST(CASE
            WHEN DATEPART(YEAR,b.DateDT) % 4 <> 0 THEN 0
            WHEN DATEPART(YEAR,b.DateDT) % 100 <> 0 THEN 1
            WHEN DATEPART(YEAR,b.DateDT) % 400 <> 0 THEN 0
            ELSE 1
            END AS bit)
  ,FirstDateOfYearDT = CAST(DATEADD(YEAR, DATEDIFF(YEAR, 0, b.DateDT), 0) AS date)
  ,LastDateOfYearDT = CAST(DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, b.DateDT) + 1, 0)) AS date)
  ,IsWeekdayFLG = CAST(IIF(DATEPART(WEEKDAY,b.DateDT) IN (1,7),0,1) AS bit)
  ,IsBusinessDayFLG = CAST(IIF(DATEPART(WEEKDAY,b.DateDT) IN (1,7),0,1) AS bit)
  ,PreviousBusinessDayDT = bus.PreviousBusinessDayDT
  ,NextBusinessDayDT = bus.NextBusinessDayDT
  ,IsHolidayFLG = CAST(NULL AS bit) --SET BY UPDATE
  ,IsSSMHolidayFLG = CAST(NULL AS bit) --SET BY UPDATE
  ,HolidayNM = CAST(NULL AS varchar) --SET BY UPDATE
  ,IsHolidaySeasonFLG = hs.FLG
  ,HolidaySeasonNM = CAST(NULL AS varchar)

/*######## Fiscal Date Parts - SSM Fiscal period follows the normal calendard period ########*/

  ,FiscalYearNM = CONCAT('FY ',YEAR(b.DateDT))
  ,FiscalQuarterNBR = CAST(DATEPART(QUARTER,b.DateDT) AS tinyint)
  ,FiscalMonthNBR = CAST(DATEPART(MONTH,b.DateDT) AS tinyint)
  ,FiscalMonthYearTXT = CONCAT(
        CASE DATEPART(MONTH,b.DateDT)
          WHEN 1 THEN 'Jan'
          WHEN 2 THEN 'Feb'
          WHEN 3 THEN 'Mar'
          WHEN 4 THEN 'Apr'
          WHEN 5 THEN 'May'
          WHEN 6 THEN 'Jun'
          WHEN 7 THEN 'Jul'
          WHEN 8 THEN 'Aug'
          WHEN 9 THEN 'Sep'
          WHEN 10 THEN 'Oct'
          WHEN 11 THEN 'Nov'
          WHEN 12 THEN 'Dec'
          END,'-',DATEPART(YEAR,b.DateDT))
  ,FiscalFirstDayOfMonthDT = DATEADD(DAY, -1 * DATEPART(DAY, b.DateDT) + 1, b.DateDT)
  ,FiscalLastDayOfMonthDT = EOMONTH(b.DateDT)
  ,FiscalFirstDayOfQuarterDT = CAST(DATEADD(QUARTER, DATEDIFF(QUARTER, 0, b.DateDT), 0) AS date)
  ,FiscalLastDayOfQuarterDT = CAST(DATEADD (DAY, -1, DATEADD(QUARTER, DATEDIFF(QUARTER, 0, b.DateDT) + 1, 0)) AS date)
  ,FiscalFirstDayOfYearDT = CAST(DATEADD(YEAR, DATEDIFF(YEAR, 0, b.DateDT), 0) AS date)
  ,FiscalLastDayOfYearDT = CAST(DATEADD(DAY, -1, DATEADD(YEAR, DATEDIFF(YEAR, 0, b.DateDT) + 1, 0)) AS date)
  ,LastLoadDTS = CURRENT_TIMESTAMP

FROM
  #Base AS b
  LEFT JOIN BusinessDaysNextPrev AS bus
    ON b.DateDT = bus.DateDT
  LEFT JOIN HolidaySeason AS hs
    ON b.DateDT BETWEEN hs.StartDT AND hs.EndDT
ORDER BY
  b.DateDT
;

/*###########################################################################################################################*/
/* UPDATE HOLIDAYS */
/*###########################################################################################################################*/

IF OBJECT_ID (N'CORE.Reference.StandardCalendar') IS NOT NULL

BEGIN
  /* New Year's Day: 1st of January */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'New Year''s Day'
    ,IsSSMHolidayFLG = 1
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    (CalendarMonthNBR = 1 AND CalendarDayNBR = 1 AND DayOfWeekNBR BETWEEN 2 AND 5)
    OR (CalendarMonthNBR = 12	AND CalendarDayNBR = 31 AND DayOfWeekNBR = 6)
    OR (CalendarMonthNBR = 1	AND CalendarDayNBR = 2 AND DayOfWeekNBR = 2)
  ;

  /* Martin Luther King, Jr. Day: 3rd Monday in January, beginning in 1983 */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Martin Luther King, Jr. Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 1
    AND DayOfWeekNBR = 2
    AND DayOfWeekInMonthNBR = 3
    AND CalendarYearNBR >= 1983
  ;

  /* President's Day: 3rd Monday in February */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'President''s Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 2
    AND DayOfWeekNBR = 2
    AND DayOfWeekInMonthNBR = 3
  ;

  /* Valentine's Day: 14th of February */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Valentine''s Day'
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 2
    AND CalendarDayNBR = 14
  ;

  /* Saint Patrick's Day: 17th of March */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Saint Patrick''s Day'
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 3
    AND CalendarDayNBR = 17
  ;

  /* Mother's Day: 2nd Sunday in May */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Mother''s Day'
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 5
    AND DayOfWeekNBR = 1
    AND DayOfWeekInMonthNBR = 2
  ;

  /* Memorial Day: Last Monday in May */
  WITH
  Holiday AS (
    SELECT
      CalendarYearNBR
      ,CalendarMonthNBR
      ,DayOfWeekNBR
      ,MAX(DayOfWeekInMonthNBR) AS MaxDayOfWeekInMonth
    FROM
      CORE.Reference.StandardCalendar
    WHERE
      CalendarMonthNBR = 5
      AND DayOfWeekNBR = 2
    GROUP BY
      CalendarYearNBR
      ,CalendarMonthNBR
      ,DayOfWeekNBR
  )

  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,IsSSMHolidayFLG = 1
    ,HolidayNM = 'Memorial Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar AS c
    INNER JOIN Holiday AS h
      ON c.CalendarYearNBR = h.CalendarYearNBR
      AND c.CalendarMonthNBR = h.CalendarMonthNBR
      AND c.DayOfWeekNBR = h.DayOfWeekNBR
      AND c.DayOfWeekInMonthNBR = h.MaxDayOfWeekInMonth
  ;

  /* Independence Day (USA): 4th of July */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,IsSSMHolidayFLG = 1
    ,HolidayNM = 'Independence Day (USA)'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    (CalendarMonthNBR = 7 AND CalendarDayNBR = 4 AND DayOfWeekNBR BETWEEN 2 AND 5)
    OR (CalendarMonthNBR = 7	AND CalendarDayNBR = 3 AND DayOfWeekNBR = 6)
    OR (CalendarMonthNBR = 7	AND CalendarDayNBR = 5 AND DayOfWeekNBR = 2)
  ;

  /* Labor Day: 1st Monday in September */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,IsSSMHolidayFLG = 1
    ,HolidayNM = 'Labor Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 9
    AND DayOfWeekNBR = 2
    AND DayOfWeekInMonthNBR = 1
  ;

  /* Columbus Day: 2nd Monday in October */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Columbus Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 10
    AND DayOfWeekNBR = 2
    AND DayOfWeekInMonthNBR = 2
  ;

  /* Halloween: 31st of October */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Halloween'
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 10
    AND CalendarDayNBR = 31
  ;

  /* Veteran's Day: 11th of November */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Veteran''s Day'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    (CalendarMonthNBR = 11 AND CalendarDayNBR = 11 AND DayOfWeekNBR BETWEEN 2 AND 5)
    OR (CalendarMonthNBR = 11	AND CalendarDayNBR = 10 AND DayOfWeekNBR = 6)
    OR (CalendarMonthNBR = 11	AND CalendarDayNBR = 12 AND DayOfWeekNBR = 2)
  ;

  /* Thanksgiving: 4th Thursday in November */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,IsSSMHolidayFLG = 1
    ,HolidayNM = 'Thanksgiving'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarMonthNBR = 11
    AND DayOfWeekNBR = 5
    AND DayOfWeekInMonthNBR = 4
  ;

  /* Election Day (USA): 1st Tuesday after November 1st, only in even-numbered years.  Always in the range of November 2-8. */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,HolidayNM = 'Election Day (USA)'
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    CalendarYearNBR % 2 = 0
    AND CalendarMonthNBR = 11
    AND DayOfWeekNBR = 3
    AND CalendarDayNBR BETWEEN 2 AND 8
  ;

  /* Christmas: 25th of December */
  UPDATE CORE.Reference.StandardCalendar
  SET
    IsHolidayFLG = 1
    ,IsSSMHolidayFLG = 1
    ,HolidayNM = 'Christmas'
    ,IsBusinessDayFLG = 0
  FROM
    CORE.Reference.StandardCalendar
  WHERE
    (CalendarMonthNBR = 12 AND CalendarDayNBR = 25 AND DayOfWeekNBR BETWEEN 2 AND 5)
    OR (CalendarMonthNBR = 12	AND CalendarDayNBR = 24 AND DayOfWeekNBR = 6)
    OR (CalendarMonthNBR = 12	AND CalendarDayNBR = 26 AND DayOfWeekNBR = 2)
  ;

END

PRINT 'CORE.Reference.StandardCalendar has been successfully created and loaded with '+ CAST(@Rows AS varchar) +' rows.'

END
GO