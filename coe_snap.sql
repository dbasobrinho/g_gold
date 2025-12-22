-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Tempo de Execução por SQL_ID (AWR)                                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 01/03/2018                                                                   |
-- | Exemplo    : @tun_coe_snap.sql                                                            |
-- | Arquivo    : tun_coe_snap.sql                                                             |
-- | Referência : https://dbasobrinho.com.br                                                   |
-- | Modificacao: 1.1 - 01/09/2020 - rfsobrinho - Inclusão de PX_SERVERS e CPU_TIME            |
-- |              1.2 - 24/03/2023 - rfsobrinho - Adição de CON_ID e formato uniforme          |
-- |              1.3 - 22/06/2025 - rfsobrinho - Otimização de cálculo de minutos e layout    |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                 https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+ 
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
--> while true; do
-->   echo ===================================================
-->   date '+%Y-%m-%d %H:%M:%S'
-->   echo "@s.sql" | sqlplus -s / as sysdba | tail -n +12 | egrep -i 'f2xb0s01bh9cy|SESSIONWAIT'
-->   sleep 10
-->   echo . . . 
--> done
-- +-------------------------------------------------------------------------------------------+

SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'snap[tempo_exec_sqlid.sql]', action_name => 'snap[tempo_exec_sqlid.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/tun_coe_snap.sql                          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Tempo de Execucao por SQL_ID (AWR)              +-+-+-+-+-+-+-+-+-+-+-+        |
PROMPT | Instância: &current_instance                               |d|b|a|s|o|b|r|i|n|h|o|        |
PROMPT | Versão   : 1.3                                             +-+-+-+-+-+-+-+-+-+-+-+        |
PROMPT +-------------------------------------------------------------------------------------------+

ACCEPT sql_id2 char   PROMPT 'SQL_ID    [*] = '
ACCEPT days    number PROMPT 'SYSDATE - [1] = ' DEFAULT 1
PROMPT

SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       190 
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES 

COL inst_id      FORMAT 99               HEADING 'INST'                 JUSTIFY CENTER
COL snap_id      FORMAT 99999999         HEADING 'ID SNAP'             JUSTIFY CENTER
COL sql_id       FORMAT a13              HEADING 'SQL_ID'              JUSTIFY CENTER
COL sql_profile  FORMAT a28              HEADING 'SQL PROFILE'         JUSTIFY CENTER 
COL loads_delta  FORMAT 999              HEADING 'LOADS'               JUSTIFY CENTER 
COL cpu_time     FORMAT 9999999999       HEADING 'CPU (MIN)'           JUSTIFY CENTER  
COL elapsed_time FORMAT 9999999999       HEADING 'ELAPSED (MIN)'       JUSTIFY CENTER  
COL btime        FORMAT a13              HEADING 'INICIO'              JUSTIFY CENTER 
COL etime        FORMAT a05              HEADING 'FIM'                 JUSTIFY CENTER 
COL minutes      FORMAT 9999             HEADING 'MIN'                 JUSTIFY CENTER  
COL executions   FORMAT 999999           HEADING 'EXEC'                JUSTIFY CENTER 
COL rrows        FORMAT 99999999         HEADING 'LINHAS'              JUSTIFY CENTER 
COL avg_duration FORMAT a12              HEADING 'MÉDIO (s)'           JUSTIFY CENTER 
COL p_hash_value FORMAT 9999999999       HEADING 'PLAN HASH'           JUSTIFY CENTER
COL rows         FORMAT 9999999999       HEADING 'ROWS'                JUSTIFY CENTER
COL diskread     FORMAT 9999999999       HEADING 'DISK READ/EXEC'      JUSTIFY CENTER
COL buffergets   FORMAT 9999999999       HEADING 'BUFFER GET/EXEC'     JUSTIFY CENTER
COL px_servers   FORMAT 9999             HEADING 'PX'                  JUSTIFY CENTER
COL con_id       FORMAT a03              HEADING 'CDB'                 JUSTIFY CENTER


SET COLSEP '|'
SELECT 
    a.instance_number AS inst_id,
	lpad(to_char(a.con_id),3,' ')  con_id, -- a.dbid
    a.snap_id, 
    a.sql_id,
    a.plan_hash_value AS p_hash_value,
    substr(a.sql_profile,1,28)  sql_profile,
    a.loads_delta,
    a.cpu_time_delta / 60000 AS cpu_time,
    TO_CHAR(b.begin_interval_time, 'ddMMYY hh24:mi') AS btime,
    TO_CHAR(b.end_interval_time, 'hh24:mi') AS etime,
    ABS(EXTRACT(MINUTE FROM (b.end_interval_time - b.begin_interval_time)) +
        EXTRACT(HOUR FROM (b.end_interval_time - b.begin_interval_time)) * 60 +
        EXTRACT(DAY FROM (b.end_interval_time - b.begin_interval_time)) * 24 * 60) AS minutes,
    a.rows_processed_delta AS rrows,
    ROUND(a.disk_reads_delta / GREATEST(a.executions_delta, 1), 0) AS diskread,
    ROUND(a.buffer_gets_delta / GREATEST(a.executions_delta, 1), 0) AS buffergets,
    a.px_servers_execs_delta AS px_servers,
    a.executions_delta AS executions,
    --ROUND(a.elapsed_time_delta / 1000000 / GREATEST(a.executions_delta, 1), 7) AS agv_duration
		trim(TO_CHAR(ROUND(a.elapsed_time_delta / 1000000 / GREATEST(a.executions_delta, 1), 7),'FM0000.0000000')) AS avg_duration
FROM dba_hist_sqlstat a
JOIN dba_hist_snapshot b
    ON a.snap_id = b.snap_id
    AND a.instance_number = b.instance_number
    AND a.dbid = b.dbid
WHERE a.sql_id = '&&sql_id2'
    AND b.begin_interval_time > trunc(sysdate - &&days) --> TRUNC(SYSDATE - 33)
ORDER BY b.begin_interval_time DESC, a.instance_number
/
CLEAR BREAKS
CLEAR COLUMNS
TTITLE OFF
UNDEF days
UNDEF sql_id2
PROMPT.                                                                                ______ _ ___ 
PROMPT.                                                                               |_  / _` / __| +-+-+-+-+-+-+-+-+-+-+-+
PROMPT.                                                                    _   _   _   / / (_| \__ \ |d|b|a|s|o|b|r|i|n|h|o|
PROMPT.                                                                   (_) (_) (_) /___\__,_|___/ +-+-+-+-+-+-+-+-+-+-+-+
PROMPT 



---------     update dba_hist_sqlstat
---------     set sql_profile = 'guina_f4uu1bp8udxy0_2390458381'
---------     where sql_id = 'f4uu1bp8udxy0'
---------     and sql_profile like '%guina_f4uu1bp8udxy0%';
---------     commit work;

---------     update WRH$_SQLSTAT 
---------     set sql_profile = 'guina_f4uu1bp8udxy0_2390458381'
---------     where sql_id = 'f4uu1bp8udxy0'
---------     and sql_profile like '%guina_f4uu1bp8udxy0%';
---------     commit work;


---------     select count(1) from WRH$_SQLSTAT 
---------     where sql_id = 'f4uu1bp8udxy0'
---------     and sql_profile like '%guina_f4uu1bp8udxy0_23904583%';
---------     commit work;
