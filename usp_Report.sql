USE [DBA_DB]
GO
/****** Object:  StoredProcedure [dbo].[usp_Report]    Script Date: 22.7.2019 09:14:10 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF OBJECT_ID('dbo.usp_Report') IS NULL
  EXEC ('CREATE PROCEDURE dbo.usp_Report AS RETURN 0;');
GO

ALTER PROCEDURE [dbo].[usp_Report]
AS

SET LANGUAGE us_english;  

DECLARE @startdate date = CONVERT(DATE,GETDATE()-7)
DECLARE @enddate date = CONVERT(DATE,GETDATE())


IF OBJECT_ID('#temp_report_perfmonstats') IS NOT NULL DROP TABLE #temp_report_perfmonstats

SELECT * INTO #temp_report_perfmonstats FROM (
	select 
		[type] = 'Min',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		cntr_value 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('SQL CPU','Other CPU','Memory Grants Pending','User Connections','Page life expectancy','Free Memory (KB)','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,cntr_value

	UNION

	select 
		[type] = 'Min',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		value_per_second 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('Batch Requests/sec','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,value_per_second
 ) k
 PIVOT (
 MIN(cntr_value)
 FOR _WEEKDAY IN
		([Monday], [Tuesday], [Wednesday], [Thursday], [Friday], [Saturday], [Sunday])
) AS pvt                                                                                                                                                                                                                                                                                 
UNION ALL

SELECT * FROM (
	select 
		[type] = 'Max',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		cntr_value 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('SQL CPU','Other CPU','Memory Grants Pending','User Connections','Page life expectancy','Free Memory (KB)','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,cntr_value

	UNION

	select 
		[type] = 'Max',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		value_per_second 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('Batch Requests/sec','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,value_per_second
 ) k
 PIVOT (
 MAX(cntr_value)
 FOR _WEEKDAY IN
		([Monday], [Tuesday], [Wednesday], [Thursday], [Friday], [Saturday], [Sunday])
) AS pvt                                                                                                                                 

UNION ALL 

SELECT * FROM (
	select 
		[type] = 'Average',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		cntr_value 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('SQL CPU','Other CPU','Memory Grants Pending','User Connections','Page life expectancy','Free Memory (KB)','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,cntr_value

	UNION

	select 
		[type] = 'Average',
		_WEEKDAY = DATENAME(WEEKDAY, check_date), 
		counter_name,
		value_per_second 
	from Log_PerfmonStats
	where check_date between @startdate and @enddate
	and counter_name in ('Batch Requests/sec','','','')
	GROUP BY DATENAME(WEEKDAY, check_date),counter_name,value_per_second
 ) k
 PIVOT (
 AVG(cntr_value)
 FOR _WEEKDAY IN
		([Monday], [Tuesday], [Wednesday], [Thursday], [Friday], [Saturday], [Sunday])
) AS pvt     
ORDER BY 2,1

DECLARE @table VARCHAR(MAX)

		SET @table =
				N'<p><b>Report</b> : Weekly perfmon counters. BETWEEN '+CAST(@startdate AS VARCHAR(100))+' AND '+CAST(@enddate AS VARCHAR(100))+'</p>'+
				N'<table border=1>' +
				N'<tr>
				<th>[type]</th>
				<th>[counter_name]</th>
				<th>[Monday]</th>
				<th>[Tuesday]</th>
				<th>[Wednesday]</th>
				<th>[Thursday]</th>
				<th>[Friday]</th>
				<th>[Saturday]</th>
				<th>[Sunday]</th>
				</tr>' +
				CAST((SELECT
						td = [type]
						,''
						,td = [counter_name]
						,''
						,td = [Monday]
						,''
						,td = [Tuesday]
						,''
						,td = [Wednesday]
						,''
						,td = [Thursday]
						,''
						,td = [Friday]
						,''
						,td = [Saturday]
						,''
						,td = [Sunday]
						,''
					FROM #temp_report_perfmonstats
					FOR XML PATH ('tr'), TYPE)
				AS NVARCHAR(MAX)) +
				N'</table>';	


IF OBJECT_ID('#temp_report_waittype') IS NOT NULL DROP TABLE #temp_report_waittype
	SELECT TOP 10 wait_type,AVG(avg_wait) avg_wait,AVG(avg_resource) avg_resource,AVG(avg_signal) avg_signal 
		INTO #temp_report_waittype
	FROM Log_WaitStats 
		WHERE check_date>CAST(GETDATE()-7 AS DATE)
	GROUP BY wait_type
	ORDER BY avg_wait DESC

		SET @table=@table+
		N'<br>
		<p><b>Report</b> : Weekly wait statistics counters. BETWEEN '+CAST(@startdate AS VARCHAR(100))+' AND '+CAST(@enddate AS VARCHAR(100))+'</p>'+
				N'<table border=1>' +
				N'<tr>
				<th>[wait_type]</th>
				<th>[wait_type]</th>
				<th>[avg_resource]</th>
				<th>[avg_signal]</th>
				</tr>' +
				CAST((SELECT
						td = [wait_type]
						,''
						,td = [avg_wait]
						,''
						,td = [avg_resource]
						,''
						,td = [avg_signal]
						,''
					FROM #temp_report_waittype
					FOR XML PATH ('tr'), TYPE)
				AS NVARCHAR(MAX)) +
				N'</table>';


INSERT INTO ErrorLog (check_date,server_name,alert_group,alert_name,priority,error_message)
SELECT TOP 1
	GETDATE() check_date,@@SERVERNAME server_name,
	'Weekly Report' alert_group,
	'Weekly - Perfmon Counters and Wait Stats Detail Report ' alert_name,
	1 priority ,
	@table error_message

UPDATE ConfigThreshold SET last_check_date=GETDATE() WHERE alert_group='Report - Perfmon Counters' 

