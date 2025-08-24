-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Localizar sessão a partir do SOPID                                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 24/08/2016                                                                   |
-- | Exemplo    : @s_sopid.sql 12345                                                           |  
-- | Arquivo    : s_sopid.sql                                                                  |
-- | Referencia : s_all.sql                                                                    |
-- | Modificacao: 1.0 - 24/08/2016 - rfsobrinho - Criação                                      |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- | "O Guina não tinha dó, se reagir, BUMMM! vira pó!"                                        |
-- +-------------------------------------------------------------------------------------------+

SET VERIFY OFF
SET TERMOUT OFF
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 's[s_sopid.sql]', action_name => 's[s_sopid.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Localizar sessao pelo SOPID                          +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT | Instancia: &current_instance                                    |d|b|a|s|o|b|r|i|n|h|o|   |
PROMPT | Versao   : 1.0                                                  +-+-+-+-+-+-+-+-+-+-+-+   |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
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
CLEAR COLUMNS 
CLEAR BREAKS 
CLEAR COMPUTES
col "SID/SERIAL" format a15  heading 'SID/SERIAL@I' justify c
col slave        format a14  heading 'SLAVE/W_CLASS' justify c
col opid         format a04  heading 'OPID' justify c
col sopid        format a08  heading 'S-OPID' justify c
col username     format a09  heading 'USERNAME' justify c
col osuser       format a09  heading 'OSUSER' justify c
col call_et      format a07  heading 'CALL_ET' justify c
col program      format a10  heading 'PROGRAM' justify c
col client_info  format a23  heading 'CLIENT_INFO' justify c
col machine      format a19  heading 'MACHINE' justify c
col logon_time   format a12  heading 'LOGON_TIME' justify c
col hold         format a06  heading 'HOLD' justify c
col sessionwait  format a24  heading 'SESSION_WAIT' justify c
col status       format a08  heading 'STATUS' justify c
col hash_value   format a10  heading 'HASH_VALUE' justify c
col CS           format a03  heading 'C-S' justify c
col sc_wait      format a06  heading 'WAIT' justify c
col SQL_ID       format a17  heading 'SQL_ID/CHILD' justify c
col module       format a07  heading 'MODULE' justify c 

SET COLSEP '|'
ACCEPT QQ_SO_PID CHAR PROMPT '>>> Informe o SO_PID da sessão desejada: '

PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT |  Buscando informações da sessão com SO_PID = &QQ_SO_PID                                  
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT

select  s.sid || ',' || s.serial#|| case when s.inst_id is not null then ',@' || s.inst_id end  as "SID/SERIAL"
,    case upper(nvl(s.server,'?'))
         when 'DEDICATED' then 'D'
         when 'SHARED'    then 'S'
         when 'POOLED'    then 'D'       -- DRCP (Database Resident Connection Pool)
		  when 'NONE'      then 'N' 
         else nvl(s.server,'?')
     end || decode(upper(s.status),'ACTIVE','-A','-I') AS CS
,--decode(upper(s.status),'ACTIVE','A','I')||' '||
 to_char(nvl((case when e.qcsid is not null then e.qcsid || ',' || e.qcserial#|| case when e.inst_id is not null then ',@' || e.inst_id end end),substr(trim(s.WAIT_CLASS),1,12)))  as SLAVE
,    to_char(p.pid)          as opid
,    to_char(p.spid)         as sopid
,    substr(substr(s.username,1,10)||decode(s.username,'SYS',SUBSTR(nvl2(s.module,' [',null)||UPPER(s.module),1,6)||nvl2(s.module,']',null)),1,9) as username
,    substr(s.osuser,1,09)   as osuser
--,    substr(s.program,1,10)  as program
,    case when instr(s.program,'(J0') > 0  then substr(s.program,instr(s.program,'(J0'),10)||'-JOB' else substr(s.program,1,10) end  as program
,    substr(s.machine, NVL(INSTR(s.machine, '\')+1, 1),19) as machine   --'
,    to_char(s.logon_time,'ddmm:hh24mi')|| 
     case when to_number(to_char((sysdate-nvl(s.last_call_et,0)/86400),'yyyymmddhh24miss'))-to_number(to_char(s.logon_time,'yyyymmddhh24miss')) > 60 then '[P]' ELSE '[*]' END as logon_time,        to_char(s.last_call_et)              as call_et
--,     decode(s.state,'WAITING','[W]','[C]')||substr((select trim(replace(replace(substr(event,1,100),'SQL*Net'),'Streams')) from gv$session_wait j where j.sid = s.sid and j.INST_ID =  s.inst_id),1,23) as sessionwait
,     decode(s.state,'WAITING',substr((select trim(replace(replace(substr(event,1,100),'SQL*Net'),'Streams')) from gv$session_wait j where j.sid = s.sid and j.INST_ID =  s.inst_id),1,24),'ON CPU') as sessionwait
,        s.sql_id||' '||SQL_CHILD_NUMBER  as sql_id
,    s.blocking_session || ',' || s.blocking_instance as hold
,        to_char(s.seconds_in_wait) as sc_wait
,     substr(SUBSTR(nvl2(s.module,'[',null)||UPPER(trim(s.module)),1,6)||nvl2(s.module,']',null),1,7) as module
from gv$session s
,        gv$process p
,    gv$px_session e
Where s.paddr       = p.addr    (+)
  and s.inst_id     = p.inst_id (+)
  --and s.status      = 'ACTIVE'   --and s.sid= 2568
  and s.inst_id     = e.inst_id (+)
  and s.sid         = e.sid     (+)
  and s.serial#     = e.serial# (+)
    and p.spid = &QQ_SO_PID
  --and s.WAIT_CLASS != 'Idle'
  --and nvl((case when e.qcsid is not null then e.qcsid || ',' || e.qcserial#|| case when e.inst_id is not null then ',@' || e.inst_id end end),substr(trim(s.WAIT_CLASS),1,13)) != 'Idle'
  and s.username is not null
order by s.status desc, decode(s.username,'SYS',to_number(s.inst_id||50000000),s.inst_id) , case when instr(SLAVE,',,@') >0 then (substr(SLAVE,3,2)||'1') when instr(SLAVE,'@') >0 then  (decode(upper(s.WAIT_CLASS),'IDLE',2,1)||substr(SLAVE,3,2)||'2') else null end, 
decode(s.username,'SYS',50000000,sc_wait), s.sql_id, s.machine, s.last_call_et
/
UNDEF QQ_SO_PID