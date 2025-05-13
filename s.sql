-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Sessoes Ativas                                                               |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 15/12/2015                                                                   |
-- | Exemplo    : @s.sql                                                                       |  
-- | Arquivo    : s.sql                                                                        |
-- | Referncia  :                                                                              |
-- | Modificacao: 2.1 - 03/08/2019 - rfsobrinho - Vizulizar MODULE no USERNAME                 |
-- |              2.2 - 24/02/2021 - rfsobrinho - Ver POOL conexao e CHILD                     |  
-- |              2.3 - 17/09/2023 - rfsobrinho - novo machine                                 |
-- |              2.4 - 17/12/2024 - rfsobrinho - Incluido o TOP SQL ATIVO:                    |
-- |              2.5 - 08/05/2025 - rfsobrinho - sessionwait incluido C = CPU e W = WAITING   |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
-- echo "@s.sql" | sqlplus -s / as sysdba | tail -n +12 | egrep -i 'APP_BOB|SESSIONWAIT'
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[s.sql]', action_name =>  's[s.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/s.sql                                     |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Sessoes Ativas                                        +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 2.5                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+

SET TERMOUT OFF;
COLUMN TOP_SQL_ATIVO NEW_VALUE TOP_SQL_ATIVO NOPRINT;
SELECT LISTAGG(qtd || ' >> ' || sql_id, '  |   ') 
       WITHIN GROUP (ORDER BY qtd DESC) AS TOP_SQL_ATIVO
FROM (
    SELECT COUNT(1) AS qtd, sql_id
    FROM (
        SELECT s.sql_id || '[' || s.sql_child_number||']' AS sql_id
        FROM gv$session s, gv$process p, gv$px_session e
        WHERE s.paddr = p.addr (+)
          AND s.inst_id = p.inst_id (+)
          AND s.status = 'ACTIVE'
          AND s.inst_id = e.inst_id (+)
          AND s.sid = e.sid (+)
          AND s.serial# = e.serial# (+)
          AND NVL(
              CASE WHEN e.qcsid IS NOT NULL THEN e.qcsid || ',' || e.qcserial# END, 
              SUBSTR(TRIM(s.WAIT_CLASS), 1, 13)
          ) != 'Idle'
          AND s.username IS NOT NULL
		  and s.sql_id is not null
    )
    GROUP BY sql_id
    HAVING COUNT(1) > 0
)
WHERE ROWNUM <= 3;
SET TERMOUT ON;

PROMPT | TOP ATIVO: &TOP_SQL_ATIVO                                                                
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
col "SID/SERIAL" format a15  HEADING 'SID/SERIAL@I'
col slave        format a16  HEADING 'SLAVE/W_CLASS'
col opid         format a04
col sopid        format a08
col username     format a10
col osuser       format a10
col call_et      format a07
col program      format a10
col client_info  format a23
col machine      format a19
col logon_time   format a13 
col hold         format a06
col sessionwait  format a26
col status       format a08
col hash_value   format a10 
col sc_wait      format a06 HEADING 'WAIT'
col SQL_ID       format a15 HEADING 'SQL_ID/CHILD'
col module       format a08 HEADING 'MODULE'
SET COLSEP '|'
select  s.sid || ',' || s.serial#|| case when s.inst_id is not null then ',@' || s.inst_id end  as "SID/SERIAL"
,decode(upper(s.status),'ACTIVE','A','I')||' '||
 to_char(nvl((case when e.qcsid is not null then e.qcsid || ',' || e.qcserial#|| case when e.inst_id is not null then ',@' || e.inst_id end end),substr(trim(s.WAIT_CLASS),1,12)))  as SLAVE
,    to_char(p.pid)          as opid
,    to_char(p.spid)         as sopid
,    substr(s.username,1,10)||decode(s.username,'SYS',SUBSTR(nvl2(s.module,' [',null)||UPPER(s.module),1,6)||nvl2(s.module,']',null)) as username
,    substr(s.osuser,1,10)   as osuser
--,    substr(s.program,1,10)  as program
,    case when instr(s.program,'(J0') > 0  then substr(s.program,instr(s.program,'(J0'),10)||'-JOB' else substr(s.program,1,10) end  as program
,    substr(s.machine, NVL(INSTR(s.machine, '\')+1, 1),19) as machine   --'
,    to_char(s.logon_time,'ddmm:hh24mi')|| 
     case when to_number(to_char((sysdate-nvl(s.last_call_et,0)/86400),'yyyymmddhh24miss'))-to_number(to_char(s.logon_time,'yyyymmddhh24miss')) > 60 then '[P]' ELSE '[NP]' END as logon_time
,        to_char(s.last_call_et)              as call_et
,     decode(s.state,'WAITING','W ','C '),substr((select trim(replace(replace(substr(event,1,100),'SQL*Net'),'Streams')) from gv$session_wait j where j.sid = s.sid and j.INST_ID =  s.inst_id),1,24) as sessionwait
,        s.sql_id||' '||SQL_CHILD_NUMBER  as sql_id
,    s.blocking_session || ',' || s.blocking_instance as hold
,        to_char(s.seconds_in_wait) as sc_wait
,     SUBSTR(nvl2(s.module,'[',null)||UPPER(trim(s.module)),1,6)||nvl2(s.module,']',null) as module
from gv$session s
,        gv$process p
,    gv$px_session e
Where s.paddr       = p.addr    (+)
  and s.inst_id     = p.inst_id (+)
  and s.status      = 'ACTIVE'   --and s.sid= 2568
  and s.inst_id     = e.inst_id (+)
  and s.sid         = e.sid     (+)
  and s.serial#     = e.serial# (+)
  --and s.WAIT_CLASS != 'Idle'
  and nvl((case when e.qcsid is not null then e.qcsid || ',' || e.qcserial#|| case when e.inst_id is not null then ',@' || e.inst_id end end),substr(trim(s.WAIT_CLASS),1,13)) != 'Idle'
  and s.username is not null
order by decode(s.username,'SYS',to_number(s.inst_id||50000000),s.inst_id) , case when instr(SLAVE,',,@') >0 then (substr(SLAVE,3,2)||'1') when instr(SLAVE,'@') >0 then  (decode(upper(s.WAIT_CLASS),'IDLE',2,1)||substr(SLAVE,3,2)||'2') else null end, 
decode(s.username,'SYS',50000000,sc_wait), s.sql_id, s.machine, s.last_call_et
/
SET FEEDBACK on


--SET COLSEP ' '