DECLARE @spid INT

CREATE TABLE #sp_who2		( 
							SPID		INT,				Status		VARCHAR(255), 
							Login		VARCHAR(255),		HostName	VARCHAR(255), 
							BlkBy		VARCHAR(255),		DBName		VARCHAR(255), 
							Command		VARCHAR(MAX),		CPUTime		INT, 
							DiskIO		INT,				LastBatch	VARCHAR(255), 
							ProgramName VARCHAR(255),		SPID2		INT, 
							REQUESTID	INT
							) 

CREATE TABLE #jobid			(
							id			VARCHAR(34),		SPID		int, 
							name		NVARCHAR(MAX),		Description NVARCHAR(MAX)
							)

CREATE TABLE #Inputbuffer	(
							EventID			int		identity(1,1),
							EventType		varchar	(400),
							Parameters		varchar	(400),
							EventInfo		varchar	(4000),
							SPID			int		null
							)
	
INSERT INTO #sp_who2 EXEC sp_who2
 
INSERT INTO #jobid 
		select 
			distinct 
			substring(programname, 30, 34),		SPID, 
			Name,								Description
		from	#sp_who2
				, msdb.dbo.sysjobs 
		where 
			programname like 'SQLAgent - TSQL JobStep%'
			and substring(programname, 30, 34) = CONVERT(VARCHAR(34), CONVERT(VARBINARY(32), job_id), 1)

DECLARE csrLocks CURSOR FAST_FORWARD 
    FOR 
      SELECT 
			spid
      FROM	#sp_who2 
	  where 
			HostName = 'REPORTSERVER01   '

OPEN csrLocks
FETCH csrLocks INTO @spid
WHILE @@FETCH_STATUS = 0
    BEGIN
		BEGIN TRY
			INSERT #Inputbuffer (EventType, Parameters, EventInfo)
			EXEC ('DBCC INPUTBUFFER (' + @spid + ')')
		END TRY
		BEGIN CATCH
			INSERT #Inputbuffer (EventType, Parameters, EventInfo)
			Values ('', '', 'Report Expired.' )
		END CATCH

      UPDATE	#Inputbuffer
      SET		SPID = @spid
      WHERE		EventID = (SELECT MAX(EventID) FROM #Inputbuffer)

      FETCH csrLocks INTO @spid
    END
CLOSE csrLocks
DEALLOCATE csrLocks

Select distinct 
	a.SPID,										b.[Total Blocked Processes]		as [Total this is Blocking], 
	a.Blkby			as [This is Blocked By],	a.Login, 
	a.Hostname		as [Server],				a.dbname						as [DataBase], 
	c.Name			as [Job Name],				c.Description, 
	a.programname	as [Program],				#Inputbuffer.EventInfo			as [Report Buffer]  
from	(	(
			select 
				* 
			from #sp_who2 
			where 
				spid in		(
							select 
								blkby 
							from #sp_who2 
							where 
								blkby <> '  .'
							) 
				and Login <> ''
			) a
			JOIN	(
					select 
						count(distinct spid)	as [Total Blocked Processes], 
						blkby					as [Blocked By SPID] 
					from #sp_who2 
					where 
						blkby <> '  .' 
					group by 
						BlkBy
					) b
				ON a.SPID = b.[Blocked By SPID]
			left outer JOIN	(
							Select 
								SPID, 
								name, 
								description 
							from #jobid
							) c
				on a.SPID = c.SPID
			LEFT JOIN #Inputbuffer
				ON a.SPID = #Inputbuffer.SPID
		) 
Order by 
	a.blkby 
asc 

select 
	top 10
	#sp_who2.*
	, sysjobs.name 
from #sp_who2 
	LEFT JOIN msdb.dbo.sysjobs 
		ON programname like 'SQLAgent - TSQL JobStep%'
		and substring(programname, 30, 34) = CONVERT(VARCHAR(34), CONVERT(VARBINARY(32), job_id), 1)
--where spid = 935
order by 
	DiskIO 
desc

--select * from #sp_who2 where Login = 'EASYCOM\seager' --and HostName <> 'TS4-R2           '

Drop Table #sp_who2
drop table #jobid
drop table #Inputbuffer

 --Extra Commands:
  
 --Running Task info by SPID.
 --dbcc inputbuffer(425)

  --Kill Blocker by SPID.
  --Kill 425 with Statusonly

 -- select * from sys.dm_hadr_availability_replica_states

-- select * from msdb.dbo.sysjobs with (NOLOCK)
--	Inner Join msdb.dbo.sysjobsteps with (NOLOCK)
--		ON msdb.dbo.sysjobs.job_id = msdb.dbo.sysjobsteps.job_id
--Where msdb.dbo.sysjobsteps.command like '%Maintenance_CreateOrAmendPriceData%'

--exec pqnew.dbo.sp_Search_code 'NewWebPlatform_PriceUpdates_New'