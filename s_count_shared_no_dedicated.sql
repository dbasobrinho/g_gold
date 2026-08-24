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

SELECT COUNT(s.inst_id) CNT_inst_id,
       s.server,
	   s.username ,
       p.spid,
       COUNT(*) qtd_sessoes
FROM gv$session s
LEFT JOIN gv$process p
  ON s.inst_id = p.inst_id
 AND s.paddr   = p.addr
WHERE s.username <> 'SYS'
AND SERVER <> 'DEDICATED'
GROUP BY s.server, p.spid, s.username 
ORDER BY qtd_sessoes, s.server, s.username , p.spid;



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