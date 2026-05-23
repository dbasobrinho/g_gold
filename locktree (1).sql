-- |
-- +-------------------------------------------------------------------------------------------+
-- | Objetivo   : Active Locked Tree                                                           |
-- | Criador    : Roberto Fernandes Sobrinho                                                   |
-- | Data       : 25/10/2018                                                                   |
-- | Exemplo    : @locktree.sql                                                                |
-- | Arquivo    : locktree.sql                                                                 |
-- | Referencia :                                                                              |
-- | Modificacao: 2.0 - 25/10/2018 - rfsobrinho - primeira versao                              |
-- |              2.1 - 20/08/2025 - rfsobrinho - Ajuste XID e WAIT_USN/SLOT/SEQ no report     |
-- +-------------------------------------------------------------------------------------------+
-- |                                                                https://dbasobrinho.com.br |
-- +-------------------------------------------------------------------------------------------+
-- |"O Guina não tinha dó, se ragir, BUMMM! vira pó!"
-- +-------------------------------------------------------------------------------------------+
SET TERMOUT OFF;
ALTER SESSION SET NLS_DATE_FORMAT='DD-MON-YY HH24:MI:SS';
EXEC dbms_application_info.set_module( module_name => 'locktree[locktree.sql]', action_name =>  'locktree[locktree.sql]');
COLUMN current_instance NEW_VALUE current_instance NOPRINT;
SELECT rpad(sys_context('USERENV', 'INSTANCE_NAME'), 17) current_instance FROM dual;
SET TERMOUT ON;
PROMPT
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | https://github.com/dbasobrinho/g_gold/blob/main/locktree.sql                              |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | Script   : Arvore de Locks Oracle                                +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT | Instancia: &current_instance                                     |d|b|a|s|o|b|r|i|n|h|o|  |
PROMPT | Versao   : 2.2                                                   +-+-+-+-+-+-+-+-+-+-+-+  |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT
SET ECHO        OFF
SET FEEDBACK    on
SET HEADING     ON
SET LINES       210    
SET PAGES       300    
SET TERMOUT     ON
SET TIMING      OFF
SET TRIMOUT     ON
SET TRIMSPOOL   ON
SET VERIFY      OFF
CLEAR COLUMNS 
CLEAR BREAKS
CLEAR COMPUTES
SET COLSEP '|'
COLUMN level              FORMAT 9999      HEADING 'LEVEL|-'           JUSTIFY CENTER
COLUMN username           FORMAT A26       HEADING 'USERNAME|-'        JUSTIFY CENTER
COLUMN osuser             FORMAT A20       HEADING 'OSUSER|-'          JUSTIFY CENTER
COLUMN SID_SERIAL         FORMAT A16       HEADING 'SID/SERIAL|-'      JUSTIFY CENTER
COLUMN block_sid          FORMAT A12       HEADING 'SID/BLOCK|-'       JUSTIFY CENTER
COLUMN status             FORMAT A8        HEADING 'STATUS|-'          JUSTIFY CENTER
COLUMN logon_time         FORMAT A15       HEADING 'LOGON TIME|-'      JUSTIFY CENTER
COLUMN SessionWait        FORMAT A30       HEADING 'EVENT WAIT|-'      JUSTIFY CENTER
COLUMN xid                FORMAT A16       HEADING 'XID|-'             JUSTIFY CENTER
--COLUMN wait_usn           FORMAT 999999    HEADING 'WAIT|USN'          JUSTIFY CENTER
--COLUMN wait_slot          FORMAT 999999    HEADING 'WAIT|SLOT'         JUSTIFY CENTER
--COLUMN wait_seq           FORMAT 999999    HEADING 'WAIT|SEQ'          JUSTIFY CENTER
COLUMN prev_sql_id        FORMAT A13       HEADING 'SQLID PREV|-'      JUSTIFY CENTER
COLUMN sql_id             FORMAT A13       HEADING 'SQLID|-'           JUSTIFY CENTER
COLUMN last_call_et       FORMAT 99999999  HEADING 'LAST|CALL_ET'      JUSTIFY CENTER
COLUMN seconds_in_wait    FORMAT 99999999  HEADING 'SECONDS|IN_WAIT'   JUSTIFY CENTER
col RESOURCE_MAN format a01  heading 'M' justify c
SET COLSEP '|'


WITH blockers AS (
  SELECT w.inst_id    AS waiter_inst,
         w.sid        AS waiter_sid,
         h.inst_id    AS holder_inst,
         h.sid        AS holder_sid
    FROM gv$lock w,
         gv$lock h
   WHERE w.type    = 'TX'
     AND h.type    = 'TX'
     AND w.id1     = h.id1
     AND w.id2     = h.id2
     AND w.request > 0
     AND h.lmode   > 0
     AND NOT (w.sid = h.sid AND w.inst_id = h.inst_id)
)
SELECT level AS lvl,
       LPAD(' ', (level-1)*2) ||
         NVL(SUBSTR(s.username, 1, 24), '(oracle)') AS username,
       DECODE(NVL(s.resource_consumer_group, '<>'),
              'OTHER_GROUPS','o',
              '_ORACLE_BACKGROUND_GROUP_','b',
              'SYS_GROUP','s',
              ' ',' ','!') AS rm,
       SUBSTR(s.osuser, 1, 20) AS osuser,
       s.sid || ',' || s.serial# || ',@' || s.inst_id AS sid_serial,
       NVL2(b.holder_sid,
            b.holder_sid || ',@' || b.holder_inst,
            ' ') AS block_sid,
       s.status,
       TO_CHAR(s.logon_time, 'DDMMYY HH24:MI:SS') AS logon_time,
       SUBSTR(s.event, 1, 30) AS event_wait,
       NVL((SELECT RAWTOHEX(t.xid)
              FROM gv$transaction t
             WHERE t.inst_id  = s.inst_id
               AND t.ses_addr = s.saddr
               AND ROWNUM = 1),
           'N/A') AS xid,
       s.prev_sql_id,
       s.sql_id,
       s.last_call_et,
       s.seconds_in_wait AS sec_in_wait
  FROM gv$session s,
       blockers   b
 WHERE s.sid     = b.waiter_sid (+)
   AND s.inst_id = b.waiter_inst (+)
   AND s.type    = 'USER'
   AND (b.holder_sid IS NOT NULL
        OR EXISTS (SELECT 1 FROM blockers x
                    WHERE x.holder_sid  = s.sid
                      AND x.holder_inst = s.inst_id))
 CONNECT BY NOCYCLE
            PRIOR s.sid     = b.holder_sid
        AND PRIOR s.inst_id = b.holder_inst
 START WITH b.holder_sid IS NULL
        AND EXISTS (SELECT 1 FROM blockers x
                     WHERE x.holder_sid  = s.sid
                       AND x.holder_inst = s.inst_id)
 ORDER SIBLINGS BY s.sid
/
