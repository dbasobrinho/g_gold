-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Tempo de Execucao por SQL_ID (AWR)                                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 01/03/2018                                                                   |
-- | Exemplo    : @coe_snap.sql                                                                |
-- | Arquivo    : coe_snap.sql                                                                 |
-- | Referencia : https://dbasobrinho.com.br                                                   |
-- | Modificacao: 1.1 - 01/09/2020 - rfsobrinho - Inclusao de PX_SERVERS e CPU_TIME            |
-- |              1.2 - 24/03/2023 - rfsobrinho - Adicao de CON_ID e formato uniforme          |
-- |              1.3 - 22/06/2025 - rfsobrinho - Otimizacao de calculo de minutos e layout    |
-- |              1.4 - 10/09/2026 - rfsobrinho - Filtro EXEC > 0, DBID do CDB e CPU em seg    |
-- |              1.5 - 10/09/2026 - rfsobrinho - Quebra de tempo por exec, ELA total e OFFL % |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                 https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+ 
-- |"O Guina nao tinha do, se ragir, BUMMM! vira po!"
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
EXEC dbms_application_info.set_module( module_name => 'snap[coe_snap.sql]', action_name => 'snap[coe_snap.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/coe_snap.sql                              |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Tempo de Execucao por SQL_ID (AWR)              +-+-+-+-+-+-+-+-+-+-+-+        |
PROMPT | Instancia: &current_instance                               |d|b|a|s|o|b|r|i|n|h|o|        |
PROMPT | Versao   : 1.5                                             +-+-+-+-+-+-+-+-+-+-+-+        |
PROMPT +-------------------------------------------------------------------------------------------+

ACCEPT sql_id2 char   PROMPT 'SQL_ID    [*] = '
ACCEPT days    number PROMPT 'SYSDATE - [1] = ' DEFAULT 1
PROMPT

SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       240 
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
SET HEADSEP     '|'

CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES 

COL inst_id      FORMAT 99               HEADING 'INST|-'              JUSTIFY CENTER
COL snap_id      FORMAT 99999999         HEADING 'ID|SNAP'             JUSTIFY CENTER
COL sql_id       FORMAT a13              HEADING 'SQL_ID|-'            JUSTIFY CENTER
COL p_hash_value FORMAT 9999999999       HEADING 'PLAN|HASH'           JUSTIFY CENTER
COL sql_profile  FORMAT a28              HEADING 'SQL|PROFILE'         JUSTIFY CENTER
COL loads_delta  FORMAT 999              HEADING 'LOADS|-'             JUSTIFY CENTER
COL btime        FORMAT a13              HEADING 'INICIO|-'            JUSTIFY CENTER
COL etime        FORMAT a05              HEADING 'FIM|-'               JUSTIFY CENTER
COL executions   FORMAT 99999999         HEADING 'EXEC|-'              JUSTIFY CENTER
COL avg_duration FORMAT a12              HEADING 'ELA|AVG (s)'         JUSTIFY CENTER
COL cpu_exec     FORMAT 9990.0000        HEADING 'CPU|AVG (s)'         JUSTIFY CENTER
COL io_exec      FORMAT 9990.0000        HEADING 'IO WT|AVG (s)'       JUSTIFY CENTER
COL clu_exec     FORMAT 9990.0000        HEADING 'CLUSTER WT|AVG (s)'  JUSTIFY CENTER
COL conc_exec    FORMAT 9990.0000        HEADING 'CONC WT|AVG (s)'     JUSTIFY CENTER
COL elapsed_time FORMAT 9999990.99       HEADING 'ELA TOTAL|(s)'       JUSTIFY CENTER
COL rows_exec    FORMAT 99999990.99      HEADING 'LINHAS|AVG'          JUSTIFY CENTER
COL diskread     FORMAT 9999999999       HEADING 'DISK READ|AVG'       JUSTIFY CENTER
COL buffergets   FORMAT 9999999999       HEADING 'BUFFER GET|AVG'      JUSTIFY CENTER
COL px_servers   FORMAT 999999           HEADING 'PX|-'                JUSTIFY CENTER
COL offload_pct  FORMAT 990              HEADING 'OFFL|%'              JUSTIFY CENTER


PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | LEGENDA DOS CAMPOS (tempos em segundos; AVG = media por execucao; WT = espera)            |
PROMPT |                                                                                           |
PROMPT | INST               : numero da instancia (no do RAC)                                      |
PROMPT | ID SNAP            : id do snapshot do AWR                                                |
PROMPT | SQL_ID             : identificador da SQL                                                 |
PROMPT | PLAN HASH          : plano de execucao usado no intervalo                                 |
PROMPT | SQL PROFILE        : SQL profile aplicado (vazio = nenhum)                                |
PROMPT | LOADS              : vezes que o cursor foi carregado ou recarregado (hard parse)         |
PROMPT | INICIO / FIM       : janela do snapshot                                                   |
PROMPT | EXEC               : execucoes no intervalo (so aparecem linhas com EXEC > 0)             |
PROMPT | ELA AVG (s)        : tempo medio por execucao (elapsed total / EXEC)                      |
PROMPT | CPU AVG (s)        : media de CPU por execucao                                            |
PROMPT | IO WT AVG (s)      : media de espera de I/O por execucao (User I/O)                       |
PROMPT | CLUSTER WT AVG (s) : media de espera de cluster por execucao (interconnect RAC, gc)       |
PROMPT | CONC WT AVG (s)    : media de espera de concorrencia + application (latch/lock)           |
PROMPT | ELA TOTAL (s)      : tempo total da SQL no snapshot (peso dela no intervalo)              |
PROMPT | LINHAS AVG         : media de linhas por execucao (total de linhas / EXEC)                |
PROMPT | DISK READ AVG      : media de blocos lidos do disco por execucao                          |
PROMPT | BUFFER GET AVG     : media de blocos lidos da memoria (logical reads) por execucao        |
PROMPT | PX                 : execucoes de PX slaves no intervalo (0 = rodou em serial)            |
PROMPT | OFFL %             : % dos bytes lidos do disco elegiveis para smart scan (Exadata)       |
PROMPT |                      vazio = nao leu nada do disco; 0 = leu do disco, mas sem smart scan  |
PROMPT |                                                                                           |
PROMPT | DICA               : CPU + IO WT + CLUSTER WT + CONC WT fica perto do ELA AVG;            |
PROMPT |                      a diferenca e outra espera (rede, commit etc.).                      |
PROMPT |                      Com PX, CPU e ELA somam o tempo dos slaves do no.                    |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET COLSEP '|'
SELECT 
    a.instance_number                                                        AS inst_id,
    a.snap_id,
    a.sql_id,
    a.plan_hash_value                                                        AS p_hash_value,
    SUBSTR(a.sql_profile,1,28)                                               AS sql_profile,
    a.loads_delta,
    TO_CHAR(b.begin_interval_time, 'ddMMYY hh24:mi')                         AS btime,
    TO_CHAR(b.end_interval_time, 'hh24:mi')                                  AS etime,
    a.executions_delta                                                       AS executions,
    TRIM(TO_CHAR(ROUND(a.elapsed_time_delta / 1000000 / a.executions_delta, 7),'FM0000.0000000')) AS avg_duration,
    ROUND(a.cpu_time_delta / 1000000 / a.executions_delta, 4)                AS cpu_exec,
    ROUND(a.iowait_delta   / 1000000 / a.executions_delta, 4)                AS io_exec,
    ROUND(a.clwait_delta   / 1000000 / a.executions_delta, 4)                AS clu_exec,
    ROUND((a.ccwait_delta + a.apwait_delta) / 1000000 / a.executions_delta, 4) AS conc_exec,
    ROUND(a.elapsed_time_delta / 1000000, 2)                                 AS elapsed_time,
    ROUND(a.rows_processed_delta / a.executions_delta, 2)                    AS rows_exec,
    ROUND(a.disk_reads_delta     / a.executions_delta, 0)                    AS diskread,
    ROUND(a.buffer_gets_delta    / a.executions_delta, 0)                    AS buffergets,
    a.px_servers_execs_delta                                                 AS px_servers,
    ROUND(100 * a.io_offload_elig_bytes_delta / NULLIF(a.physical_read_bytes_delta, 0), 0) AS offload_pct
FROM dba_hist_sqlstat a
JOIN dba_hist_snapshot b
    ON a.snap_id = b.snap_id
    AND a.instance_number = b.instance_number
    AND a.dbid = b.dbid
WHERE a.sql_id = '&&sql_id2'
    AND a.dbid = (SELECT dbid FROM v$database)
    AND a.executions_delta > 0
    AND b.begin_interval_time > trunc(sysdate - &&days) --> TRUNC(SYSDATE - 33)
ORDER BY b.begin_interval_time DESC, a.instance_number, a.plan_hash_value
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
