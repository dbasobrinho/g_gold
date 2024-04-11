-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Metricas Historicas de Sessoes                                               |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 11/04/2024                                                                   |
-- | Exemplo    : @s_history_metric__date.sql                                                  |
-- | Parametros : <01*> Data Inicial (DD/MM/YYYY HH24:MI) = 10/04/2024 10:00                   |
-- |			  <02*> Data Final   (DD/MM/YYYY HH24:MI) = 10/04/2024 12:00                   | 
-- | Arquivo    : s_history_metric__date.sql                                                   |
-- | Modificacao: 2.1 - 03/08/2019 - rfsobrinho - Vizulizar MODULE no USERNAME                 |
-- |              2.2 - 24/02/2021 - rfsobrinho - Ver POOL conexao e CHILD                     |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY hh24:mi:ss';
ALTER SESSION FORCE PARALLEL DML PARALLEL   10;
ALTER SESSION FORCE PARALLEL QUERY PARALLEL 10;
alter session set db_file_multiblock_read_count=128 ;
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s_history_metric__date.sql                |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Metricas Historicas de Sessoes                        +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 1.0                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    10
SET HEADING     ON
SET LINES       188
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES

col SNAP_ID               format 999            HEADING 'SNAP|ID'          JUSTIFY CENTER
col DBID                  format 99             HEADING 'DB|ID'             JUSTIFY CENTER
col INSTANCE_NUMBER       format 99             HEADING 'I|-'               JUSTIFY CENTER
col BEGIN_TIME            format A18            HEADING 'BEGIN|TIME'        JUSTIFY CENTER
col END_TIME              format A18            HEADING 'END|TIME'          JUSTIFY CENTER
col AVG_TOTAL_SESSIONS    format 999999999      HEADING 'AVG SESS|TOTAL'    JUSTIFY CENTER
col MAX_TOTAL_SESSIONS    format 999999999      HEADING 'MAX SESS|TOTAL'    JUSTIFY CENTER
col AVG_ACTIVE_SESSIONS   format 999999999      HEADING 'AVG SESS|ACTIVE'   JUSTIFY CENTER
col MAX_ACTIVE_SESSIONS   format 999999999      HEADING 'MAX SESS|ACTIVE'   JUSTIFY CENTER
col AVG_SERIAL_SESSIONS   format 999999999      HEADING 'AVG SESS|SERIAL'   JUSTIFY CENTER
col MAX_SERIAL_SESSIONS   format 999999999      HEADING 'MAX SESS|SERIAL'   JUSTIFY CENTER
col AVG_PARALLEL_SESSIONS format 999999999      HEADING 'AVG SESS|PARALLEL' JUSTIFY CENTER
col MAX_PARALLEL_SESSIONS format 999999999      HEADING 'MAX SESS|PARALLEL' JUSTIFY CENTER
col AVG_PQ_SESSIONS       format 999999999      HEADING 'AVG SESS|PQ'       JUSTIFY CENTER
col MAX_PQ_SESSIONS       format 999999999      HEADING 'MAX SESS|PQ'       JUSTIFY CENTER
col AVG_PQ_SLAVE_SESSIONS format 999999999      HEADING 'AVG SESS|PQ_SLAVE' JUSTIFY CENTER
col MAX_PQ_SLAVE_SESSIONS format 999999999      HEADING 'MAX SESS|PQ_SLAVE' JUSTIFY CENTER
SET COLSEP '|'


PROMPT
ACCEPT DATA_INI CHAR PROMPT 'Data Inicial (DD/MM/YYYY HH24:MI) = ' 
ACCEPT DATA_FIM CHAR PROMPT 'Data Final   (DD/MM/YYYY HH24:MI) = ' 
--ACCEPT v_sql_id CHAR PROMPT 'SQL_ID                      (ALL) = ' DEFAULT ALL
PROMPT
PROMPT
SELECT /* ##dbasobrinho##s_history_metric__date.sql## */ 
       AVG_SES_COUNT.SNAP_ID,
       --AVG_SES_COUNT.DBID,
       AVG_SES_COUNT.INSTANCE_NUMBER,
       AVG_SES_COUNT.BEGIN_TIME,
       AVG_SES_COUNT.END_TIME,
       --AVG_SES_COUNT.METRIC_NAME,        
       AVG_SES_COUNT.AVERAGE AVG_TOTAL_SESSIONS,
       AVG_SES_COUNT.MAXVAL  MAX_TOTAL_SESSIONS,
       -----
       AVG_ACT_SES.AVERAGE AVG_ACTIVE_SESSIONS,
       AVG_ACT_SES.MAXVAL  MAX_ACTIVE_SESSIONS,
       -----
       AVG_SERIAL_SESSIONS.AVERAGE AVG_SERIAL_SESSIONS,
       AVG_SERIAL_SESSIONS.MAXVAL  MAX_SERIAL_SESSIONS,
       -----
       AVG_PARALLEL_SESSIONS.AVERAGE AVG_PARALLEL_SESSIONS,
       AVG_PARALLEL_SESSIONS.MAXVAL  MAX_PARALLEL_SESSIONS,
       -----
       AVG_PQ_SESSIONS.AVERAGE AVG_PQ_SESSIONS,
       AVG_PQ_SESSIONS.MAXVAL  MAX_PQ_SESSIONS,
       -----
       AVG_PQ_SLV_SESSIONS.AVERAGE AVG_PQ_SLAVE_SESSIONS,
       AVG_PQ_SLV_SESSIONS.MAXVAL  MAX_PQ_SLAVE_SESSIONS
  FROM (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2143
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_SES_COUNT,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2147
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_ACT_SES,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2148
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_SERIAL_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2148
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PARALLEL_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2137
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PQ_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2138
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PQ_SLV_SESSIONS
 WHERE AVG_SES_COUNT.SNAP_ID = AVG_ACT_SES.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_ACT_SES.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER = AVG_ACT_SES.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_SERIAL_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_SERIAL_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_SERIAL_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PARALLEL_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PARALLEL_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_PARALLEL_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PQ_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PQ_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER = AVG_PQ_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PQ_SLV_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PQ_SLV_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_PQ_SLV_SESSIONS.INSTANCE_NUMBER(+)
 order by SNAP_ID, INSTANCE_NUMBER;


PROMPT
ACCEPT DATA_INI CHAR PROMPT 'Data Inicial (DD/MM/YYYY HH24:MI) = ' 
ACCEPT DATA_FIM CHAR PROMPT 'Data Final   (DD/MM/YYYY HH24:MI) = ' 
--ACCEPT v_sql_id CHAR PROMPT 'SQL_ID                      (ALL) = ' DEFAULT ALL
PROMPT
PROMPT
SELECT /* ##dbasobrinho##s_history_metric__date.sql## */ 
       AVG_SES_COUNT.SNAP_ID,
       --AVG_SES_COUNT.DBID,
       AVG_SES_COUNT.INSTANCE_NUMBER,
       AVG_SES_COUNT.BEGIN_TIME,
       AVG_SES_COUNT.END_TIME,
       --AVG_SES_COUNT.METRIC_NAME,        
       AVG_SES_COUNT.AVERAGE AVG_TOTAL_SESSIONS,
       AVG_SES_COUNT.MAXVAL  MAX_TOTAL_SESSIONS,
       -----
       AVG_ACT_SES.AVERAGE AVG_ACTIVE_SESSIONS,
       AVG_ACT_SES.MAXVAL  MAX_ACTIVE_SESSIONS,
       -----
       AVG_SERIAL_SESSIONS.AVERAGE AVG_SERIAL_SESSIONS,
       AVG_SERIAL_SESSIONS.MAXVAL  MAX_SERIAL_SESSIONS,
       -----
       AVG_PARALLEL_SESSIONS.AVERAGE AVG_PARALLEL_SESSIONS,
       AVG_PARALLEL_SESSIONS.MAXVAL  MAX_PARALLEL_SESSIONS,
       -----
       AVG_PQ_SESSIONS.AVERAGE AVG_PQ_SESSIONS,
       AVG_PQ_SESSIONS.MAXVAL  MAX_PQ_SESSIONS,
       -----
       AVG_PQ_SLV_SESSIONS.AVERAGE AVG_PQ_SLAVE_SESSIONS,
       AVG_PQ_SLV_SESSIONS.MAXVAL  MAX_PQ_SLAVE_SESSIONS
  FROM (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2143
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_SES_COUNT,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2147
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_ACT_SES,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2148
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_SERIAL_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2148
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PARALLEL_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2137
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PQ_SESSIONS,
       (select SNAP_ID,
               DBID,
               INSTANCE_NUMBER,
               BEGIN_TIME,
               END_TIME,
               METRIC_NAME,
               AVERAGE,
               MAXVAL,
               METRIC_UNIT
          from dba_hist_sysmetric_summary
         where METRIC_ID = 2138
           and snap_id >=
               (select min(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_INI', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))  
           and snap_id <=
               (select max(z.snap_id)
                  from dba_hist_snapshot z
                 where to_char(z.begin_interval_time,'YYMMDD_HH24')  = to_char(to_date('&DATA_FIM', 'dd/mm/yyyy hh24:mi'),'YYMMDD_HH24'))
         order by INSTANCE_NUMBER, SNAP_ID) AVG_PQ_SLV_SESSIONS
 WHERE AVG_SES_COUNT.SNAP_ID = AVG_ACT_SES.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_ACT_SES.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER = AVG_ACT_SES.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_SERIAL_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_SERIAL_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_SERIAL_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PARALLEL_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PARALLEL_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_PARALLEL_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PQ_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PQ_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER = AVG_PQ_SESSIONS.INSTANCE_NUMBER(+)
      --
   AND AVG_SES_COUNT.SNAP_ID = AVG_PQ_SLV_SESSIONS.SNAP_ID(+)
   AND AVG_SES_COUNT.DBID = AVG_PQ_SLV_SESSIONS.DBID(+)
   AND AVG_SES_COUNT.INSTANCE_NUMBER =
       AVG_PQ_SLV_SESSIONS.INSTANCE_NUMBER(+)
 order by SNAP_ID, INSTANCE_NUMBER;


SET FEEDBACK on
UNDEFINE DATA_INI
UNDEFINE DATA_FIM

--SET COLSEP ' '
