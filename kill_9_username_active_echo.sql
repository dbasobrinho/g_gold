select z.*
from(
select  
     '!kill -9 '||to_char(p.spid)         as SQL_ID
,    substr((select trim(replace(replace(substr(event,1,100),'SQL*Net'),'Streams')) from gv$session_wait j where j.sid = s.sid and j.INST_ID =  s.inst_id),1,24) as sessionwait
from gv$session s
,        gv$process p
,    gv$px_session e
Where s.paddr       = p.addr    (+)
  and s.inst_id     = p.inst_id (+)
  and s.status      = 'ACTIVE'
  and s.inst_id     = e.inst_id (+)
  and s.sid         = e.sid     (+)
  and s.serial#     = e.serial# (+)
  and s.WAIT_CLASS != 'Idle'
  and s.username = 'FPS_BOP' and s.inst_id IN (Select INSTANCE_NUMBER from v$INSTANCE)
  and nvl((case when e.qcsid is not null then e.qcsid || ',' || e.qcserial#|| case when e.inst_id is not null then ',@' || e.inst_id end end),substr(trim(s.WAIT_CLASS),1,13)) != 'Idle'
  and s.username is not null
) z
where z.sessionwait like '%&ENTER_SESSIONWAIT_LIKE%'
/
