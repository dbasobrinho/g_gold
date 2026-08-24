SET COLSEP '|'
COLUMN CNT_inst_id FORMAT 99
COLUMN server FORMAT A10
COLUMN spid FORMAT A10
COLUMN username FORMAT A30 

SET ECHO        OFF
SET FEEDBACK    ON
SET HEADING     ON
SET LINES       190 
SET PAGES       300 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF

SET COLSEP '|'

COLUMN inst_id       FORMAT 99
COLUMN sid           FORMAT 999999
COLUMN serial#       FORMAT 999999
COLUMN username      FORMAT A30
COLUMN service_name  FORMAT A44
COLUMN program       FORMAT A35
COLUMN logon_time    FORMAT A20
COLUMN status        FORMAT A10
COLUMN server        FORMAT A10

SELECT inst_id,
       sid,
       serial#,
       username,
	   server,
       service_name,
       program,
       TO_CHAR(logon_time,'DD/MM/YYYY HH24:MI:SS') logon_time,
       status
FROM gv$session
WHERE username = upper('&xxyyyzzz')
ORDER BY logon_time;

UNDEF xxyyyzzz

---   ALTER SYSTEM SET dispatchers='(PROTOCOL=TCP) (SERVICE=siscompXDB)' SCOPE=BOTH SID='*';
---   2026-02-25T11:01:48.076927-03:00
---   ALTER SYSTEM SET parallel_degree_policy='AUTO' SCOPE=BOTH SID='*';

---  while true
---  do
---    echo "===== $(date '+%d/%m/%Y %H:%M:%S') ====="
---    
---    echo "@s_count_shared_no_dedicated.sql" | sqlplus -s / as sysdba \
---    | egrep -v 'f2xb0s01bh9cy|SESSIONWAIT'
---    
---    echo "===== $(date '+%d/%m/%Y %H:%M:%S') ====="
---    sleep 5
---  done