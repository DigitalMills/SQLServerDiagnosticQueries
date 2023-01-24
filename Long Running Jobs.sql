SELECT
    j.name		AS		job_name,
	Convert(date,ja.start_execution_date) [Start Date],
	CONVERT(varchar, DATEADD(s, DATEDIFF(SECOND,ja.start_execution_date, getdate()), 0), 108) [RunTime],
	Js.step_name,	
	ISNULL(last_executed_step_id,0)+1 AS curr_step,
	js.command,
	ja.job_id	
FROM msdb.dbo.sysjobactivity ja 
	LEFT JOIN msdb.dbo.sysjobhistory jh 
		ON ja.job_history_id = jh.instance_id
	JOIN msdb.dbo.sysjobs j 
		ON ja.job_id = j.job_id
	JOIN msdb.dbo.sysjobsteps js
		ON ja.job_id = js.job_id
		AND ISNULL(ja.last_executed_step_id,0)+1 = js.step_id
WHERE 
	ja.session_id = (
					SELECT  
						TOP 1 session_id 
					FROM msdb.dbo.syssessions	ORDER BY 
						agent_start_date 
					DESC
					)
	AND start_execution_date is not null
	AND stop_execution_date is null
	AND j.category_id = 0
	AND j.name not like 'Import NWP Orders%' --orders jobs spool so ignore these.
order by 
	start_execution_date 
asc