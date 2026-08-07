SET ECHO        OFF
SET FEEDBACK    ON
SET HEADING     ON
SET LINES       220
SET PAGES       320 
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS
CLEAR BREAKS
CLEAR COMPUTES
SET COLSEP '|'


col service_name        format a15
col machine             format a25
col username            format a25
col qtde            format 999999999
col inst_id            format 999

select count(*) qtde, inst_id, service_name, substr(machine,1,20) machine --, username 
from gv$session 
where service_name not in ('SYS$BACKGROUND', 'SYS$USERS')
group by inst_id, service_name,substr(machine,1,20) --, username
 order by service_name, inst_id
/
SET LINES       220
SET PAGES       320 