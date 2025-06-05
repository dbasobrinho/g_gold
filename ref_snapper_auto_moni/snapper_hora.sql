SET COLSEP '|'
set linesize 600
set pages  120
col TIME_INTERVAL           FORMAT  a19
col "SQL_SERVICE_MS"        format  999G990D99   justify right
col "COMMIT/S"              format  99G990D99   justify right
col "CPU_%"                 format  990D99   justify right
col "LOAD" head "OS_LOAD"   format  9990D99   justify right
col "READ_MB/S"             format  999G990D99   justify right
col "WRITE_MB/S"            format  999G990D99   justify right
col "READS/CALL"            format  999G990D99   justify right
col "USER_CALLS/S"          format  999G990D99   justify right
col "REDO_MB/S"             format  990D99   justify right
col "READ_LATENCY_MS"       format  990D99   justify right
col "NET_MB/S"              format  990D99   justify right
col "HARD_PARSE/S"          format  999G990D99   justify right
col "LOGONS/S"              format  999G990D99   justify right
col "WAIT_TOTAL_%"          format  90D99   justify right

col "TIME_INTERVAL  -24H" format a20
col "TIME_INTERVAL   -1H" like "TIME_INTERVAL  -24H"
col "TIME_INTERVAL"       like "TIME_INTERVAL  -24H"

col " " format a5

select  /*+ CURSOR_SHARING_EXACT */
  TO_CHAR(min(BEGIN_TIME), 'DD HH24:MI') || ' - ' || TO_CHAR(MAX(END_TIME), 'DD HH24:MI') "TIME_INTERVAL  -24H",
  AVG(DECODE(METRIC_NAME, 'SQL Service Response Time', AVERAGE, null)) / 10 "SQL_SERVICE_MS",                     null " " ,
  AVG(DECODE(METRIC_NAME, 'Host CPU Utilization (%)', AVERAGE, null)) "CPU_%",                                    null " " ,
  AVG(DECODE(METRIC_NAME, 'Current OS Load', AVERAGE, null)) "LOAD",                                              null " " ,
  AVG(DECODE(METRIC_NAME, 'Physical Read Bytes Per Sec', AVERAGE, null)) / 1024 / 1024 "READ_MB/S",               null " " ,
  AVG(DECODE(METRIC_NAME, 'Physical Write Bytes Per Sec', AVERAGE, null)) / 1024 / 1024 "WRITE_MB/S",             null " " ,
  AVG(DECODE(METRIC_NAME, 'User Calls Per Sec', AVERAGE, null)) "USER_CALLS/S",                                   null " " ,
  AVG(DECODE(METRIC_NAME, 'Redo Generated Per Sec', AVERAGE, null) / 1024 / 1024) "REDO_MB/S",                    null " " ,
  AVG(DECODE(METRIC_NAME, 'Average Synchronous Single-Block Read Latency', AVERAGE, null) ) "READ_LATENCY_MS",    null " " ,
  AVG(DECODE(METRIC_NAME, 'Network Traffic Volume Per Sec', AVERAGE, null) / 1024 / 1024) "NET_MB/S",             null " " ,
  AVG(DECODE(METRIC_NAME, 'Hard Parse Count Per Sec', AVERAGE, null)) "HARD_PARSE/S",                             null " " ,
  AVG(DECODE(METRIC_NAME, 'Logons Per Sec', AVERAGE, null)) "LOGONS/S",                                           null " " ,
  AVG(DECODE(METRIC_NAME, 'Database Wait Time Ratio', AVERAGE, null)) "WAIT_TOTAL_%",                             null " "
from
      DBA_HIST_SYSMETRIC_SUMMARY  DHSS
WHERE
      DHSS.GROUP_ID = 2
AND
      INSTANCE_NUMBER = sys_context ('userenv','INSTANCE')
AND
      BEGIN_TIME between sysdate - 1 - 1/24 and sysdate
--GROUP BY
--      TO_CHAR(BEGIN_TIME, 'HH24:MI:SS') || ' - ' || TO_CHAR(END_TIME, 'HH24:MI:SS')
--ORDER BY
--      TIME_INTERVAL DESC
/


select  /*+ CURSOR_SHARING_EXACT */
  TO_CHAR(BEGIN_TIME, 'HH24:MI:SS') || ' - ' || TO_CHAR(END_TIME, 'HH24:MI:SS') "TIME_INTERVAL   -1H",
  SUM(DECODE(METRIC_NAME, 'SQL Service Response Time', AVERAGE, 0))  / 10 "SQL_SERVICE_MS",                               null " " ,
  SUM(DECODE(METRIC_NAME, 'Host CPU Utilization (%)', AVERAGE, 0)) "CPU_%",                                    null " " ,
  SUM(DECODE(METRIC_NAME, 'Current OS Load', AVERAGE, 0)) "LOAD",                                              null " " ,
  SUM(DECODE(METRIC_NAME, 'Physical Read Bytes Per Sec', AVERAGE, 0)) / 1024 / 1024 "READ_MB/S",               null " " ,
  SUM(DECODE(METRIC_NAME, 'Physical Write Bytes Per Sec', AVERAGE, 0)) / 1024 / 1024 "WRITE_MB/S",             null " " ,
  SUM(DECODE(METRIC_NAME, 'User Calls Per Sec', AVERAGE, 0)) "USER_CALLS/S",                                   null " " ,
  SUM(DECODE(METRIC_NAME, 'Redo Generated Per Sec', AVERAGE, 0) / 1024 / 1024) "REDO_MB/S",                       null " " ,
  SUM(DECODE(METRIC_NAME, 'Average Synchronous Single-Block Read Latency', AVERAGE, 0) ) "READ_LATENCY_MS",               null " " ,
  SUM(DECODE(METRIC_NAME, 'Network Traffic Volume Per Sec', AVERAGE, 0) / 1024 / 1024) "NET_MB/S",             null " " ,
  SUM(DECODE(METRIC_NAME, 'Hard Parse Count Per Sec', AVERAGE, 0)) "HARD_PARSE/S",                             null " " ,
  SUM(DECODE(METRIC_NAME, 'Logons Per Sec', AVERAGE, 0)) "LOGONS/S",                             null " " ,
  SUM(DECODE(METRIC_NAME, 'Database Wait Time Ratio', AVERAGE, 0)) "WAIT_TOTAL_%",                             null " "
from
      V$SYSMETRIC_SUMMARY  VSS
WHERE
      VSS.GROUP_ID = 2
GROUP BY
  TO_CHAR(BEGIN_TIME, 'HH24:MI:SS') || ' - ' || TO_CHAR(END_TIME, 'HH24:MI:SS')
--ORDER BY
--  TIME_INTERVAL DESC
/

/*
DEBUG COLUMNS

col PCT format 9990D99
col pct_rank format 9990D99
col debug like pct
col "SQL_SERVICE_%"   like PCT
col "COMMIT/S_%"     like PCT


col "LOAD_%"         like PCT
col "LOAD_MTB"       like "LOAD"
col "LOAD_MTB_ABS"   like "LOAD"

col "READ_MB/S_%"       like PCT
col "READ_MB/S_MTB"     like "LOAD"
col "READ_MB/S_MTB_ABS" like "LOAD"

col norm2 like pct

col COMMIT/S_MTB_ABS    like pct
col MAX_ABS like pct

*/

col GRAPH format a5

select
"TIME_INTERVAL",
"SQL_SERVICE_MS"        ,
case when ("SQL_SERVICE_MS_MTB"/max("SQL_SERVICE_MS_MTB_ABS") over ()) > 0 then
    rpad('+', (("SQL_SERVICE_MS_MTB"/max("SQL_SERVICE_MS_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("SQL_SERVICE_MS_MTB"/max("SQL_SERVICE_MS_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"CPU_%"        ,
case when ("CPU_%_MTB"/max("CPU_%_MTB_ABS") over ()) > 0 then
    rpad('+', (("CPU_%_MTB"/max("CPU_%_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("CPU_%_MTB"/max("CPU_%_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"LOAD"      ,
case when ("LOAD_MTB"/max("LOAD_MTB_ABS") over ()) > 0 then
    rpad('+', (("LOAD_MTB"/max("LOAD_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("LOAD_MTB"/max("LOAD_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"READ_MB/S"    ,
case when ("READ_MB/S_MTB"/max("READ_MB/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("READ_MB/S_MTB"/max("READ_MB/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("READ_MB/S_MTB"/max("READ_MB/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"WRITE_MB/S"   ,
case when ("WRITE_MB/S_MTB"/max("WRITE_MB/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("WRITE_MB/S_MTB"/max("WRITE_MB/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("WRITE_MB/S_MTB"/max("WRITE_MB/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"USER_CALLS/S"   ,
case when ("USER_CALLS/S_MTB"/max("USER_CALLS/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("USER_CALLS/S_MTB"/max("USER_CALLS/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("USER_CALLS/S_MTB"/max("USER_CALLS/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"REDO_MB/S"    ,
case when ("REDO_MB/S_MTB"/max("REDO_MB/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("REDO_MB/S_MTB"/max("REDO_MB/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("REDO_MB/S_MTB"/max("REDO_MB/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"READ_LATENCY_MS"    ,
case when ("READ_LATENCY_MS_MTB"/nullif(max("READ_LATENCY_MS_MTB_ABS") over (),0)) > 0 then
    rpad('+', (("READ_LATENCY_MS_MTB"/nullif(max("READ_LATENCY_MS_MTB_ABS") over (),0))) *  5 ,'+')
else
    rpad('-', (("READ_LATENCY_MS_MTB"/nullif(max("READ_LATENCY_MS_MTB_ABS") over (),0))) * -5 ,'-')
end as GRAPH,
"NET_MB/S" ,
case when ("NET_MB/S_MTB"/max("NET_MB/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("NET_MB/S_MTB"/max("NET_MB/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("NET_MB/S_MTB"/max("NET_MB/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"HARD_PARSE/S",
case when ("HARD_PARSE/S_MTB"/max("HARD_PARSE/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("HARD_PARSE/S_MTB"/max("HARD_PARSE/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("HARD_PARSE/S_MTB"/max("HARD_PARSE/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"LOGONS/S",
case when ("LOGONS/S_MTB"/max("LOGONS/S_MTB_ABS") over ()) > 0 then
    rpad('+', (("LOGONS/S_MTB"/max("LOGONS/S_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("LOGONS/S_MTB"/max("LOGONS/S_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH,
"WAIT_TOTAL_%",
case when ("WAIT_TOTAL_%_MTB"/max("WAIT_TOTAL_%_MTB_ABS") over ()) > 0 then
    rpad('+', (("WAIT_TOTAL_%_MTB"/max("WAIT_TOTAL_%_MTB_ABS") over ())) *  5 ,'+')
else
    rpad('-', (("WAIT_TOTAL_%_MTB"/max("WAIT_TOTAL_%_MTB_ABS") over ())) * -5 ,'-')
end as GRAPH
from  (
   with DADOS as (
   SELECT /*+ CURSOR_SHARING_EXACT */
   TO_CHAR(BEGIN_TIME, 'HH24:MI:SS') || ' - ' || TO_CHAR(END_TIME, 'HH24:MI:SS') TIME_INTERVAL,
   NULLIF(SUM(DECODE(METRIC_NAME, 'SQL Service Response Time', VALUE, 0)/10),0) "SQL_SERVICE_MS",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Host CPU Utilization (%)', VALUE, 0)),0) "CPU_%",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Current OS Load', VALUE, 0)),0) "LOAD",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Physical Read Bytes Per Sec', VALUE, 0)),0) / 1024 / 1024 "READ_MB/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Physical Write Bytes Per Sec', VALUE, 0)),0) / 1024 / 1024 "WRITE_MB/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Logical Reads Per User Call', VALUE, 0)),0) "LOGREAD_CALLS/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'User Calls Per Sec', VALUE, 0) ),0) "USER_CALLS/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Redo Generated Per Sec', VALUE, 0) / 1024 / 1024),0) "REDO_MB/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Average Synchronous Single-Block Read Latency', VALUE, 0) ),0) "READ_LATENCY_MS",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Network Traffic Volume Per Sec', VALUE, 0) / 1024 / 1024),0) "NET_MB/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Hard Parse Count Per Sec', VALUE, 0)),0) "HARD_PARSE/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Logons Per Sec', VALUE, 0)),0) "LOGONS/S",
   NULLIF(SUM(DECODE(METRIC_NAME, 'Database Wait Time Ratio', VALUE, 0)),0) "WAIT_TOTAL_%"
   FROM
         V$SYSMETRIC_HISTORY SMH
   WHERE
        SMH.GROUP_ID = 2
--    AND  BEGIN_TIME >= sysdate-(1/24*3/4)
    AND  BEGIN_TIME >= sysdate-(2/24)
   GROUP BY
   TO_CHAR(BEGIN_TIME, 'HH24:MI:SS') || ' - ' || TO_CHAR(END_TIME, 'HH24:MI:SS')
   ORDER BY
   TIME_INTERVAL DESC
   )
   select
   TIME_INTERVAL  ,
   --, (val - MIN(val) OVER())/ ( MAX(val) OVER() - MIN(val) OVER() ) - 0.5 norm
   "SQL_SERVICE_MS"   , (("SQL_SERVICE_MS" - avg("SQL_SERVICE_MS") over () ) / avg("SQL_SERVICE_MS") over () *100 )               "SQL_SERVICE_MS_%", "SQL_SERVICE_MS"  - avg("SQL_SERVICE_MS") over ()  "SQL_SERVICE_MS_MTB", nullif(abs("SQL_SERVICE_MS"  - avg("SQL_SERVICE_MS") over () ),0) "SQL_SERVICE_MS_MTB_ABS",
   "CPU_%"     , (("CPU_%"  - avg("CPU_%") over () ) / avg("CPU_%") over () *100 )                    "CPU_%_%",  "CPU_%"  - avg("CPU_%") over ()  "CPU_%_MTB", nullif(abs("CPU_%"  - avg("CPU_%") over () ) ,0) "CPU_%_MTB_ABS",
   "LOAD"     , (("LOAD"  - avg("LOAD") over () ) / avg("LOAD") over () *100 )                    "LOAD_%",  "LOAD"  - avg("LOAD") over ()  "LOAD_MTB", nullif(abs("LOAD"  - avg("LOAD") over () ) ,0) "LOAD_MTB_ABS",
   "READ_MB/S"     , (("READ_MB/S"  - avg("READ_MB/S") over () ) / avg("READ_MB/S") over () *100 )                    "READ_MB/S_%",  "READ_MB/S"  - avg("READ_MB/S") over ()  "READ_MB/S_MTB", nullif(abs("READ_MB/S"  - avg("READ_MB/S") over () ) ,0) "READ_MB/S_MTB_ABS",
   "WRITE_MB/S"     , (("WRITE_MB/S"  - avg("WRITE_MB/S") over () ) / avg("WRITE_MB/S") over () *100 )                    "WRITE_MB/S_%",  "WRITE_MB/S"  - avg("WRITE_MB/S") over ()  "WRITE_MB/S_MTB", nullif(abs("WRITE_MB/S"  - avg("WRITE_MB/S") over () ) ,0) "WRITE_MB/S_MTB_ABS",
   "REDO_MB/S"     , (("REDO_MB/S"  - avg("REDO_MB/S") over () ) / avg("REDO_MB/S") over () *100 )                    "REDO_MB/S_%",  "REDO_MB/S"  - avg("REDO_MB/S") over ()  "REDO_MB/S_MTB", nullif(abs("REDO_MB/S"  - avg("REDO_MB/S") over () ) ,0) "REDO_MB/S_MTB_ABS",
   "USER_CALLS/S"     , (("USER_CALLS/S"  - avg("USER_CALLS/S") over () ) / avg("USER_CALLS/S") over () *100 )                    "USER_CALLS/S_%",  "USER_CALLS/S"  - avg("USER_CALLS/S") over ()  "USER_CALLS/S_MTB", nullif(abs("USER_CALLS/S"  - avg("USER_CALLS/S") over () ) ,0) "USER_CALLS/S_MTB_ABS",
   "READ_LATENCY_MS"     , (("READ_LATENCY_MS"  - avg("READ_LATENCY_MS") over () ) / avg("READ_LATENCY_MS") over () *100 )                    "READ_LATENCY_MS_%",  "READ_LATENCY_MS"  - avg("READ_LATENCY_MS") over ()  "READ_LATENCY_MS_MTB", nullif(abs("READ_LATENCY_MS"  - avg("READ_LATENCY_MS") over () ) ,0) "READ_LATENCY_MS_MTB_ABS",
   "NET_MB/S"     , (("NET_MB/S"  - avg("NET_MB/S") over () ) / avg("NET_MB/S") over () *100 )                    "NET_MB/S_%",  "NET_MB/S"  - avg("NET_MB/S") over ()  "NET_MB/S_MTB", nullif(abs("NET_MB/S"  - avg("NET_MB/S") over () ) ,0) "NET_MB/S_MTB_ABS",
   "HARD_PARSE/S"     , (("HARD_PARSE/S"  - avg("HARD_PARSE/S") over () ) / avg("HARD_PARSE/S") over () *100 )                    "HARD_PARSE/S_%",  "HARD_PARSE/S"  - avg("HARD_PARSE/S") over ()  "HARD_PARSE/S_MTB", nullif(abs("HARD_PARSE/S"  - avg("HARD_PARSE/S") over () ) ,0) "HARD_PARSE/S_MTB_ABS",
   "LOGONS/S"     , (("LOGONS/S"  - avg("LOGONS/S") over () ) / avg("LOGONS/S") over () *100 )                    "LOGONS/S_%",  "LOGONS/S"  - avg("LOGONS/S") over ()  "LOGONS/S_MTB", nullif(abs("LOGONS/S"  - avg("LOGONS/S") over () ) ,0) "LOGONS/S_MTB_ABS",
   "WAIT_TOTAL_%"     , (("WAIT_TOTAL_%"  - avg("WAIT_TOTAL_%") over () ) / avg("WAIT_TOTAL_%") over () *100 )                    "WAIT_TOTAL_%_%",  "WAIT_TOTAL_%"  - avg("WAIT_TOTAL_%") over ()  "WAIT_TOTAL_%_MTB", nullif(abs("WAIT_TOTAL_%"  - avg("WAIT_TOTAL_%") over () ) ,0) "WAIT_TOTAL_%_MTB_ABS"
   from DADOS
   ORDER BY
   TIME_INTERVAL DESC
)
/
