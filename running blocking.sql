SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

--What's running
SELECT [req].[session_id],
       DB_NAME([req].[database_id]) AS 'Database',
       [req].[status],
       [sqltext].[text],
       [req].[command],
       [req].[cpu_time] / 1000 AS [cpu_time_sec],
       [req].[total_elapsed_time] / 1000 AS [total_elapsed_time_sec],
       [req].[granted_query_memory] * 8 / 1000 AS [granted_query_memory_mb],
       [ses].[host_name],
       [ses].[program_name]
FROM [sys].[dm_exec_requests] req
    INNER JOIN [sys].[dm_exec_sessions] ses
        ON [req].[session_id] = [ses].[session_id]
    CROSS APPLY [sys].[dm_exec_sql_text]([req].[sql_handle]) AS sqltext
WHERE [sqltext].[text] NOT IN ( 'sp_server_diagnostics' )
      AND [req].[session_id] != @@Spid
ORDER BY [ses].[total_elapsed_time] DESC;

--What's blocking
SELECT [req].[session_id],
       DB_NAME([req].[database_id]) AS 'Database',
       [req].[status],
       [req].[blocking_session_id],
       [req].[wait_type],
       [req].[wait_time] / 1000 AS [wait_time_sec],
       [req].[wait_resource],
       [req].[transaction_id]
FROM [sys].[dm_exec_requests] req
WHERE [req].[status] = N'suspended'
      AND [req].[wait_time] > 0
ORDER BY [req].[wait_time] DESC;
GO