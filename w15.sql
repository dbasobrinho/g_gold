-- V15.1 - Carlos Furushima : Formatacao Display
set lines 2000 pages 2000;
set head on feed on serverout on ;
set long 99999999;
set time on;
set timing on;
set verify off;
SET COLSEP '|';
set timing on
set sqlblanklines on
alter session set nls_date_format='DD/MM/YYYY HH24:MI:SS';
-- SET PAGES 400
-- SET LINES 400
-- COL "SID" 9999 Head "Session ID|SID"  JUSTIFY center
-- COL "SERIAL#" 9999 Head "Session |Serial#"  JUSTIFY center
COL EVENT FORMAT A29 Head "Wait Event|Evento de Espera"  JUSTIFY center
COL "SQL TEXT" FORMAT A52 word_wrapped   HEADING  "       |               SQL or PL/SQL TEXT            |      "  JUSTIFY center
COL "SQLID_CHILDNUMBER" FORMAT A17 Head "SQL ID|Child Number"  JUSTIFY center
COL "SID SERIAL#" FORMAT A11 Head "SID|SERIAL#"  JUSTIFY center
COL "PGA USED MB" FORMAT 99999 Head "PGA|USED|MB"  JUSTIFY center
COL "TEMP USED MB" FORMAT 99999 Head "TEMP|USED|MB"  JUSTIFY center
COL "Offload" FORMAT A10 Head "OFFLOAD"  JUSTIFY center
COL "SEC_IN_WAIT" FORMAT 999 Head "Segs|in|wait"  JUSTIFY center
COL "SEC_IN_WAIT_WAIT_TIME" FORMAT a7 Head "Segs|in|wait"  JUSTIFY center
COL "SEC_IN_WAIT_WAIT_TIME" FORMAT a7 Head "Segs|in|wait"  JUSTIFY center
COL "LAST_CALL_ET" FORMAT 99999 Head "Last|Call|ET"  JUSTIFY center
COL "BLCKSESS" FORMAT a8 Head "BLCK|SESS"  JUSTIFY center
-- COL "BLCKSESS" FORMAT 99999 Head "BLCK|SESS"  JUSTIFY center
COL "OS PID" FORMAT A9 Head "OS|PID"  JUSTIFY center
COL "SECONDS WAITED" FORMAT a6 Head "SEC|WAITED"  JUSTIFY center
COL "OBJETO_PLSQL" FORMAT a22 Head "OBJETO|PLSQL"  JUSTIFY center
COL "PGA TEMP MB"  FORMAT a7 Head "PGA/TMP|MB"  JUSTIFY center
COL "PGA|TEMP"  FORMAT a7 Head "PGA/TMP|MB"  JUSTIFY center
COL "ORIGEM"  FORMAT a18 Head "MACHINE|ORIGEM"  JUSTIFY center
COL "READ LATENCY"   FORMAT a4 Head "READ|LATENCY"  JUSTIFY center
COL "DETALHE CHAMADA"  FORMAT a40 Head "ORIGEM:DETALHE|CHAMADA"  JUSTIFY center
-- COL "DETALHE CHAMADA"  FORMAT a40 Head "ORIGEM:DETALHE|CHAMADA|Mch->Usr->Pg->Call->CMD->Obj->COUNT_EXEC_SQL->CPUUSED"  JUSTIFY center
-- COL "DETALHE CHAMADA"  FORMAT a35 Head "ORIGEM:DETALHE|CHAMADA"  JUSTIFY center



SET TERMOUT OFF;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
with PLSQL_OBJ as
(select       /* NOIA WAITEVENT  */
decode(d_o.object_name, null, 'N.O.', d_o.object_name) as "OBJETO_PLSQL" ,
        sid , decode(vs.plsql_entry_object_id, null, 'N.O.', vs.plsql_entry_object_id) -- ,vs.plsql_entry_object_id
from dba_objects d_o right join v$session vs on d_o.object_id = vs.plsql_entry_object_id
where vs.status='ACTIVE'),
DBAOBJECTS as (
select object_id, object_name,  TO_CHAR(LAST_DDL_TIME, 'DD/MON') as "LAST_DDL_TIME" from dba_objects
union all
select 0 , 'Read UNDO', 'N/D' from dual
union all
select -1 , 'Wait bkg process', 'N/D' from dual
),
TX_INFO as
(select
   sid as SID,
   substr(s.username,1,18) as username,
   substr(s.program,1,15) as program,
decode(s.command, 0,'No Command', 1,'Create Table', 2,'Insert', 3,'Select', 6,'Update', 7,'Delete', 9,'Create Index', 15,'Alter Table', 21,'Create View', 23,'Validate Index', 35,'Alter Database', 39,'Create Tablespace', 41,'Drop Tablespace', 40,'Alter Tablespace', 47,'PL/SQL EXECUTE', 53,'Drop User', 62,'Analyze Table', 63,'Analyze Index',122,'NETWORK ERROR',128,'FLASHBACK',129,'CREATE SESSION',134,'ALTER PUBLIC SYNONYM',135,'DIRECTORY EXECUTE',136,'SQL*LOADER DIRECT PATH LOAD',137,'DATAPUMP DIRECT PATH UNLOAD',160,'CREATE JAVA',161,'ALTER JAVA',162,'DROP JAVA',170, 'CALL METHOD', s.command||': Other') as command
from v$session s , AUDIT_ACTIONS aa
where s.COMMAND=aa.ACTION ) ,
CURSOR_CACHE as (
  SELECT a.value curr_cached, p.value max_cached,
s.username, s.sid as SID, s.serial# as SERIAL#
FROM v$sesstat a, v$statname b, v$session s, v$parameter2 p
WHERE a.statistic# = b.statistic# and s.sid=a.sid
AND p.name='session_cached_cursors'
AND b.name = 'session cursor cache count') ,
VSESSION_FURUSHIMA as (
SELECT
    -- s.sid,     s.serial#,    s.sql_id,    s.last_call_et,    s.seconds_in_wait,    s.module,    s.event,
        s.*,
    DECODE(s.wait_time, 0, 'WAITING', 'ON CPU') AS session_state,
    sn.network_received AS bytes_received_via_sql_net,
    sn.network_sent AS bytes_sent_via_sql_net,
    sn.cpu_metric,
    sn.io_read_metric,
    sn.io_write_metric,
    sn.redo_writes,
    sn.redo_entries,
    sn.redo_write_time
FROM
    v$session s
LEFT JOIN (
    SELECT
        ss.sid,
                -- The total number of bytes received from the client over Net8.
        MAX(CASE WHEN sn.name = 'bytes received via SQL*Net from client' THEN ss.value END) AS network_received,
                -- The total number of bytes sent to the client from the foreground process(es).
        MAX(CASE WHEN sn.name = 'bytes sent via SQL*Net to client' THEN ss.value END) AS network_sent,
        MAX(CASE WHEN sn.name = 'CPU used by this session' THEN ss.value END) AS cpu_metric,
                -- This statistic stores the number of physical blocks when the operating system retrieves a database block from the disk subsystem. This is a buffer cache miss.
        MAX(CASE WHEN sn.name = 'physical reads' THEN ss.value END) AS io_read_metric,
                -- This statistic stores the number of I/O requests to the operating system to write a database block to the disk subsystem. The bulk of the writes are performed either by DBWR or LGWR.
        MAX(CASE WHEN sn.name = 'physical writes' THEN ss.value END) AS io_write_metric,
                -- redo writes : Count of the total number of writes by LGWR to the redo log files.
        MAX(CASE WHEN sn.name = 'redo writes' THEN ss.value END) AS redo_writes,
                -- redo entries : This statistic increments each time redo entries are copied into the redo log buffer.
        MAX(CASE WHEN sn.name = 'redo entries' THEN ss.value END) AS redo_entries,
                -- redo write time : The total elapsed time of the write from the redo log buffer to the current redo log file in 10s of milliseconds.
        MAX(CASE WHEN sn.name = 'redo write time' THEN ss.value END) AS redo_write_time
    FROM
        v$sesstat ss
    JOIN
        v$statname sn ON ss.statistic# = sn.statistic#
    WHERE
        sn.name IN (
            'bytes received via SQL*Net from client',
            'bytes sent via SQL*Net to client',
            'CPU used by this session',
            'physical reads',
            'physical writes',
            'redo writes',
            'redo entries',
            'redo write time'
        )
    GROUP BY
        ss.sid
) sn ON s.sid = sn.sid
WHERE
    s.status = 'ACTIVE'
ORDER BY
    s.sid       ),
LATENCIA_IO as (SELECT /*+ MATERIALIZE */ TO_CHAR(VALUE, 'FM9990.00') AS Read_Latency FROM v$sysmetric WHERE metric_name = 'Average Synchronous Single-Block Read Latency'),
TUDOM_SESSIONS as (
select  * from ( SELECT DISTINCT * FROM   ( (
SELECT 1,
               W.sid  AS SID_SESSION_WAIT,
               W.wait_time       AS WAIT_TIME_SESSION_WAIT,
               W.event           AS EVENT_SESSION_WAIT,
               W.seconds_in_wait AS SECONDS_IN_WAIT_SESSION_WAIT,
               W.wait_class      AS WAIT_CLASS_SESSION_WAIT
        FROM   v$session_wait W) A
         FULL OUTER JOIN
---------------------------------------------------
                    VSESSION_FURUSHIMA  B
                 -- ( SELECT session_state, VSESSION_FURUSHIMA.*  FROM   VSESSION_FURUSHIMA ) B
----------------------------------------------------
                      ON A.sid_session_wait = B.sid )
WHERE  ( status = 'ACTIVE' AND wait_time > 0 )
        OR ( wait_class != 'Idle' )
)),
CURSOR_CPUUSED as (
SELECT DISTINCT a.value   cpu_usage,
                s.sid     AS SID,
                s.serial# AS SERIAL#
FROM   v$sesstat a,
       v$statname b,
       v$session s
WHERE  a.statistic# = b.statistic#
       AND s.sid = a.sid
       AND a.value <> 0
       AND b.NAME LIKE '%CPU used by this session%'
ORDER  BY s.sid
),
V_SQL as (
select
SQLT.SQL_TEXT as SQL_TEXT_NEWLINE ,
SQLT.PIECE as PIECE_NEWLINE ,
SQLT.ADDRESS as ADDRESS_NL ,
SQL.IO_CELL_OFFLOAD_ELIGIBLE_BYTES ,
SQL.SQL_ID as SQL_ID ,
SQL.HASH_VALUE as HASH_VALUE,
SQL.ADDRESS as ADDRESS,
SQL.CPU_TIME ,
SQL.CHILD_NUMBER as CHILD_NUMBER ,
SQL.PLAN_HASH_VALUE as PLAN_HASH_VALUE ,
SQL.EXECUTIONS as EXECUTIONS ,
decode(SQL.SQL_PLAN_BASELINE,null,' ','SQL PLAN Baseline USED') as BASELINE ,
decode(SQL.SQL_PROFILE,null,' ','SQL PROFILE USED') as PROFILE
       from V$SQLTEXT_WITH_NEWLINES  SQLT FULL OUTER JOIN V$SQL SQL
                on SQLT.SQL_ID = SQL.SQL_ID
                        and SQLT.HASH_VALUE = SQL.HASH_VALUE
)
SELECT /* FURUSHIMA - WAITEVENT.sql */
                TDSESS.SID|| ',' ||TDSESS.SERIAL# "SID SERIAL#" ,
                to_char(P.SPID) "OS PID" ,
                TDSESS.EVENT,
                TDSESS.BLOCKING_INSTANCE ||':'|| TDSESS.BLOCKING_SESSION as BLCKSESS,
                REPLACE(DBMS_LOB.SUBSTR(SQL.SQL_TEXT_NEWLINE, 55), CHR(5)) "SQL TEXT",
                TDSESS.machine||' -> '||TDSESS.USERNAME||' -> '||txi.program||' -> '||OBJETO_PLSQL||' -> '||txi.command||' -> '|| OBJECT_NAME  ||' -> ' ||  TDSESS.session_state || ' -> ' || SQL.executions || ' (exec) -> ' || SQL.BASELINE || '*' || SQL.PROFILE  || ' (plan) -> ' || bytes_received_via_sql_net||'(R):'||bytes_sent_via_sql_net||'(S)' || ' -> ' || io_read_metric||'(RD):'||io_write_metric||'(WR) -> '|| redo_entries ||'(RD_E) : '||redo_write_time || '(RD_W)'     as "DETALHE CHAMADA",
                TDSESS.SQL_ID|| ':' ||TDSESS.SQL_CHILD_NUMBER "SQLID_CHILDNUMBER" ,
                TRUNC(p.pga_used_mem / (1024 * 1024)) || ':' || TRUNC(u.blocks * 8 / 1024) AS "PGA|TEMP",
                to_char(DECODE(SIGN(TDSESS.WAIT_TIME), 1,'C',0,'W',-1,'C') ||' : '||TDSESS.SECONDS_IN_WAIT) as "SEC_IN_WAIT_WAIT_TIME" ,
                TDSESS.LAST_CALL_ET
-----------------------------------------------
------------ CLAUSULAS FROM
-----------------------------------------------
FROM
                V$PROCESS P,
                V_SQL SQL ,
                TUDOM_SESSIONS TDSESS FULL OUTER JOIN PLSQL_OBJ plobj on   TDSESS.sid = plobj.sid
                   FULL OUTER JOIN  DBAOBJECTS DBAOBJ on TDSESS.ROW_WAIT_OBJ# = DBAOBJ.OBJECT_ID
                   FULL OUTER JOIN  TX_INFO txi on TDSESS.SID = txi.SID
                   FULL OUTER JOIN  CURSOR_CACHE cc on TDSESS.SID = cc.SID
                   FULL OUTER JOIN  CURSOR_CPUUSED cpu on TDSESS.SID = cpu.SID
                   left join v$sort_usage u on TDSESS.saddr = u.session_addr
-----------------------------------------------
------------ CLAUSULAS WHERE
-----------------------------------------------
WHERE
                                1=1
                                AND TDSESS.sid IS NOT NULL
                                AND TDSESS.paddr = p.addr
                                AND TDSESS.SQL_ID = SQL.SQL_ID
                                AND TDSESS.sql_hash_value = SQL.hash_value
                                AND TDSESS.sql_child_number = SQL.child_number
                                AND TDSESS.sql_address = SQL.address
                                AND SQL.PIECE_NEWLINE < 2
-----------------------------------------------
------------ CLAUSULAS ORDER BY
-----------------------------------------------
ORDER BY
TDSESS.LAST_CALL_ET  ,
TDSESS.SID_SESSION_WAIT ,
SQL.PIECE_NEWLINE ;