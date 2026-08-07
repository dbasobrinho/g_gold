-- +-------------------------------------------------------------------------------------------+ 
-- | Objetivo   : Wait Event detalhado por sessao (RAC / multi instancia)                      |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Arquivo    : w_rac.sql                                                                    |
-- | Exemplo    : @w_rac.sql                                                                   |
-- | Base       : w.sql (V15.1) convertido de v$ para gv$ com inst_id em todos os joins        |
-- | Versao     : V16 - RAC - varre todas as instancias do cluster                             |
-- |                                                                https://dbasobrinho.com.br | 
-- +-------------------------------------------------------------------------------------------+
SET TIMING ON 
SET SQLBLANKLINES ON
SET LONG 99999999
SET LINES 2000
SET PAGES 2000
SET HEAD ON
SET FEED ON
SET SERVEROUT ON
SET VERIFY OFF
SET ECHO OFF
SET COLSEP '|'

SPOOL w_rac.out

COL "SID SERIAL#"           FORMAT A14    HEAD "INST:SID|SERIAL#"                  JUSTIFY CENTER
COL "OS PID"                FORMAT A9     HEAD "OS|PID"                            JUSTIFY CENTER
COL EVENT                   FORMAT A29    HEAD "Wait Event|Evento de Espera"       JUSTIFY CENTER
COL BLCKSESS                FORMAT A8     HEAD "BLCK|I:SESS"                        JUSTIFY CENTER
COL "SQL TEXT"              FORMAT A52 WORD_WRAPPED HEAD "SQL or PL/SQL|TEXT"       JUSTIFY CENTER
COL "DETALHE CHAMADA"       FORMAT A40    HEAD "ORIGEM:DETALHE|CHAMADA"             JUSTIFY CENTER
COL "SQLID_CHILDNUMBER"     FORMAT A17    HEAD "SQL ID|Child Number"               JUSTIFY CENTER
COL "PGA|TEMP"              FORMAT A7     HEAD "PGA/TMP|MB"                         JUSTIFY CENTER
COL "SEC_IN_WAIT_WAIT_TIME" FORMAT A7     HEAD "Segs|in wait"                       JUSTIFY CENTER
COL LAST_CALL_ET            FORMAT 99999  HEAD "Last|Call|ET"                       JUSTIFY CENTER

SET TERMOUT OFF;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
ALTER SESSION SET NLS_DATE_FORMAT='DD/MM/YYYY HH24:MI:SS';
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Report   : Wait Event (RAC)                                                               |
PROMPT | Conexao  : &current_instance  (o relatorio varre TODAS as instancias do cluster)          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

WITH PLSQL_OBJ AS (
  SELECT /* w_rac */
         vs.inst_id                                              AS inst_id,
         vs.sid                                                  AS sid,
         DECODE(d_o.object_name, NULL, 'N.O.', d_o.object_name)  AS "OBJETO_PLSQL"
  FROM   gv$session vs
         LEFT JOIN dba_objects d_o
                ON d_o.object_id = vs.plsql_entry_object_id
  WHERE  vs.status = 'ACTIVE'
),
DBAOBJECTS AS (
  SELECT object_id, object_name, TO_CHAR(last_ddl_time, 'DD/MON') AS "LAST_DDL_TIME" FROM dba_objects
  UNION ALL SELECT  0, 'Read UNDO',        'N/D' FROM dual
  UNION ALL SELECT -1, 'Wait bkg process', 'N/D' FROM dual
),
TX_INFO AS (
  SELECT s.inst_id                  AS inst_id,
         s.sid                      AS sid,
         SUBSTR(s.username,1,18)    AS username,
         SUBSTR(s.program,1,15)     AS program,
         DECODE(s.command, 0,'No Command', 1,'Create Table', 2,'Insert', 3,'Select', 6,'Update', 7,'Delete', 9,'Create Index', 15,'Alter Table', 21,'Create View', 23,'Validate Index', 35,'Alter Database', 39,'Create Tablespace', 41,'Drop Tablespace', 40,'Alter Tablespace', 47,'PL/SQL EXECUTE', 53,'Drop User', 62,'Analyze Table', 63,'Analyze Index', 122,'NETWORK ERROR', 128,'FLASHBACK', 129,'CREATE SESSION', 134,'ALTER PUBLIC SYNONYM', 135,'DIRECTORY EXECUTE', 136,'SQL*LOADER DIRECT PATH LOAD', 137,'DATAPUMP DIRECT PATH UNLOAD', 160,'CREATE JAVA', 161,'ALTER JAVA', 162,'DROP JAVA', 170,'CALL METHOD', s.command||': Other') AS command
  FROM   gv$session s, audit_actions aa
  WHERE  s.command = aa.action
),
VSESSION_FFU AS (
  SELECT s.*,
         DECODE(s.wait_time, 0, 'WAITING', 'ON CPU') AS session_state,
         sn.network_received AS bytes_received_via_sql_net,
         sn.network_sent     AS bytes_sent_via_sql_net,
         sn.cpu_metric,
         sn.io_read_metric,
         sn.io_write_metric,
         sn.redo_writes,
         sn.redo_entries,
         sn.redo_write_time
  FROM   gv$session s
         LEFT JOIN (
           SELECT ss.inst_id, ss.sid,
                  MAX(CASE WHEN sn.name = 'bytes received via SQL*Net from client' THEN ss.value END) AS network_received,
                  MAX(CASE WHEN sn.name = 'bytes sent via SQL*Net to client'       THEN ss.value END) AS network_sent,
                  MAX(CASE WHEN sn.name = 'CPU used by this session'                THEN ss.value END) AS cpu_metric,
                  MAX(CASE WHEN sn.name = 'physical reads'                          THEN ss.value END) AS io_read_metric,
                  MAX(CASE WHEN sn.name = 'physical writes'                         THEN ss.value END) AS io_write_metric,
                  MAX(CASE WHEN sn.name = 'redo writes'                             THEN ss.value END) AS redo_writes,
                  MAX(CASE WHEN sn.name = 'redo entries'                            THEN ss.value END) AS redo_entries,
                  MAX(CASE WHEN sn.name = 'redo write time'                         THEN ss.value END) AS redo_write_time
           FROM   gv$sesstat ss
                  JOIN gv$statname sn
                    ON ss.statistic# = sn.statistic#
                   AND ss.inst_id    = sn.inst_id
           WHERE  sn.name IN ( 'bytes received via SQL*Net from client',
                               'bytes sent via SQL*Net to client',
                               'CPU used by this session',
                               'physical reads',
                               'physical writes',
                               'redo writes',
                               'redo entries',
                               'redo write time' )
           GROUP  BY ss.inst_id, ss.sid
         ) sn
           ON s.inst_id = sn.inst_id
          AND s.sid     = sn.sid
  WHERE  s.status = 'ACTIVE'
),
TUDOM_SESSIONS AS (
  SELECT * FROM (
    SELECT DISTINCT * FROM (
      ( SELECT w.inst_id          AS inst_id_wait,
               w.sid              AS sid_session_wait,
               w.wait_time        AS wait_time_session_wait,
               w.event            AS event_session_wait,
               w.seconds_in_wait  AS seconds_in_wait_session_wait,
               w.wait_class       AS wait_class_session_wait
        FROM   gv$session_wait w ) a
      FULL OUTER JOIN
        VSESSION_FFU b
        ON  a.sid_session_wait = b.sid
        AND a.inst_id_wait     = b.inst_id
    )
    WHERE ( status = 'ACTIVE' AND wait_time > 0 )
       OR ( wait_class != 'Idle' )
  )
),
V_SQL AS (
  SELECT sqlt.inst_id                          AS inst_id,
         sqlt.sql_text                         AS sql_text_newline,
         sqlt.piece                            AS piece_newline,
         sqlt.address                          AS address_nl,
         sql.io_cell_offload_eligible_bytes    AS io_cell_offload_eligible_bytes,
         sql.sql_id                            AS sql_id,
         sql.hash_value                        AS hash_value,
         sql.address                           AS address,
         sql.cpu_time                          AS cpu_time,
         sql.child_number                      AS child_number,
         sql.plan_hash_value                   AS plan_hash_value,
         sql.executions                        AS executions,
         DECODE(sql.sql_plan_baseline, NULL, ' ', 'SQL PLAN Baseline USED') AS baseline,
         DECODE(sql.sql_profile,       NULL, ' ', 'SQL PROFILE USED')       AS profile
  FROM   gv$sqltext_with_newlines sqlt
         JOIN gv$sql sql
           ON  sqlt.inst_id    = sql.inst_id
           AND sqlt.sql_id     = sql.sql_id
           AND sqlt.hash_value = sql.hash_value
)
SELECT /* FFU - w_rac.sql */
       TDSESS.inst_id ||':'|| TDSESS.sid ||','|| TDSESS.serial#                              AS "SID SERIAL#",
       TO_CHAR(p.spid)                                                                       AS "OS PID",
       TDSESS.event                                                                          AS EVENT,
       TDSESS.blocking_instance ||':'|| TDSESS.blocking_session                              AS BLCKSESS,
       REPLACE(DBMS_LOB.SUBSTR(sql.sql_text_newline, 55), CHR(5))                            AS "SQL TEXT",
       TDSESS.machine ||' -> '|| TDSESS.username ||' -> '|| txi.program ||' -> '|| plobj."OBJETO_PLSQL" ||' -> '|| txi.command ||' -> '|| dbaobj.object_name ||' -> '|| TDSESS.session_state ||' -> '|| sql.executions ||' (exec) -> '|| sql.baseline ||'*'|| sql.profile ||' (plan) -> '|| TDSESS.bytes_received_via_sql_net ||'(R):'|| TDSESS.bytes_sent_via_sql_net ||'(S) -> '|| TDSESS.io_read_metric ||'(RD):'|| TDSESS.io_write_metric ||'(WR) -> '|| TDSESS.redo_entries ||'(RD_E) : '|| TDSESS.redo_write_time ||'(RD_W)'  AS "DETALHE CHAMADA",
       TDSESS.sql_id ||':'|| TDSESS.sql_child_number                                         AS "SQLID_CHILDNUMBER",
       TRUNC(p.pga_used_mem / (1024 * 1024)) ||':'|| TRUNC(u.blocks * 8 / 1024)              AS "PGA|TEMP",
       TO_CHAR(DECODE(SIGN(TDSESS.wait_time), 1,'C', 0,'W', -1,'C') ||' : '|| TDSESS.seconds_in_wait) AS "SEC_IN_WAIT_WAIT_TIME",
       TDSESS.last_call_et                                                                   AS LAST_CALL_ET
FROM   gv$process P,
       V_SQL sql,
       TUDOM_SESSIONS TDSESS
         LEFT JOIN PLSQL_OBJ plobj
                ON  TDSESS.inst_id = plobj.inst_id
                AND TDSESS.sid     = plobj.sid
         LEFT JOIN DBAOBJECTS dbaobj
                ON  TDSESS.row_wait_obj# = dbaobj.object_id
         LEFT JOIN TX_INFO txi
                ON  TDSESS.inst_id = txi.inst_id
                AND TDSESS.sid     = txi.sid
         LEFT JOIN gv$sort_usage u
                ON  TDSESS.inst_id = u.inst_id
                AND TDSESS.saddr   = u.session_addr
WHERE  1 = 1
   AND TDSESS.sid IS NOT NULL
   AND TDSESS.paddr             = p.addr
   AND TDSESS.inst_id           = p.inst_id
   AND TDSESS.sql_id            = sql.sql_id
   AND TDSESS.sql_hash_value    = sql.hash_value
   AND TDSESS.sql_child_number  = sql.child_number
   AND TDSESS.sql_address       = sql.address
   AND TDSESS.inst_id           = sql.inst_id
   AND sql.piece_newline < 2
ORDER  BY TDSESS.inst_id,
          TDSESS.last_call_et,
          TDSESS.sid,
          sql.piece_newline
/

SPOOL OFF
SET LINES       220
SET PAGES       300
